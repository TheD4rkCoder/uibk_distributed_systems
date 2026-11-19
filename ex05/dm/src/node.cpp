#define THREADED // the synchronous zoo_* API is only declared for threaded builds
#include <zookeeper/zookeeper.h>

#include <atomic>
#include <chrono>
#include <condition_variable>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <mutex>
#include <sstream>
#include <string>
#include <thread>
#include <vector>

using namespace std::chrono_literals;

constexpr auto kSessionTimeout = 10000ms;
constexpr const char *kRootPath = "/ex05";
constexpr const char *kAuctionsPath = "/ex05/auctions";

// The whole auction state lives in one znode, e.g. "open|120|A" or "closed|120|A"
// ZooKeeper's data version of that znode is the compare-and-set version
struct Auction {
	bool closed = false;
	long highestBid = 0;
	std::string highestBidder = "";
	int version = -1;
};

struct Node {
	zhandle_t *zk = nullptr;
	std::string id;
	std::string auctionPath;

	std::atomic<bool> running{true};
	std::atomic<bool> changePending{false};
	std::mutex watchMutex;
	std::condition_variable watchCondition;
};

static std::mutex g_outputMutex;

// CLARIFICATION: I've used an LLM to modify my program to have better ouptput; these helper functions (until `parse_auction`) were fully LLM-generated
static std::string timestamp()
{
	auto now = std::chrono::system_clock::now();
	long long micros = std::chrono::duration_cast<std::chrono::microseconds>(now.time_since_epoch()).count();
	char buffer[32];
	std::snprintf(buffer, sizeof buffer, "%lld.%03lld", micros / 1000000, (micros / 1000) % 1000);
	return buffer;
}

static void print_line(const std::string &line)
{
	std::lock_guard<std::mutex> lock(g_outputMutex);
	std::printf("%s\n", line.c_str());
	std::fflush(stdout);
}

static void log_line(const Node &node, const std::string &message)
{
	print_line("[" + node.id + " " + timestamp() + "] " + message);
}

static std::string trim(const std::string &text)
{
	size_t begin = text.find_first_not_of(" \t\r\n");
	if (begin == std::string::npos)
		return "";
	size_t end = text.find_last_not_of(" \t\r\n");
	return text.substr(begin, end - begin + 1);
}

static std::vector<std::string> split_on(const std::string &text, char separator)
{
	std::vector<std::string> parts;
	std::string part;
	for (char character : text) {
		if (character == separator) {
			parts.push_back(part);
			part.clear();
		} else {
			part += character;
		}
	}
	parts.push_back(part);
	return parts;
}

static Auction parse_auction(const std::string &data, int version)
{
	Auction auction;
	auction.version = version;

	std::vector<std::string> parts = split_on(data, '|');
	if (parts.size() != 3)
		return auction;

	auction.closed = parts[0] == "closed";
	auction.highestBid = std::strtol(parts[1].c_str(), nullptr, 10);
	auction.highestBidder = parts[2];
	return auction;
}

static std::string format_auction(bool closed, long bid, const std::string &bidder)
{
	return std::string(closed ? "closed" : "open") + "|" + std::to_string(bid) + "|" + bidder;
}

static std::string state_text(const Auction &auction)
{
	if (auction.closed) {
		if (auction.highestBidder.empty())
			return "closed, no winner";
		return "closed, winner " + auction.highestBidder + " with " + std::to_string(auction.highestBid);
	}
	if (auction.highestBidder.empty())
		return "open, no bids";
	return "open, highest " + std::to_string(auction.highestBid) + " by " + auction.highestBidder;
}

static bool is_connected(const Node &node)
{
	return node.zk != nullptr && zoo_state(node.zk) == ZOO_CONNECTED_STATE;
}

// Reads the authoritative auction state. ZNONODE means the auction does not exist yet.
static int read_auction(const Node &node, Auction &auction)
{
	char buffer[256];
	int length = sizeof buffer;
	struct Stat stat;
	int result = zoo_get(node.zk, node.auctionPath.c_str(), 0, buffer, &length, &stat);
	if (result != ZOK)
		return result;

	if (length < 0)
		length = 0;
	auction = parse_auction(std::string(buffer, static_cast<size_t>(length)), stat.version);
	return ZOK;
}

// Creates an empty, open auction. Returns ZNODEEXISTS if another node was faster.
static int create_auction(const Node &node)
{
	std::string data = format_auction(false, 0, "");
	char createdPath[256];
	return zoo_create(node.zk, node.auctionPath.c_str(), data.c_str(), static_cast<int>(data.size()),
	                  &ZOO_OPEN_ACL_UNSAFE, 0, createdPath, sizeof createdPath);
}

static bool ensure_path(const Node &node, const std::string &path)
{
	char createdPath[256];
	int result = zoo_create(node.zk, path.c_str(), "", 0, &ZOO_OPEN_ACL_UNSAFE, 0, createdPath, sizeof createdPath);
	if (result == ZOK || result == ZNODEEXISTS)
		return true;

	log_line(node, "cannot create " + path + ": " + std::string(zerror(result)));
	return false;
}

