#include <zenoh.hxx>

#include <chrono>
#include <cstdio>
#include <cstring>
#include <deque>
#include <fstream>
#include <iostream>
#include <mutex>
#include <random>
#include <set>
#include <string>
#include <thread>
#include <vector>

using Clock = std::chrono::steady_clock;
using namespace std::chrono_literals;

// btw is google's style to prefix consts with `k`
// cluster size could be determined dynamically with the zenoh liveliness stuff, but I dont have more time
constexpr int kClusterSize = 3;                      // majority is 2
constexpr const char *kZenohTopic = "ex04/election"; // one key for every message
constexpr auto kHeartbeatInterval = 50ms;
constexpr auto kElectionTimeoutMin = 150ms;
constexpr auto kElectionTimeoutMax = 300ms;
// hearbeat only logs with kHeartbeatInterval >= 500ms
// constexpr auto kHeartbeatInterval = 500ms;
// constexpr auto kElectionTimeoutMin = 1s;
// constexpr auto kElectionTimeoutMax = 1500ms;

enum class Role { Follower, Candidate, Leader };

static const char *role_name(Role role)
{
	if (role == Role::Follower)
		return "follower";
	if (role == Role::Candidate)
		return "candidate";
	return "leader";
}

struct Node {
	char id;

	// persistent
	int term = 0;
	char votedFor = 0; // 0 = did not vote

	// volatile
	Role role = Role::Follower;
	char leader = 0; // 0 = unknown
	std::set<char> votes;

	Clock::time_point lastContact;
	Clock::time_point nextHeartbeat;
	std::chrono::milliseconds electionTimeout{};
};

static Clock::time_point g_start = Clock::now();
static void log(const Node &n, const std::string &msg)
{
	double t = std::chrono::duration<double>(Clock::now() - g_start).count();
	std::printf("[%c %5.3f] %s\n", n.id, t, msg.c_str());
}

static std::mt19937 g_rng(std::random_device{}());
static std::chrono::milliseconds random_timeout()
{
	std::uniform_int_distribution<int> dist(static_cast<int>(kElectionTimeoutMin.count()),
	                                        static_cast<int>(kElectionTimeoutMax.count()));
	return std::chrono::milliseconds(dist(g_rng));
}

static void load_state(Node &n)
{
	std::ifstream file(std::string(".election_state_") + n.id);
	if (!(file >> n.term >> n.votedFor))
		return; // first start
	if (n.votedFor == '-')
		n.votedFor = 0;

	std::string msg = "restored term " + std::to_string(n.term);
	if (n.votedFor != 0)
		msg += ", voted for " + std::string(1, n.votedFor);
	log(n, msg);
}

static void save_state(const Node &n)
{
	char vote = '-';
	if (n.votedFor != 0)
		vote = n.votedFor;

	// trunc means overwrite (default would be append)
	std::ofstream file(std::string(".election_state_") + n.id, std::ios::trunc);
	file << n.term << ' ' << vote << '\n';
}

static void bump_term(Node &n, int term, const std::string &reason)
{
	if (term <= n.term)
		return;

	log(n, "term " + std::to_string(n.term) + " -> " + std::to_string(term) + " (" + reason + ")");
	n.term = term;
	n.votedFor = 0;
	save_state(n);
}

// this struct is sent as raw bytes and copied back with memcpy
// The nodes run the same binary on the same machine / same type of machine,
// so I don't care about padding and byte order (just note that this could be a problem)
struct Message {
	char type; // 'R' request for votes, 'V' vote, 'H' heartbeat
	char from; // sender
	char to;   // 'V' only: the candidate being voted for
	int term;  // native byte order
};

static void send(zenoh::Session &session, const Message &m)
{
	auto data = std::string(reinterpret_cast<const char *>(&m), sizeof m);
	session.put(zenoh::KeyExpr(kZenohTopic), data);
}

static void start_election(Node &n, zenoh::Session &session)
{
	n.role = Role::Candidate;
	n.term += 1;
	n.votedFor = n.id;
	save_state(n);
	n.votes = {n.id};
	n.leader = 0;
	n.lastContact = Clock::now();
	n.electionTimeout = random_timeout();
	log(n, "election timeout -> candidate, term " + std::to_string(n.term));

	send(session, Message{'R', n.id, 0, n.term});
}

static void handle_heartbeat(Node &n, const Message &m)
{
	std::string leader = std::string(1, m.from);
	bump_term(n, m.term, "heartbeat from " + leader);

	// tecnically abusable, but idk what to do about that
	if (n.role != Role::Follower) {
		log(n, std::string("-> follower (") + role_name(n.role) + " saw heartbeat from " + leader + ")");
		n.role = Role::Follower;
	}

	n.leader = m.from;
	n.lastContact = Clock::now();

	if (kHeartbeatInterval >= 500ms) {
		log(n, "heartbeat from " + leader + ", term " + std::to_string(n.term));
	}
}

