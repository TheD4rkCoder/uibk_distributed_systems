# EX02 Report: Shared State (C++ version)

**Student Name:** David Mairhofer
**Student ID:** `csbc2382`

---

## Setup

Same [main.tf](../main.tf) as the Python version

But this time with:

```bash
sudo dnf install -y gcc-c++        # both nodes
sudo dnf install -y redis6         # only A, the store
```
Start Redis on A, then copy and compile the programs:
```bash
redis6-server --port 6379 --bind 0.0.0.0 --protected-mode no --daemonize yes
scp -i ../labsuser.pem counter.cpp single.cpp ec2-user@<ip>:~/
g++ -O2 -std=c++17 -pthread counter.cpp -o counter
g++ -O2 -std=c++17 -pthread single.cpp -o single
```

## Task 1 - Replicated counter

[counter.cpp](counter.cpp):
same logic as the python counterpart

```cpp
// thread, runs the whole program
static void receive_loop(int fd) {        
    ...
    g_a = max(g_a, pa);                   
    g_b = max(g_b, pb);
}
...
if (basic) {
    g_a++;  // basic: both nodes change slot a
} else if (role == "A") {
    g_a++;  // improved: A only changes its own slot
} else {
    g_b++;
}  
send_all(fd, to_string(g_a) + " " + to_string(g_b) + "\n");
```


```bash
./counter <A|B> <my_port> <peer_host> <peer_port> <increments> <basic|improved>
```

### 1.1 - Basic version

A increments 100 times, B none:
```bash
./counter A 5002 127.0.0.1 5002 100 basic   # on A
./counter B 5002 172.31.87.249 5002 0 basic # on B
```
```
A: local 0.1094 ms, send 1.728 ms, sync 0.158 ms, A=100 B=0 total=100
B: local 0.0000 ms, send 0.000 ms, sync 2.536 ms, A=100 B=0 total=100
```

### 1.2 - Concurrent increments

One increment on each node:
```
A: local 0.0040 ms, send 0.024 ms, sync 0.088 ms, A=1 B=0 total=1
B: local 0.0013 ms, send 0.020 ms, sync 0.399 ms, A=1 B=0 total=1
```
Result is 1 but should be 2. Both increment from 0 to 1, then `max(1, 1)` keeps one of them.

It gets worse with more increments: 
100 increments each (correct: 200) gave 100, 123, 118 in three local runs. 30 each gave 30 pretty consistently (probably because increments are too fast)

### 1.3 - Lost, duplicated and old messages

look at python version

### 1.4 - Improved version

Each node increments only its own field and they combine in the end:
```bash
./counter A 5006 127.0.0.1 5006 100 improved   # on A
./counter B 5006 172.31.87.249 5006 100 improved # on B
```
```
1 increment each:    A=1 B=1 total=2
100 increments each: A: local 0.1426 ms, send 1.414 ms, sync 0.191 ms, A=100 B=100 total=200
                     B: local 0.0484 ms, send 0.923 ms, sync 1.999 ms, A=100 B=100 total=200
```

## Task 2 - Single-copy counter

The counter lives in Redis on A. 

I never used redis before, so here a short note for myself:
Redis is an in-memory key-value store; the nodes send it text commands like `INCR counter` and get the answer back. `INCR` is atomic, so the whole +1 happens inside Redis. 

The programs speak the Redis protocol directly (thanks deepseek for explaining this), so no client library is needed.

```cpp
if (safe) {
    redis_cmd(fd, "INCR counter");       // atomic
} else {
    int value = atoi(redis_cmd(fd, "GET counter").c_str());
    this_thread::sleep_for(chrono::milliseconds(5));
    redis_cmd(fd, "SET counter " + to_string(value + 1));  // not atomic
}
```

```bash
./single <redis_host> <redis_port> <increments> <safe|unsafe>
```

### 2.1 - Safe increments

```bash
./single 127.0.0.1 6379 100 safe       # on A
./single 172.31.87.249 6379 100 safe   # on B, started at the same time
```
```
A: safe: 1.61 ms, counter: 100
B: safe: 18.50 ms, counter: 200
```

### 2.2 - Concurrent updates

```bash
./single 127.0.0.1 6379 100 unsafe       # on A
./single 172.31.87.249 6379 100 unsafe   # on B
```
```
A: unsafe: 514.8 ms, counter: 126
B: unsafe: 564.1 ms, counter: 106
final counter: 126   (instead of 200, 74 increments lost)
```
Both read the same value before the other wrote, so they overwrote each other.

A second update does not fail and does not run in parallel: Redis handles one command at a time, the next one waits. The 200 in 2.1 is the proof, no update was lost or failed.

## Task 3 - Comparison

| what                                            | time         |
| ----------------------------------------------- | ------------ |
| replicated: 100 local increments                | 0.05-0.14 ms |
| replicated: sending those 100 messages          | 0.9-1.7 ms   |
| replicated: waiting for the peer's last message | 0.08-2.0 ms  |
| single-copy: 100 INCR from A                    | 1.6 ms       |
| single-copy: 100 INCR from B                    | 18.5 ms      |
| store unsafe: 100 GET/SET with 5 ms sleep       | ~0.55 s      |
