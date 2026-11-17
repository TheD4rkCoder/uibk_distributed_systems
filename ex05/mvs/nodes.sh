#ssh helpers for the experiments, addresses from the terraform output, source it in this directory
PUB=($(terraform output -json public_ips | python3 -c "import json, sys; print(*json.load(sys.stdin))"))
ZKPUB=$(terraform output -raw zookeeper_public_ip)
ZK=$(terraform output -raw zookeeper_private_ip):2181
NAMES=(A B C D E)
SSH="ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -o LogLevel=ERROR -o ControlMaster=auto -o ControlPath=/tmp/cm-ex05-%h -o ControlPersist=30m"
OUT=logs

on() { local i=$1; shift; $SSH ec2-user@${PUB[$i]} "$@"; }
idx() { case $1 in A) echo 0;; B) echo 1;; C) echo 2;; D) echo 3;; E) echo 4;; esac; }
stamp() { python3 -c "import time; t = time.time(); print('$1', time.strftime('%H:%M:%S', time.gmtime(t)) + '.%03d' % (t % 1 * 1000))" | tee -a $OUT/$LOG.events; }
now_plus() { python3 -c "import time; print(round(time.time() + $1, 3))"; }

#node i reads its commands from cmd.txt (start <i> <auction>), cmd <i> <command> appends one
start() {
  on $1 "pkill -f '[t]ail -n 0 -F cmd.txt'; touch cmd.txt"
  on $1 "nohup sh -c 'tail -n 0 -F cmd.txt | python3 -u auction_node.py ${NAMES[$1]} $ZK --auction $2 >> $LOG.log 2>&1' > /dev/null 2>&1 < /dev/null &"
}
cmd() { local i=$1; shift; on $i "echo '$*' >> cmd.txt"; }

kill9() { on $1 "pkill -9 -f '[a]uction_node.py'"; on $1 "pkill -f '[t]ail -n 0 -F cmd.txt'"; stamp "kill -9 ${NAMES[$1]}"; }
pause() { on $1 "pkill -STOP -f '[a]uction_node.py'"; stamp "pause ${NAMES[$1]}"; }
resume() { on $1 "pkill -CONT -f '[a]uction_node.py'"; stamp "resume ${NAMES[$1]}"; }
disconnect() {
  on $1 "sudo nft -f -" <<'NFT'
table inet ex05 {
  chain out { type filter hook output priority 0; tcp dport 2181 drop; }
  chain in { type filter hook input priority 0; tcp sport 2181 drop; }
}
NFT
  stamp "disconnect ${NAMES[$1]}"
}
reconnect() { on $1 "sudo nft delete table inet ex05"; stamp "reconnect ${NAMES[$1]}"; }

clean() {
  for i in 0 1 2 3 4; do on $i "pkill -CONT -f '[a]uction_node.py'; pkill -f '[a]uction_node.py'; sudo nft delete table inet ex05 2>/dev/null; rm -f *.log cmd.txt" & done; wait
  $SSH ec2-user@$ZKPUB "sudo docker exec zookeeper bin/zkCli.sh deleteall /auctions" > /dev/null 2>&1
  $SSH ec2-user@$ZKPUB "sudo docker exec zookeeper bin/zkCli.sh deleteall /members" > /dev/null 2>&1
}
stop_all() { for i in 0 1 2 3 4; do on $i "pkill -CONT -f '[a]uction_node.py'; pkill -f '[a]uction_node.py'; pkill -f '[t]ail -n 0 -F cmd.txt'; sudo nft delete table inet ex05 2>/dev/null" & done; wait; }
fetch() { for i in 0 1 2 3 4; do on $i "cat $LOG.log 2>/dev/null" > $OUT/${LOG}_${NAMES[$i]}.log & done; wait; find $OUT -name "${LOG}_*.log" -empty -delete; }
