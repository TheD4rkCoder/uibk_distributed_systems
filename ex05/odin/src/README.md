# EX05 

CLI, Docker Setup and chaos_test.py was created with AI

## Setup

Example setup

```bash
docker compose up -d --build
docker exec -it ex05-node1 python3 auction_node.py    
docker exec ex05-node2 python3 auction_node.py query 
docker compose down
```

Commands: `bid <bidder> <amount>`, `query`, `close`, `new`, `nodes`, `dump`.
Each node container has its own IP and reaches ZooKeeper (`zookeeper:2181`) only over the
network.




## Task 1

Experiment:

Bids through different nodes, then the same state everywhere. Run with `experiment1.sh`

Output:

```
node1 connected to zookeeper:2181
auction 7 started
node1 connected to zookeeper:2181
bid accepted: alice=10 on auction 7 (v1)
node2 connected to zookeeper:2181
bid accepted: bob=20 on auction 7 (v2)
node3 connected to zookeeper:2181
bid accepted: eve=25 on auction 7 (v3)
node4 connected to zookeeper:2181
bid accepted: maurits=30 on auction 7 (v4)
node5 connected to zookeeper:2181
bid accepted: alice=35 on auction 7 (v5)
node1 connected to zookeeper:2181
auction 7 CLOSED by node1, winner alice=35
node1 connected to zookeeper:2181
auction 7 CLOSED by node1, winner alice=35 (v6)
node2 connected to zookeeper:2181
auction 7 CLOSED by node1, winner alice=35 (v6)
node3 connected to zookeeper:2181
auction 7 CLOSED by node1, winner alice=35 (v6)
node4 connected to zookeeper:2181
auction 7 CLOSED by node1, winner alice=35 (v6)
node5 connected to zookeeper:2181
auction 7 CLOSED by node1, winner alice=35 (v6)
```

## Task 2
The ZooKeeper server applies every write one at a time, in a single order. For all the properties I used conditional writes. Every znode has a version, that increases each write. Additionally no bids are accepted after closing, until a new election explicitely starts again. 

Experiments:

In `expoment2.sh`

`--think 1` widens the read→write window so conflicts happen reliably; `-v` shows the retries

Output:

```
node1 connected to zookeeper:2181
auction 8 started
2026-11-16 17:58:50,811 INFO kazoo.client: Connecting to zookeeper(172.22.0.2):2181, use_ssl: False
2026-11-16 17:58:50,822 INFO kazoo.client: Connecting to zookeeper(172.22.0.2):2181, use_ssl: False
2026-11-16 17:58:50,823 INFO kazoo.client: Zookeeper connection established, state: CONNECTED
2026-11-16 17:58:50,823 INFO auction: connected to ZooKeeper
2026-11-16 17:58:50,825 INFO kazoo.client: Zookeeper connection established, state: CONNECTED
2026-11-16 17:58:50,825 INFO auction: connected to ZooKeeper
2026-11-16 17:58:50,925 INFO kazoo.client: Closing connection to zookeeper:2181
2026-11-16 17:58:50,925 INFO kazoo.client: Zookeeper session closed, state: CLOSED
node1 connected to zookeeper:2181
bid accepted: alice=100 on auction 8 (v1)
2026-11-16 17:58:51,543 INFO auction: bid conflict on auction 8 v0, retrying
2026-11-16 17:58:51,552 INFO kazoo.client: Closing connection to zookeeper:2181
2026-11-16 17:58:51,553 INFO kazoo.client: Zookeeper session closed, state: CLOSED
node2 connected to zookeeper:2181
bid 90 does not exceed 100 (alice)
2026-11-16 17:58:51,735 INFO kazoo.client: Connecting to zookeeper(172.22.0.2):2181, use_ssl: False
2026-11-16 17:58:51,738 INFO kazoo.client: Zookeeper connection established, state: CONNECTED
2026-11-16 17:58:51,738 INFO auction: connected to ZooKeeper
node5 connected to zookeeper:2181
already closed: auction 8 CLOSED by node4, winner alice=100
node4 connected to zookeeper:2181
auction 8 CLOSED by node4, winner alice=100
2026-11-16 17:58:51,962 INFO auction: bid conflict on auction 8 v1, retrying
2026-11-16 17:58:51,964 INFO kazoo.client: Closing connection to zookeeper:2181
2026-11-16 17:58:51,964 INFO kazoo.client: Zookeeper session closed, state: CLOSED
node3 connected to zookeeper:2181
auction 8 is closed
```

