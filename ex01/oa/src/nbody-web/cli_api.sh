#!/bin/bash

# Bash script to give the user a simple cli to run the nbody simulation and print the request time

num_bodies=$1
max_time=$2
address=$3

if [ -z "$num_bodies" ]; then
    echo "Usage: $0 <num_bodies> [max_time] [address]"
    exit 1
fi

if [ -z "$max_time" ]; then
    max_time=25
fi

if [ -z "$address" ]; then
    address="http://localhost:8000"
fi

time curl -s -X POST "${address}/api/simulate" \
    -H "Content-Type: application/json" \
    -d "{\"n\": $num_bodies, \"t_max\": $max_time}" > /dev/null