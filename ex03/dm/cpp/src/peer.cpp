// EX03 Task 1+2: discovery via liveliness tokens + pub/sub hellos.
//   ./peer --name A [--hello-ms 2000] [--peers-ms 5000] [--no-multicast --connect tcp/127.0.0.1:7447]
#include <chrono>
#include <cstdio>
#include <set>
#include <string>
#include <thread>

#include "common.h"

using namespace std::chrono_literals;
static std::string me;                 // set before any callback runs
static std::set<std::string> peers;    // live peers, callback-thread only (Zenoh serialises callbacks)

int main(int argc, char** argv) {
  std::setvbuf(stdout, nullptr, _IOLBF, 0);
  std::string name, connect;
  int hello_ms = 2000, peers_ms = 5000;
  bool no_multicast = false;
  for (int i = 1; i < argc; i++) {
    std::string a = argv[i];
    if (a == "--name") name = argv[++i];
    else if (a == "--hello-ms") hello_ms = std::stoi(argv[++i]);
    else if (a == "--peers-ms") peers_ms = std::stoi(argv[++i]);
    else if (a == "--no-multicast") no_multicast = true;
    else if (a == "--connect") connect = argv[++i];
  }
  if (name.empty()) { std::fprintf(stderr, "usage: %s --name A [--hello-ms N] [--peers-ms N]\n", argv[0]); return 1; }
  me = name;

  try {
    auto session = zenoh::Session::open(make_config(no_multicast, connect));

    auto hello_sub = session.declare_subscriber(zenoh::KeyExpr("ex03/hello/*"),
        [](zenoh::Sample& s) {
          std::string key(s.get_keyexpr().as_string_view());
          std::string from = key.substr(key.rfind('/') + 1);
          if (from == me) return;  // our own hello
          std::printf("[%s] hello rx from %s: %s\n", me.c_str(), from.c_str(),
                      s.get_payload().as_string().c_str());
        }, zenoh::closures::none);

    zenoh::Session::LivelinessSubscriberOptions lopts;
    lopts.history = true;  // replay tokens that already exist
    auto liv_sub = session.liveliness_declare_subscriber(zenoh::KeyExpr("ex03/nodes/**"),
        [](zenoh::Sample& s) {
          std::string key(s.get_keyexpr().as_string_view());
          std::string peer = key.substr(key.rfind('/') + 1);
          if (peer == me) return;
          if (s.get_kind() == Z_SAMPLE_KIND_PUT) { peers.insert(peer); std::printf("[%s] peer joined: %s\n", me.c_str(), peer.c_str()); }
          else                                   { peers.erase(peer);  std::printf("[%s] peer left: %s\n",  me.c_str(), peer.c_str()); }
        }, zenoh::closures::none, std::move(lopts));

    auto token = session.liveliness_declare_token(zenoh::KeyExpr("ex03/nodes/" + me));
    std::printf("[%s] announced as ex03/nodes/%s\n", me.c_str(), me.c_str());

    auto next_hello = std::chrono::steady_clock::now();
    auto next_peers = next_hello;
    while (true) {
      auto now = std::chrono::steady_clock::now();
      if (now >= next_hello) {
        session.put(zenoh::KeyExpr("ex03/hello/" + me), "Hello from Node " + me);
        std::printf("[%s] hello tx: Hello from Node %s\n", me.c_str(), me.c_str());
        next_hello = now + std::chrono::milliseconds(hello_ms);
      }
      if (now >= next_peers) {
        std::string list;
        for (auto& p : peers) list += (list.empty() ? "" : ", ") + p;
        std::printf("[%s] known peers: [%s]\n", me.c_str(), list.c_str());
        next_peers = now + std::chrono::milliseconds(peers_ms);
      }
      std::this_thread::sleep_for(50ms);
    }
  } catch (const std::exception& e) {
    std::fprintf(stderr, "error: %s\n", e.what());
    return 1;
  }
}
