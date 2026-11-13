#include "leader_election.hpp"
#include <cstdlib>
#include <zenoh.hxx>

#include <iostream>
#include <mutex>
#include <set>
#include <string>
#include <thread>
#include <chrono>
#include <zenoh/api/sample.hxx>
#include <ctime>
#include <iomanip>

// Code was written by me except stated otherwise, 
// with exception of the logging information, which was ai generated

// log every n-th heartbeat (sent / received) so the output stays readable
constexpr int HEARTBEAT_LOG_EVERY = 10;

static const char* role_name(ROLE role) {
    switch (role) {
        case ROLE::FOLLOWER:  return "FOLLOWER";
        case ROLE::CANDIDATE: return "CANDIDATE";
        case ROLE::LEADER:    return "LEADER";
    }
    return "?";
}

// prints: [HH:MM:SS.mmm] [<node> | term <t> | <ROLE>] <msg>
static void log(const node_id_t& node, int term, ROLE role, const std::string& msg) {
    static std::mutex log_mutex;
    using namespace std::chrono;
    auto now = system_clock::now();
    std::time_t t = system_clock::to_time_t(now);
    auto ms = duration_cast<milliseconds>(now.time_since_epoch()).count() % 1000;
    std::tm tm{};
    localtime_r(&t, &tm);

    std::lock_guard<std::mutex> lock(log_mutex);
    std::cout << "[" << std::put_time(&tm, "%H:%M:%S") << "."
              << std::setfill('0') << std::setw(3) << ms << std::setfill(' ') << "] "
              << "[" << node << " | term " << term << " | " << role_name(role) << "] "
              << msg << std::endl;
}


