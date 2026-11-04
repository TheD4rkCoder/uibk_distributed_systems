# EX03 - Network Topologies, Peer Discovery & Byzantine Agreement

```
terraform init
terraform apply
scp *.py ec2-user@<public ip>:~/    #all 4 nodes
```

`<router>` = router_private_ip from the terraform output, no node address is configured anywhere

## 1.1 / 1.2

```
python3 peer_node.py A tcp/<router>:7447    #node 1
python3 peer_node.py B tcp/<router>:7447    #node 2, ctrl+c and start again for 1.2
python3 peer_node.py C tcp/<router>:7447    #node 3
```

## 2.1

```
python3 pubsub_node.py A tcp/<router>:7447
python3 pubsub_node.py B tcp/<router>:7447
python3 pubsub_node.py C tcp/<router>:7447
```

## 3.2

start the lieutenants first, add `--traitor` to the commander for the second experiment

```
python3 byzantine_node.py L1 --role lieutenant --nodes 3 --connect tcp/<router>:7447
python3 byzantine_node.py L2 --role lieutenant --nodes 3 --connect tcp/<router>:7447
python3 byzantine_node.py C --role commander --order attack --nodes 3 --connect tcp/<router>:7447
```

## 3.3

same with `--nodes 4` and a third lieutenant L3, `--traitor` on the commander or on one lieutenant

```
python3 byzantine_node.py L3 --role lieutenant --nodes 4 --connect tcp/<router>:7447
```

```
terraform destroy
```
