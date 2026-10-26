# EX02 Report: Shared State

**Student Name:** Maurits van Staalduinen  
**Student ID:** `c9881018`  

---

## Task 1 - Replicated Counter

### 1.1 - Max-Based Synchronization

> Implement a program in which each node sends its counter to the other node. When receiving a counter value, the node updates its own counter using `counter = max(local_counter, received_counter)`. Demonstrate that the two counters eventually become equal if increments stop and synchronization messages are delivered.

wrote replicated_max.py in python, no extra packages needed

one program, started once per node with its own name, port and the address of the other node

nodes talk over UDP, so a message can get lost (relevant for 1.3)

each node has a receive thread that merges incoming values, the main thread does the increments

counter is protected by a lock since both threads write it

the node sends its counter after every increment, and after the increments stopped it keeps sending every 0.5s for 10 rounds, so the other node catches up even if a message got lost

merge on receive

```python
def receive():
    global counter
    while True:
        data, _ = sock.recvfrom(64)
        received = int(data.decode())
        with lock:
            old = counter
            counter = max(counter, received)
            new = counter
        if new != old:
            log(f"recv {received}, counter {old} -> {new}")
```

increments and sync

```python
for _ in range(increments):
    with lock:
        counter += 1
        value = counter
    log(f"inc, counter = {value}")
    sync()
    time.sleep(random.uniform(0.1, 0.5))

log(f"increments stopped ({increments} local), only syncing now")
for _ in range(SYNC_ROUNDS):
    sync()
    time.sleep(SYNC_INTERVAL)
```

ran the two nodes on two separate EC2 instances (t2.micro, Amazon Linux 2023, python 3.9 is preinstalled), created with main.tf

the security group allows SSH, and UDP 5000-5001 only between the two instances

```
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

```
private_ips = [
  "172.31.91.207",
  "172.31.94.103",
]
public_ips = [
  "52.70.228.101",
  "54.152.240.223",
]
```

copied the script to both instances

```
scp replicated_max.py ec2-user@52.70.228.101:~/
scp replicated_max.py ec2-user@54.152.240.223:~/
```

started A on the first instance and B on the second one, at the same time, with the private IP of the other node as peer, A does 10 increments and B does 7

```
ssh ec2-user@52.70.228.101 'python3 replicated_max.py A 5000 172.31.94.103:5001 10'
ssh ec2-user@54.152.240.223 'python3 replicated_max.py B 5001 172.31.91.207:5000 7'
```

output node A

```
[A 19:09:40] listening on 5000, peer 172.31.94.103:5001, 10 increments
[A 19:09:43] recv 1, counter 0 -> 1
[A 19:09:43] inc, counter = 2
[A 19:09:43] inc, counter = 3
[A 19:09:43] recv 4, counter 3 -> 4
[A 19:09:43] inc, counter = 5
[A 19:09:43] inc, counter = 6
[A 19:09:43] recv 7, counter 6 -> 7
[A 19:09:43] inc, counter = 8
[A 19:09:44] recv 9, counter 8 -> 9
[A 19:09:44] inc, counter = 10
[A 19:09:44] recv 11, counter 10 -> 11
[A 19:09:44] inc, counter = 12
[A 19:09:44] recv 13, counter 12 -> 13
[A 19:09:44] inc, counter = 14
[A 19:09:44] recv 15, counter 14 -> 15
[A 19:09:45] inc, counter = 16
[A 19:09:45] inc, counter = 17
[A 19:09:45] increments stopped (10 local), only syncing now
[A 19:09:50] final counter = 17
```

output node B

```
[B 19:09:40] listening on 5001, peer 172.31.91.207:5000, 7 increments
[B 19:09:43] inc, counter = 1
[B 19:09:43] recv 2, counter 1 -> 2
[B 19:09:43] recv 3, counter 2 -> 3
[B 19:09:43] inc, counter = 4
[B 19:09:43] recv 5, counter 4 -> 5
[B 19:09:43] recv 6, counter 5 -> 6
[B 19:09:43] inc, counter = 7
[B 19:09:43] recv 8, counter 7 -> 8
[B 19:09:44] inc, counter = 9
[B 19:09:44] recv 10, counter 9 -> 10
[B 19:09:44] inc, counter = 11
[B 19:09:44] recv 12, counter 11 -> 12
[B 19:09:44] inc, counter = 13
[B 19:09:44] recv 14, counter 13 -> 14
[B 19:09:44] inc, counter = 15
[B 19:09:45] recv 16, counter 15 -> 16
[B 19:09:45] increments stopped (7 local), only syncing now
[B 19:09:45] recv 17, counter 16 -> 17
[B 19:09:50] final counter = 17
```

both nodes end with 17, so after the increments stop and the messages arrive the counters are equal

max only ever goes up and gives the same result no matter in which order the values are merged, so once both nodes have seen the highest value they stay equal

17 is also the right total (10 + 7) here, but only because the two instances are in the same datacenter, so every message arrived (way under a ms) before the next local increment and the increments never actually overlapped (see 1.2)

destroyed the instances afterwards

```
terraform destroy
```

### 1.2 - Concurrent Increments

> Initially, both counters are zero. A increments its counter once. At the same time, B increments its counter once. Both nodes exchange their counter values.
> What is the resulting counter value? What should it be?
> Explain why the two nodes agreeing on a value does not necessarily mean that the value is correct.

resulting counter is 1 on both nodes, but it should be 2 (one increment on A + one on B)

A has 1 and B has 1, A receives 1 from B -> max(1, 1) = 1, B receives 1 from A -> max(1, 1) = 1

the counter value doesn't say who did the increments, so for max "B did its own increment" looks exactly the same as "B already got my increment", the two increments get merged into one and one of them is lost

tried it with the program, added an optional 5th argument recv delay to replicated_max.py, the receive thread only starts after that many seconds

messages that arrive before that wait in the socket buffer, so both nodes increment once before they merge anything (same as both messages still being on the way when the other node increments)

```python
recv_delay = float(sys.argv[5]) if len(sys.argv) > 5 else 0