// Gets the auction, creating it if this is the very first bid or close.
static int get_or_create_auction(const Node &node, Auction &auction)
{
	for (int attempt = 0; attempt < 5; ++attempt) {
		int result = read_auction(node, auction);
		if (result == ZOK)
			return ZOK;
		if (result != ZNONODE)
			return result;

		result = create_auction(node);
		if (result == ZOK || result == ZNODEEXISTS)
			continue; // re-read: another node may have won the create race
		if (result == ZCONNECTIONLOSS || result == ZOPERATIONTIMEOUT)
			continue;
		return result;
	}
	return ZCONNECTIONLOSS;
}

static void watcher(zhandle_t *, int type, int state, const char *, void *context)
{
	Node *node = static_cast<Node *>(context);

	if (type == ZOO_SESSION_EVENT) {
		if (state == ZOO_CONNECTED_STATE)
			log_line(*node, "connected to ZooKeeper");
		else if (state == ZOO_CONNECTING_STATE)
			log_line(*node, "reconnecting to ZooKeeper");
		else if (state == ZOO_EXPIRED_SESSION_STATE)
			log_line(*node, "ZooKeeper session expired");
		return;
	}

	node->changePending = true;
	node->watchCondition.notify_all();
}

// Event-driven updates: the watch triggers on any change to the auction znode.
// The command interface still reads from ZooKeeper for every query.
static void watch_loop(Node &node)
{
	int lastVersion = -1;
	bool firstRead = true;

	while (node.running) {
		if (!is_connected(node)) {
			std::unique_lock<std::mutex> lock(node.watchMutex);
			node.watchCondition.wait_for(lock, 200ms, [&] { return !node.running; });
			continue;
		}

		char buffer[256];
		int length = sizeof buffer;
		struct Stat stat;
		int result = zoo_wget(node.zk, node.auctionPath.c_str(), watcher, &node, buffer, &length, &stat);

		if (result == ZOK) {
			if (length < 0)
				length = 0;
			if (!firstRead && stat.version != lastVersion) {
				Auction auction = parse_auction(std::string(buffer, static_cast<size_t>(length)), stat.version);
				log_line(node, "watch update: " + state_text(auction));
			}
			lastVersion = stat.version;
			firstRead = false;
		}

		std::unique_lock<std::mutex> lock(node.watchMutex);
		node.watchCondition.wait_for(lock, 1s, [&] { return node.changePending.load() || !node.running; });
		node.changePending = false;
	}
}

static void place_bid(Node &node, long amount)
{
	if (!is_connected(node)) {
		log_line(node, "bid " + std::to_string(amount) + " rejected: not connected to ZooKeeper");
		return;
	}
	if (amount <= 0) {
		log_line(node, "bid " + std::to_string(amount) + " rejected: bid must be positive");
		return;
	}

	int conflicts = 0;
	for (int attempt = 0; attempt < 100; ++attempt) {
		if (!is_connected(node)) {
			log_line(node, "bid " + std::to_string(amount) + " rejected: lost connection to ZooKeeper");
			return;
		}

		Auction auction;
		int result = get_or_create_auction(node, auction);
		if (result != ZOK) {
			if (result == ZCONNECTIONLOSS || result == ZOPERATIONTIMEOUT)
				continue;
			log_line(node, "bid " + std::to_string(amount) + " rejected: " + std::string(zerror(result)));
			return;
		}

		if (auction.closed) {
			log_line(node, "bid " + std::to_string(amount) + " rejected: auction already closed (" + state_text(auction)
			                   + ")");
			return;
		}
		// A retry after connection loss may find our own earlier write already committed.
		if (auction.highestBidder == node.id && auction.highestBid == amount) {
			log_line(node, "bid " + std::to_string(amount) + " accepted (already committed); " + state_text(auction));
			return;
		}
		if (amount <= auction.highestBid) {
			log_line(node, "bid " + std::to_string(amount) + " rejected: does not exceed highest "
			                   + std::to_string(auction.highestBid));
			return;
		}

		std::string data = format_auction(false, amount, node.id);
		result = zoo_set2(node.zk, node.auctionPath.c_str(), data.c_str(), static_cast<int>(data.size()),
		                  auction.version, nullptr);

		if (result == ZOK) {
			Auction committed = parse_auction(data, auction.version + 1);
			log_line(node, "bid " + std::to_string(amount) + " accepted after " + std::to_string(conflicts)
			                   + " conflict(s); " + state_text(committed));
			return;
		}
		if (result == ZBADVERSION) {
			++conflicts; // someone else wrote between our read and our compare-and-set: read again
			continue;
		}
		if (result == ZCONNECTIONLOSS || result == ZOPERATIONTIMEOUT)
			continue;
		log_line(node, "bid " + std::to_string(amount) + " rejected: " + std::string(zerror(result)));
		return;
	}
	log_line(node, "bid " + std::to_string(amount) + " rejected: too many conflicts");
}

