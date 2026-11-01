
#include <cstdlib>
#include <zenoh.hxx>

#include <iostream>
#include <mutex>
#include <set>
#include <string>
#include <thread>
#include <chrono>
#include <zenoh/api/keyexpr.hxx>
#include <zenoh/api/sample.hxx>

int main(int argc, char** argv) {
    using namespace zenoh;

    if (argc != 2) {
        std::cerr << "Usage: " << argv[0] << "<node_id>\n";
        return EXIT_FAILURE;
    }

    // Give each application instance a unique ID
    std::string node_id(argv[1]);

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

    auto on_sample_liveliness = [&peers, &peers_mutex, &own_key](const Sample& sample) {
        std::string key(sample.get_keyexpr().as_string_view());
        if (key == own_key) {
            return;
        }

        std::lock_guard<std::mutex> lock(peers_mutex);
        if (sample.get_kind() == Z_SAMPLE_KIND_PUT) {
            peers.insert(key);
            std::cout << "[JOIN] " << key << std::endl;
        } else {
            peers.erase(key);
            std::cout << "[LEAVE] " << key << std::endl;
        }
    };

    auto on_sample_subscriber = [&own_key](const Sample& sample) {
        std::string key(sample.get_keyexpr().as_string_view());
        if (key == own_key) {
            return;
        }

        std::cout << "[RECEIVED] from " << key << ": " << sample.get_payload().as_string() << std::endl; 
    };

    // subscribe to the 
    auto liveliness_subscriber = session.liveliness_declare_subscriber(
        "mesh/nodes/**",
        on_sample_liveliness,
        []() {},
        std::move(options)
    );



    // Declare  own presence
    auto token = session.liveliness_declare_token(own_key);

    auto publisher = session.declare_publisher(own_key);

    auto message_subscriber = session.declare_subscriber(
        "mesh/nodes/**",
        on_sample_subscriber,
        closures::none
    );

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

        publisher.put("Hello!");

        std::lock_guard<std::mutex> lock(peers_mutex);
        std::cout << "[PEERS] " << node_id << " sees "
                  << peers.size() << " peer(s):";
        for (const auto& peer : peers) {
            std::cout << " " << peer;
        }
        std::cout << std::endl;
    }

    return 0;
}
