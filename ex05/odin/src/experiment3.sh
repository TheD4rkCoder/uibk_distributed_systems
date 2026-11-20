#!/bin/bash
# Task 3, steps 1-5: crash and restart.
# Node A (node1) runs as a long-lived process (interactive CLI fed through a FIFO), so killing
# its container really crashes a running node, including its ephemeral membership znode.
cd "$(dirname "$0")"

A="python3 /app/auction_node.py"
TMP=$(mktemp -d)
trap 'exec 3>&- 2>/dev/null; kill $(jobs -p) 2>/dev/null; rm -rf "$TMP"; docker compose down 2>/dev/null' EXIT

step() { echo; echo "=== $*"; }

# start_node_a: long-running node A, output prefixed with [A]
start_node_a() {
    rm -f "$TMP/a.fifo"; mkfifo "$TMP/a.fifo"
    docker exec -i ex05-node1 python3 -u /app/auction_node.py <"$TMP/a.fifo" 2>&1 \
        | sed -u 's/node1> //g; /^$/d; /^commands:/d; /^  /d; s/^/    [A] /' &
    exec 3>"$TMP/a.fifo"
    sleep 1.5
}
send_a() { echo "    [A] > $*"; echo "$*" >&3; sleep 1; }

docker compose up -d --build >/dev/null 2>&1
docker exec ex05-node2 $A close >/dev/null    # make sure we start from a fresh auction
docker exec ex05-node2 $A new

step "1. start nodes A and B, bid through A"
start_node_a
send_a bid alice 10
docker exec ex05-node2 $A nodes

step "2. crash node A (docker kill)"
docker kill ex05-node1 >/dev/null
exec 3>&-
sleep 7    # > session timeout (5 s): ZooKeeper expires A's session and its ephemeral znode
docker exec ex05-node2 $A nodes

step "3. node B: higher bid, then close"
docker exec ex05-node2 $A bid bob 20
docker exec ex05-node2 $A close

step "4. restart node A"
docker start ex05-node1 >/dev/null
start_node_a

step "5. node A sees the final result and cannot change it"
send_a query
send_a bid alice 500
send_a close
send_a quit
wait

step "final state as stored in ZooKeeper (read via node B)"
docker exec ex05-node2 $A dump | tail -n 1
