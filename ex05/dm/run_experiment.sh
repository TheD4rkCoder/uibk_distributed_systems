#!/usr/bin/env bash
# Runs the fault-tolerance experiments against the five app nodes and stores the
# logs and a pass/fail summary in results/. Run terraform apply and ./deploy.sh first.
set -u
cd "$(dirname "$0")"

KEY=${LABSUSER_PEM:-$HOME/Downloads/labsuser.pem}
REMOTE_USER=${REMOTE_USER:-ec2-user}
SSH_OPTIONS=${SSH_OPTIONS:-} # e.g. "-F /dev/null" when the local ssh config is unreadable
ZK_VERSION=3.9.3

zk_public=$(terraform output -json | python3 -c "import json,sys; print(json.load(sys.stdin)['zookeeper_public_ip']['value'])")
ZK_HOST=$(terraform output -json | python3 -c "import json,sys; print(json.load(sys.stdin)['zookeeper_private_ip']['value'])")":2181"
mapfile -t apps < <(terraform output -json |
	python3 -c "import json,sys; print('\n'.join(json.load(sys.stdin)['app_public_ips']['value']))")
hosts=(A:${apps[0]} B:${apps[1]} C:${apps[2]} D:${apps[3]} E:${apps[4]})

ssh_do() { # host, remote command
	ssh $SSH_OPTIONS -i "$KEY" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
		-o ConnectTimeout=10 -o LogLevel=ERROR "$REMOTE_USER@$1" "$2"
}

# Runs one node session; its commands are read from stdin (see the calls below).
start_node() { # id host auction logfile
	{
		printf '%s\n%s\n%s\n' "$1" "$3" "$ZK_HOST"
		cat
	} | ssh_do "$2" 'export LD_LIBRARY_PATH=$HOME; exec $HOME/node' > "results/$4" 2>&1
}

# Same, but keeps stdin open so the node can be killed while it is running.
hold_node() { # id host auction logfile
	{
		printf '%s\n%s\n%s\n' "$1" "$3" "$ZK_HOST"
		sleep 120
	} | ssh_do "$2" 'export LD_LIBRARY_PATH=$HOME; exec $HOME/node' > "results/$4" 2>&1 &
}

host_of() { # node id -> public ip
	local entry
	for entry in "${hosts[@]}"; do
		[ "${entry%%:*}" = "$1" ] && echo "${entry#*:}"
	done
}

pass=0
fail=0
check() { # description, then a test command
	if eval "$2"; then
		echo "PASS $1"
		pass=$((pass + 1))
	else
		echo "FAIL $1"
		fail=$((fail + 1))
	fi
}

zk_running() {
	ssh_do "$zk_public" "apache-zookeeper-$ZK_VERSION-bin/bin/zkServer.sh status" >/dev/null 2>&1
}

zk_wait() {
	for _ in $(seq 30); do
		zk_running && return 0
		sleep 1
	done
	return 1
}

