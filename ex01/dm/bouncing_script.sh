#!/usr/bin/env bash
set -uo pipefail

SRC=${SRC:-bouncing_dvd.cpp}
BIN=${BIN:-./solver}
CSV=${CSV:-results.csv}

[ -f "$SRC" ] || { echo "error: $SRC not found in $(pwd)"; exit 1; }
g++ -O2 -std=c++17 -o "$BIN" "$SRC" || { echo "compile failed"; exit 1; }
echo "built $BIN"

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

gen() {
    printf "%s %s %s\n%s %s %s %s\n%s %s\n" \
        "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9" "${10}" > "$TMP/$1.txt"
}

gen s1_light    100000      100001      10000000000    0 0 1 1 50000      50000
gen s2_medium   1000000     1000001     100000000000   0 0 1 1 500000     500000
gen s3_heavy    5000000     5000001     1000000000000  0 0 1 1 2500000    2500000
gen s4_extreme  100000000   1000        10000000000    0 0 1 1 50000000   500
gen s5_insane   1000000000  1000        10000000000    0 0 1 1 500000000  500

printf "case,wall_s,max_rss_kb,output\n" > "$CSV"
for f in "$TMP"/*.txt; do
    name=$(basename "$f" .txt)
    /usr/bin/time -f "%e,%M" -o "$TMP/$name.stat" \
        "$BIN" < "$f" > "$TMP/$name.out" 2>/dev/null
    IFS=, read -r wall rss < "$TMP/$name.stat"
    out=$(tr -d '[:space:]' < "$TMP/$name.out")
    printf "%-14s wall=%-8ss rss=%-8s out=%s\n" "$name" "$wall" "$rss" "$out"
    printf "%s,%s,%s,%s\n" "$name" "$wall" "$rss" "$out" >> "$CSV"
done