static void close_auction(Node &node)
{
	if (!is_connected(node)) {
		log_line(node, "close rejected: not connected to ZooKeeper");
		return;
	}

	int conflicts = 0;
	for (int attempt = 0; attempt < 100; ++attempt) {
		if (!is_connected(node)) {
			log_line(node, "close rejected: lost connection to ZooKeeper");
			return;
		}

		Auction auction;
		int result = get_or_create_auction(node, auction);
		if (result != ZOK) {
			if (result == ZCONNECTIONLOSS || result == ZOPERATIONTIMEOUT)
				continue;
			log_line(node, "close rejected: " + std::string(zerror(result)));
			return;
		}

		if (auction.closed) {
			log_line(node, "close: already closed after " + std::to_string(conflicts) + " conflict(s); "
			                   + state_text(auction));
			return;
		}

		std::string data = format_auction(true, auction.highestBid, auction.highestBidder);
		result = zoo_set2(node.zk, node.auctionPath.c_str(), data.c_str(), static_cast<int>(data.size()),
		                  auction.version, nullptr);

		if (result == ZOK) {
			Auction committed = parse_auction(data, auction.version + 1);
			log_line(node, "close: " + state_text(committed) + " after " + std::to_string(conflicts) + " conflict(s)");
			return;
		}
		if (result == ZBADVERSION) {
			++conflicts;
			continue;
		}
		if (result == ZCONNECTIONLOSS || result == ZOPERATIONTIMEOUT)
			continue;
		log_line(node, "close rejected: " + std::string(zerror(result)));
		return;
	}
	log_line(node, "close rejected: too many conflicts");
}

static void query_auction(Node &node)
{
	if (!is_connected(node)) {
		log_line(node, "query rejected: not connected to ZooKeeper");
		return;
	}

	Auction auction;
	int result = read_auction(node, auction);
	if (result == ZNONODE) {
		log_line(node, "query: open, no bids (auction does not exist yet)");
		return;
	}
	if (result != ZOK) {
		log_line(node, "query rejected: " + std::string(zerror(result)));
		return;
	}
	log_line(node, "query: " + state_text(auction));
}

static bool wait_for_connection(const Node &node)
{
	for (int attempt = 0; attempt < 150; ++attempt) {
		int state = zoo_state(node.zk);
		if (state == ZOO_CONNECTED_STATE)
			return true;
		if (state == ZOO_EXPIRED_SESSION_STATE || state == ZOO_AUTH_FAILED_STATE)
			return false;
		std::this_thread::sleep_for(100ms);
	}
	return false;
}

int main()
{
	std::setvbuf(stdout, nullptr, _IOLBF, 0);
	zoo_set_debug_level(ZOO_LOG_LEVEL_ERROR); // keep the client's own log lines out of the experiment output

	std::string input;

	std::cout << "Node ID (A/B/C/...): ";
	std::getline(std::cin, input);
	std::string nodeId = trim(input);
	if (nodeId.empty()) {
		std::cerr << "node ID must not be empty\n";
		return 1;
	}

	std::cout << "Auction ID (default 1): ";
	std::getline(std::cin, input);
	std::string auctionId = trim(input);
	if (auctionId.empty())
		auctionId = "1";

	std::cout << "ZooKeeper host:port (default 127.0.0.1:2181): ";
	std::getline(std::cin, input);
	std::string hosts = trim(input);
	if (hosts.empty())
		hosts = "127.0.0.1:2181";

	Node node;
	node.id = nodeId;
	node.auctionPath = std::string(kAuctionsPath) + "/" + auctionId;
	node.zk = zookeeper_init(hosts.c_str(), watcher, static_cast<int>(kSessionTimeout.count()), nullptr, &node, 0);
	if (node.zk == nullptr) {
		std::cerr << "could not create ZooKeeper handle\n";
		return 1;
	}

	if (!wait_for_connection(node)) {
		std::cerr << "could not connect to ZooKeeper at " << hosts << "\n";
		zookeeper_close(node.zk);
		return 1;
	}

	ensure_path(node, kRootPath);
	ensure_path(node, kAuctionsPath);

	log_line(node, "connected to " + hosts + ", auction " + auctionId);

	Auction auction;
	int result = read_auction(node, auction);
	if (result == ZOK)
		log_line(node, "state: " + state_text(auction));
	else if (result == ZNONODE)
		log_line(node, "state: open, no bids (auction does not exist yet)");

	std::thread watchThread(watch_loop, std::ref(node));

	std::cout << "commands: bid <amount> | query | close | quit\n";
	std::string line;
	while (std::getline(std::cin, line)) {
		line = trim(line);
		if (line.empty())
			continue;

		std::istringstream commandStream(line);
		std::string command;
		commandStream >> command;

		if (command == "quit")
			break;
		if (command == "query") {
			query_auction(node);
		} else if (command == "close") {
			close_auction(node);
		} else if (command == "bid") {
			long amount = 0;
			if (!(commandStream >> amount) || amount <= 0)
				log_line(node, "bid rejected: usage is 'bid <positive integer>'");
			else
				place_bid(node, amount);
		} else {
			log_line(node, "unknown command: " + line);
		}
	}

	node.running = false;
	node.changePending = true;
	node.watchCondition.notify_all();
	watchThread.join();
	zookeeper_close(node.zk);
	return 0;
}
