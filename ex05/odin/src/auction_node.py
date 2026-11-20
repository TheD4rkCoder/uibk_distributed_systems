#!/usr/bin/env python3
"""
Distributed auction node, coordinated exclusively through Apache ZooKeeper.

Usage:
    python3 auction_node.py                  # interactive CLI
    python3 auction_node.py bid alice 50     # one-shot commands (handy for experiments)
    python3 auction_node.py query
    python3 auction_node.py close
    python3 auction_node.py new
    python3 auction_node.py --json worker    # random-bid loop, used by chaos_test.py

Configuration (flags override environment):
    --zk  / ZK_HOSTS   e.g. "10.0.1.23:2181"   (default 127.0.0.1:2181)
    --id  / NODE_ID    e.g. "node-1"           (default: hostname)
"""

from __future__ import annotations

import argparse
import json
import logging
import os
import random
import socket
import sys
import threading
import time
import uuid
from dataclasses import asdict, dataclass, field

from kazoo.client import KazooClient, KazooState
from kazoo.exceptions import BadVersionError, KazooException, NodeExistsError, NoNodeError
from kazoo.handlers.threading import KazooTimeoutError

ROOT = "/auction"
CURRENT_PATH = f"{ROOT}/current"
AUCTIONS_PATH = f"{ROOT}/auctions"
NODES_PATH = f"{ROOT}/nodes"

SESSION_TIMEOUT = 5.0   # seconds
OP_TIMEOUT = 3.0        # seconds
MAX_RETRIES = 100

log = logging.getLogger("auction")


def auction_path(aid: int) -> str:
    return f"{AUCTIONS_PATH}/{aid:010d}"


def new_auction_state(aid: int) -> dict:
    return {
        "id": aid,
        "status": "OPEN", # OPEN | CLOSED
        "highest": None, # {"bidder", "amount", "node", "op"} or None
        "bids": [], # all accepted bids
        "winner": None, # set exactly once, by close()
        "closed_by": None,
        "closed_version": None, 
    }


def describe(state: dict) -> str:
    h = state["highest"]
    if state["status"] == "OPEN":
        best = f"highest {h['bidder']}={h['amount']}" if h else "no bids yet"
        return f"auction {state['id']} OPEN, {best} ({len(state['bids'])} bids)"
    w = state["winner"]
    result = f"winner {w['bidder']}={w['amount']}" if w else "no winner"
    return f"auction {state['id']} CLOSED by {state['closed_by']}, {result}"


def encode(obj) -> bytes:
    return json.dumps(obj).encode()


def decode(data: bytes):
    return json.loads(data.decode())


class NotConnectedError(Exception):
    """Raised when an operation is attempted without a live ZooKeeper session."""


@dataclass
class Result:
    op: str
    result: str # accepted | rejected | closed | already_closed | started | ok | error
    msg: str = ""
    auction: int | None = None
    version: int | None = None
    retries: int = 0
    data: dict = field(default_factory=dict)


