#!/usr/bin/env bash
# Fetch the zenoh-c runtime + zenoh-cpp headers (no system install needed).
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p .vendor && cd .vendor
[ -f zenohc/lib/libzenohc.so ] || { curl -sSL -o zenohc.zip https://github.com/eclipse-zenoh/zenoh-c/releases/download/1.10.2/zenoh-c-1.10.2-x86_64-unknown-linux-gnu-standalone.zip && unzip -oq zenohc.zip -d zenohc; }
[ -f zenohcpp/include/zenoh.hxx ] || { curl -sSL -o zenohcpp.zip https://github.com/eclipse-zenoh/zenoh-cpp/releases/download/1.10.2/zenohcpp-1.10.2-standalone.zip && unzip -oq zenohcpp.zip -d zenohcpp; }
echo "vendor ready"