receiver = threading.Timer(recv_delay, receive)
receiver.daemon = True
receiver.start()
```

also log a received value now when it doesn't change the counter (counter stays ...), otherwise the merge in this run wouldn't show up in the output

same setup as in 1.1, created the two EC2 instances again with main.tf (new IPs)

```
terraform plan -out=tfplan
terraform apply tfplan
```

```
private_ips = [
  "172.31.38.4",
  "172.31.42.221",
]
public_ips = [
  "3.90.106.39",
  "54.146.173.188",
]
```

```
scp replicated_max.py ec2-user@3.90.106.39:~/
scp replicated_max.py ec2-user@54.146.173.188:~/
```

both nodes 1 increment, receive thread starts after 5s

```
ssh ec2-user@3.90.106.39 'python3 replicated_max.py A 5000 172.31.42.221:5001 1 5'
ssh ec2-user@54.146.173.188 'python3 replicated_max.py B 5001 172.31.38.4:5000 1 5'
```

output node A

```
[A 13:56:55] listening on 5000, peer 172.31.42.221:5001, 1 increments
[A 13:56:58] inc, counter = 1
[A 13:56:58] increments stopped (1 local), only syncing now
[A 13:57:00] recv 1, counter stays 1
[A 13:57:03] final counter = 1
```

output node B

```
[B 13:56:55] listening on 5001, peer 172.31.38.4:5000, 1 increments
[B 13:56:58] inc, counter = 1
[B 13:56:58] increments stopped (1 local), only syncing now
[B 13:57:00] recv 1, counter stays 1
[B 13:57:03] final counter = 1
```

destroyed the instances afterwards (terraform destroy)

both end with 1, 2 increments were done in total, so 1 increment is lost

why agreeing doesn't mean correct:

both nodes agree on 1, so the replicas are consistent (they converged), but the value is still wrong

converging only means both replicas end in the same state, it says nothing about whether that state contains all the updates

max always converges (order of merges and duplicates don't matter), but for concurrent increments it just picks one of them instead of adding them up, the lost increment is not visible anywhere, both nodes are in sync and no one notices

correct would mean the final value = number of increments done on all nodes together, in 1.1 that was only the case because the increments never overlapped

### 1.3 - Message Loss, Duplication and Reordering

> Consider what happens if a synchronization message is lost, the same message is received twice, or an older message arrives after a newer one. Which situations cause problems for your implementation? Explain briefly.

| Situation | Causes a problem? | Explanation |
| :--- | :--- | :--- |
| **Message lost** | no (only delayed) | every message has the whole counter, the next sync sends it again, so the nodes are just out of sync until the next message arrives |
| **Message received twice** | no | max(c, x) applied twice is the same as once, the counter doesn't change the second time |
| **Older message arrives after newer one** | no | the older value is smaller or equal, so max ignores it |

none of the three is a problem, because the node always sends its whole counter (not "+1") and max doesn't care about order or duplicates

duplicates actually happen all the time already, in the sync rounds the same value is sent again every 0.5s (counter stays ... in the logs)

lost messages would only be a problem if all the messages after the last change get lost, then the nodes stay different after the sync rounds end (only 10 rounds in my program), with the assumption that communication eventually resumes that doesn't happen

if the nodes sent increments ("+1") instead of the counter, a lost message would lose an increment and a duplicate would count it twice

the real problem of this implementation is concurrent increments (1.2), not the network

### 1.4 - Preventing Lost Increments

> Modify your protocol so that increments performed independently by A and B are not lost.
> Show that your improved solution produces the correct total when both nodes increment concurrently and subsequently exchange their state.

wrote replicated_gcounter.py, same structure as replicated_max.py (UDP, receive thread, sync rounds, same arguments incl. recv delay)

instead of one integer every node keeps one count per node, e.g. {"A": 10, "B": 7}

a node only ever increments its own entry, so every entry has only one writer

the whole map is sent as JSON, on receive every entry is merged with max, the counter value is the sum of all entries

```python
counts = {name: 0}
```

```python
def receive():
    last = None
    while True:
        data, _ = sock.recvfrom(1024)
        received = json.loads(data.decode())
        with lock:
            old = dict(counts)
            for n, c in received.items():
                counts[n] = max(counts.get(n, 0), c)
            new = dict(counts)
        if new != old:
            log(f"recv {received}, counts {old} -> {new}, value = {sum(new.values())}")
        elif received != last:
            log(f"recv {received}, counts stay {new}, value = {sum(new.values())}")
        last = received
```

```python
for _ in range(increments):
    with lock:
        counts[name] += 1
        value = sum(counts.values())
    log(f"inc, counts = {counts}, value = {value}")
    sync()
    time.sleep(random.uniform(0.1, 0.5))
