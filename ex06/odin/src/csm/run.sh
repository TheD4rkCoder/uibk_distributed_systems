#!/usr/bin/env bash
# Runs the UC2 resource reservation demo on Cirrina: etcd + Zenoh + 1 resource manager + 3 clients,
# each Cirrina instance in its own container (see config/docker-compose.yml).
#
# Usage: ./run.sh
# Prerequisites: Docker with the compose plugin.
# Combined CSML log output is shown in the terminal and written to ./logs/run.log.
# The stack is torn down (incl. etcd data) on exit, so every run starts from fresh persistent state.

set -euo pipefail
cd "$(dirname "$0")"

COMPOSE=(docker compose -f config/docker-compose.yml -p uc2-csml)
TIMEOUT_S=120
LOG_DIR=logs
LOG="$LOG_DIR/run.log"

command -v docker >/dev/null || { echo "error: 'docker' not found on PATH" >&2; exit 1; }

cleanup() {
    trap - EXIT INT TERM
    echo ">>> stopping containers"
    "${COMPOSE[@]}" down --remove-orphans -t 2 >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

mkdir -p "$LOG_DIR"
: >"$LOG"

echo ">>> starting etcd, zenoh, resource manager and 3 clients"
"${COMPOSE[@]}" down --remove-orphans -t 2 >/dev/null 2>&1 || true   # fresh etcd state
"${COMPOSE[@]}" up -d --force-recreate

# Follow the Cirrina containers' logs (etcd/zenoh are noisy and left out).
"${COMPOSE[@]}" logs -f --no-color manager client1 client2 client3 >"$LOG" 2>&1 &
LOGS_PID=$!
tail -n +1 -F "$LOG" 2>/dev/null &
TAIL_PID=$!

waited=0
until grep -q "All resource requests completed" "$LOG"; do
    sleep 1
    waited=$((waited + 1))
    if (( waited >= TIMEOUT_S )); then
        echo "error: timed out after ${TIMEOUT_S}s waiting for 'All resource requests completed'" >&2
        kill "$LOGS_PID" "$TAIL_PID" 2>/dev/null || true
        exit 1
    fi
done

sleep 2   # let the last client/manager log lines arrive
kill "$LOGS_PID" "$TAIL_PID" 2>/dev/null || true
echo ">>> done after ~${waited}s, full log in $LOG"
