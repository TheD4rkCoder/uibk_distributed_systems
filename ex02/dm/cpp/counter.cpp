#include <algorithm>
#include <atomic>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <mutex>
#include <string>
#include <thread>
#include <arpa/inet.h>
#include <netinet/tcp.h>
#include <sys/socket.h>
#include <unistd.h>

using namespace std;
using Clock = chrono::steady_clock;

static mutex g_m;      // protects the state, used by both threads
static atomic<bool> g_ready{false};  // our first increment happened (for 1.2)
static int g_a = 0;    // slot of A
static int g_b = 0;    // slot of B

static void send_all(int fd, const string& msg) {
    size_t off = 0;
    while (off < msg.size()) off += send(fd, msg.c_str() + off, msg.size() - off, 0);
}

static void receive_loop(int fd) {
    string buf;
    char tmp[4096];
    for (;;) {
        ssize_t n = recv(fd, tmp, sizeof tmp, 0);
        if (n <= 0) return;  // peer closed its side
        buf.append(tmp, n);
        size_t nl;
        while ((nl = buf.find('\n')) != string::npos) {
            int pa = 0, pb = 0;
            if (sscanf(buf.c_str(), "%d %d", &pa, &pb) == 2) {
                while (!g_ready) this_thread::yield();  // do not merge before our own increment
                lock_guard<mutex> lk(g_m);
                g_a = max(g_a, pa);
                g_b = max(g_b, pb);
            }
            buf.erase(0, nl + 1);
        }
    }
}

static int connect_to(const string& host, int port) {
    for (int i = 0; i < 100; i++) {  // wait until A is up
        sockaddr_in addr{};
        addr.sin_family = AF_INET;
        addr.sin_port = htons(port);
        if (inet_pton(AF_INET, host.c_str(), &addr.sin_addr) == 1) {
            int fd = socket(AF_INET, SOCK_STREAM, 0);
            if (connect(fd, (sockaddr*)&addr, sizeof addr) == 0) return fd;
            close(fd);
        }
        this_thread::sleep_for(chrono::milliseconds(200));
    }
    fprintf(stderr, "could not connect to %s:%d\n", host.c_str(), port);
    exit(1);
}

static double ms(Clock::duration d) {
    return chrono::duration<double, milli>(d).count();
}

int main(int argc, char* argv[]) {
    if (argc != 7) {
        fprintf(stderr, "usage: %s <A|B> <my_port> <peer_host> <peer_port> <increments> <basic|improved>\n",
                argv[0]);
        return 1;
    }
    string role = argv[1];
    int my_port = atoi(argv[2]);
    string peer_host = argv[3];
    int peer_port = atoi(argv[4]);
    int increments = atoi(argv[5]);
    bool basic = string(argv[6]) == "basic";

    int fd;
    if (role == "A") {
        int srv = socket(AF_INET, SOCK_STREAM, 0);
        int one = 1;
        setsockopt(srv, SOL_SOCKET, SO_REUSEADDR, &one, sizeof one);
        sockaddr_in addr{};
        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = INADDR_ANY;
        addr.sin_port = htons(my_port);
        bind(srv, (sockaddr*)&addr, sizeof addr);
        listen(srv, 1);
        fd = accept(srv, nullptr, nullptr);
    } else {
        fd = connect_to(peer_host, peer_port);
    }
    int one = 1;
    setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, &one, sizeof one);  // else ~40 ms extra

    thread rx(receive_loop, fd);

    // increment our copy and send the new state right away
    double local_ms = 0, send_ms = 0;
    for (int i = 0; i < increments; i++) {
        auto t = Clock::now();
        {
            lock_guard<mutex> lk(g_m);
            if (basic) {
                g_a++;  // basic: both nodes change slot a
            } else if (role == "A") {
                g_a++;  // improved: A only changes its own slot
            } else {
                g_b++;
            }
        }
        local_ms += ms(Clock::now() - t);
        g_ready = true;  // from now on incoming states may be merged

        t = Clock::now();
        string msg;
        {
            lock_guard<mutex> lk(g_m);
            msg = to_string(g_a) + " " + to_string(g_b) + "\n";
        }
        send_all(fd, msg);
        send_ms += ms(Clock::now() - t);
    }

    // to allow receiving for 0 increments:
    g_ready = true;  
    // no more increments: wait until the peer's last state arrived
    shutdown(fd, SHUT_WR);
    auto t = Clock::now();
    rx.join();
    double sync_ms = ms(Clock::now() - t);

    int a, b;
    {
        lock_guard<mutex> lk(g_m);
        a = g_a;
        b = g_b;
    }
    int total = basic ? a : a + b;
    printf("%s: local %.4f ms, send %.3f ms, sync %.3f ms, A=%d B=%d total=%d\n",
           role.c_str(), local_ms, send_ms, sync_ms, a, b, total);
    close(fd);
}
