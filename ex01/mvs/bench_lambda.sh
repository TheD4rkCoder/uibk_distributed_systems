#!/usr/bin/env bash
# Task 3.3: time the threshold recommendation endpoint (local vs. Lambda-offloaded).
# Usage: ./bench_lambda.sh <label> [base_url]
# The mode is chosen by how the app container was started (with/without APP_THRESHOLD_LAMBDA_URL).

LABEL=${1:?label required, e.g. local or lambda}
BASE=${2:-http://localhost:8080}
REPS=3
TIMEFORMAT='%R'
ROOMS=(1000 2000 2100 2200 2300 3000 3100 4000 5000 5100)

TOKEN=$(curl -s -X POST "$BASE/api/auth/login" -H "Content-Type: application/json" \
  -d '{"username":"building_manager","password":"passwd"}' | sed -E 's/.*"bearerToken":"([^"]+)".*/\1/')

recommend() { curl -s -o /dev/null -H "Authorization: Bearer $TOKEN" "$BASE/api/rooms/$1/thresholds/recommend"; }

measure() {
  local t out=""
  for _ in $(seq $REPS); do
    t=$( { time "$@" >/dev/null 2>&1; } 2>&1 )
    out="$out $t"
  done
  echo "$out"
}

echo "[$LABEL] warm-up..."
for i in $(seq 30); do recommend "${ROOMS[$((i % 10))]}"; done

# Exp A: k sequential requests, cycling through the 10 rooms (4 sensors / ~670 values each)
sequential() { for i in $(seq "$1"); do recommend "${ROOMS[$((i % 10))]}"; done; }
echo "[$LABEL] Exp A - k sequential requests"
for k in 1 10 50 100; do echo "k=$k:$(measure sequential $k)"; done

# Exp B: 100 requests with P in flight at once
export BASE TOKEN
parallel() {
  for i in $(seq 100); do echo "${ROOMS[$((i % 10))]}"; done |
    xargs -P "$1" -I{} curl -s -o /dev/null -H "Authorization: Bearer $TOKEN" "$BASE/api/rooms/{}/thresholds/recommend"
}
echo "[$LABEL] Exp B - 100 requests, P parallel"
for p in 1 4 8; do echo "P=$p:$(measure parallel $p)"; done
