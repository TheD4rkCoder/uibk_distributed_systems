#include <chrono>
#include <cstdlib>
#include <fcntl.h>
#include <iostream>
#include <sys/wait.h>
#include <unistd.h>
#include <cstdio>

using Clock = std::chrono::steady_clock;

double to_us(Clock::duration d) {
    return std::chrono::duration<double, std::micro>(d).count();
}

int main(int argc, char *argv[]) {
    if (argc != 2 && argc != 3) {
        std::cerr << argv[0] << " <end> [processes (1 or 2, default 2)]\n";
        return EXIT_FAILURE;
    }

    int end = atoi(argv[1]);
    int processes = argc == 3 ? atoi(argv[2]) : 2;

    // create the file and get its fd
    int fd = open("shared.txt", O_CREAT | O_RDWR | O_TRUNC, 0644);
    if (fd == -1) {
        perror("open");
        return 1;
    }

    int count = 0;
    write(fd, reinterpret_cast<char *>(&count), sizeof(count));

    // with 1 process there is no contention on the lock, used as baseline
    pid_t pid = 1;
    if (processes == 2) {
        pid = fork();
        if (pid == -1) {
            perror("fork");
            return 1;
        }
    }

    Clock::duration lock_wait_time{0};
    Clock::duration update_time{0};

    Clock::time_point start = Clock::now();
    for (int i = 0; i < end; i++) {
        Clock::time_point t0 = Clock::now();
        if (lockf(fd, F_LOCK, 0) == -1) {
            perror("lockf");
            close(fd);
            return EXIT_FAILURE;
        }
        Clock::time_point t1 = Clock::now();

        lseek(fd, 0, SEEK_SET);
        read(fd, reinterpret_cast<char*>(&count), sizeof(count));
        lseek(fd, 0, SEEK_SET);
        count++;
        write(fd, reinterpret_cast<char*>(&count), sizeof(count));

        if (lockf(fd, F_ULOCK, 0) == -1) {
            perror("unlock");
            return EXIT_FAILURE;
        }
        Clock::time_point t2 = Clock::now();

        lock_wait_time += t1 - t0;
        update_time += t2 - t1;
    }
    Clock::time_point finish = Clock::now();

    // the parent waits for the child so the outputs don't interleave
    if (pid > 0 && processes == 2) {
        waitpid(pid, nullptr, 0);
    }

    std::cout << (pid == 0 ? "Child" : "Parent") << "\n";
    std::cout << "Increments: " << end << "\n";
    std::cout << "Total time: " << to_us(finish - start) << " us\n";
    std::cout << "Lock wait time: " << to_us(lock_wait_time) << " us\n";
    std::cout << "Update time (read, write, unlock): " << to_us(update_time) << " us\n";

    if (pid > 0) {
        lseek(fd, 0, SEEK_SET);
        read(fd, reinterpret_cast<char*>(&count), sizeof(count));
        std::cout << "Final count: " << count << "\n";
    }

    close(fd);

    return 0;
}