class AuctionNode:
    def __init__(self, hosts: str, node_id: str, quiet: bool = False, think: float = 0.0,
                 hold: float = 0.0):
        self.node_id = node_id
        self.quiet = quiet
        self.think = think
        self.hold = hold  # fixed delay between first read and write (stale-state experiment)
        self.zk = KazooClient(hosts=hosts, timeout=SESSION_TIMEOUT)
        self.connected = threading.Event()
        self.zk.add_listener(self._on_connection_change)
        self.on_event = None # optional callback(dict) for connection events
        self.watched_auction = None # auction id
        self.cache = None # (state, version) last seen via watch
        self.stopping = False


    def start(self):
        self.zk.start(timeout=10)
        self.zk.ensure_path(AUCTIONS_PATH)
        self.zk.ensure_path(NODES_PATH)
        self._init_first_auction()
        self._register()
        self.zk.DataWatch(CURRENT_PATH, self._on_current_changed)
        self.zk.ChildrenWatch(NODES_PATH, self._on_members_changed)

    def stop(self):
        self.stopping = True
        self.zk.stop()
        self.zk.close()

    # connection handling

    def _on_connection_change(self, state):
        # Runs on kazoo's connection thread
        if self.stopping:
            return 
        if state == KazooState.CONNECTED:
            self.connected.set()
            log.info("connected to ZooKeeper")
            self.zk.handler.spawn(self._register)
        elif state == KazooState.SUSPENDED:
            self.connected.clear()
            log.warning("connection to ZooKeeper suspended, rejecting operations")
        elif state == KazooState.LOST:
            self.connected.clear()
            log.warning("ZooKeeper session lost")
        if self.on_event:
            self.on_event({"op": "conn", "result": str(state).lower()})

    def require_connected(self):
        if not self.connected.is_set():
            raise NotConnectedError("not connected to ZooKeeper, refusing operation")

    # setup

    def _init_first_auction(self):
        if self.zk.exists(CURRENT_PATH):
            return
        tx = self.zk.transaction()
        tx.create(CURRENT_PATH, b"1")
        tx.create(auction_path(1), encode(new_auction_state(1)))
        if not any(isinstance(r, Exception) for r in tx.commit()):
            log.info("created auction 1")

    def _register(self):
        path = f"{NODES_PATH}/{self.node_id}"
        try:
            while True:
                try:
                    self.zk.create(path, encode({"host": socket.gethostname()}),
                                   ephemeral=True, makepath=True)
                    return
                except NodeExistsError:
                    try:
                        _, stat = self.zk.get(path)
                        if stat.ephemeralOwner == self.zk.client_id[0]:
                            return  # already registered in this session
                        self.zk.delete(path, version=stat.version)
                    except NoNodeError:
                        pass
        except KazooException as e:
            log.warning("could not register membership: %r", e)

    # watches

    def _on_current_changed(self, data, stat):
        if data is None:
            return
        aid = int(data)
        if aid != self.watched_auction:
            self.watched_auction = aid
            self.zk.handler.spawn(self.zk.DataWatch, auction_path(aid), self._auction_watch(aid))

    def _auction_watch(self, aid: int):
        def callback(data, stat):
            if aid != self.watched_auction:
                return False  # newer auction started
            if data is None:
                return
            state = decode(data)
            self.cache = (state, stat.version)
            if not self.quiet:
                print(f"\n[watch] {describe(state)} (v{stat.version})")
        return callback

    def _on_members_changed(self, children):
        if not self.quiet:
            print(f"\n[watch] live nodes: {sorted(children)}")

    # zk helpers

    def _get(self, path):
        return self.zk.get_async(path).get(timeout=OP_TIMEOUT)

    def _set(self, path, data, version):
        return self.zk.set_async(path, data, version).get(timeout=OP_TIMEOUT)

    def current_auction_id(self) -> int:
        data, _ = self._get(CURRENT_PATH)
        return int(data)

    def read_auction(self, aid: int):
        data, stat = self._get(auction_path(aid))
        return decode(data), stat.version

    # operations

    def query(self) -> Result:
        self.require_connected()
        aid = self.current_auction_id()
        state, version = self.read_auction(aid)
        return Result("query", "ok", f"{describe(state)} (v{version})", aid, version,
                      data={"state": state})

    def place_bid(self, bidder: str, amount: int) -> Result:
        op_id = uuid.uuid4().hex[:12]
        for retries in range(MAX_RETRIES):
            self.require_connected()
            aid = self.current_auction_id()
            state, version = self.read_auction(aid)
            info = {"op_id": op_id, "bidder": bidder, "amount": amount}

            if state["status"] != "OPEN":
                return Result("bid", "rejected", f"auction {aid} is closed", aid, version,
                              retries, info)
            highest = state["highest"]
            if highest and amount <= highest["amount"]:
                return Result("bid", "rejected",
                              f"bid {amount} does not exceed {highest['amount']} ({highest['bidder']})",
                              aid, version, retries, info)

            if self.think:
                time.sleep(random.uniform(0, self.think))
            if self.hold and retries == 0:
                log.info("holding stale read of auction %d v%d for %.1fs", aid, version, self.hold)
                time.sleep(self.hold)

            bid ={"bidder": bidder, "amount": amount, "node": self.node_id, "op": op_id}
            state["highest"] = bid
            state["bids"].append(bid)
            self.require_connected()
            try:
                stat = self._set(auction_path(aid), encode(state), version)
            except BadVersionError:
                log.info("bid conflict on auction %d v%d, retrying", aid, version)
                continue
            return Result("bid", "accepted",
                          f"bid accepted: {bidder}={amount} on auction {aid} (v{stat.version})",
                          aid, stat.version, retries, info)
        return Result("bid", "error", "too many conflicts", retries=MAX_RETRIES)

    def close(self) -> Result:
        for retries in range(MAX_RETRIES):
            self.require_connected()
            aid = self.current_auction_id()
            state, version = self.read_auction(aid)

            if state["status"] == "CLOSED":
                return Result("close", "already_closed", f"already closed: {describe(state)}",
                              aid, version, retries, {"winner": state["winner"]})

            state.update(status="CLOSED", winner=state["highest"], closed_by=self.node_id,
                         closed_version=version + 1)  # set() increments the version by one
            self.require_connected()
            try:
                stat = self._set(auction_path(aid), encode(state), version)
            except BadVersionError:
                log.info("close conflict on auction %d v%d, retrying", aid, version)
                continue
            return Result("close", "closed", describe(state), aid, stat.version, retries,
                          {"winner": state["winner"]})
        return Result("close", "error", "too many conflicts", retries=MAX_RETRIES)

    def new_auction(self) -> Result:
        self.require_connected()
        data, cstat = self._get(CURRENT_PATH)
        cur = int(data)
        state, _ = self.read_auction(cur)
        if state["status"] == "OPEN":
            return Result("new", "rejected", f"auction {cur} is still open", cur)

        nid = cur + 1
        # Atomically advance the pointer and create the new auction
        tx = self.zk.transaction()
        tx.set_data(CURRENT_PATH, str(nid).encode(), version=cstat.version)
        tx.create(auction_path(nid), encode(new_auction_state(nid)))
        results = tx.commit_async().get(timeout=OP_TIMEOUT)
        if any(isinstance(r, Exception) for r in results):
            return Result("new", "rejected", "another node started a new auction concurrently")
        return Result("new", "started", f"auction {nid} started", nid)

    def members(self) -> Result:
        self.require_connected()
        nodes = sorted(self.zk.get_children(NODES_PATH))
        return Result("nodes", "ok", f"live nodes: {nodes}", data={"nodes": nodes})

    def dump(self) -> Result:
        self.require_connected()
        auctions = {}
        for child in sorted(self.zk.get_children(AUCTIONS_PATH)):
            state, version = self.read_auction(int(child))
            auctions[int(child)] = {"state": state, "version": version}
        lines = [f"{describe(a['state'])} (v{a['version']})" for a in auctions.values()]
        return Result("dump", "ok", "\n".join(lines), self.current_auction_id(),
                      data={"auctions": auctions})