mkdir -p results
rm -f results/*.log
echo "ZooKeeper $ZK_HOST, app nodes ${apps[*]}"

echo "=== 1: bids through different nodes reach the same auction state"
printf 'bid 100\nquit\n' | start_node A "$(host_of A)" 1 exp1-A-bid.log
printf 'query\nquit\n' | start_node B "$(host_of B)" 1 exp1-B-query.log
printf 'bid 90\nquit\n' | start_node D "$(host_of D)" 1 exp1-D-low.log
printf 'bid 150\nquit\n' | start_node C "$(host_of C)" 1 exp1-C-bid.log
printf 'query\nquit\n' | start_node E "$(host_of E)" 1 exp1-E-query.log
printf 'close\nquit\n' | start_node A "$(host_of A)" 1 exp1-A-close.log
printf 'bid 200\nquery\nquit\n' | start_node D "$(host_of D)" 1 exp1-D-after.log
printf 'close\nquit\n' | start_node E "$(host_of E)" 1 exp1-E-close.log

check "bid 100 accepted and visible on B" 'grep -q "accepted after 0 conflict(s); open, highest 100 by A" results/exp1-A-bid.log && grep -q "query: open, highest 100 by A" results/exp1-B-query.log'
check "lower bid 90 rejected on D" 'grep -q "does not exceed highest 100" results/exp1-D-low.log'
check "higher bid 150 accepted and visible on E" 'grep -q "open, highest 150 by C" results/exp1-E-query.log'
check "close on A declares C as winner" 'grep -q "close: closed, winner C with 150" results/exp1-A-close.log'
check "bid after close rejected" 'grep -q "bid 200 rejected: auction already closed" results/exp1-D-after.log'
check "second close does not change the result" 'grep -q "close: already closed.*closed, winner C with 150" results/exp1-E-close.log'

echo "=== 2a: five simultaneous identical bids per round"
: > results/exp2-equal.log
for round in 1 2 3 4 5; do
	amount=$((round * 100))
	for entry in "${hosts[@]}"; do
		printf 'bid %s\nquit\n' "$amount" | start_node "${entry%%:*}" "${entry#*:}" 2 "exp2-${entry%%:*}-r$round.log" &
	done
	wait
	cat results/exp2-*-r"$round".log >> results/exp2-equal.log
done
printf 'query\nquit\n' | start_node A "$(host_of A)" 2 exp2-query.log

check "exactly one accepted bid per round (5 of 25)" 'test "$(grep -c "accepted" results/exp2-equal.log)" -eq 5'
check "all other simultaneous bids rejected as not exceeding" 'test "$(grep -c "does not exceed highest" results/exp2-equal.log)" -eq 20'
check "final state is the last round's amount" 'grep -q "query: open, highest 500 by" results/exp2-query.log'

echo "=== 2b: simultaneous bids with different amounts"
: > results/exp2-mixed.log
for entry in "${hosts[@]}"; do
	case "${entry%%:*}" in
	A) amount=120 ;; B) amount=140 ;; C) amount=160 ;; D) amount=180 ;; E) amount=200 ;;
	esac
	printf 'bid %s\nquit\n' "$amount" | start_node "${entry%%:*}" "${entry#*:}" 3 "exp2-mixed-${entry%%:*}.log" &
done
wait
cat results/exp2-mixed-*.log > results/exp2-mixed.log
printf 'query\nquit\n' | start_node A "$(host_of A)" 3 exp2-mixed-query.log

check "the highest of the competing bids wins" 'grep -q "query: open, highest 200 by E" results/exp2-mixed-query.log'

echo "=== 2c: two simultaneous closes"
printf 'bid 100\nquit\n' | start_node A "$(host_of A)" 4 exp3-A-bid.log
printf 'bid 200\nquit\n' | start_node B "$(host_of B)" 4 exp3-B-bid.log
printf 'close\nquit\n' | start_node A "$(host_of A)" 4 exp3-A-close.log &
printf 'close\nquit\n' | start_node B "$(host_of B)" 4 exp3-B-close.log &
wait
cat results/exp3-*-close.log > results/exp3-closes.log

check "one close wins and the other sees the same result" 'test "$(grep -c "close: closed, winner B with 200" results/exp3-closes.log)" -eq 1 && test "$(grep -c "close: already closed" results/exp3-closes.log)" -eq 1'

echo "=== 2d: bid racing with close"
printf 'bid 100\nquit\n' | start_node A "$(host_of A)" 5 exp4-A-bid.log
printf 'close\nquit\n' | start_node C "$(host_of C)" 5 exp4-C-close.log &
printf 'bid 300\nquit\n' | start_node B "$(host_of B)" 5 exp4-B-bid.log &
wait
wait
printf 'query\nquit\n' | start_node D "$(host_of D)" 5 exp4-D-query.log

if grep -q "close: closed, winner B with 300" results/exp4-C-close.log; then
	expected="closed, winner B with 300"
else
	expected="closed, winner A with 100"
fi
check "close result is consistent with the accepted bid ($expected)" 'grep -q "query: $expected" results/exp4-D-query.log'
if grep -q "close: closed, winner B with 300" results/exp4-C-close.log; then
	check "the racing bid was committed before the close" 'grep -q "bid 300 accepted" results/exp4-B-bid.log'
else
	check "the racing bid was rejected by the close" 'grep -q "bid 300 rejected: auction already closed" results/exp4-B-bid.log'
fi

echo "=== 3: crash and restart"
hold_node A "$(host_of A)" 6 exp5-A-before.log
sleep 2
printf 'bid 100\nquit\n' | start_node A "$(host_of A)" 6 exp5-A-bid.log
hold_node A "$(host_of A)" 6 exp5-A-crash.log
sleep 2
ssh_do "$(host_of A)" 'pkill -9 -x node' >/dev/null 2>&1
sleep 0.5
printf 'bid 150\nquit\n' | start_node B "$(host_of B)" 6 exp5-B-bid.log
printf 'close\nquit\n' | start_node C "$(host_of C)" 6 exp5-C-close.log
printf 'query\nquit\n' | start_node A "$(host_of A)" 6 exp5-A-restart.log
printf 'bid 130\nclose\nquit\n' | start_node A "$(host_of A)" 6 exp5-A-after.log
wait

check "the accepted bid survived the crash" 'grep -q "close: closed, winner B with 150" results/exp5-C-close.log'
check "the restarted node reads the final state" 'grep -q "state: closed, winner B with 150" results/exp5-A-restart.log && grep -q "query: closed, winner B with 150" results/exp5-A-restart.log'
check "the restarted node cannot change the result" 'grep -q "bid 130 rejected: auction already closed" results/exp5-A-after.log && grep -q "close: already closed" results/exp5-A-after.log'

echo "=== 4: node without ZooKeeper"
{
	printf 'A\n7\n%s\n' "$ZK_HOST"
	sleep 2
	printf 'query\n'
	sleep 14
	printf 'query\nbid 600\nquit\n'
} | ssh_do "$(host_of A)" 'export LD_LIBRARY_PATH=$HOME; exec $HOME/node' > results/exp6-A.log 2>&1 &
sleep 3
ssh_do "$zk_public" "apache-zookeeper-$ZK_VERSION-bin/bin/zkServer.sh stop" >/dev/null 2>&1
wait
ssh_do "$zk_public" "apache-zookeeper-$ZK_VERSION-bin/bin/zkServer.sh start" >/dev/null 2>&1
zk_wait
printf 'query\nquit\n' | start_node B "$(host_of B)" 7 exp6-B-after.log

check "operations are rejected while ZooKeeper is unreachable" 'grep -q "query rejected: not connected to ZooKeeper" results/exp6-A.log && grep -q "bid 600 rejected" results/exp6-A.log'
check "the node works again once ZooKeeper is back" 'grep -q "query:" results/exp6-B-after.log'

echo "=== 5: five auctions with a crash in the middle"
hold_node E "$(host_of E)" 12 exp7-E-crash.log
for auction in 10 11 12 13 14; do
	for bid in 1 2 3 4 5 6; do
		index=$((RANDOM % 5))
		printf 'bid %s\nquit\n' "$((bid * 100))" |
			start_node "${hosts[index]%%:*}" "${hosts[index]#*:}" "$auction" "exp7-$auction-bid$bid.log"
	done
	printf 'close\nquit\n' | start_node A "$(host_of A)" "$auction" "exp7-$auction-close.log"
	[ "$auction" = 12 ] && ssh_do "$(host_of E)" 'pkill -9 -x node' >/dev/null 2>&1
done
sleep 1

for entry in "${hosts[@]}"; do
	for auction in 10 11 12 13 14; do
		printf 'query\nquit\n' | start_node "${entry%%:*}" "${entry#*:}" "$auction" "exp7-query-${entry%%:*}-$auction.log"
	done
done
printf 'query\nquit\n' | start_node E "$(host_of E)" 12 exp7-restart-E.log

for auction in 10 11 12 13 14; do
	# every node must report exactly the same final state for this auction
	result=$(cat results/exp7-query-*-"$auction".log | sed -n 's/.*] query: //p' | sort -u)
	check "auction $auction has one consistent result on all five nodes ($result)" \
		'test "$(printf "%s" "$result" | grep -c .)" -eq 1 && printf "%s" "$result" | grep -q "closed, winner"'
done
check "the crashed node recovers the final state of auction 12" 'grep -q "state: closed, winner" results/exp7-restart-E.log'
wait

{
	echo "passed: $pass"
	echo "failed: $fail"
} | tee results/summary.txt
[ "$fail" -eq 0 ]
