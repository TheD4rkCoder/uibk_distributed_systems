// EX03 Task 3: Byzantine generals, one round of oral messages over Zenoh.
//   commander:  ./byzantine --name c --role commander --lieutenants l1,l2 [--traitor --lie l1=attack,l2=retreat]
//   lieutenant: ./byzantine --name l1 --role lieutenant --commander c --lieutenants l1,l2 [--traitor --forward-lie retreat]
// Wire format is plain text:  <round>|<from>|<order>   e.g.  0|c|attack
#include <chrono>
#include <cstdio>
#include <map>
#include <mutex>
#include <set>
#include <string>
#include <thread>
#include <vector>

#include "common.h"

using namespace std::chrono_literals;
using Clock = std::chrono::steady_clock;

static std::string me, order_arg, forward_lie, commander, role;
static bool traitor = false;
static std::map<std::string, std::string> lies;   // --lie: lieutenant -> order the traitor commander sends
static std::mutex mu;
static std::string first_value;                   // round-0 value from the commander
static std::vector<std::string> forwards;         // round-1 values

static std::string order_for(const std::string& lt) {
  if (!traitor) return order_arg;
  auto it = lies.find(lt);
  return it == lies.end() ? order_arg : it->second;   // loyal order unless told to lie
}
static std::string forward_for(const std::string& received) {
  if (traitor && !forward_lie.empty()) return forward_lie;
  return received;
}
static std::string decide(const std::vector<std::string>& v) {   // strict majority, tie -> safe order
  int attack = 0;
  for (auto& o : v) attack += (o == "attack");
  int n = static_cast<int>(v.size());
  if (2 * attack > n) return "attack";
  if (2 * (n - attack) > n) return "retreat";
  return "retreat";   // 1-1: cannot tell who lied, pick the safe order
}

int main(int argc, char** argv) {
  std::setvbuf(stdout, nullptr, _IOLBF, 0);
  std::vector<std::string> lieutenants;
  std::string connect;
  bool no_multicast = false;
  for (int i = 1; i < argc; i++) {
    std::string a = argv[i];
    if (a == "--name") me = argv[++i];
    else if (a == "--role") role = argv[++i];
    else if (a == "--commander") commander = argv[++i];
    else if (a == "--order") order_arg = check_order(argv[++i]);
    else if (a == "--traitor") traitor = true;
    else if (a == "--forward-lie") forward_lie = check_order(argv[++i]);
    else if (a == "--no-multicast") no_multicast = true;
    else if (a == "--connect") connect = argv[++i];
    else if (a == "--lie") {                       // --lie l1=attack,l2=retreat
      std::string spec = argv[++i];
      size_t pos = 0;
      while (pos < spec.size()) {
        size_t comma = spec.find(',', pos);
        std::string pair = spec.substr(pos, comma == std::string::npos ? std::string::npos : comma - pos);
        auto eq = pair.find('=');
        if (eq != std::string::npos) lies[pair.substr(0, eq)] = check_order(pair.substr(eq + 1));
        pos = (comma == std::string::npos) ? spec.size() : comma + 1;
      }
    } else if (a == "--lieutenants") {
      std::string list = argv[++i];
      size_t pos = 0;
      while (pos < list.size()) {
        size_t comma = list.find(',', pos);
        lieutenants.push_back(list.substr(pos, comma == std::string::npos ? std::string::npos : comma - pos));
        pos = (comma == std::string::npos) ? list.size() : comma + 1;
      }
    }
  }
  if (me.empty() || role.empty() || lieutenants.empty()) {
    std::fprintf(stderr, "usage: %s --name N --role commander|lieutenant --lieutenants l1,l2 ...\n", argv[0]);
    return 1;
  }
  if (order_arg.empty()) order_arg = "attack";

  try {
    auto session = zenoh::Session::open(make_config(no_multicast, connect));

    auto send = [&](const std::string& to, int round, const std::string& order) {
      session.put(zenoh::KeyExpr("ex03/byz/" + to), std::to_string(round) + "|" + me + "|" + order);
    };

    auto inbox = session.declare_subscriber(zenoh::KeyExpr("ex03/byz/" + me),
        [](zenoh::Sample& s) {
          std::string msg = s.get_payload().as_string();
          size_t p1 = msg.find('|'), p2 = msg.find('|', p1 + 1);
          if (p1 == std::string::npos || p2 == std::string::npos) return;
          int round = std::stoi(msg.substr(0, p1));
          std::string from = msg.substr(p1 + 1, p2 - p1 - 1);
          std::string order = msg.substr(p2 + 1);
          std::lock_guard<std::mutex> lock(mu);
          if (round == 0) first_value = order;
          else { forwards.push_back(order); std::printf("[%s] rx round 1 from %s: %s\n", me.c_str(), from.c_str(), order.c_str()); }
        }, zenoh::closures::none);

    zenoh::Session::LivelinessSubscriberOptions lopts;
    lopts.history = true;
    auto live_sub = session.liveliness_declare_subscriber(zenoh::KeyExpr("ex03/nodes/**"),
        [](zenoh::Sample&) {}, zenoh::closures::none, std::move(lopts));

    auto token = session.liveliness_declare_token(zenoh::KeyExpr("ex03/nodes/" + me));

    // wait until every participant's token exists (simple poll on our own liveliness get would need a query
    // callback; instead just give discovery a moment)
    std::this_thread::sleep_for(1500ms);

    if (role == "commander") {
      for (auto& lt : lieutenants) {
        std::string order = order_for(lt);
        std::printf("[%s] -> %s: %s (round 0)\n", me.c_str(), lt.c_str(), order.c_str());
        send(lt, 0, order);
      }
    } else {
      auto deadline = Clock::now() + 6s;
      for (;;) {
        { std::lock_guard<std::mutex> lock(mu); if (!first_value.empty()) break; }
        if (Clock::now() > deadline) { std::fprintf(stderr, "[%s] no order from commander\n", me.c_str()); return 1; }
        std::this_thread::sleep_for(20ms);
      }
      std::string received;
      { std::lock_guard<std::mutex> lock(mu); received = first_value; }
      std::printf("[%s] commander order: %s\n", me.c_str(), received.c_str());
      for (auto& other : lieutenants) {
        if (other == me) continue;
        std::string order = forward_for(received);
        std::printf("[%s] -> %s: %s (round 1)\n", me.c_str(), other.c_str(), order.c_str());
        send(other, 1, order);
      }
    }

    if (role == "lieutenant") {
      size_t others = lieutenants.size() - 1;
      auto deadline = Clock::now() + 2s;
      for (;;) {
        { std::lock_guard<std::mutex> lock(mu); if (forwards.size() >= others) break; }
        if (Clock::now() > deadline) break;
        std::this_thread::sleep_for(20ms);
      }
      std::vector<std::string> values;
      { std::lock_guard<std::mutex> lock(mu); values = forwards; }
      values.insert(values.begin(), first_value);   // commander's value first
      std::string list;
      for (auto& v : values) list += (list.empty() ? "" : ", ") + v;
      std::printf("[%s] holds [%s] (commander + %zu forwards) -> DECISION %s\n", me.c_str(), list.c_str(),
                  values.size() - 1, decide(values).c_str());
    }
    std::this_thread::sleep_for(500ms);   // let the last put flush before exiting
  } catch (const std::exception& e) {
    std::fprintf(stderr, "error: %s\n", e.what());
    return 1;
  }
}
