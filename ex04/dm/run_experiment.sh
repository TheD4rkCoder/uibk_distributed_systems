#!/bin/bash
# Runs the three-node experiment and stores the logs in samples/:
#   initial election -> kill the leader -> restart it 0.45 s later.
# CLARIFICATION: I used deepseek to help me with the implementation of this script!
set -u # this option causes the shell to exit with an error if an undefined variable is used; nice for in development
cd "$(dirname "$0")"

if [ ! -x build/node ]; then
	echo "build the node first: cmake -B build -S . && cmake --build build" >&2
	exit 1
fi

rm -f .election_state_* samples/*.log
mkdir -p samples

start_node() {
	printf '%s\n' "$1" | ./build/node >> "samples/$1.log" 2>&1 & # & moves the process to the background
	echo "$1 $! $(date +%s.%N)" >> samples/events.log
}

node_of() {  # first node that logged the given message
	sed -n "s/^\[\([A-C]\) [0-9.]*\] $1.*/\1/p" samples/[ABC].log | head -1
}

echo "event start $(date +%s.%N)" >> samples/events.log
start_node A
start_node B
start_node C
sleep 0.5                                 # initial election

leader=$(node_of "elected leader")
echo "leader: $leader"
echo "event kill $leader $(date +%s.%N)" >> samples/events.log
kill "$(awk -v id="$leader" '$1 == id { print $2; exit }' samples/events.log)"
sleep 0.45                                # failure detection + re-election

echo "event restart $leader $(date +%s.%N)" >> samples/events.log
start_node "$leader"
sleep 0.3                                 # restarted node catches up

echo "event end $(date +%s.%N)" >> samples/events.log
pkill -x node
sleep 0.2
echo "logs in samples/, plot with: python3 plot.py"
