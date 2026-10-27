import socket
import sys
import threading

counter = 0
lock = threading.Lock()


def handle(conn):
    # read one command: INCR, GET, or SET <value>
    op, *args = conn.recv(100).decode().split()

    with lock:
        global counter
        if op == "INCR":
            counter += 1  # nobody can be between the read and the write
        elif op == "SET":
            counter = int(args[0])
        # GET changes nothing, it just returns the value

    conn.sendall(f"{counter}\n".encode())
    conn.close()


def main():
    server = socket.create_server(("", int(sys.argv[1])))
    while True:
        conn, _ = server.accept()
        threading.Thread(target=handle, args=(conn,)).start()


main()
