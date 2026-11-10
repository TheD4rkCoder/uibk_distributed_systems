# EX04 - Leader Election

```
terraform init
terraform apply
scp election_node.py ec2-user@<public ip>:~/    #all 3 nodes
```

`<a>`, `<b>`, `<c>` = private IPs from the terraform output, `NODES="A=<a>:6000 B=<b>:6000 C=<c>:6000"`

## 2.1 - 2.3

one terminal per node, `--start-at` = the same unix time on all three (optional)

```
python3 election_node.py A $NODES --fresh    #on A
python3 election_node.py B $NODES --fresh    #on B
python3 election_node.py C $NODES --fresh    #on C
```

2.2: `pkill -9 -f election_node.py` on the leader

2.3: start it again without `--fresh`, it reads its term and vote from state_<name>.json

## 3.1 split votes

same instant on all nodes, fixed vs random timeout

```
python3 election_node.py A $NODES --fresh --timeout 150 150 --start-at <t> --run 3
python3 election_node.py A $NODES --fresh --timeout 150 300 --start-at <t> --run 3
```

## 3.1 isolated node

```
sudo dnf install -y nftables
sudo nft -f - <<'EOF'
table inet ex04 {
  chain in { type filter hook input priority 0; udp dport 6000 drop; }
  chain out { type filter hook output priority 0; udp dport 6000 drop; }
}
EOF
sudo nft delete table inet ex04    #heal
```

logs of the runs in the report are in logs/

```
terraform destroy
```
