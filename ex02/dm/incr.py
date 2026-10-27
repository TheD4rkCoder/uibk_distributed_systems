import socket
import sys
import time


def store(host, port, cmd):
    s = socket.create_connection((host, port))
    s.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)  # else ~40 ms extra on EC2
    s.sendall(cmd.encode())
    reply = s.recv(100).decode().strip()
    s.close()
    return reply


def main():
    host, port, n, mode = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
    start = float(sys.argv[5]) if len(sys.argv) > 5 else 0  # both nodes start at the same time

    while time.time() < start:
        time.sleep(0.001)

    t0 = time.perf_counter()
    for _ in range(n):
        if mode == "safe":
            store(host, port, "INCR")
        else:
            value = int(store(host, port, "GET") or 0)  # read
            time.sleep(0.005)  # widen the race window
            store(host, port, f"SET {value + 1}")  # write the old value + 1
    elapsed = (time.perf_counter() - t0) * 1000

    print(f"{mode}: {elapsed:.1f} ms, counter {store(host, port, 'GET')}")


main()
