#include <chrono>
#include <cstdlib>
#include <iostream>
#include <string>
#include <thread>
#include <arpa/inet.h>
#include <netdb.h>
#include <netinet/tcp.h>
#include <sys/socket.h>
#include <unistd.h>

using namespace std;

static int connect_to(const string& host, int port) {
    for (int i = 0; i < 100; i++) {  // wait until redis is up
        addrinfo hints{};
        hints.ai_family = AF_INET;
        hints.ai_socktype = SOCK_STREAM;
        addrinfo* res = nullptr;
        if (getaddrinfo(host.c_str(), to_string(port).c_str(), &hints, &res) == 0) {
            int fd = socket(AF_INET, SOCK_STREAM, 0);
            if (connect(fd, res->ai_addr, res->ai_addrlen) == 0) {
                freeaddrinfo(res);
                return fd;
            }
            close(fd);
            freeaddrinfo(res);
        }
        this_thread::sleep_for(chrono::milliseconds(200));
    }
    cerr << "could not connect to " << host << ":" << port << "\n";
    exit(1);
}

static void send_all(int fd, const string& msg) {
    size_t sent = 0;
    while (sent < msg.size()) {
        int n = send(fd, msg.c_str() + sent, msg.size() - sent, 0);
        if (n <= 0) exit(1);
        sent += n;
    }
}

// reads one line, e.g. "+1\r\n" or "$3\r\n123\r\n"
static string read_line(int fd) {
    string line;
    char c;
    while (recv(fd, &c, 1, 0) == 1) {
        if (c == '\n') break;
        if (c != '\r') line += c;
    }
    return line;
}

// one command = one request + one reply, the connection stays open
static string redis_cmd(int fd, const string& cmd) {
    send_all(fd, cmd + "\r\n");
    string line = read_line(fd);
    if (!line.empty() && line[0] == '$') {  // bulk string: value is the next line
        if (line == "$-1") return "";
        return read_line(fd);
    }
    // from playing around i got:":1" for INCR, "-ERR ..." on errors
    return line;  
}

int main(int argc, char* argv[]) {
    if (argc != 5) {
        cerr << "usage: " << argv[0] << " <redis_host> <redis_port> <increments> <safe|unsafe>\n";
        return 1;
    }
    string host = argv[1];
    int port = atoi(argv[2]);
    int increments = atoi(argv[3]);
    bool safe = string(argv[4]) == "safe";

    int fd = connect_to(host, port);
    int one = 1;
    setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, &one, sizeof(one));

    auto t0 = chrono::steady_clock::now();
    for (int i = 0; i < increments; i++) {
        if (safe) {
            redis_cmd(fd, "INCR counter");
        } else {
            int value = atoi(redis_cmd(fd, "GET counter").c_str());
            this_thread::sleep_for(chrono::milliseconds(5));  // widen the race window
            redis_cmd(fd, "SET counter " + to_string(value + 1));
        }
    }
    auto t1 = chrono::steady_clock::now();

    double ms = chrono::duration<double, milli>(t1 - t0).count();
    cout << (safe ? "safe" : "unsafe") << ": " << ms << " ms, counter: "
         << redis_cmd(fd, "GET counter") << "\n";
    close(fd);
}
