# EX05 Report: Fault Tolerance & Coordination

**Student Name:** Maurits van Staalduinen  
**Student ID:** `c9881018`  

Claude Sonnet 5.5 used for handin formating, table formating, and clearer wording

**Chosen stack:** python 3.9 + kazoo 2.10, standalone zookeeper 3.9.3 (docker)

## Task 1 - Distributed Auction

### Implementation

auction_node.py, one process per node with its name and the zookeeper address, commands typed on stdin (open, bid, query, close)

the nodes don't know each other, they only talk to zookeeper, the node itself keeps no auction state

| znode | type | content |
| :--- | :--- | :--- |
| **/auctions/<id>** | persistent | json state: item, status open / closed, highest bid, winner, closed_by |
| **/auctions/<id>/bids/bid-000000000N** | persistent sequential | one per accepted bid (bidder, amount, node, bid id) |
| **/members/<node>** | ephemeral | exists while the node's session is alive |

every write is a read-modify-write of the state znode, with the version from the read as condition, in one transaction with the bid history entry

```python
def write(state, stat, bid=None):
    tx = zk.transaction()
    tx.set_data(path(), json.dumps(state).encode(), version=stat.version)
    if bid:
        tx.create(path() + "/bids/bid-", json.dumps(bid).encode(), sequence=True)
    result = tx.commit()
    if isinstance(result[0], BadVersionError):
        return None
    ...
```

bid: read state -> closed or amount <= highest: reject -> else write, version conflict -> read again and check again

close: read state -> already closed: show that result -> else write status closed with winner = highest bid (none if no bids)

query: sync + read, the number of accepted bids comes from the history children

every node also has a DataWatch on the state znode and a ChildrenWatch on /members, so changes are printed when they happen, without polling

### Experiment

6 t2.micro instances from main.tf: A-E and zookeeper, port 2181 only open inside the security group

auction bike, bids through A, C, E, B, D one after another, then query on all 5 at the same time (at <t> query), close on C

```
[A 23:45:42.754] bid bike alice 100 accepted, id A-1794872742750-1 (v0 -> v1, zxid 0xbb)
[C 23:45:44.434] bid bike bob 150 accepted, id C-1794872744428-1 (v1 -> v2, zxid 0xbc)
[E 23:45:48.079] bid bike carol 120 rejected: not higher than bob 150 (v2)
[B 23:45:50.363] bid bike dave 200 accepted, id B-1794872750358-1 (v2 -> v3, zxid 0xbd)
[D 23:45:52.224] bid bike erin 250 accepted, id D-1794872752217-1 (v3 -> v4, zxid 0xbe)
[A 23:45:54.957] query bike (item) v4: open, highest erin 250 (bid via D), 4 accepted bids
[B 23:45:54.957] query bike (item) v4: open, highest erin 250 (bid via D), 4 accepted bids
[C 23:45:54.957] ...same on C, D, E
[C 23:48:34.431] close bike: closed by C, winner erin 250 (bid via D) (v4 -> v5, zxid 0xc1)
[E 23:48:36.159] bid bike carol 300 rejected: closed by C, winner erin 250 (bid via D)
[A 23:48:39.345] query bike (item) v5: closed by C, winner erin 250 (bid via D), 4 accepted bids
```

all 5 nodes show the same state (v4, then v5) and the watches on every node printed v1 ... v5 in the same order

the lower bid on E and the bid after the close were rejected

---

## Task 2 - Concurrent Bids

### Conflicting updates

the state znode's version is the coordination: set_data(..., version=v) only succeeds if nobody wrote since the read, zookeeper orders all writes (zxid), so for every version exactly one write wins

the loser gets BadVersionError, reads the new state and checks again, so a decision is always made on the newest state