```

why this works: max per entry can't lose anything, since only A writes counts["A"] the highest value of it is always A's newest one, same for B, the increments of A and B end up in different entries and are added up in the sum

the merge is still max, so lost / duplicate / reordered messages are still no problem (like in 1.3)

ran it on the two EC2 instances again (same main.tf, new IPs)

```
terraform plan -out=tfplan
terraform apply tfplan
```

```
private_ips = [
  "172.31.82.168",
  "172.31.94.44",
]
public_ips = [
  "44.204.162.113",
  "100.62.119.248",
]
```

```
scp replicated_gcounter.py replicated_max.py ec2-user@44.204.162.113:~/
scp replicated_gcounter.py replicated_max.py ec2-user@100.62.119.248:~/
```

run 1, the situation from 1.2: both nodes 1 increment, receive thread starts after 5s

```
ssh ec2-user@44.204.162.113 'python3 replicated_gcounter.py A 5000 172.31.94.44:5001 1 5'
ssh ec2-user@100.62.119.248 'python3 replicated_gcounter.py B 5001 172.31.82.168:5000 1 5'
```

output node A

```
[A 15:55:41] listening on 5000, peer 172.31.94.44:5001, 1 increments
[A 15:55:44] inc, counts = {'A': 1}, value = 1
[A 15:55:45] increments stopped (1 local), only syncing now
[A 15:55:46] recv {'B': 1}, counts {'A': 1} -> {'A': 1, 'B': 1}, value = 2
[A 15:55:47] recv {'B': 1, 'A': 1}, counts stay {'A': 1, 'B': 1}, value = 2
[A 15:55:50] final counts = {'A': 1, 'B': 1}, value = 2
```

output node B

```
[B 15:55:41] listening on 5001, peer 172.31.82.168:5000, 1 increments
[B 15:55:44] inc, counts = {'B': 1}, value = 1
[B 15:55:45] increments stopped (1 local), only syncing now
[B 15:55:46] recv {'A': 1}, counts {'B': 1} -> {'B': 1, 'A': 1}, value = 2
[B 15:55:47] recv {'A': 1, 'B': 1}, counts stay {'B': 1, 'A': 1}, value = 2
[B 15:55:50] final counts = {'B': 1, 'A': 1}, value = 2
```

both end with 2, with replicated_max.py the same run gave 1 (1.2)

run 2, more increments: A 10, B 7, receive thread starts after 9s, so all 17 increments happen before any merge

```
ssh ec2-user@44.204.162.113 'python3 replicated_gcounter.py A 5000 172.31.94.44:5001 10 9'
ssh ec2-user@100.62.119.248 'python3 replicated_gcounter.py B 5001 172.31.82.168:5000 7 9'
```

output node A

```
[A 15:56:46] listening on 5000, peer 172.31.94.44:5001, 10 increments
[A 15:56:49] inc, counts = {'A': 1}, value = 1
[A 15:56:50] inc, counts = {'A': 2}, value = 2
[A 15:56:50] inc, counts = {'A': 3}, value = 3
[A 15:56:50] inc, counts = {'A': 4}, value = 4
[A 15:56:51] inc, counts = {'A': 5}, value = 5
[A 15:56:51] inc, counts = {'A': 6}, value = 6
[A 15:56:52] inc, counts = {'A': 7}, value = 7
[A 15:56:52] inc, counts = {'A': 8}, value = 8
[A 15:56:52] inc, counts = {'A': 9}, value = 9
[A 15:56:52] inc, counts = {'A': 10}, value = 10
[A 15:56:52] increments stopped (10 local), only syncing now
[A 15:56:55] recv {'B': 1}, counts {'A': 10} -> {'A': 10, 'B': 1}, value = 11
[A 15:56:55] recv {'B': 2}, counts {'A': 10, 'B': 1} -> {'A': 10, 'B': 2}, value = 12
[A 15:56:55] recv {'B': 3}, counts {'A': 10, 'B': 2} -> {'A': 10, 'B': 3}, value = 13
[A 15:56:55] recv {'B': 4}, counts {'A': 10, 'B': 3} -> {'A': 10, 'B': 4}, value = 14
[A 15:56:55] recv {'B': 5}, counts {'A': 10, 'B': 4} -> {'A': 10, 'B': 5}, value = 15
[A 15:56:55] recv {'B': 6}, counts {'A': 10, 'B': 5} -> {'A': 10, 'B': 6}, value = 16
[A 15:56:55] recv {'B': 7}, counts {'A': 10, 'B': 6} -> {'A': 10, 'B': 7}, value = 17
[A 15:56:55] recv {'B': 7, 'A': 10}, counts stay {'A': 10, 'B': 7}, value = 17
[A 15:56:57] final counts = {'A': 10, 'B': 7}, value = 17
```

output node B

```
[B 15:56:46] listening on 5001, peer 172.31.82.168:5000, 7 increments
[B 15:56:49] inc, counts = {'B': 1}, value = 1
[B 15:56:49] inc, counts = {'B': 2}, value = 2
[B 15:56:49] inc, counts = {'B': 3}, value = 3
[B 15:56:50] inc, counts = {'B': 4}, value = 4
[B 15:56:50] inc, counts = {'B': 5}, value = 5
[B 15:56:50] inc, counts = {'B': 6}, value = 6
[B 15:56:50] inc, counts = {'B': 7}, value = 7
[B 15:56:51] increments stopped (7 local), only syncing now
[B 15:56:55] recv {'A': 1}, counts {'B': 7} -> {'B': 7, 'A': 1}, value = 8
[B 15:56:55] recv {'A': 2}, counts {'B': 7, 'A': 1} -> {'B': 7, 'A': 2}, value = 9
[B 15:56:55] recv {'A': 3}, counts {'B': 7, 'A': 2} -> {'B': 7, 'A': 3}, value = 10
[B 15:56:55] recv {'A': 4}, counts {'B': 7, 'A': 3} -> {'B': 7, 'A': 4}, value = 11
[B 15:56:55] recv {'A': 5}, counts {'B': 7, 'A': 4} -> {'B': 7, 'A': 5}, value = 12
[B 15:56:55] recv {'A': 6}, counts {'B': 7, 'A': 5} -> {'B': 7, 'A': 6}, value = 13
[B 15:56:55] recv {'A': 7}, counts {'B': 7, 'A': 6} -> {'B': 7, 'A': 7}, value = 14
[B 15:56:55] recv {'A': 8}, counts {'B': 7, 'A': 7} -> {'B': 7, 'A': 8}, value = 15
[B 15:56:55] recv {'A': 9}, counts {'B': 7, 'A': 8} -> {'B': 7, 'A': 9}, value = 16
[B 15:56:55] recv {'A': 10}, counts {'B': 7, 'A': 9} -> {'B': 7, 'A': 10}, value = 17
[B 15:56:55] recv {'A': 10, 'B': 7}, counts stay {'B': 7, 'A': 10}, value = 17
[B 15:56:56] final counts = {'B': 7, 'A': 10}, value = 17
```

both end with 17 = 10 + 7, nothing lost

same run with replicated_max.py for comparison

```
ssh ec2-user@44.204.162.113 'python3 replicated_max.py A 5000 172.31.94.44:5001 10 9'
ssh ec2-user@100.62.119.248 'python3 replicated_max.py B 5001 172.31.82.168:5000 7 9'
```

output node A

```
[A 15:56:59] listening on 5000, peer 172.31.94.44:5001, 10 increments
[A 15:57:02] inc, counter = 1
[A 15:57:03] inc, counter = 2
[A 15:57:03] inc, counter = 3
[A 15:57:03] inc, counter = 4
[A 15:57:04] inc, counter = 5
[A 15:57:04] inc, counter = 6
[A 15:57:04] inc, counter = 7
[A 15:57:05] inc, counter = 8
[A 15:57:05] inc, counter = 9
[A 15:57:05] inc, counter = 10
[A 15:57:06] increments stopped (10 local), only syncing now
[A 15:57:08] recv 1, counter stays 10
[A 15:57:08] recv 2, counter stays 10
[A 15:57:08] recv 3, counter stays 10
[A 15:57:08] recv 4, counter stays 10
[A 15:57:08] recv 5, counter stays 10
[A 15:57:08] recv 6, counter stays 10
[A 15:57:08] recv 7, counter stays 10
[A 15:57:09] recv 10, counter stays 10
[A 15:57:11] final counter = 10
```

output node B

```
[B 15:56:59] listening on 5001, peer 172.31.82.168:5000, 7 increments
[B 15:57:02] inc, counter = 1
[B 15:57:03] inc, counter = 2
[B 15:57:03] inc, counter = 3
[B 15:57:03] inc, counter = 4
[B 15:57:03] inc, counter = 5
[B 15:57:04] inc, counter = 6
[B 15:57:04] inc, counter = 7
[B 15:57:05] increments stopped (7 local), only syncing now
[B 15:57:08] recv 1, counter stays 7
[B 15:57:08] recv 2, counter stays 7
[B 15:57:08] recv 3, counter stays 7
[B 15:57:08] recv 4, counter stays 7
[B 15:57:08] recv 5, counter stays 7
[B 15:57:08] recv 6, counter stays 7
[B 15:57:08] recv 7, counter stays 7
[B 15:57:08] recv 8, counter 7 -> 8
[B 15:57:08] recv 9, counter 8 -> 9
[B 15:57:08] recv 10, counter 9 -> 10
[B 15:57:10] final counter = 10
```

both agree on 10, the 7 increments of B are lost

note: first tried recv delay 10, then B was already done with its sync rounds when its receive thread started, so B ended with only its own count, 9s is after all increments but before the sync rounds end

destroyed the instances afterwards (terraform destroy)

---

## Task 2 - Single-Copy Counter

**Chosen data store:** Redis

### 2.1 - Safe Increment

> Implement an increment operation that safely updates the shared counter. Run increments from both nodes and verify that the resulting counter value is correct.
> Explain why this works without requiring the two application nodes to exchange synchronization messages.

used Redis 6.2 on a third EC2 instance, the two nodes run on the other two instances, the nodes never talk to each other, only to redis

added the store to main.tf, user_data installs redis6 and makes it listen on all interfaces (port 6379 is only open inside the security group), the nodes get python3-pip and the redis python package

```
#shared data store for task 2
resource "aws_instance" "store" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.key.key_name
  vpc_security_group_ids = [aws_security_group.nodes.id]

  #listen on all interfaces, the security group only lets the nodes in
  user_data = <<-EOF
    #!/bin/bash
    dnf install -y redis6
    sed -i 's/^bind .*/bind 0.0.0.0/; s/^protected-mode yes/protected-mode no/' /etc/redis6/redis6.conf
    systemctl enable --now redis6
  EOF
}
```

```
terraform plan -out=tfplan
terraform apply tfplan
```

```
private_ips = [
  "172.31.92.178",
  "172.31.81.121",
]
public_ips = [
  "54.89.105.205",
  "54.196.60.39",
]
store_private_ip = "172.31.86.146"
store_public_ip = "18.208.165.40"
```

```
scp single_copy.py ec2-user@54.89.105.205:~/
scp single_copy.py ec2-user@54.196.60.39:~/
```

wrote single_copy.py, one program for all of task 2, the mode argument picks how an increment is done (unsafe, incr, lock, watch, see 2.2 for the others)

the safe increment is just INCR, redis does the read + 1 + write as one command

```python
def incr_atomic():
    return r.incr("counter"), 0
