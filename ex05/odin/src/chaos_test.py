#!/usr/bin/env python3
"""
Task 3.6: run several auctions while randomly injecting faults, then verify invariants.

Every node container (docker-compose.yml) runs one auction_node.py `worker` that bids
continuously. Meanwhile this harness randomly injects faults into the node containers:

  crash      docker kill + docker start     node crashes, restarts with no local state
  partition  network disconnect > timeout   ZooKeeper unreachable, session expires
  blip       network disconnect < timeout   connection suspended, session survives
  freeze     docker pause > timeout         process stops mid-operation and resumes later
                                            with stale local state (e.g. a GC pause)

Each auction is closed by two concurrent `close` calls on different nodes, while bids keep
coming in. At the end all auctions are read from ZooKeeper and checked.

    docker compose up -d --build
    python3 chaos_test.py --auctions 10 --duration 15
"""

from __future__ import annotations

import argparse
import json
import random
import subprocess
import sys
import threading
import time
from collections import Counter, defaultdict
from pathlib import Path

NETWORK = "ex05-auction"
NODES = [f"ex05-node{i}" for i in range(1, 6)]
SESSION_TIMEOUT = 5.0


def docker(*args, check=False):
    return subprocess.run(["docker", *args], capture_output=True, text=True, check=check)


def node_cmd(container, node_args):
    return ["docker", "exec", container, "python3", "-u", "auction_node.py", *node_args]


def run_once(container, node_args, timeout=60) -> dict:
    """Run a one-shot auction command (--json) in a container and return its result."""
    p = subprocess.run(node_cmd(container, ["--json", *node_args]),
                       capture_output=True, text=True, timeout=timeout)
    lines = [ln for ln in p.stdout.splitlines() if ln.startswith("{")]
    if lines:
        return json.loads(lines[-1])
    return {"result": "error", "msg": (p.stdout + p.stderr).strip()[-300:], "auction": None}


class Worker:
    def __init__(self, container, args, sink):
        self.container, self.args, self.sink = container, args, sink
        self.wid = container.removeprefix("ex05-")

    def start(self):
        node_args = ["--id", self.wid, "--json", "--think", str(self.args.think),
                     "--interval", str(self.args.interval), "worker"]
        proc = subprocess.Popen(node_cmd(self.container, node_args), stdout=subprocess.PIPE,
                                stderr=subprocess.DEVNULL, text=True, bufsize=1)
        threading.Thread(target=self._read, args=(proc,), daemon=True).start()

    def _read(self, proc):
        for line in proc.stdout:
            try:
                ev = json.loads(line)
            except json.JSONDecodeError:
                continue
            ev["worker"] = self.wid
            self.sink(ev)

    def stop(self):
        docker("exec", self.container, "pkill", "-KILL", "-f", "auction_node.py")


class Cluster:
    """Tracks which containers are currently faulted / in use, and injects faults."""

    def __init__(self, workers, args, rng):
        self.workers, self.args, self.rng = workers, args, rng
        self.busy = set()
        self.lock = threading.Lock()
        self.stop_evt = threading.Event()
        self.threads = []
        self.counts = Counter()
        self.log = []

    # -- reserve healthy containers for closes / queries so faults don't hit them
    def acquire(self, n):
        while True:
            with self.lock:
                free = [w for w in self.workers if w.container not in self.busy]
                if free:
                    picked = self.rng.sample(free, min(n, len(free)))
                    self.busy.update(w.container for w in picked)
                    return picked
            time.sleep(0.2)

    def release(self, picked):
        with self.lock:
            self.busy.difference_update(w.container for w in picked)

    # -- fault injection
    def run_faults(self):
        while not self.stop_evt.wait(self.rng.uniform(0.5, 1.5) * self.args.fault_interval):
            with self.lock:
                free = [w for w in self.workers if w.container not in self.busy]
                if len(free) <= 1:   # keep at least one healthy node
                    continue
                w = self.rng.choice(free)
                self.busy.add(w.container)
            kind = self.rng.choice(["crash", "partition", "blip", "freeze"])
            t = threading.Thread(target=self._fault, args=(w, kind))
            t.start()
            self.threads.append(t)

    def _fault(self, w, kind):
        c = w.container
        try:
            print(f"  ! {kind:9s} {w.wid}")
            self.counts[kind] += 1
            self.log.append({"t": time.time(), "kind": kind, "node": w.wid})
            if kind == "crash":
                docker("kill", c)
                time.sleep(self.rng.uniform(0.5, 3))
                docker("start", c, check=True)
                w.start()
            elif kind in ("partition", "blip"):
                docker("network", "disconnect", NETWORK, c)
                time.sleep(SESSION_TIMEOUT + self.rng.uniform(1, 3) if kind == "partition"
                           else self.rng.uniform(0.5, SESSION_TIMEOUT / 2))
                docker("network", "connect", NETWORK, c)
            else:
                docker("pause", c)
                time.sleep(SESSION_TIMEOUT + self.rng.uniform(1, 3))
                docker("unpause", c)
        finally:
            self.release([w])

    def finish(self):
        self.stop_evt.set()
        for t in self.threads:
            t.join()


def heal_all():
    """Undo leftovers of an interrupted run."""
    for c in NODES:
        docker("unpause", c)
        docker("start", c)
        docker("network", "connect", NETWORK, c)   # fails harmlessly if already connected