| Requirement | Why it holds |
| :--- | :--- |
| **no lower bid over a higher one** | the "amount > highest" check and the write are on the same version |
| **closed only once** | closing is a versioned write too, a second close sees status closed on the retry |
| **no bids after close** | a bid read before the close has an old version, its write fails, the retry sees closed |
| **bid concurrent with close** | whichever write gets the version first wins, the other retries: bid first -> it is in the winner, close first -> bid rejected |

bid and history entry are one transaction (multi), either both or none

no locks: a node that crashes holding a lock would block the others until its session expires, with the versioned write there is nothing to release

### Experiments

hold 0.3 on all nodes (time between read and write) so the requests really overlap, the same at <t> on several nodes

two competing bids, then 5 bids at the same time

```
[A 23:48:58.429] bid lamp alice 300: state changed since v0, retry
[B 23:48:58.429] bid lamp bob 310 accepted, id B-1794872938122-1 (v0 -> v1, zxid 0xe2)
[A 23:48:58.430] bid lamp alice 300 rejected: not higher than bob 310 (v1)

[D 23:49:02.013] bid lamp u3 510 accepted, id D-1794872941708-1 (v1 -> v2, zxid 0xe4)
[A 23:49:02.017] bid lamp u0 500 rejected: not higher than u3 510 (v2)
[E 23:49:02.321] bid lamp u4 530 accepted, id E-1794872941708-1 (v2 -> v3, zxid 0xe9)
[C 23:49:02.324] bid lamp u2 520 rejected: not higher than u4 530 (v3)
[B 23:49:02.628] bid lamp u1 540 accepted, id B-1794872941708-2 (v3 -> v4, zxid 0xec)
```

all 5 read v1, D won it, the others retried, the higher ones were accepted one after the other (B after 2 retries), the lower ones rejected, the end result is the maximum 540

bid while another node closes, close first (bid held 0.6s):

```
[B 23:49:08.217] close lamp: closed by B, winner u1 540 (bid via B) (v4 -> v5, zxid 0xed)
[A 23:49:08.719] bid lamp alice 600: state changed since v4, retry
[A 23:49:08.719] bid lamp alice 600 rejected: closed by B, winner u1 540 (bid via B)
```

bid first (close held 0.6s):

```
[A 23:49:16.219] bid vase alice 700 accepted, id A-1794872956214-4 (v1 -> v2, zxid 0xf5)
[B 23:49:16.719] close vase: state changed since v1, retry
[B 23:49:17.323] close vase: closed by B, winner alice 700 (bid via A) (v2 -> v3, zxid 0xf7)
```

two nodes close at the same time:

```
[D 23:49:23.952] close clock: closed by D, winner erin 800 (bid via E) (v1 -> v2, zxid 0x100)
[C 23:49:23.951] close clock: state changed since v1, retry
[C 23:49:23.952] close clock: already closed by D, winner erin 800 (bid via E) (v2)
```

all 4 requirements hold: amounts in the history only go up, one close per auction, the bid racing the close is either in the result (vase) or rejected (lamp), both closing nodes report the same winner

---

## Task 3 - Crash Recovery and Stale State

### Crash and restart (3.1 - 3.5)

auction car, only A and B running, A killed with kill -9

```
[A 23:49:39.690] bid car alice 1000 accepted, id A-1794872979684-1 (v0 -> v1, zxid 0x11a)
kill -9 A 23:49:41.731
[B 23:49:45.186] members ['B']
[B 23:49:47.911] bid car bob 1200 accepted, id B-1794872987905-1 (v1 -> v2, zxid 0x11c)
[B 23:49:49.300] close car: closed by B, winner bob 1200 (bid via B) (v2 -> v3, zxid 0x11d)
[A 23:49:51.150] start, zookeeper 172.31.95.3:2181
[A 23:49:51.161] watch car v3: closed by B, winner bob 1200 (bid via B)
[A 23:49:51.163] query car (item) v3: closed by B, winner bob 1200 (bid via B), 2 accepted bids
[A 23:49:55.607] bid car alice 5000 rejected: closed by B, winner bob 1200 (bid via B)
[A 23:49:55.987] close car: already closed by B, winner bob 1200 (bid via B) (v3)
```

