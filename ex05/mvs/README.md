# EX05 - Fault Tolerance & Coordination

```
terraform init
terraform apply
scp auction_node.py ec2-user@<public ip>:~/    #all 5 nodes
```

`<zk>` = zookeeper_private_ip from the terraform output, the nodes only talk to zookeeper

## node

one terminal per node (A-E), commands are typed into the node

```
python3 auction_node.py A <zk>:2181 --auction bike
```

```
open <auction> [item]       #create the auction if it doesn't exist and switch to it
bid <bidder> <amount>
query
close
hold <s>                    #wait between reading and writing the state, to provoke races
at <unix time> <command>    #run a command at a given time, for simultaneous commands on several nodes
bot <s> <max gap>           #random bids for s seconds
```

## 1

bids through different nodes, then `query` on all nodes, `close` on one

## 2

`hold 0.3` on the nodes, then the same `at <t> bid ...` / `at <t> close` on several nodes

## 3

```
pkill -9 -f auction_node.py                  #crash A, restart with the same command
pkill -STOP / -CONT -f auction_node.py       #pause longer than the 4s session timeout
sudo nft -f - <<'EOF'                        #cut A off from zookeeper
table inet ex05 {
  chain out { type filter hook output priority 0; tcp dport 2181 drop; }
  chain in { type filter hook input priority 0; tcp sport 2181 drop; }
}
EOF
sudo nft delete table inet ex05              #reconnect
```

## 3.6 random faults

nodes.sh has the ssh helpers (addresses from the terraform output), faults.sh runs N auctions with random crashes, pauses and disconnects and checks the result with check_auctions.py

```
bash faults.sh 20
```

```
terraform destroy
```