## Task 3
The whole auction state lives in ZooKeeper only (persistent znodes), so a crashed node loses nothing: an accepted bid is only acknowledged after ZooKeeper has committed the write. A node has no state that matters locally. Every operation (also after a restart) first reads the current auction and its version from ZooKeeper. The only local copy is the watch cache, which is used for display and never for a decision.

A node with outdated state cannot overwrite anything, because every write is a conditional `set(path, data, version)` with the version it read. If someone else wrote in between, ZooKeeper answers with `BadVersion`, the node re-reads and decides again (e.g. sees that the auction is closed). The same check stops a second close, so there can't be a conflicting winner.

A node that can't reach ZooKeeper refuses every operation. The connection listener clears a `connected` flag on `SUSPENDED`/`LOST`, which is checked before every read and write. If a node is cut off while its write is in flight, the write fails with `ConnectionLoss`/`SessionExpired` instead of being applied later. Each node also registers an ephemeral znode in `/auction/nodes`, which ZooKeeper removes once the session expires (crash detection).

Experiments:

Crash and restart (steps 1-5) in `experiment3.sh`. Node A runs as a long-lived process, so `docker kill` crashes a running node

Output:

```
node2 connected to zookeeper:2181
auction 22 started

=== 1. start nodes A and B, bid through A
    [A] [watch] auction 22 OPEN, no bids yet (0 bids) (v0)
    [A] node1 connected to zookeeper:2181
    [A] > bid alice 10
    [A] bid accepted: alice=10 on auction 22 (v1)
    [A] [watch] auction 22 OPEN, highest alice=10 (1 bids) (v1)

=== 2. crash node A (docker kill)
node2 connected to zookeeper:2181
live nodes: ['node2']

=== 3. node B: higher bid, then close
node2 connected to zookeeper:2181
bid accepted: bob=20 on auction 22 (v2)
node2 connected to zookeeper:2181
auction 22 CLOSED by node2, winner bob=20

=== 4. restart node A
    [A] [watch] auction 22 CLOSED by node2, winner bob=20 (v3)
    [A] [watch] live nodes: ['node1', 'node2']
    [A] node1 connected to zookeeper:2181

=== 5. node A sees the final result and cannot change it
    [A] > query
    [A] auction 22 CLOSED by node2, winner bob=20 (v3)
    [A] > bid alice 500
    [A] auction 22 is closed
    [A] > close
    [A] already closed: auction 22 CLOSED by node2, winner bob=20
    [A] > quit

=== final state as stored in ZooKeeper (read via node B)
auction 22 CLOSED by node2, winner bob=20 (v3)
```

Stale state and disconnects in `experiment3_stale.sh`

`--hold 4` makes node A wait between its read and its write, so it works with an outdated version. In b) the container is frozen with `docker pause` (longer than the 5 s session timeout), in c) a long-running node is cut off with `iptables`

Output:

