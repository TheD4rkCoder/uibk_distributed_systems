cmake_minimum_required(VERSION 3.16)

project(node LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Set -DZOOKEEPER_ROOT=/path if the C client is not installed system-wide.
find_path(ZOOKEEPER_INCLUDE_DIR zookeeper/zookeeper.h HINTS "${ZOOKEEPER_ROOT}/include")
find_library(ZOOKEEPER_LIBRARY NAMES zookeeper_mt HINTS "${ZOOKEEPER_ROOT}/lib")

if(NOT ZOOKEEPER_INCLUDE_DIR OR NOT ZOOKEEPER_LIBRARY)
	message(FATAL_ERROR "ZooKeeper C client not found; set -DZOOKEEPER_ROOT=...")
endif()

add_executable(node src/node.cpp)
target_include_directories(node PRIVATE "${ZOOKEEPER_INCLUDE_DIR}")
target_link_libraries(node PRIVATE "${ZOOKEEPER_LIBRARY}" pthread)