# CLI

HELP = """commands:
  bid <bidder> <amount>   place a bid on the current auction
  query                   show the current auction
  close                   close the current auction
  new                     start a new auction (current one must be closed)
  nodes                   list live nodes
  dump                    show all auctions
  help                    show this help
  quit                    exit"""


def execute(node: AuctionNode, args: list[str]) -> Result:
    cmd, rest = args[0].lower(), args[1:]
    try:
        if cmd == "bid" and len(rest) == 2:
            return node.place_bid(rest[0], int(rest[1]))
        if cmd == "query":
            return node.query()
        if cmd == "close":
            return node.close()
        if cmd == "new":
            return node.new_auction()
        if cmd == "nodes":
            return node.members()
        if cmd == "dump":
            return node.dump()
        if cmd == "help":
            return Result("help", "ok", HELP)
        return Result(cmd, "error", f"unknown command: {' '.join(args)}\n{HELP}")
    except ValueError:
        return Result(cmd, "error", "amount must be an integer")
    except NotConnectedError as e:
        r = Result(cmd, "error", str(e))
        if cmd == "query" and node.cache:
            state, version = node.cache
            r.msg += f"\nlast known state (possibly stale!): {describe(state)} (v{version})"
        return r
    except (KazooException, KazooTimeoutError) as e:
        return Result(cmd, "error", f"ZooKeeper error: {type(e).__name__}")


def emit(node_id: str, r: Result, as_json: bool):
    if as_json:
        print(json.dumps({"t": time.time(), "node": node_id, **asdict(r)}), flush=True)
    else:
        print(r.msg if r.result != "error" else f"error: {r.msg}")


BIDDERS = ["alice", "bob", "carol", "dave", "eve"]


def run_worker(node: AuctionNode, interval: float, as_json: bool):
    """Bid random amounts forever (used by chaos_test.py)."""
    node.on_event = lambda ev: emit(node.node_id, Result(**ev), as_json)
    while True:
        q = execute(node, ["query"])
        if q.result == "ok":
            h = q.data["state"]["highest"]
            amount = max(1, (h["amount"] if h else 0) + random.randint(-3, 10))
            emit(node.node_id, execute(node, ["bid", random.choice(BIDDERS), str(amount)]), as_json)
        time.sleep(random.uniform(0, interval))


def main():
    parser = argparse.ArgumentParser(description="ZooKeeper auction node")
    parser.add_argument("--zk", default=os.environ.get("ZK_HOSTS", "127.0.0.1:2181"))
    parser.add_argument("--id", default=os.environ.get("NODE_ID", socket.gethostname()))
    parser.add_argument("--json", action="store_true", help="machine-readable output")
    parser.add_argument("--think", type=float, default=0.0,
                        help="max random delay between read and conditional write (s)")
    parser.add_argument("--hold", type=float, default=0.0,
                        help="fixed delay between the first read and the write of a bid (s)")
    parser.add_argument("--interval", type=float, default=0.5, help="worker: max pause between bids")
    parser.add_argument("-v", "--verbose", action="store_true")
    parser.add_argument("command", nargs="*", help="optional one-shot command")
    args = parser.parse_args()

    logging.basicConfig(
        level=logging.INFO if args.verbose else logging.WARNING,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )

    one_shot = bool(args.command)
    node = AuctionNode(args.zk, args.id, quiet=one_shot or args.json, think=args.think,
                       hold=args.hold)
    try:
        node.start()
    except KazooTimeoutError:
        sys.exit(f"could not connect to ZooKeeper at {args.zk}")
    if not args.json:
        print(f"{args.id} connected to {args.zk}")

    try:
        if args.command == ["worker"]:
            run_worker(node, args.interval, args.json)
        elif one_shot:
            emit(args.id, execute(node, args.command), args.json)
        else:
            print(HELP)
            while True:
                try:
                    line = input(f"{args.id}> ").split()
                except EOFError:
                    break
                if not line:
                    continue
                if line[0] in ("quit", "exit"):
                    break
                emit(args.id, execute(node, line), args.json)
    except KeyboardInterrupt:
        pass
    finally:
        node.stop()


if __name__ == "__main__":
    main()