def verify(auctions, events, closes, tested):
    problems = []
    hist_ops = {}
    for aid, entry in auctions.items():
        s, ver = entry["state"], entry["version"]
        amounts = [b["amount"] for b in s["bids"]]
        hist_ops[aid] = {b["op"] for b in s["bids"]}
        if any(b <= a for a, b in zip(amounts, amounts[1:])):
            problems.append(f"auction {aid}: accepted bids not strictly increasing {amounts}")
        if s["highest"] != (s["bids"][-1] if s["bids"] else None):
            problems.append(f"auction {aid}: highest bid is not the last accepted bid")
        if s["status"] == "CLOSED":
            if s["winner"] != s["highest"]:
                problems.append(f"auction {aid}: winner differs from highest bid")
            if ver != s["closed_version"]:
                problems.append(f"auction {aid}: modified after closing (v{s['closed_version']} -> v{ver})")

    for ev in events:
        if ev["op"] == "bid" and ev["result"] == "accepted":
            if ev["data"]["op_id"] not in hist_ops.get(ev["auction"], set()):
                problems.append(f"acknowledged bid {ev['data']} on auction {ev['auction']} was lost")

    for aid in tested:
        rs = closes.get(aid, [])
        n_closed = sum(r["result"] == "closed" for r in rs)
        if n_closed != 1:
            problems.append(f"auction {aid}: {n_closed} successful closes (expected exactly 1)")
        final = auctions[aid]["state"]
        if final["status"] != "CLOSED":
            problems.append(f"auction {aid}: not closed")
        for r in rs:
            if r["result"] in ("closed", "already_closed") and r["data"]["winner"] != final["winner"]:
                problems.append(f"auction {aid}: closer saw winner {r['data']['winner']}, final {final['winner']}")
    return problems


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--auctions", type=int, default=5)
    ap.add_argument("--duration", type=float, default=15, help="seconds of bidding per auction")
    ap.add_argument("--fault-interval", type=float, default=2.0, help="mean seconds between faults")
    ap.add_argument("--think", type=float, default=0.2, help="worker read->write delay (more conflicts)")
    ap.add_argument("--interval", type=float, default=0.3, help="worker max pause between bids")
    ap.add_argument("--no-faults", action="store_true", help="only concurrency, no fault injection")
    ap.add_argument("--seed", type=int, default=None)
    ap.add_argument("--out", default="chaos_results.json")
    args = ap.parse_args()

    rng = random.Random(args.seed)
    heal_all()

    # make sure an auction is open before the workers start
    r = run_once(NODES[0], ["--id", "harness", "query"])
    if r["result"] == "error":
        sys.exit(f"cannot run auction node: {r['msg']}\n(did you run `docker compose up -d --build`?)")
    if r["data"]["state"]["status"] == "CLOSED":
        run_once(NODES[0], ["--id", "harness", "new"])

    events, lock = [], threading.Lock()

    def sink(ev):
        with lock:
            events.append(ev)

    workers = [Worker(c, args, sink) for c in NODES]
    for w in workers:
        w.start()
    cluster = Cluster(workers, args, rng)
    fault_thread = threading.Thread(target=cluster.run_faults, daemon=True)
    if not args.no_faults:
        fault_thread.start()

    closes, tested = defaultdict(list), []
    try:
        for round_ in range(args.auctions):
            print(f"--- round {round_ + 1}/{args.auctions}: bidding for {args.duration}s")
            time.sleep(args.duration)

            # two concurrent closes on different healthy nodes, while bids keep coming in
            closers = cluster.acquire(2)
            if len(closers) == 1:
                closers *= 2
            results = [None, None]

            def do_close(i):
                results[i] = run_once(closers[i].container, ["--id", f"closer-{i + 1}", "close"])

            ts = [threading.Thread(target=do_close, args=(i,)) for i in range(2)]
            for t in ts:
                t.start()
            for t in ts:
                t.join()
            cluster.release(closers)
            for r in results:
                print(f"  close: {r['result']:14s} {r.get('msg', '')}")
                if r.get("auction") is not None:
                    closes[r["auction"]].append(r)
            aid = next((r["auction"] for r in results if r.get("auction") is not None), None)
            if aid is not None:
                tested.append(aid)

            if round_ < args.auctions - 1:
                time.sleep(1)  # bids arriving now must be rejected (auction closed)
                (n,) = cluster.acquire(1)
                print(f"  new:   {run_once(n.container, ['--id', 'harness', 'new'])['msg']}")
                cluster.release([n])
    finally:
        print("--- stopping, waiting for running faults to end")
        cluster.finish()
        heal_all()
        time.sleep(1)
        for w in workers:
            w.stop()

    time.sleep(1)
    dump = run_once(NODES[0], ["--id", "harness", "dump"])
    auctions = {int(k): v for k, v in dump["data"]["auctions"].items()}
    problems = verify(auctions, events, closes, tested)

    c = Counter((e["op"], e["result"]) for e in events)
    print("\n=== summary")
    print(f"auctions tested : {tested}")
    print(f"faults injected : {dict(cluster.counts)}")
    print(f"bids accepted   : {c[('bid', 'accepted')]}")
    print(f"bids rejected   : {c[('bid', 'rejected')]}")
    print(f"bids errored    : {c[('bid', 'error')]}  (disconnected / session expired / timeout)")
    print(f"CAS retries     : {sum(e.get('retries', 0) for e in events)}")
    print(f"sessions lost   : {c[('conn', 'lost')]}, suspended: {c[('conn', 'suspended')]}")
    for aid in tested:
        s = auctions[aid]["state"]
        w = s["winner"]
        print(f"auction {aid:3d}    : {len(s['bids']):3d} bids, winner "
              f"{w['bidder'] + '=' + str(w['amount']) if w else '-'}, closed by {s['closed_by']}")
    print("\nINVARIANTS:", "ALL OK" if not problems else f"{len(problems)} VIOLATIONS")
    for p in problems:
        print("  -", p)

    Path(args.out).write_text(json.dumps(
        {"events": events, "closes": closes, "auctions": auctions, "problems": problems,
         "faults": cluster.log}, indent=1))
    print(f"raw results written to {args.out}")
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