```
=== a) stale read: A reads, holds its copy for 4 s; meanwhile B outbids and closes
bid accepted: alice=10 on auction 23 (v1)
    [A] INFO auction: holding stale read of auction 23 v1 for 4.0s
bid accepted: bob=20 on auction 23 (v2)
auction 23 CLOSED by node2, winner bob=20
    [A] INFO auction: bid conflict on auction 23 v1, retrying
    [A] auction 23 is closed
auction 23 CLOSED by node2, winner bob=20 (v3)

=== b) freeze: A reads, is paused for 8 s (> 5 s session timeout); meanwhile B outbids and closes
bid accepted: alice=10 on auction 24 (v1)
    [A] INFO auction: holding stale read of auction 24 v1 for 3.0s
    -- node1 paused
bid accepted: bob=20 on auction 24 (v2)
auction 24 CLOSED by node2, winner bob=20
    [A] WARNING kazoo.client: Connection dropped: socket connection error: Broken pipe
    [A] WARNING auction: connection to ZooKeeper suspended, rejecting operations
    [A] error: ZooKeeper error: ConnectionLoss
    -- node1 resumed
auction 24 CLOSED by node2, winner bob=20 (v3)

=== c) disconnect: long-running A loses its ZooKeeper connection
bid accepted: alice=10 on auction 25 (v1)
    [A] [watch] auction 25 OPEN, highest alice=10 (1 bids) (v1)
    -- node1 cut off from ZooKeeper (iptables DROP :2181)
    [A] WARNING auction: connection to ZooKeeper suspended, rejecting operations
    [A] > bid carol 15
    [A] error: not connected to ZooKeeper, refusing operation
    [A] > query
    [A] error: not connected to ZooKeeper, refusing operation
    [A] last known state (possibly stale!): auction 25 OPEN, highest alice=10 (1 bids) (v1)
bid accepted: bob=20 on auction 25 (v2)
auction 25 CLOSED by node2, winner bob=20
    [A] > close
    [A] error: not connected to ZooKeeper, refusing operation
    -- node1 reconnected
    [A] WARNING auction: ZooKeeper session lost
    [A] INFO auction: connected to ZooKeeper
    [A] [watch] auction 25 CLOSED by node2, winner bob=20 (v3)
    [A] > query
    [A] auction 25 CLOSED by node2, winner bob=20 (v3)
    [A] > bid carol 500
    [A] auction 25 is closed
    [A] > close
    [A] already closed: auction 25 CLOSED by node2, winner bob=20
```

Random faults (step 6) in `experiment3_chaos.sh` (runs `chaos_test.py --auctions 10 --duration 15 --seed 42`, extra args are passed through)

Each node runs a worker that bids continuously. The harness randomly crashes containers (`docker kill` + `start`), partitions them (`docker network disconnect` longer than the session timeout), causes short blips, and freezes them (`docker pause` longer than the session timeout, so the process resumes with stale state mid-operation). Each auction is closed by two concurrent `close` calls on different nodes. At the end it checks: bids strictly increasing, winner = highest bid, nothing modified after close, every acknowledged bid present in the final state, exactly one successful close per auction.

Output:

```
=== summary
auctions tested : [26, 27, 28, 29, 30, 31, 32, 33, 34, 35]
faults injected : {'blip': 18, 'crash': 25, 'partition': 21, 'freeze': 15}
bids accepted   : 805
bids rejected   : 1096
bids errored    : 16  (disconnected / session expired / timeout)
CAS retries     : 554
sessions lost   : 25, suspended: 38
auction  26    :  86 bids, winner eve=392, closed by closer-1
auction  27    :  76 bids, winner eve=392, closed by closer-2
auction  28    :  76 bids, winner bob=389, closed by closer-1
auction  29    :  90 bids, winner eve=424, closed by closer-2
auction  30    :  74 bids, winner alice=369, closed by closer-1
auction  31    :  70 bids, winner dave=369, closed by closer-1
auction  32    :  82 bids, winner bob=438, closed by closer-1
auction  33    :  85 bids, winner dave=403, closed by closer-2
auction  34    :  70 bids, winner carol=391, closed by closer-2
auction  35    :  97 bids, winner alice=482, closed by closer-1

INVARIANTS: ALL OK
```

79 faults over 10 auctions and no violation. The 16 errored bids are bids that a disconnected/frozen node refused or that failed in flight. They were never acknowledged to the bidder. Full log and raw events are in `results/chaos_seed42.{log,json}`.