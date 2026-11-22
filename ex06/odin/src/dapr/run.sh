#!/usr/bin/env bash
# Runs the UC2 resource reservation demo: 1 resource manager + 3 clients, each with its own Dapr sidecar.
#
# Usage: ./run.sh [--clean]
#   --clean   flush the Redis instance first (drops old pub/sub streams and state from earlier runs)
#
# Prerequisites: `dapr init` done (Redis on localhost:6379), Java 21, Maven.
# Per-process logs are written to ./logs/, combined output is shown in the terminal.

set -euo pipefail
cd "$(dirname "$0")"

NUM_CLIENTS=3
TIMEOUT_S=120
LOG_DIR=logs
RESOURCES=./config

PIDS=()

cleanup() {
    trap - EXIT INT TERM
    echo ">>> stopping all apps"
    for app in manager $(seq -f "client%g" 1 "$NUM_CLIENTS"); do
        dapr stop --app-id "$app" >/dev/null 2>&1 || true
    done
    for pid in "${PIDS[@]}"; do
        kill "$pid" 2>/dev/null || true
    done
    wait 2>/dev/null || true
}
trap cleanup EXIT INT TERM

for cmd in dapr java mvn; do
    command -v "$cmd" >/dev/null || { echo "error: '$cmd' not found on PATH" >&2; exit 1; }
done

if [[ "${1:-}" == "--clean" ]]; then
    echo ">>> flushing Redis"
    docker exec dapr_redis redis-cli FLUSHALL >/dev/null
fi

echo ">>> compiling"
mvn -q compile
CP="target/classes:$(mvn -q dependency:build-classpath -Dmdep.outputFile=/dev/stdout)"

mkdir -p "$LOG_DIR"
rm -f "$LOG_DIR"/*.log

# start_app <app-id> <main-class> [args...]
# Runs the app under its own sidecar in the background; app output goes to logs/<app-id>.log
# and is echoed to the terminal with an [app-id] prefix.
start_app() {
    local app_id=$1; shift
    local log="$LOG_DIR/$app_id.log"
    dapr run --app-id "$app_id" --resources-path "$RESOURCES" --log-level warn \
        -- java -cp "$CP" "$@" >"$log" 2>&1 &
    PIDS+=($!)
    tail -n +1 -F "$log" 2>/dev/null | sed -u "s/^/[$app_id] /" &
    PIDS+=($!)
}

# wait_for <file> <text>: blocks until <text> appears in <file> (or times out)
wait_for() {
    local file=$1 text=$2 waited=0
    until grep -q "$text" "$file" 2>/dev/null; do
        sleep 1
        waited=$((waited + 1))
        if (( waited >= TIMEOUT_S )); then
            echo "error: timed out waiting for '$text' in $file" >&2
            exit 1
        fi
    done
}

echo ">>> starting resource manager"
start_app manager uc2.ResourceManager
wait_for "$LOG_DIR/manager.log" "Resource Manager initialized"

echo ">>> starting $NUM_CLIENTS clients"
for i in $(seq 1 "$NUM_CLIENTS"); do
    start_app "client$i" uc2.Client "$i"
done

wait_for "$LOG_DIR/manager.log" "All resource requests completed"
for i in $(seq 1 "$NUM_CLIENTS"); do
    wait_for "$LOG_DIR/client$i.log" "Client $i finished"
done

sleep 1  # let the log tails flush
echo ">>> done, logs are in $LOG_DIR/"
