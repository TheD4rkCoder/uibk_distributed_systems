# EX04 Report: Leader Election

**Student Name:** Maurits van Staalduinen  
**Student ID:** `c9881018`  

Claude Opus 5.5 used for the code, running the aws experiments and the report draft

**Chosen stack:** python 3.9, plain udp sockets with json messages (no middleware)

## Task 1 - State Machine & Leader Election

### 1.1 - State Variables

election_node.py, one process per node, started with its name and the address of every node

| Variable | Kind | Where |
| :--- | :--- | :--- |
| **current_term** | persistent, starts at 0 | state_<name>.json |
| **voted_for** | persistent, None or a node name | state_<name>.json |
| **role** | volatile, always starts as follower | memory |
| leader, votes, timers | volatile | memory |

the state file is written with write + fsync + rename before a vote or a candidacy goes out, so a node that crashes and restarts can't vote twice in the same term

```python
def save_state():
    tmp = state_file + ".tmp"
    with open(tmp, "w") as f:
        json.dump({"current_term": st.term, "voted_for": st.voted_for}, f)
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, state_file)
```

### 1.2 - Election and Heartbeats

4 message types, every message carries term and sender:

| Message | Sent by | Answer |
| :--- | :--- | :--- |
| **vote_req** | candidate to all | vote_resp with granted true / false |
| **heartbeat** | leader to all, every 50ms | heartbeat_resp, success false if the leader's term is old |

election timeout random in 150-300ms, picked again on every reset (granted vote, valid heartbeat, new candidacy)

follower or candidate timer runs out -> term + 1, vote for itself, vote_req to everyone

majority = len(nodes) // 2 + 1 (2 of 3), the candidate becomes leader on the vote that reaches it and sends the first heartbeat right away

one rule for every message: a higher term is adopted, voted_for is cleared and the node becomes follower

```python
def handle(msg):
    if msg["term"] > st.term:
        step_down(msg["term"], f"{msg['type']} from {msg['from']}")
    handlers[msg["type"]](msg)

def on_vote_req(msg):
    candidate = msg["from"]
    granted = msg["term"] == st.term and st.voted_for in (None, candidate)
    ...
    send(candidate, "vote_resp", granted=granted)
```

a single thread: the socket timeout is set to the next due timer (heartbeat or election deadline), so no locks are needed

rejections are sent explicitly (vote_resp granted=false, heartbeat_resp success=false), the reply carries the receiver's term, so a stale sender finds out about the newer term right away

each node logs a summary once per second instead of 20 heartbeat lines: followers count received heartbeats per leader, the leader counts acks per follower

---

## Task 2 - Experiments & Failure Recovery

3 t2.micro instances (A, B, C) from main.tf, each node started in its own ssh session, udp port 6000 only open inside the security group

the clocks were synced by chrony to ~10 us, so timestamps from different nodes can be compared

```
python3 election_node.py A A=172.31.16.186:6000 B=172.31.28.158:6000 C=172.31.31.56:6000 --fresh --start-at <t>    #same for B and C
```

### 2.1 - Initial Leader Election

```
[C 21:08:10.701] start as follower, term 0, cluster ['A', 'B', 'C'], majority 2, timeout 150-300 ms
[C 21:08:10.895] election timeout, no leader -> candidate, term 1
[A 21:08:10.895] term 0 -> 1 (vote_req from C)
[A 21:08:10.899] vote for C in term 1
[C 21:08:10.899] vote from A (2/3, need 2)
[C 21:08:10.899] elected leader, term 1, votes ['A', 'C'] (5.7 ms after becoming candidate)
[B 21:08:11.327] start as follower, term 0, ...
[B 21:08:11.350] term 0 -> 1 (heartbeat from C)
[C 21:08:12.701] leader, term 1, heartbeat acks in the last 1s: A 20, B 20
[A 21:08:12.777] follower, term 1, heartbeats in the last 1s: C 20
[B 21:08:12.328] follower, term 1, heartbeats in the last 1s: C 20
```

C's timer ran out first (194 ms), A's vote was enough, C was leader 4 ms later

B's ssh started it 0.6s late, it didn't need an election: the first heartbeat (23 ms after start) set its term to 1

after that every second: 20 heartbeats at each follower, 20 acks per follower at C, one leader, no other node became candidate

### 2.2 - Leader Crash & Re-election

kill -9 on C (crash, no goodbye message)

```
kill -9 C 21:08:22.167
[B 21:08:22.311] election timeout, no heartbeat from C for 159 ms -> candidate, term 2
[A 21:08:22.311] term 1 -> 2 (vote_req from B)
[A 21:08:22.314] vote for B in term 2
[B 21:08:22.314] vote from A (2/3, need 2)
[B 21:08:22.314] elected leader, term 2, votes ['A', 'B'] (4.7 ms after becoming candidate)
[A 21:08:22.777] follower, term 2, heartbeats in the last 1s: C 8, B 10
[B 21:08:23.328] leader, term 2, heartbeat acks in the last 1s: A 20, C 0
```

detection: nothing tells the others that C is gone, they only see that heartbeats stop, B's election timer (159 ms) ran out first, A's was longer

follower -> candidate: B increments its term to 2, votes for itself and sends vote_req

new term: A sees term 2 > 1, adopts it and votes B, B has 2 of 3 and is leader 147 ms after the crash

2 of 3 is still a majority, so the cluster works without C, B keeps sending to C (0 acks)