```

before the loop both nodes INCR the key "ready" and wait until it is 2, so the increments of A and B really run at the same time (otherwise one node could be done before the other one starts because of the ssh startup)

```python
r.incr("ready")
while int(r.get("ready")) < 2:  #wait for the other node
    time.sleep(0.001)
```

before every run counter and ready are reset to 0 on the store, then both nodes are started at the same time, 1000 increments each

```
ssh ec2-user@18.208.165.40 'redis6-cli set counter 0; redis6-cli set ready 0; redis6-cli del lock'
ssh ec2-user@54.89.105.205 'python3 single_copy.py A 172.31.86.146 incr 1000'
ssh ec2-user@54.196.60.39 'python3 single_copy.py B 172.31.86.146 incr 1000'
ssh ec2-user@18.208.165.40 'redis6-cli get counter'
```

output node A

```
[A 16:02:33] redis 172.31.86.146, mode incr, 1000 increments, hold 0s
[A 16:02:33] start
[A 16:02:33] done, 1000 increments in 0.284s (0.284 ms per increment)
[A 16:02:33] counter now = 1855
```

output node B

```
[B 16:02:33] redis 172.31.86.146, mode incr, 1000 increments, hold 0s
[B 16:02:33] start
[B 16:02:33] done, 1000 increments in 0.333s (0.333 ms per increment)
[B 16:02:33] counter now = 2000
```

```
store: 2000
```

counter is 2000 = 1000 + 1000, nothing lost

A printed 1855 when it was done, so B was still incrementing at that time, the increments really overlapped

why no sync messages are needed: there is only one copy of the counter, in redis, the nodes don't keep their own state, so there is nothing to merge

every increment goes to the same place and redis executes the commands one after the other (one thread for commands), so each INCR sees the result of the INCR before, it doesn't matter which node sent it

the synchronization happens inside the store, not between the nodes

### 2.2 - Simultaneous Increments

> What could go wrong if both nodes read the current value, increment it locally, and then write the result back?

the two read-modify-writes can interleave: A reads 5, B reads 5, both write 6, so 2 increments only count as 1 (lost update)

GET and SET are each atomic, but nothing keeps the other node from changing the counter between them

tried it with mode unsafe

```python
def incr_unsafe():
    value = int(r.get("counter"))
    time.sleep(hold)
    r.set("counter", value + 1)
    return value + 1, 0