alice's bid survives the crash, it is in zookeeper and not in A

B sees the crash 3.5s later: A's ephemeral /members/A is deleted when its session (4s timeout) expires

the restarted A has no local state, it reads v3 from zookeeper on start (13 ms after starting), its bid and close are rejected / return the existing result

### Stale state

A reads the state (boat v0, open, no bids) and waits 3s before writing, in between B bids 2500 and closes

```
[B 23:50:03.016] bid boat bob 2500 accepted, id B-1794873003012-2 (v0 -> v1, zxid 0x123)
[B 23:50:03.514] close boat: closed by B, winner bob 2500 (bid via B) (v1 -> v2, zxid 0x125)
[A 23:50:05.519] bid boat alice 2000: state changed since v0, retry
[A 23:50:05.519] bid boat alice 2000 rejected: closed by B, winner bob 2500 (bid via B)
```

A paused (SIGSTOP) for 9s in the middle of a close, after reading kite v1 (highest bob 100), meanwhile B accepts carol 150

```
pause A 23:50:12.351
[B 23:50:13.568] bid kite carol 150 accepted, id B-1794873013563-4 (v1 -> v2, zxid 0x12b)
[B 23:50:15.188] members ['B']
resume A    #~23:50:21.0, stamped after the ssh command returned
[A 23:50:21.079] zookeeper connection suspended, rejecting operations
[A 23:50:21.207] zookeeper session lost (expired), rejecting operations
[A 23:50:21.309] zookeeper connected
[A 23:50:21.325] watch kite v2: open, highest carol 150 (bid via B)
[A 23:50:22.187] close kite: state changed since v1, retry
[A 23:50:24.192] close kite: closed by A, winner carol 150 (bid via B) (v2 -> v3, zxid 0x130)
```

A's close was based on v1 and would have made bob 100 the winner, the write with version 1 fails, the retry closes with the real highest bid carol 150

A cut off from zookeeper with nftables for 12s

```
disconnect A 23:50:33.453
[A 23:50:34.539] zookeeper connection suspended, rejecting operations
[B 23:50:37.188] members ['B']
[A 23:50:37.773] bid sled alice 50 rejected: no zookeeper connection
[A 23:50:38.154] query rejected: no zookeeper connection
[B 23:50:38.761] bid sled bob 60 accepted, id B-1794873038757-6 (v1 -> v2, zxid 0x135)
reconnect A 23:50:45.463
[A 23:50:46.130] zookeeper session lost (expired), rejecting operations
[A 23:50:46.256] zookeeper connected
[A 23:50:46.260] watch sled v2: open, highest bob 60 (bid via B)
[A 23:50:50.160] bid sled alice 70 accepted, id A-1794873050155-3 (v2 -> v3, zxid 0x138)
```

A notices the missing ping replies after 1.1s and rejects everything until it has a session again, after that it continues from the current state v2

how a recovered node is kept from acting on outdated state:

- no auction state on the node, only in zookeeper, a (re)started node reads it before doing anything
- every decision is made on a fresh read, and the write only succeeds with that read's version, a write based on old data (paused, slow, reconnected node) fails with BadVersionError
- the connection listener marks the node as disconnected on SUSPENDED / LOST, then no operation is started
- if the connection drops while a write is in flight the result is unknown, the node reports "outcome unknown" with the bid id, the id in the state / history shows later if it was committed

### Random faults (3.6)

faults.sh, 20 auctions on all 5 nodes, per auction:

- 4 random nodes run bot 6 0.3 (6s of random bids slightly above the highest bid they saw, 0-0.3s apart)
- the 5th node closes at a random time 2-5s after the start, while the bots are still bidding
- 1-2 of the other nodes get a random fault 0.5-5s after the start, for 1-8s: crash (kill -9, then restart), pause (SIGSTOP / SIGCONT) or disconnect (nftables)
- afterwards every node calls close again, all have to report the same result

