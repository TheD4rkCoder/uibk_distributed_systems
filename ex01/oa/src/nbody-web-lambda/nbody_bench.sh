#!/bin/bash

# Bash script to run the nbody simulation with different parameters and measure the request time

repetitions=$1
address=$2

if [ -z "$repetitions" ] || [ -z "$address" ]; then
    echo "Usage: $0 <repetitions> <address>"
    exit 1
fi

parameters=("20" "50" "100" "150")
max_time=$3

if [ -z "$max_time" ]; then
    max_time=25
fi

output_file="nbody_bench_results.csv"

echo "n,t_max,time" > "$output_file"

for ((i=0; i<repetitions; i++)); do
    for num_bodies in "${parameters[@]}"; do
        echo "Running simulation with n=$num_bodies, t_max=$max_time (Iteration $((i+1)))"

        (
        request_time=$(curl -s -X POST "${address}/api/simulate" \
            -H "Content-Type: application/json" \
            -d "{\"n\": $num_bodies, \"t_max\": $max_time}" \
            -o /dev/null -w "%{time_total}")
        echo "$num_bodies,$max_time,$request_time" >> "$output_file"
        ) &
    done
    wait
done