```

```
ssh ec2-user@18.208.165.40 'redis6-cli set counter 0; redis6-cli set ready 0; redis6-cli del lock'
ssh ec2-user@54.89.105.205 'python3 single_copy.py A 172.31.86.146 unsafe 1000'
ssh ec2-user@54.196.60.39 'python3 single_copy.py B 172.31.86.146 unsafe 1000'
ssh ec2-user@18.208.165.40 'redis6-cli get counter'
```

output node A

```
[A 16:02:38] redis 172.31.86.146, mode unsafe, 1000 increments, hold 0s
[A 16:02:39] start
[A 16:02:39] done, 1000 increments in 0.543s (0.543 ms per increment)
[A 16:02:39] counter now = 1007
```

output node B

```
[B 16:02:38] redis 172.31.86.146, mode unsafe, 1000 increments, hold 0s
[B 16:02:38] start
[B 16:02:39] done, 1000 increments in 0.629s (0.629 ms per increment)
[B 16:02:39] counter now = 1147
```

```
store: 1147
```

should be 2000, 853 increments are lost

with hold 1 (1s sleep between GET and SET, so every update of A overlaps with one of B) it's even worse, 6 increments and the counter is 3, every single update of the other node is overwritten

```
ssh ec2-user@18.208.165.40 'redis6-cli set counter 0; redis6-cli set ready 0; redis6-cli del lock'
ssh ec2-user@54.89.105.205 'python3 single_copy.py A 172.31.86.146 unsafe 3 1'
ssh ec2-user@54.196.60.39 'python3 single_copy.py B 172.31.86.146 unsafe 3 1'
ssh ec2-user@18.208.165.40 'redis6-cli get counter'
```

output node A

```
[A 16:03:32] redis 172.31.86.146, mode unsafe, 3 increments, hold 1.0s
[A 16:03:32] start
[A 16:03:33] inc 1, counter = 1, took 1.002s
[A 16:03:34] inc 2, counter = 2, took 1.001s
[A 16:03:35] inc 3, counter = 3, took 1.003s
[A 16:03:35] done, 3 increments in 3.006s (1002.150 ms per increment)
[A 16:03:35] counter now = 3
```

output node B

```
[B 16:03:31] redis 172.31.86.146, mode unsafe, 3 increments, hold 1.0s
[B 16:03:32] start
[B 16:03:33] inc 1, counter = 1, took 1.003s
[B 16:03:34] inc 2, counter = 2, took 1.002s
[B 16:03:35] inc 3, counter = 3, took 1.002s
[B 16:03:35] done, 3 increments in 3.007s (1002.397 ms per increment)
[B 16:03:35] counter now = 3
```

```
store: 3
```

> Explain how your chosen data store prevents this problem.

INCR: read, +1 and write are one command, redis executes commands one by one in a single thread, so no other command can run in between, two INCRs can't interleave

besides INCR I tried the two other ways redis offers to make GET + SET safe:

lock: SET lock <name> NX PX 10000 only sets the key if it doesn't exist yet, so only one node gets it, the other one tries again every 1ms, PX makes the lock expire after 10s in case a node dies while holding it

```python
def incr_lock():
    #returns the time spent waiting for the lock
    start = time.perf_counter()
    while not r.set("lock", name, nx=True, px=LOCK_TIMEOUT_MS):
        time.sleep(0.001)
    waited = time.perf_counter() - start
    value = int(r.get("counter"))
    time.sleep(hold)
    r.set("counter", value + 1)
    r.delete("lock")
    return value + 1, waited
```

watch: WATCH counter, GET, then MULTI/SET/EXEC, redis only executes the transaction if counter wasn't changed since WATCH, otherwise EXEC fails (WatchError) and the node starts over (optimistic, no lock)

```python
def incr_watch():
    #returns how often the transaction failed
    retries = 0
    with r.pipeline() as pipe:
        while True:
            try:
                pipe.watch("counter")
                value = int(pipe.get("counter"))
                time.sleep(hold)
                pipe.multi()
                pipe.set("counter", value + 1)
                pipe.execute()
                return value + 1, retries
            except redis.WatchError:
                retries += 1
