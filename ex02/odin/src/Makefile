CC=g++
CFLAGS=-std=c++17 -Wall -Wextra -pthread
LDLIBS=-lrt

TARGETS=replicatedCounter1_1 replicatedCounter1_4 single_copyCounter

all: $(TARGETS)

%: %.cpp
	$(CC) $(CFLAGS) -o $@ $< $(LDLIBS)

clean:
	rm -f $(TARGETS)

.PHONY: all clean