check_auctions.py then reads all auctions and bid histories from zookeeper and compares them with the node logs

29 faults: 14 crashes, 10 disconnects, 5 pauses, 12 of them before the close (during bidding), 17 after it

| Auction | Accepted bids | Increasing | Winner = highest | All bids before close | Close results |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **f01** | 63 | yes | yes (e1 353) | yes | 1 |
| **f05** | 103 | yes | yes (a3 586) | yes | 1 |
| **f09** | 115 | yes | yes (d2 648) | yes | 1 |
| **f16** | 121 | yes | yes (d1 675) | yes | 1 |
| ... | | | | | |
| **all 20** | 1605 | 20 / 20 | 20 / 20 | 20 / 20 | 1 each |

full table in logs/faults_check.txt

- every bid a node reported as accepted (1605) is in the history, none lost, every history entry was acknowledged
- bid amounts in the history strictly increasing, winner = last accepted bid = highest
- no bid created after the close: every bid's czxid is lower than the zxid of the closing write
- 20 closes, the other 100 close calls (5 per auction at the end) all returned "already closed" with the same winner
- 88 version conflicts, all resolved by a retry, 75 bids rejected as not higher
- 32 operations rejected because the node had no zookeeper connection, 11 sessions expired (long pause / disconnect), the nodes got a new session and continued from the zookeeper state
- no "outcome unknown": no fault hit a write that was in flight

the bots stop as soon as they read a closed state, so the race of a bid with the close itself only shows in task 2

---

## Questions

> How is the auction state represented in ZooKeeper? Which parts must be persistent?

one persistent znode per auction with the whole state as json (status, highest bid, winner), its version is used for every update

accepted bids as persistent sequential children, as history to check the result

the node membership as ephemeral znodes, only for failure detection

persistent: the state znode and the bid history, they are the authoritative result and have to survive node crashes (zookeeper writes them to its transaction log / snapshots before answering), ephemeral: only the membership, it should disappear with the node

this also covers the zookeeper server: the aws lab stopped all instances overnight, after the restart /auctions/car was still closed with winner bob 1200 (data dir on the host disk)

> Which ZooKeeper mechanisms prevent conflicting updates from concurrent nodes?

conditional set_data with the znode version (compare and set): zookeeper applies writes one after another in zxid order, a write on an outdated version fails

multi transactions: state update and history entry are applied together or not at all

sessions: an expired session can't write anymore, its requests fail with SessionExpired

local locks wouldn't help, the nodes are on different machines

> What happens if two nodes try to close the auction simultaneously?

both read the open state with the same version and try to write closed, zookeeper accepts only the first, the second gets BadVersionError

the second reads again, sees closed and reports the existing result (task 2, clock: D closed, C got "already closed by D" with the same winner)

there is one final result, and the closed state is never written again

> How does a restarted node obtain the correct auction state?

it opens a new zookeeper session, reads the state znode and sets the watches again (task 3: A shows v3 closed 13 ms after the restart)

it has no local state that could be outdated, a quick restart with the same name waits until the old session's ephemeral member node is gone

> What happens if an application node cannot reach ZooKeeper? Why might rejecting operations be preferable to continuing with locally cached state?

the client notices missing ping replies (suspended, 1.1s in the experiment), the node rejects bids, closes and queries, after the session timeout zookeeper deletes its ephemeral node and the others see it leave

on reconnect within the timeout the session continues, otherwise a new session is created and the state read again

with a cached state the node would accept bids that are lower than bids accepted elsewhere in the meantime or after the auction was closed (in the disconnect run B accepted bob 60 while A still had bob 10)

and it could tell a participant "accepted" or "you won" although that is never written, rejecting keeps the answers consistent (CP instead of AP), the cost is that the node is unavailable while disconnected

