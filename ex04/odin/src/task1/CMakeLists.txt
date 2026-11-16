cmake_minimum_required(VERSION 3.16)

project(zenoh_mesh LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

find_package(zenohc REQUIRED)
find_package(zenohcxx REQUIRED)

add_executable(leader_election leader_election.cpp)

target_link_libraries(leader_election
    PRIVATE zenohcxx::zenohc
)