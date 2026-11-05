// Minimal Zenoh session setup for the EX03 exercises (zenoh-cpp 1.10).
#pragma once
#include <zenoh.hxx>
#include <stdexcept>
#include <string>

// Default: peer-to-peer, discovery over UDP multicast. `--no-multicast --connect tcp/...` uses a router.
inline zenoh::Config make_config(bool no_multicast, const std::string& connect) {
  auto cfg = zenoh::Config::create_default();
  if (no_multicast) cfg.insert_json5("scouting/multicast/enabled", "false");
  if (!connect.empty()) cfg.insert_json5("connect/endpoints", "[\"" + connect + "\"]");
  return cfg;
}

// "attack"/"retreat" -> enum-ish string validation (the wire format is just text).
inline std::string check_order(const std::string& o) {
  if (o != "attack" && o != "retreat") throw std::runtime_error("order must be attack or retreat");
  return o;
}
