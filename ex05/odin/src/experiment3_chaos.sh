#!/bin/bash
# Task 3, step 6: many auctions with randomly injected faults (crash, partition, blip, freeze).
# Any extra arguments are passed to chaos_test.py, e.g.  ./experiment3_chaos.sh --auctions 20
cd "$(dirname "$0")"
mkdir -p results
trap 'docker compose down 2>/dev/null' EXIT

docker compose up -d --build >/dev/null 2>&1
sleep 2

SEED=${SEED:-42}
python3 -u chaos_test.py --auctions 10 --duration 15 --seed "$SEED" \
    --out "results/chaos_seed${SEED}.json" "$@" | tee "results/chaos_seed${SEED}.log"
exit "${PIPESTATUS[0]}"