```

both also give the correct result with 1000 increments per node

```
ssh ec2-user@18.208.165.40 'redis6-cli set counter 0; redis6-cli set ready 0; redis6-cli del lock'
ssh ec2-user@54.89.105.205 'python3 single_copy.py A 172.31.86.146 lock 1000'
ssh ec2-user@54.196.60.39 'python3 single_copy.py B 172.31.86.146 lock 1000'
ssh ec2-user@18.208.165.40 'redis6-cli get counter'
```

output node A

```
[A 16:02:51] redis 172.31.86.146, mode lock, 1000 increments, hold 0s
[A 16:02:51] start
[A 16:02:53] done, 1000 increments in 2.666s (2.666 ms per increment)
[A 16:02:53] waited 1.646s for the lock in total
[A 16:02:53] counter now = 1995
```

output node B

```
[B 16:02:51] redis 172.31.86.146, mode lock, 1000 increments, hold 0s
[B 16:02:51] start
[B 16:02:53] done, 1000 increments in 2.674s (2.674 ms per increment)
[B 16:02:53] waited 1.653s for the lock in total
[B 16:02:53] counter now = 2000
```

```
store: 2000
```

```
ssh ec2-user@18.208.165.40 'redis6-cli set counter 0; redis6-cli set ready 0; redis6-cli del lock'
ssh ec2-user@54.89.105.205 'python3 single_copy.py A 172.31.86.146 watch 1000'
ssh ec2-user@54.196.60.39 'python3 single_copy.py B 172.31.86.146 watch 1000'
ssh ec2-user@18.208.165.40 'redis6-cli get counter'
```

output node A

```
[A 16:02:59] redis 172.31.86.146, mode watch, 1000 increments, hold 0s
[A 16:02:59] start
[A 16:03:00] done, 1000 increments in 1.142s (1.142 ms per increment)
[A 16:03:00] 282 failed transactions (retried)
[A 16:03:00] counter now = 1284
```

output node B

```
[B 16:02:59] redis 172.31.86.146, mode watch, 1000 increments, hold 0s
[B 16:02:59] start
[B 16:03:01] done, 1000 increments in 1.823s (1.823 ms per increment)
[B 16:03:01] 879 failed transactions (retried)
[B 16:03:01] counter now = 2000
```

```
store: 2000
```

> Investigate what happens when one node attempts to update the counter while another update is in progress. What happens to the second update? Does it wait, fail, or complete immediately?
> Explain the observed behavior and how the data store ensures consistency.

used hold 1 (1s between GET and SET) and 3 increments per node, so an update takes 1s and the other node tries to update during it, every increment is logged

incr: completes immediately, an INCR takes way under a ms in redis, if the other node's INCR arrives at the same time it is just executed right after it (the commands are queued, redis runs them one by one), it never waits noticeably and never fails, in 2.1 one INCR took ~0.3 ms including the network, while the other node was incrementing at the same time

lock: the second update waits

```
ssh ec2-user@18.208.165.40 'redis6-cli set counter 0; redis6-cli set ready 0; redis6-cli del lock'
ssh ec2-user@54.89.105.205 'python3 single_copy.py A 172.31.86.146 lock 3 1'
ssh ec2-user@54.196.60.39 'python3 single_copy.py B 172.31.86.146 lock 3 1'
ssh ec2-user@18.208.165.40 'redis6-cli get counter'
```

output node A

```
[A 16:03:06] redis 172.31.86.146, mode lock, 3 increments, hold 1.0s
[A 16:03:06] start
[A 16:03:08] inc 1, counter = 2, took 2.004s, waited 1.002s for the lock
[A 16:03:09] inc 2, counter = 3, took 1.003s, waited 0.000s for the lock
[A 16:03:10] inc 3, counter = 4, took 1.003s, waited 0.000s for the lock
[A 16:03:10] done, 3 increments in 4.010s (1336.642 ms per increment)
[A 16:03:10] waited 1.003s for the lock in total
[A 16:03:10] counter now = 4
```

output node B

```
[B 16:03:06] redis 172.31.86.146, mode lock, 3 increments, hold 1.0s
[B 16:03:06] start
[B 16:03:07] inc 1, counter = 1, took 1.003s, waited 0.000s for the lock
[B 16:03:11] inc 2, counter = 5, took 4.011s, waited 3.009s for the lock
[B 16:03:12] inc 3, counter = 6, took 1.003s, waited 0.000s for the lock
[B 16:03:12] done, 3 increments in 6.018s (2006.140 ms per increment)
[B 16:03:12] waited 3.010s for the lock in total
[B 16:03:12] counter now = 6
```

```
store: 6
```

B got the lock first, A waited 1s until B released it, after that A got the lock again right away for inc 2 and 3 (it releases and takes the lock again before B's next try, the lock is not fair), so B waited 3s for its second increment

counter is 6, correct, the updates just don't run in parallel anymore

watch: the second update fails and is retried

```
ssh ec2-user@18.208.165.40 'redis6-cli set counter 0; redis6-cli set ready 0; redis6-cli del lock'
ssh ec2-user@54.89.105.205 'python3 single_copy.py A 172.31.86.146 watch 3 1'
ssh ec2-user@54.196.60.39 'python3 single_copy.py B 172.31.86.146 watch 3 1'
ssh ec2-user@18.208.165.40 'redis6-cli get counter'
```

output node A

```
[A 16:03:18] redis 172.31.86.146, mode watch, 3 increments, hold 1.0s
[A 16:03:18] start
[A 16:03:19] inc 1, counter = 1, took 1.003s, 0 retries
[A 16:03:21] inc 2, counter = 2, took 1.002s, 0 retries
[A 16:03:22] inc 3, counter = 3, took 1.003s, 0 retries
[A 16:03:22] done, 3 increments in 3.009s (1002.866 ms per increment)
[A 16:03:22] 0 failed transactions (retried)
[A 16:03:22] counter now = 3
```

output node B

```
[B 16:03:18] redis 172.31.86.146, mode watch, 3 increments, hold 1.0s
[B 16:03:18] start
[B 16:03:23] inc 1, counter = 4, took 4.010s, 3 retries
[B 16:03:24] inc 2, counter = 5, took 1.002s, 0 retries
[B 16:03:25] inc 3, counter = 6, took 1.003s, 0 retries
[B 16:03:25] done, 3 increments in 6.016s (2005.178 ms per increment)
[B 16:03:25] 3 failed transactions (retried)
[B 16:03:25] counter now = 6
```

```
store: 6
```

B's first transaction failed 3 times, each time A changed the counter while B was in its 1s hold, so EXEC was rejected and B started over with the new value, only when A was done B got through

counter is 6, correct

| Mode | Second update | Correct? |
| :--- | :--- | :--- |
| **unsafe** | completes, overwrites the other update | no (3 instead of 6, 1147 instead of 2000) |
| **incr** | completes immediately (executed right after the other command) | yes |
| **lock** | waits until the lock is released | yes |
| **watch** | fails (EXEC aborted), retried with the new value | yes |

how redis keeps it consistent: there is only one copy and redis executes one command at a time, INCR is a single command so it can't be interrupted, with the lock only one node is between GET and SET at any time, with WATCH redis rejects every write that is based on an old value

with the lock and watch the waiting / retrying shows up in the time: 1000 increments took ~2.7s with the lock and 1.1-1.8s with watch, compared to ~0.3s with INCR

destroyed the instances afterwards (terraform destroy)

---

## Task 3 - Comparison

### 3.1 - Measurements (100 Increments)

setup: same 3 EC2 instances as in task 2 (t2.micro, same datacenter, created again with main.tf), node A and B on two of them, redis on the third

```
private_ips = [
  "172.31.36.168",
  "172.31.33.143",
]
public_ips = [
  "18.232.163.34",
  "54.156.65.60",
]
store_private_ip = "172.31.35.149"
store_public_ip = "54.89.55.147"
```

```
scp bench_replicated.py single_copy.py ec2-user@18.232.163.34:~/
scp bench_replicated.py single_copy.py ec2-user@54.156.65.60:~/
```

timing with time.perf_counter() inside the programs, so the ssh / python startup is not included

**replicated**

wrote bench_replicated.py, same protocol as replicated_gcounter.py (one count per node, merge with max, state sent over UDP after every increment), but without the sleeps, 100 increments per node as fast as possible

measures 3 things separately per run:

- local: only the increment itself (counts[name] += 1 with the lock)
- send: sending the state to the other node after every increment (sendto)
- sync: from the own last increment until the node gets a state from the other node that contains all 200 increments, from then on both replicas are equal (it keeps resending its state every 1ms meanwhile, in case a message got lost)

```python
    for _ in range(increments):
        t0 = time.perf_counter()
        with lock:
            counts[name] += 1
        t1 = time.perf_counter()
        send()
        t2 = time.perf_counter()
        local += t1 - t0
        send_t += t2 - t1

    end = time.perf_counter()
    while not synced.wait(0.001):  #resend in case a message got lost
        send()
    sync_t = time.perf_counter() - end
