#random faults: N auctions, 4 nodes bid randomly for 6s, 1 node closes in between, 1-2 other nodes get a fault
source nodes.sh
LOG=faults; N=${1:-20}
for i in 0 1 2 3 4; do on $i true || { echo "node ${NAMES[$i]} not reachable"; exit 1; }; done
rm -f $OUT/faults*; clean
for i in 0 1 2 3 4; do start $i f01 & done; wait; sleep 4
rnd() { python3 -c "import random; print(round(random.uniform($1, $2), 2))"; }
fault() {  #node, auction, start time, duration
  local v=$1 a=$2 at=$3 dur=$4
  sleep $(python3 -c "import time; print(max($at - time.time(), 0))")
  case $((RANDOM % 3)) in
    0) kill9 $v; stamp "$a (crash ${NAMES[$v]} for ${dur}s)"; sleep $dur; start $v $a; stamp "restart ${NAMES[$v]}" ;;
    1) pause $v; stamp "$a (pause ${NAMES[$v]} for ${dur}s)"; sleep $dur; resume $v ;;
    2) disconnect $v; stamp "$a (disconnect ${NAMES[$v]} for ${dur}s)"; sleep $dur; reconnect $v ;;
  esac
}
auctions=""
for n in $(seq -w 1 $N); do
  a=f$n; auctions="$auctions,$a"
  for i in 0 1 2 3 4; do cmd $i "open $a" & done; wait; sleep 1
  order=($(python3 -c "import random; l = list(range(5)); random.shuffle(l); print(*l)"))
  closer=${order[0]}
  t=$(now_plus 2)
  for i in 0 1 2 3 4; do [ $i != $closer ] && cmd $i "at $t bot 6 0.3" & done
  cmd $closer "at $(python3 -c "print($t + $(rnd 2 5))") close" &
  wait
  for k in $(seq 1 $((1 + RANDOM % 2))); do
    fault ${order[$k]} $a $(python3 -c "print($t + $(rnd 0.5 5))") $(rnd 1 8) &
  done
  wait; sleep 4
  for i in 0 1 2 3 4; do cmd $i "close" & done; wait; sleep 2
done
stop_all; fetch
cat $OUT/faults_*.log | on 0 "cat > faults_all.log"
on 0 "cat > check_auctions.py" < check_auctions.py
on 0 "python3 check_auctions.py $ZK ${auctions#,} faults_all.log" | tee $OUT/faults_check.txt