### 2.3 - Node Recovery

C started again 4.5s later, without --fresh

```
restart C 21:08:26.720
[C 21:08:26.760] restored term 1, voted for C from state_C.json
[C 21:08:26.760] start as follower, term 1, ...
[C 21:08:26.765] term 1 -> 2 (heartbeat from B)
[C 21:08:26.767] following B, term 2
[C 21:08:27.761] follower, term 2, heartbeats in the last 1s: B 20
[B 21:08:28.327] leader, term 2, heartbeat acks in the last 1s: A 20, C 20
```

C comes back with its old term 1 from the state file and as follower, the role isn't persisted, being leader before means nothing after a restart

the first heartbeat from B (5 ms later) has term 2 > 1, C adopts it and follows B

no new election: heartbeats come every 50ms, the shortest timeout is 150ms, so the restarted node always hears the leader before its own timer runs out

B stays leader in term 2, it just counts C's acks again

---

## Task 3 - Conceptual Questions

### 3.1

> Why are randomized election timeouts critical for preventing perpetual split votes?

if timers run out at the same time, every node becomes candidate, votes for itself and rejects the others, nobody gets a majority

with the same timeout they all restart at the same time and the same thing happens in every term

with random timeouts one node is usually tens of ms earlier, its vote_req (a few ms) reaches the others before their timers run out, they vote for it

measured with 10 cold starts of A, B, C at the same instant (--start-at, clocks synced), fixed 150ms vs random 150-300ms:

| Timeout | Leader in term 1 | Leader later | No leader after 3s | Time to leader |
| :--- | :--- | :--- | :--- | :--- |
| **fixed 150ms** | 0 / 10 | 6 / 10 (term 3, 3, 3, 4, 5, 10) | 4 / 10 (19 split terms each) | 463-1538 ms |
| **random 150-300ms** | 10 / 10 | - | - | 161-214 ms |

```
[A 21:11:36.219] election timeout, no leader -> candidate, term 1
[B 21:11:36.218] election timeout, no leader -> candidate, term 1
[C 21:11:36.219] election timeout, no leader -> candidate, term 1
[A 21:11:36.219] reject vote for B in term 1 (term 1, voted for A)
[A 21:11:36.372] election timeout, no majority in term 1 -> candidate, term 2
[B 21:11:36.370] election timeout, no majority in term 1 -> candidate, term 2
```

with fixed timeouts only the small jitter of the python loop sometimes breaks the symmetry, in 4 runs it never did

> What happens if two candidates receive an equal number of votes in a cluster, and how does the system recover?

no candidate has a majority, so the term has no leader, a node votes only once per term, so the votes aren't moved to another candidate

the candidates stay candidates until their timers run out, start a new term (+1), vote for themselves and ask again

a new random timeout is drawn for every candidacy, so one of them is usually first in the next term and wins it, a tie only costs one more timeout (150-300ms)

in the fixed runs above, all 3 nodes were candidates with 1 vote each, terms 1 and 2 had no leader, B won term 3

with 3 nodes a 1:1 tie only happens if the third node is down or a candidate itself, with an even number of nodes (e.g. 2:2 in 4) it can happen with all nodes up

> How does comparing currentTerm prevent an isolated or delayed node from disrupting the active cluster with stale messages?

every message carries the sender's term: lower term -> rejected, the reply carries the newer term and makes the sender step down

tested with nftables dropping all udp 6000 traffic of leader A for ~3s (logs/isolate_*.log):

```
cut A 21:10:59.956
[C 21:11:00.103] election timeout, no heartbeat from A for 174 ms -> candidate, term 2
[C 21:11:00.105] elected leader, term 2, votes ['B', 'C'] (5.6 ms after becoming candidate)
heal A    #nft rule removed ~21:11:02.87
[B 21:11:02.875] reject heartbeat from A (term 1 < 2)
[C 21:11:02.875] reject heartbeat from A (term 1 < 2)
[A 21:11:02.876] term 1 -> 2 (heartbeat_resp from B), leader -> follower
[A 21:11:02.906] following C, term 2
```

A thinks it is leader of term 1 the whole time, after healing its heartbeats are ignored, the answer moves it to term 2 and it follows C, the cluster isn't affected

the other way doesn't work as well: an isolated follower keeps starting elections and its term grows (A, ~3s alone: term 3 -> 15)

```
[A 21:11:11.106] reject heartbeat from C (term 2 < 15)
[C 21:11:11.107] term 2 -> 15 (heartbeat_resp from A), leader -> follower
[A 21:11:11.160] elected leader, term 16, votes ['A', 'B']
```

its higher term forces the working leader C to step down, safety still holds (one leader per term), but there is a needless re-election

real systems add a pre-vote round (only increment the term if a majority would vote) and a log check (raft only votes for candidates with an up-to-date log)

> Is leader election alone sufficient to guarantee linearizable consistency in a distributed database? Explain briefly.

no, it only guarantees at most one leader per term, not that there is only one node that thinks it is leader

in the isolate run A acted as leader of term 1 for ~2.8s while C was already leader of term 2, if A answered reads it would return stale data, and writes it accepted would be lost

linearizability also needs: replicating every write to a majority before acknowledging it (log replication + commit), only electing nodes that have all committed writes, and reads checked with a majority (read index / leases), which is the part left out of this exercise

---

instances destroyed with terraform destroy after the runs
