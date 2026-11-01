
#include <cstdlib>
#include <zenoh.hxx>

#include <iostream>
#include <mutex>
#include <set>
#include <string>
#include <thread>
#include <chrono>
#include <zenoh/api/bytes.hxx>
#include <zenoh/api/keyexpr.hxx>
#include <zenoh/api/publisher.hxx>
#include <zenoh/api/sample.hxx>

enum action_t {
    ATTACK,
    RETREAT
};

inline const char* ToString(action_t action) {
    switch (action) {
        case ATTACK: return "ATTACK";
        case RETREAT: return "RETREAT";
        default: return "[UNKNOWN ACTION]";
    }
}

typedef struct {
    bool is_commander;
    action_t action;
} message_t;

static_assert(std::is_trivially_copyable<message_t>::value);

using namespace zenoh;

Bytes to_bytes(const message_t& message) {
    std::vector<uint8_t> buffer(sizeof(message_t));
    memcpy(buffer.data(), &message, sizeof(message_t));
    return Bytes(std::move(buffer));
}

bool from_bytes(const Bytes& bytes, message_t& message) {
    std::vector<uint8_t> buffer = bytes.as_vector();
    if (buffer.size() != sizeof(message_t)) {
        return false;
    }
    memcpy(&message, buffer.data(), sizeof(message_t));
    return true;
}

int main(int argc, char** argv) {

    if (argc != 4) {
        std::cerr << "Usage: " << argv[0] << "<node_id> <commander> <traitor>\n";
        return EXIT_FAILURE;
    }

    // Give each application instance a unique ID
    std::string node_id(argv[1]);
    std::string commander(argv[2]);
    std::string traitor(argv[3]);
    bool is_commander;
    bool is_traitor;

    srand(42);

    if (!commander.compare("true")) {
        is_commander = true;
    }
    else if (!commander.compare("false")) {
        is_commander = false;
    }
    else {
        std::cerr << "Error: commander must be true or false, got " << commander << std::endl;
        return EXIT_FAILURE;
    }
    if (!traitor.compare("true")) {
        is_traitor = true;
    }
    else if (!traitor.compare("false")) {
        is_traitor = false;
    }
    else {
        std::cerr << "Error: traitor must be true or false, got " << traitor << std::endl;
        return EXIT_FAILURE;
    }
    


    // Open a Zenoh session.
    auto config = Config::create_default();
    auto session = Session::open(std::move(config));

    std::string own_key = "mesh/nodes/" + node_id;

    // Known peers
    std::set<std::string> peers;
    std::mutex peers_mutex;

    // Subscribe to node liveliness
    Session::LivelinessSubscriberOptions options;
    // also report nodes that were online before started
    options.history = true;
    
    auto send_to = [&session, &node_id](const std::string& receiver, message_t &message) {
        session.put("mesh/msg/" + receiver + "/" + node_id, to_bytes(message));
    };

    auto on_sample_liveliness = [&peers, &peers_mutex, &own_key](const Sample& sample) {
        std::string key(sample.get_keyexpr().as_string_view());
        std::string name = key.substr(std::string("mesh/nodes/").size());
        if (key == own_key) {
            return;
        }

        std::lock_guard<std::mutex> lock(peers_mutex);
        if (sample.get_kind() == Z_SAMPLE_KIND_PUT) {
            peers.insert(name);
            std::cout << "[JOIN] " << key << std::endl;
        } else {
            peers.erase(name);
            std::cout << "[LEAVE] " << key << std::endl;
        }
    };

    auto on_sample_subscriber = [&peers, &peers_mutex, is_traitor, send_to, is_commander](const Sample& sample) {
        std::string key(sample.get_keyexpr().as_string_view());
        std::string name = key.substr(key.rfind('/') + 1);

        message_t message;
        if (!from_bytes(sample.get_payload(), message)) {
            std::cerr << "Malformed message from " << key << std::endl;
            return;
        }
        
        std::cout << "[RECEIVED] from " << name << ": " << ToString(message.action) << std::endl; 

        // only forward message if it is from the commander, else infinite loop
        if (!message.is_commander) {
            return;
        }
        std::lock_guard<std::mutex> lock(peers_mutex);
        message.is_commander = false;

        for (const auto& peer : peers) {
            if (peer == name) {
                continue;
            }
            if (is_traitor) {
                message.action = (rand() % 2) ? ATTACK : RETREAT;
            }
            send_to(peer, message);
        }

    };

    // subscribe to the 
    auto liveliness_subscriber = session.liveliness_declare_subscriber(
        "mesh/nodes/**",
        on_sample_liveliness,
        []() {},
        std::move(options)
    );







    auto message_subscriber = session.declare_subscriber(
        "mesh/msg/"  + node_id + "/*",
        on_sample_subscriber,
        closures::none
    );

    // Declare  own presence
    auto token = session.liveliness_declare_token(own_key);
    
    std::cout << "Node " << node_id << " is online."
              << std::endl;

    // Keep the session, subscriber and token alive
    std::cout << "Listening for other nodes. Ctrl+C to exit."
              << std::endl;

    // Periodically display the discovered peers
    while (true) {
        std::this_thread::sleep_for(
            std::chrono::seconds(5)
        );

        if (!is_commander) {
            // others are just kept alive and logic is in subscriber function
            continue;
        }

        std::lock_guard<std::mutex> lock(peers_mutex);
        if (peers.size() != 2) {
            std::cout << "Must be 3 for Byzantene Scheme, currently: " << peers.size() + 1
                << std::endl;
            continue;
        }
        
        if (is_traitor) {
            std::cout << "Traitor commander\n";
            action_t action =  (rand() % 2) ? ATTACK : RETREAT;

            for (auto peer : peers) {
                message_t message {is_commander, action};
                send_to(peer, message);
                action = (action == RETREAT) ? ATTACK : RETREAT;
            }
        }
        else {
            action_t action =  (rand() % 2) ? ATTACK : RETREAT;
            
            std::cout << "Loyal commander, send " << ToString(action) << std::endl;
            
            message_t message {is_commander, action};
            for (auto peer : peers) {
                send_to(peer, message);
            }
        }


    }

    return 0;
}