static void handle_vote_req(Node &n, const Message &m, zenoh::Session &session)
{
	// a higher term means we are behind, so drop whatever role we had
	if (m.term > n.term && n.role != Role::Follower) {
		log(n, std::string("-> follower (") + role_name(n.role) + " saw vote request in term " + std::to_string(m.term)
		           + ")");
		n.role = Role::Follower;
	}

	// m.term >= n.term:
	std::string candidate = std::string(1, m.from);
	// this also resets `votedFor` (when it's a election for a new term)
	bump_term(n, m.term, "vote request from " + candidate);

	// one vote per term, and a refusal needs no answer
	if (n.votedFor == 0 || n.votedFor == m.from) {
		if (n.votedFor == 0)
			log(n, "vote for " + candidate + " in term " + std::to_string(m.term));
		n.votedFor = m.from;
		n.leader = 0;
		n.lastContact = Clock::now(); // granting a vote also resets our timer
		save_state(n);
		send(session, Message{'V', n.id, m.from, n.term});
	}
}

static void handle_vote_resp(Node &n, const Message &m)
{
	// everyone hears every granted vote, so only count the ones addressed to this node
	if (n.role != Role::Candidate || m.to != n.id || m.term != n.term)
		return;

	n.votes.insert(m.from);
	log(n, "vote from " + std::string(1, m.from) + " (" + std::to_string(n.votes.size()) + "/"
	           + std::to_string(kClusterSize) + ")");

	if (static_cast<int>(n.votes.size()) * 2 > kClusterSize) {
		n.role = Role::Leader;
		n.leader = n.id;
		n.nextHeartbeat = Clock::now();
		log(n, "elected leader, term " + std::to_string(n.term));
	}
}

int main()
{
	// disable stdout buffering so that the log messages appear immediately
	// (if piped input/output; otherwise, stdout is line-buffered by default)
	std::setvbuf(stdout, nullptr, _IOLBF, 0);

	std::string input;
	std::cout << "Node ID (A/B/C or any char): ";
	std::getline(std::cin, input);
	if (input.size() != 1) {
		std::cerr << "node ID must be a single character\n";
		return 1;
	}

	Node n;
	n.id = input[0];
	load_state(n);
	n.lastContact = Clock::now();
	n.electionTimeout = random_timeout();
	log(n, std::string("start: ") + role_name(n.role) + ", term " + std::to_string(n.term));

	try {
		auto session = zenoh::Session::open(zenoh::Config::create_default());

		std::mutex inboxMutex;
		std::deque<Message> inbox; // fifo queue
		auto subscriber = session.declare_subscriber(
		    zenoh::KeyExpr(kZenohTopic),
		    [&](zenoh::Sample &sample) {
			    std::string data = sample.get_payload().as_string();
			    if (data.size() != sizeof(Message)) {
				    log(n, "Ignoring message \"" + data + "\" (wrong size)");
				    return;
			    }
			    Message m;
			    std::memcpy(&m, data.data(), sizeof m);
			    std::lock_guard<std::mutex> lock(inboxMutex);
			    inbox.push_back(m);
		    },
		    zenoh::closures::none);

		while (true) {
			// handle everything that arrived since the last iteration
			std::deque<Message> batch{};
			{
				std::lock_guard<std::mutex> lock(inboxMutex);
				batch.swap(inbox);
			}
			for (auto &m : batch) {
				// zenoh also delivers the node's own puts:
				if (m.from == n.id)
					continue;
				// stale message from an old term
				// e.g. an old leader that has not yet realized it is no longer the leader
				if (m.term < n.term)
					continue;
				if (m.type == 'H')
					handle_heartbeat(n, m);
				else if (m.type == 'R')
					handle_vote_req(n, m, session);
				else if (m.type == 'V')
					handle_vote_resp(n, m);
			}

			auto now = Clock::now();
			if (n.role == Role::Leader) {
				if (now >= n.nextHeartbeat) {
					send(session, Message{'H', n.id, 0, n.term});
					n.nextHeartbeat = now + kHeartbeatInterval;
					if (kHeartbeatInterval >= 500ms) {
						log(n, "heartbeat-log: still leader; term " + std::to_string(n.term));
					}
				}
			} else if (now - n.lastContact >= n.electionTimeout) {
				start_election(n, session);
			}

			std::this_thread::sleep_for(1ms);
		}
	} catch (const std::exception &e) {
		std::fprintf(stderr, "zenoh error: %s\n", e.what());
		return 1;
	}
}
