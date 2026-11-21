#!/usr/bin/env bash
# LLM generated!
# Starts three local Dapr apps, each with its own sidecar.
# Requires: `dapr init` has created Redis, and `dapr` is on PATH.
set -euo pipefail
cd "$(dirname "$0")"

mvn -q -DskipTests -Dkotlin.compiler.daemon=false compile

pids=()
cleanup() {
  for pid in "${pids[@]:-}"; do
    kill "$pid" 2>/dev/null || true
  done
}
trap cleanup EXIT INT TERM

start() {
  local app_id=$1 http_port=$2 grpc_port=$3 main_class=$4
  echo "starting $app_id (HTTP $http_port, gRPC $grpc_port)"
  dapr run \
    --app-id "$app_id" \
    --dapr-http-port "$http_port" \
    --dapr-grpc-port "$grpc_port" \
    --resources-path ./config \
    -- mvn -q exec:java -Dexec.mainClass="$main_class" &
  pids+=("$!")
}

start inventory 3501 50002 uc3.InventoryKt
start payment   3502 50003 uc3.PaymentKt
sleep 10
start coordinator 3500 50001 uc3.CoordinatorKt
coordinator_pid=$!

# The coordinator exits after its summary; inventory/payment would otherwise
# keep this script alive forever.
wait "$coordinator_pid"
