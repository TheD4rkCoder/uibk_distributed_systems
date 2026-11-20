#!/bin/bash
# Task 3: nodes with outdated local state / without ZooKeeper connectivity.
#   a) stale read:   A reads the auction, holds the stale copy while B outbids + closes, then writes
#   b) freeze:       A is frozen (docker pause) right after its read for longer than the session timeout
#   c) disconnect:   A (long-running, with a watch cache) is cut off from ZooKeeper while B
#                    outbids + closes; A must refuse operations, then see the final result on heal
cd "$(dirname "$0")"

A="python3 -u /app/auction_node.py"
TMP=$(mktemp -d)
trap 'exec 3>&- 2>/dev/null; docker exec ex05-node1 iptables -F OUTPUT 2>/dev/null; docker unpause ex05-node1 2>/dev/null; kill $(jobs -p) 2>/dev/null; rm -rf "$TMP"; docker compose down 2>/dev/null' EXIT

step() { echo; echo "=== $*"; }
fresh_auction() {
    docker exec ex05-node2 $A close >/dev/null
    docker exec ex05-node2 $A new
    docker exec ex05-node2 $A bid alice 10
}
B() { docker exec ex05-node2 $A "$@" | grep -v connected; }

docker compose up -d --build >/dev/null 2>&1

# ---------------------------------------------------------------------------
step "a) stale read: A reads, holds its copy for 4 s; meanwhile B outbids and closes"
fresh_auction
docker exec ex05-node1 $A -v --hold 4 bid carol 15 2>&1 | grep --line-buffered -E 'holding|conflict|bid|closed' | sed -u 's/^/    [A] /' &
sleep 1.5
B bid bob 20
B close
wait
B query

# ---------------------------------------------------------------------------
step "b) freeze: A reads, is paused for 8 s (> 5 s session timeout); meanwhile B outbids and closes"
fresh_auction
docker exec ex05-node1 $A -v --hold 3 bid carol 15 2>&1 | grep --line-buffered -vE "Connecting|Closing|session closed|Transition|retry policy" | sed -u 's/^/    [A] /' &
sleep 2   # A has connected and read v1, now inside its hold window
docker pause ex05-node1 >/dev/null; echo "    -- node1 paused"
B bid bob 20
B close
sleep 6.5
docker unpause ex05-node1 >/dev/null; echo "    -- node1 resumed"
wait
B query

# ---------------------------------------------------------------------------
step "c) disconnect: long-running A loses its ZooKeeper connection"
fresh_auction
rm -f "$TMP/a.fifo"; mkfifo "$TMP/a.fifo"
docker exec -i ex05-node1 python3 -u /app/auction_node.py -v <"$TMP/a.fifo" 2>&1 \
    | grep --line-buffered -vE 'kazoo|^commands:|^  ' \
    | sed -u 's/node1> //g; /^$/d; s/^/    [A] /' &
exec 3>"$TMP/a.fifo"
send_a() { echo "    [A] > $*"; echo "$*" >&3; sleep 1; }
sleep 1.5

docker exec ex05-node1 iptables -A OUTPUT -p tcp --dport 2181 -j DROP
echo "    -- node1 cut off from ZooKeeper (iptables DROP :2181)"
sleep 4          # kazoo notices missing pings -> SUSPENDED
send_a bid carol 15
send_a query
B bid bob 20
B close
sleep 3          # > session timeout in total: the server expires A's session
send_a close
docker exec ex05-node1 iptables -D OUTPUT -p tcp --dport 2181 -j DROP
echo "    -- node1 reconnected"
sleep 4          # kazoo reconnects, notices session expiry, opens a new session
send_a query
send_a bid carol 500
send_a close
send_a quit
wait

step "final state in ZooKeeper"
B dump | tail -n 3