```

both nodes start a run together (each sends its state until it got a message of that run from the other node), every message has the run number, 1 warm-up run + 5 runs

```
ssh ec2-user@18.232.163.34 'python3 bench_replicated.py A 5000 172.31.33.143:5001 100 5'
ssh ec2-user@54.156.65.60 'python3 bench_replicated.py B 5001 172.31.36.168:5000 100 5'
```

```
[A 16:19:11] listening on 5000, peer 172.31.33.143:5001, 100 increments, 5 runs + warm-up
[A 16:19:11] warm-up: local 0.091 ms, send 0.515 ms, sync 5.535 ms, value = 200
[A 16:19:11] run 1: local 0.135 ms, send 2.225 ms, sync 0.892 ms, value = 200
[A 16:19:11] run 2: local 0.240 ms, send 5.051 ms, sync 0.828 ms, value = 200
[A 16:19:12] run 3: local 0.139 ms, send 4.206 ms, sync 0.514 ms, value = 200
[A 16:19:12] run 4: local 0.156 ms, send 2.189 ms, sync 0.604 ms, value = 200
[A 16:19:12] run 5: local 0.168 ms, send 2.245 ms, sync 3.336 ms, value = 200
[A 16:19:12] mean of 5 runs: local 0.167 ms (1.67 us per increment), send 3.183 ms, sync 1.235 ms
```

```
[B 16:19:11] listening on 5001, peer 172.31.36.168:5000, 100 increments, 5 runs + warm-up
[B 16:19:11] warm-up: local 0.174 ms, send 2.122 ms, sync 0.867 ms, value = 200
[B 16:19:11] run 1: local 0.142 ms, send 2.171 ms, sync 3.400 ms, value = 200
[B 16:19:11] run 2: local 0.177 ms, send 2.452 ms, sync 3.087 ms, value = 200
[B 16:19:12] run 3: local 0.088 ms, send 1.450 ms, sync 1.967 ms, value = 200
[B 16:19:12] run 4: local 0.187 ms, send 2.167 ms, sync 3.476 ms, value = 200
[B 16:19:12] run 5: local 0.184 ms, send 2.108 ms, sync 0.631 ms, value = 200
[B 16:19:12] mean of 5 runs: local 0.156 ms (1.56 us per increment), send 2.070 ms, sync 2.512 ms
```

value is 200 on both nodes in every run

**single-copy**

single_copy.py from task 2, 100 increments per node, modes incr, lock and watch (unsafe left out, it's not correct)

added the slowest single increment to the output

alone: only node A increments (ready set to 1 so it doesn't wait for B)

concurrent: A and B increment at the same time (same as in task 2)

3 runs each, counter reset before every run

```
#alone
ssh ec2-user@54.89.55.147 'redis6-cli set counter 0; redis6-cli set ready 1; redis6-cli del lock'
ssh ec2-user@18.232.163.34 'python3 single_copy.py A 172.31.35.149 <mode> 100'

