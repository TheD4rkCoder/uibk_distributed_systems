import socket
import sys
import threading
import time

def connect(role, my_port, peer_host, peer_port):
    if role == "A":
        s = socket.socket()
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        s.bind(("", my_port))
        s.listen(1)
        conn, _ = s.accept()
    else:
        for _ in range(100):  # wait until A is up
            try:
                conn = socket.create_connection((peer_host, peer_port))
                break
            except OSError:
                time.sleep(0.2)
        else:
            sys.exit(f"could not connect to {peer_host}:{peer_port}")
    conn.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)  # else ~40 ms extra on EC2
    return conn


def receiver(f, lock, state, ready):
    # runs the whole time we are alive; merge every message we get with max()
    for line in f:
        peer = [int(x) for x in line.split()]
        ready.wait()  # never merge before our own first increment happened
        with lock:
            state[0] = max(state[0], peer[0])
            state[1] = max(state[1], peer[1])

def main():
    role, my_port, peer_host, peer_port, increments, mode = sys.argv[1:]
    increments = int(increments)
    me = 0 if role == "A" else 1

    conn = connect(role, int(my_port), peer_host, int(peer_port))
    f = conn.makefile("rb")

    state = [0, 0]
    lock = threading.Lock()
    ready = threading.Event() # for 1.2
    t = threading.Thread(target=receiver, args=(f, lock, state, ready), daemon=True)
    t.start()

    # increment our local copy and send the new state right away
    local = send = 0.0
    for i in range(increments):
        s = time.perf_counter()
        with lock:
            if mode == "basic":
                state[0] += 1
            else:
                state[me] += 1
        local += time.perf_counter() - s
        if i == 0:
            ready.set()  # from now on incoming states may be merged

        s = time.perf_counter()
        with lock:
            msg = f"{state[0]} {state[1]}\n".encode()
        conn.sendall(msg)
        send += time.perf_counter() - s

    if increments == 0:
        ready.set()  # nothing to increment, but we still merge the peer's counter

    # no more increments from us: wait until the peer's last state arrived
    conn.shutdown(socket.SHUT_WR)
    s = time.perf_counter()
    t.join()
    sync = time.perf_counter() - s

    with lock:
        a, b = state
    total = a if mode == "basic" else a + b
    print(f"{role}: local {local * 1000:.4f} ms, send {send * 1000:.3f} ms, "
          f"sync {sync * 1000:.3f} ms, A={a} B={b} total={total}")


main()
