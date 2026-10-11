#!/usr/bin/env bash
# Baseline performance measurement of the g6t3 web app on EC2.
# Usage: ./bench.sh [base_url]   (default: http://localhost:8080)
# Every measurement uses bash's `time`; each configuration is repeated REPS times.

BASE=${1:-http://localhost:8080}
REPS=3
TIMEFORMAT='%R'   # `time` prints only wall-clock seconds

login() {
  curl -s -X POST "$BASE/api/auth/login" -H "Content-Type: application/json" \
    -d "{\"username\":\"$1\",\"password\":\"passwd\"}" |
    sed -E 's/.*"bearerToken":"([^"]+)".*/\1/'
}

ADMIN=$(login admin)
DEPHEAD=$(login dephead1)
SENSORS=(30001 30002 30003 30004 30011 30012 30013 30014 30021 30022
         30023 30024 30031 30032 30033 30034 30041 30042 30043 30044
         30051 30052 30053 30054 30061 30062 30063 30064 30065 30066
         30067 30068 30075 30076 30077 30078 30085 30086 30087 30088)

get() { curl -s -o /dev/null -H "Authorization: Bearer $1" "$BASE$2"; }

# Run "$@" REPS times under `time`, print the individual timings
measure() {
  local t out=""
  for _ in $(seq $REPS); do
    t=$( { time "$@" >/dev/null 2>&1; } 2>&1 )
    out="$out $t"
  done
  echo "$out"
}

echo "warm-up (JIT, connection pool)..."
for _ in $(seq 20); do get "$DEPHEAD" "/api/dashboard/department/1?days=30"; get "$ADMIN" "/api/measurements?sensorId=30001"; done

# Experiment 1: aggregation depth, 20 sequential dashboard requests per run
dashboard() { for _ in $(seq 20); do get "$DEPHEAD" "/api/dashboard/department/1?days=$1"; done; }
echo; echo "Exp 1 - dashboard, 20 requests, depth = days of history"
for d in 1 3 7 14 30; do echo "days=$d:$(measure dashboard $d)"; done

# Experiment 2: data volume, fetch all measurements of k sensors (~720 rows each)
sensors() { for s in "${SENSORS[@]:0:$1}"; do get "$ADMIN" "/api/measurements?sensorId=$s"; done; }
echo; echo "Exp 2 - measurements of k sensors (~720 rows each)"
for k in 1 5 10 20 40; do echo "k=$k:$(measure sensors $k)"; done

# Experiment 3: concurrency, 200 requests with P in flight at once
export BASE ADMIN
parallel() { seq 200 | xargs -P "$1" -I{} curl -s -o /dev/null -H "Authorization: Bearer $ADMIN" "$BASE/api/measurements?sensorId=30001"; }
echo; echo "Exp 3 - 200 requests, P parallel clients"
for p in 1 2 4 8 16; do echo "P=$p:$(measure parallel $p)"; done