int main(int argc, char** argv) {
    using namespace zenoh;

    if (argc != 2) {
        std::cerr << "Usage: " << argv[0] << " <node_id>\n";
        return EXIT_FAILURE;
    }

    // Give each application instance a unique ID
    int seed = std::hash<std::string>{}(argv[1]);
    srand(seed);
    node_id_t node_id(argv[1]);
    State state(node_id);
    std::mutex state_mutex;

    // Open a Zenoh session.
    auto config = Config::create_default();
    auto session = Session::open(std::move(config));

    std::string own_key = "mesh/nodes/" + node_id;
    std::string heartbeat_key = "mesh/heartbeat";
    std::string receive_vote_key = "mesh/receive_vote/" + node_id;
    std::string request_vote_key = "mesh/request_vote";


    // check if a heartbeat has been sent
    bool received_heartbeat = false;
    std::mutex heartbeat_mutex;

    // Known peers
    std::set<node_id_t> peers;

    int votes = 0;
    std::mutex votes_mutex;


    // Subscribe to node liveliness
    Session::LivelinessSubscriberOptions options;
    // also report nodes that were online before started
    options.history = true;

    auto on_sample_liveliness = [&peers,  &own_key](const Sample& sample) {
        std::string key(sample.get_keyexpr().as_string_view());
        if (key == own_key) {
            return;
        }

        if (sample.get_kind() == Z_SAMPLE_KIND_PUT) {
            peers.insert(key);
            std::cout << "[JOIN] " << key << std::endl;
        } else {
            peers.erase(key);
            std::cout << "[LEAVE] " << key << std::endl;
        }
    };

    int heartbeats_received = 0;

    auto on_sample_heartbeat = [&state, &state_mutex, &received_heartbeat, &heartbeat_mutex, &heartbeats_received](const Sample& sample) {
        message_t message;
        if (!from_bytes(sample.get_payload(),message)) {
            std::cerr << "Failed to read bytes";
            return;
        }
        if (message.id == state.id) {
            // ignore own heartbeat
            return;
        }
        std::unique_lock<std::mutex> state_lock(state_mutex);
        if (state.get_current_term() < message.term) {
            log(state.id, state.get_current_term(), state.role,
                "[HEARTBEAT] from " + message.id + " has newer term " + std::to_string(message.term) + ", updating term");
            state.change_current_term(message.term);
        }
        if (state.get_current_term() > message.term) {
            log(state.id, state.get_current_term(), state.role,
                "[HEARTBEAT] ignored stale heartbeat from " + message.id + " (term " + std::to_string(message.term) + ")");
            return;
        }
        if (state.role != ROLE::FOLLOWER) {
            log(state.id, state.get_current_term(), state.role,
                "[STATE] " + std::string(role_name(state.role)) + " -> FOLLOWER (heartbeat from " + message.id + ")");
            state.role = ROLE::FOLLOWER;
        }
        if (++heartbeats_received % HEARTBEAT_LOG_EVERY == 1) {
            log(state.id, state.get_current_term(), state.role,
                "[HEARTBEAT] received from leader " + message.id + " (" + std::to_string(heartbeats_received) + " total)");
        }
        state_lock.unlock();
        std::lock_guard<std::mutex> heartbeat_lock(heartbeat_mutex);
        received_heartbeat = true;
    };

    auto on_sample_vote_request = [&state, &state_mutex, &session](const Sample& sample) {
        message_t message;
        if (!from_bytes(sample.get_payload(),message)) {
            std::cerr << "Failed to read bytes";
            return;
        }

        std::lock_guard<std::mutex> lock(state_mutex);
        // older term message
        if (message.term <= state.get_current_term()) {
            if (message.id != state.id) {
                log(state.id, state.get_current_term(), state.role,
                    "[VOTE] rejected request from " + message.id + " (term " + std::to_string(message.term)
                    + " not newer than ours)");
            }
            return;
        }
        // new term
        state.change_current_term(message.term);
        // already voted for someone else
        if (!state.voted_for.empty()) {
            log(state.id, state.get_current_term(), state.role,
                "[VOTE] rejected request from " + message.id + " (already voted for " + state.voted_for + ")");
            return;
        }
        if (state.role != ROLE::FOLLOWER) {
            log(state.id, state.get_current_term(), state.role,
                "[STATE] " + std::string(role_name(state.role)) + " -> FOLLOWER (newer term from " + message.id + ")");
            state.role = ROLE::FOLLOWER;
        }
        state.voted_for = message.id;
        log(state.id, state.get_current_term(), state.role, "[VOTE] granted vote to " + message.id);
        // send message to candidate
        session.put("mesh/receive_vote/" + message.id, to_bytes(message));
    };

    auto on_sample_vote_received = [&state, &state_mutex, &peers, &votes, &votes_mutex](const Sample& sample) {
        message_t message;
        if (!from_bytes(sample.get_payload(),message)) {
            std::cerr << "Failed to read bytes";
            return;
        }
        // not a candidate or wrong term or id does not match
        std::lock_guard<std::mutex> state_lock(state_mutex);
        if (state.role != ROLE::CANDIDATE
            || state.get_current_term() != message.term
            || state.id != message.id) {
            log(state.id, state.get_current_term(), state.role,
                "[VOTE] ignored vote for " + message.id + " in term " + std::to_string(message.term)
                + " (not a candidate in that term)");
            return;
        }

        std::lock_guard<std::mutex> votes_lock(votes_mutex);
        votes++;
        log(state.id, state.get_current_term(), state.role,
            "[VOTE] received vote (" + std::to_string(votes) + " of " + std::to_string(peers.size() + 1)
            + " nodes, need more than " + std::to_string((peers.size() + 1) / 2) + ")");
        if (votes > (peers.size()+1)/2) {
            state.role = ROLE::LEADER;
            log(state.id, state.get_current_term(), state.role,
                "[STATE] CANDIDATE -> LEADER with " + std::to_string(votes) + " votes");
        }
    };

    // subscribe to the
    auto subscriber_liveliness = session.liveliness_declare_subscriber(
        "mesh/nodes/**",
        on_sample_liveliness,
        []() {},
        std::move(options)
    );

    // subscribe to heartbeats from the leader
    auto subscriber_heartbeat = session.declare_subscriber(
        heartbeat_key,
        on_sample_heartbeat,
        []() {}
    );

    // subscribe to vote requests from candidates
    auto subscriber_vote_request = session.declare_subscriber(
        request_vote_key,
        on_sample_vote_request,
        []() {}
    );

    // subscribe to votes addressed to this node
    auto subscriber_vote_received = session.declare_subscriber(
        receive_vote_key,
        on_sample_vote_received,
        []() {}
    );


    // Declare  own presence
    auto token = session.liveliness_declare_token(own_key);

    std::cout << "Node " << node_id << " is online."
              << std::endl;

    // Keep the session, subscriber and token alive
    std::cout << "Listening for other nodes. Ctrl+C to exit."
              << std::endl;

    int heartbeats_sent = 0;

    while (true) {
        std::unique_lock<std::mutex> state_lock(state_mutex);
        ROLE current_role = state.role;
        node_id_t id = state.id;
        int current_term = state.get_current_term();
        state_lock.unlock();
        if (current_role == ROLE::LEADER) {
            if (heartbeats_sent++ % HEARTBEAT_LOG_EVERY == 0) {
                log(id, current_term, current_role,
                    "[HEARTBEAT] sending heartbeat (" + std::to_string(heartbeats_sent) + " sent)");
            }
            session.put(heartbeat_key, to_bytes({id, current_term}));
            std::this_thread::sleep_for(
                std::chrono::milliseconds(200)
            );
            continue;
        }

        std::this_thread::sleep_for(
            std::chrono::milliseconds(800 + rand() % 800)
        );
        std::unique_lock<std::mutex> heartbeat_lock(heartbeat_mutex);
        if (received_heartbeat) {
            received_heartbeat = false;
            heartbeat_lock.unlock();
            continue;
        }
        heartbeat_lock.unlock();
        // start election
        std::unique_lock<std::mutex> votes_lock(votes_mutex);
        votes = 1;
        votes_lock.unlock();

        state_lock.lock();
        log(state.id, state.get_current_term(), state.role, "[TIMEOUT] no heartbeat received, starting election");
        int new_term = state.inc_current_term();
        state.role = ROLE::CANDIDATE;
        state.voted_for = state.id;
        current_role = state.role;
        log(state.id, new_term, state.role, "[VOTE] voted for self, sending vote request");
        state_lock.unlock();
        session.put(request_vote_key,
            to_bytes({id, new_term}));
        
        int count = 0;
        int random_wait = 10 + rand() % 10;
        while (current_role == ROLE::CANDIDATE) {
            std::this_thread::sleep_for(
                std::chrono::milliseconds(50)
            );
            state_lock.lock();
            current_role = state.role;
            state_lock.unlock();
            if (count++ > random_wait) {
                state_lock.lock();
                state.role = ROLE::FOLLOWER; // election failed, go back to follower
                log(state.id, state.get_current_term(), state.role, "[TIMEOUT] election failed, no majority votes received");
                state_lock.unlock();
            }
        }

    }

    return 0;
}