#concurrent
ssh ec2-user@54.89.55.147 'redis6-cli set counter 0; redis6-cli set ready 0; redis6-cli del lock'
ssh ec2-user@18.232.163.34 'python3 single_copy.py A 172.31.35.149 <mode> 100'
ssh ec2-user@54.156.65.60 'python3 single_copy.py B 172.31.35.149 <mode> 100'
```

```
==== incr alone run 1
[A 16:19:26] done, 100 increments in 0.029s (0.292 ms per increment)
[A 16:19:26] slowest increment 0.812 ms
[A 16:19:26] counter now = 100
==== incr concurrent run 1
[A 16:19:30] done, 100 increments in 0.025s (0.254 ms per increment)
[A 16:19:30] slowest increment 0.384 ms
[A 16:19:30] counter now = 200
[B 16:19:30] done, 100 increments in 0.026s (0.257 ms per increment)
[B 16:19:30] slowest increment 0.356 ms
[B 16:19:30] counter now = 199
==== incr alone run 2
[A 16:19:34] done, 100 increments in 0.026s (0.259 ms per increment)
[A 16:19:34] slowest increment 0.638 ms
[A 16:19:34] counter now = 100
==== incr concurrent run 2
[A 16:19:38] done, 100 increments in 0.028s (0.276 ms per increment)
[A 16:19:38] slowest increment 0.801 ms
[A 16:19:38] counter now = 200
[B 16:19:38] done, 100 increments in 0.026s (0.262 ms per increment)
[B 16:19:38] slowest increment 0.371 ms
[B 16:19:38] counter now = 195
==== incr alone run 3
[A 16:19:43] done, 100 increments in 0.028s (0.278 ms per increment)
[A 16:19:43] slowest increment 0.808 ms
[A 16:19:43] counter now = 100
==== incr concurrent run 3
[A 16:19:46] done, 100 increments in 0.028s (0.278 ms per increment)
[A 16:19:46] slowest increment 0.769 ms
[A 16:19:46] counter now = 200
[B 16:19:46] done, 100 increments in 0.025s (0.253 ms per increment)
[B 16:19:46] slowest increment 0.309 ms
[B 16:19:46] counter now = 188
==== lock alone run 1
[A 16:19:50] done, 100 increments in 0.108s (1.083 ms per increment)
[A 16:19:50] slowest increment 1.879 ms
[A 16:19:50] waited 0.028s for the lock in total
[A 16:19:50] counter now = 100
==== lock concurrent run 1
[A 16:19:53] done, 100 increments in 0.205s (2.046 ms per increment)
[A 16:19:53] slowest increment 11.087 ms
[A 16:19:53] waited 0.122s for the lock in total
[A 16:19:53] counter now = 192
[B 16:19:53] done, 100 increments in 0.212s (2.120 ms per increment)
[B 16:19:53] slowest increment 17.684 ms
[B 16:19:53] waited 0.131s for the lock in total
[B 16:19:53] counter now = 200
==== lock alone run 2
[A 16:19:57] done, 100 increments in 0.103s (1.029 ms per increment)
[A 16:19:57] slowest increment 1.637 ms
[A 16:19:57] waited 0.026s for the lock in total
[A 16:19:57] counter now = 100
==== lock concurrent run 2
[A 16:20:01] done, 100 increments in 0.173s (1.727 ms per increment)
[A 16:20:01] slowest increment 11.103 ms
[A 16:20:01] waited 0.091s for the lock in total
[A 16:20:01] counter now = 160
[B 16:20:01] done, 100 increments in 0.215s (2.154 ms per increment)
[B 16:20:01] slowest increment 17.463 ms
[B 16:20:01] waited 0.134s for the lock in total
[B 16:20:01] counter now = 200
==== lock alone run 3
[A 16:20:05] done, 100 increments in 0.110s (1.096 ms per increment)
[A 16:20:05] slowest increment 1.965 ms
[A 16:20:05] waited 0.028s for the lock in total
[A 16:20:05] counter now = 100
==== lock concurrent run 3
[A 16:20:09] done, 100 increments in 0.199s (1.988 ms per increment)
[A 16:20:09] slowest increment 9.394 ms
[A 16:20:09] waited 0.115s for the lock in total
[A 16:20:09] counter now = 187
[B 16:20:09] done, 100 increments in 0.213s (2.127 ms per increment)
[B 16:20:09] slowest increment 23.273 ms
[B 16:20:09] waited 0.133s for the lock in total
[B 16:20:09] counter now = 200
==== watch alone run 1
[A 16:20:13] done, 100 increments in 0.076s (0.764 ms per increment)
[A 16:20:13] slowest increment 1.410 ms
[A 16:20:13] 0 failed transactions (retried)
[A 16:20:13] counter now = 100
==== watch concurrent run 1
[A 16:20:17] done, 100 increments in 0.101s (1.007 ms per increment)
[A 16:20:17] slowest increment 4.389 ms
[A 16:20:17] 32 failed transactions (retried)
[A 16:20:17] counter now = 134
[B 16:20:17] done, 100 increments in 0.153s (1.534 ms per increment)
[B 16:20:17] slowest increment 17.285 ms
[B 16:20:17] 93 failed transactions (retried)
[B 16:20:17] counter now = 200
==== watch alone run 2
[A 16:20:20] done, 100 increments in 0.078s (0.782 ms per increment)
[A 16:20:20] slowest increment 1.414 ms
[A 16:20:20] 0 failed transactions (retried)
[A 16:20:20] counter now = 100
==== watch concurrent run 2
[A 16:20:24] done, 100 increments in 0.105s (1.047 ms per increment)
[A 16:20:24] slowest increment 9.575 ms
[A 16:20:24] 41 failed transactions (retried)
[A 16:20:24] counter now = 141
[B 16:20:24] done, 100 increments in 0.149s (1.490 ms per increment)
[B 16:20:24] slowest increment 14.380 ms
[B 16:20:24] 87 failed transactions (retried)
[B 16:20:24] counter now = 200
==== watch alone run 3
[A 16:20:28] done, 100 increments in 0.081s (0.810 ms per increment)
[A 16:20:28] slowest increment 1.823 ms
[A 16:20:28] 0 failed transactions (retried)
[A 16:20:28] counter now = 100
==== watch concurrent run 3
[A 16:20:32] done, 100 increments in 0.153s (1.528 ms per increment)
[A 16:20:32] slowest increment 17.040 ms
[A 16:20:32] 99 failed transactions (retried)
[A 16:20:32] counter now = 200
[B 16:20:32] done, 100 increments in 0.135s (1.355 ms per increment)
[B 16:20:32] slowest increment 15.040 ms
[B 16:20:32] 76 failed transactions (retried)
[B 16:20:32] counter now = 178
```

counter is correct (100 alone, 200 concurrent) in every run

**results**, time for 100 increments of one node, mean of the runs (concurrent: mean over both nodes)

| Implementation | Measurement | 100 increments | per increment | Notes |
| :--- | :--- | :--- | :--- | :--- |
| **Replicated** | local state update | 0.16 ms | 1.6 us | A 0.167, B 0.156 ms |
| **Replicated** | sending the state (100 UDP messages) | 2.6 ms | 26 us | A 3.18, B 2.07 ms, doesn't wait for the other node |
| **Replicated** | sync until both replicas are equal | 1.9 ms | - | A 1.24, B 2.51 ms, once after the last increment |
| **Single-copy** | INCR, alone | 27.7 ms | 0.28 ms | slowest 0.81 ms |
| **Single-copy** | INCR, concurrent | 26.3 ms | 0.26 ms | slowest 0.80 ms |
| **Single-copy** | lock, alone | 107.0 ms | 1.07 ms | slowest 1.97 ms |
| **Single-copy** | lock, concurrent | 202.8 ms | 2.03 ms | slowest 23.3 ms, ~121 ms of it waiting for the lock |
| **Single-copy** | watch, alone | 78.3 ms | 0.78 ms | slowest 1.82 ms, 0 retries |
| **Single-copy** | watch, concurrent | 132.7 ms | 1.33 ms | slowest 17.3 ms, ~71 failed transactions per node and run |

differences:

replicated: the increment itself is only a local memory update (~1.6 us), it doesn't wait for anything, the network is only used afterwards to send the state, and sendto just hands the packet to the OS without waiting for an answer

the sync time is mostly waiting for the other node to finish its own increments + one message over the network, the replicas are only equal ~2 ms after the last increment, before that each node only knows its own increments + what arrived already

single-copy: every increment is at least one round trip to redis (~0.27 ms in the same datacenter), so INCR is ~170x slower than the local update, but the value is in the store right away, no extra sync step

INCR alone vs concurrent is about the same (26-28 ms), redis executes one command in microseconds, so the two nodes basically never wait for each other, the time is the network round trip

lock and watch need more round trips per increment (lock: SET NX, GET, SET, DEL = 4, watch: WATCH, GET, MULTI/SET/EXEC = 3), that's why alone they take ~1.07 ms and ~0.78 ms ("waited" alone is just the SET NX for taking the lock)

with concurrent updates they get slower: with the lock the nodes wait for each other (~2x the time, one increment up to 23 ms), with watch failed transactions have to be done again (~1.7x, up to 17 ms), INCR doesn't have that problem because the whole update is one command

so concurrent updates only affect the time if the update needs more than one command and has to be protected by a lock / transaction

destroyed the instances afterwards (terraform destroy)

### 3.2 - Discussion Questions

> Question 1: Where does synchronization happen in each implementation?

replicated: between the nodes, each node sends its state to the other one and merges what it receives (max per entry in the receive thread), the increment itself is not synchronized, it happens only locally and the sync comes later (asynchronous)

single-copy: inside redis, the nodes never talk to each other, redis executes one command at a time, so INCR can't interleave, for lock / watch redis decides who gets the lock or which transaction goes through

> Question 2: What happens if the two nodes cannot communicate temporarily?

replicated: both nodes keep working, increments are local so they still complete right away, but the replicas drift apart, each node only sees its own new increments

when the connection is back the state is sent again and merged, with the per-node counts (1.4) nothing is lost and both end with the correct total, (with plain max the concurrent increments would be lost, 1.2)

in my programs the nodes only resend for a fixed time (sync rounds / until synced), a real version would just keep syncing periodically

single-copy: nothing happens, the nodes don't need to talk to each other, only to redis, as long as both can reach redis everything works

> Question 3: What happens if the shared data store is unavailable?

single-copy: no node can read or increment the counter anymore, INCR fails with a connection error in redis-py, so the increment is lost unless the program retries it later / buffers it, redis is a single point of failure

if a node held the lock when redis was down, the lock still expires after 10s (PX), so the counter doesn't stay locked forever

replicated: doesn't use a store, so not affected

> Question 4: Which approach would you choose if increments must be immediately visible to both nodes? Why?

single-copy (with INCR): there is only one copy, as soon as INCR returns the new value is in redis and the next read from any node sees it

with the replicated counter the other node only sees an increment when the message arrived (~ms in my measurement, but not at all while the nodes can't communicate), so it's only eventually visible

downside: every increment costs a round trip (~0.27 ms instead of ~1.6 us) and it doesn't work while redis is down, but if increments must be visible right away that's the price, INCR is also the cheapest of the single-copy variants and isn't slowed down by concurrent updates
