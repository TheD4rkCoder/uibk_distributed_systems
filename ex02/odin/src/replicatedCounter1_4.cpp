#include <algorithm>
#include <chrono>
#include <cstddef>
#include <cstdlib>
#include <mqueue.h>
#include <iostream>
#include <cerrno>
#include <cstring>
#include <fcntl.h>
#include <thread>

enum MessageType { UPDATE = 0, DONE = 1 };

// valueA is the receiver's own slot, valueB the sender's own slot
struct Message {
    int type;
    int valueA;
    int valueB;
};

using Clock = std::chrono::steady_clock;

double to_us(Clock::duration d) {
    return std::chrono::duration<double, std::micro>(d).count();
}

int main(int argc, char *argv[]) {
    if (argc != 4) {
        std::cerr << argv[0] << " <sendQueue> <recvQueue> <end>\n";
        return EXIT_FAILURE;
    }

    char *name_sendQ = argv[1];
    char *name_recvQ = argv[2];
    int end = std::atoi(argv[3]);

    int private_A = 0;
    int private_B = 0;
    int other_final_A = 0;
    int other_final_B = 0;
    bool other_done = false;
    int dropped = 0;
    Message in;

    mq_attr attr = {};
    attr.mq_maxmsg = 10;
    attr.mq_msgsize = sizeof(Message);

    mqd_t sendQ = mq_open(name_sendQ, O_CREAT | O_WRONLY | O_NONBLOCK, 0660, &attr);
    mqd_t recvQ = mq_open(name_recvQ, O_CREAT | O_RDONLY | O_NONBLOCK, 0660, &attr);

    if (sendQ == (mqd_t)-1) {
        std::cerr << "mq_open: " << strerror(errno) << "\n";
        return EXIT_FAILURE;
    }

    if (recvQ == (mqd_t)-1) {
        std::cerr << "mq_open: " << strerror(errno) << "\n";
        return EXIT_FAILURE;
    }

    // Merge a message from the other node, DONE means it has no more updates
    auto handle = [&](const Message &msg) {
        if (msg.type == DONE) {
            other_done = true;
            other_final_A = msg.valueA;
            other_final_B = msg.valueB;
        } else {
            private_A = std::max(private_A, msg.valueA);
            private_B = std::max(private_B, msg.valueB);
        }
    };

    Message out = {UPDATE, private_B, private_A};
    if (mq_send(sendQ, reinterpret_cast<char *>(&out), sizeof(out), 0) == -1) {
        perror("mq_send");
    }

    // busy wait for the other node so both start the loop at (almost) the same time
    while (mq_receive(recvQ, reinterpret_cast<char *>(&in), sizeof(in), nullptr) == -1) {
        if (errno != EAGAIN) {
            perror("mq_receive");
            return EXIT_FAILURE;
        }
    }

    Clock::duration local_time{0};
    Clock::duration loop_sync_time{0};

    Clock::time_point start = Clock::now();
    for (int i = 0; i < end; i++) {
        // local update
        Clock::time_point t0 = Clock::now();
        private_A++;
        Clock::time_point t1 = Clock::now();

        // synchronization: send our state and drain everything that has arrived so far
        Message out = {UPDATE, private_B, private_A};
        if (mq_send(sendQ, reinterpret_cast<char *>(&out), sizeof(out), 0) == -1) {
            // the queue is full, the next update carries the newer state anyway
            if (errno == EAGAIN) {
                dropped++;
            } else {
                perror("mq_send");
            }
        }

        while (mq_receive(recvQ, reinterpret_cast<char *>(&in), sizeof(in), nullptr) != -1) {
            handle(in);
        }
        Clock::time_point t2 = Clock::now();

        local_time += t1 - t0;
        loop_sync_time += t2 - t1;
    }
    Clock::time_point loop_end = Clock::now();

    // Send final value (swapped like the updates), retry if the queue is full since the other node waits for it
    Message done = {DONE, private_B, private_A};
    while (mq_send(sendQ, reinterpret_cast<char *>(&done), sizeof(done), 0) == -1) {
        if (errno != EAGAIN) {
            perror("mq_send");
            break;
        }
        std::this_thread::sleep_for(std::chrono::microseconds(100));
    }

    while (!other_done) {
        if (mq_receive(recvQ, reinterpret_cast<char *>(&in), sizeof(in), nullptr) != -1) {
            handle(in);
        } else if (errno == EAGAIN) {
            std::this_thread::sleep_for(std::chrono::microseconds(100));
        } else {
            perror("mq_receive");
            break;
        }
    }

    private_A = std::max(private_A, other_final_A);
    private_B = std::max(private_B, other_final_B);
    Clock::time_point finish = Clock::now();

    std::cout << "Final count sum: " << private_A + private_B << "\n";
    std::cout << "Increments: " << end << "\n";
    std::cout << "Total time: " << to_us(finish - start) << " us\n";
    std::cout << "Local update time: " << to_us(local_time) << " us\n";
    std::cout << "Sync time in loop: " << to_us(loop_sync_time) << " us\n";
    std::cout << "Final sync time: " << to_us(finish - loop_end) << " us\n";
    std::cout << "Dropped updates: " << dropped << "\n";

    mq_close(sendQ);
    mq_close(recvQ);

    mq_unlink(name_sendQ);
    mq_unlink(name_recvQ);
    return EXIT_SUCCESS;
}
