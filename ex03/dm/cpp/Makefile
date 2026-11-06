# Minimal build: g++ + the zenoh-c / zenoh-cpp "standalone" packages in .vendor/
Z     := .vendor
CXX   := g++
CXXFLAGS := -std=c++17 -O2 -Wall -DZENOHCXX_ZENOHC -I$(Z)/zenohcpp/include -I$(Z)/zenohc/include
LDLIBS := -L$(Z)/zenohc/lib -lzenohc -Wl,-rpath,$(CURDIR)/$(Z)/zenohc/lib

all: peer byzantine
peer: src/peer.cpp src/common.h
	$(CXX) $(CXXFLAGS) $< -o $@ $(LDLIBS)
byzantine: src/byzantine.cpp src/common.h
	$(CXX) $(CXXFLAGS) $< -o $@ $(LDLIBS)
clean:
	rm -f peer byzantine
