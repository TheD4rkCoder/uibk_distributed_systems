cmake_minimum_required(VERSION 3.16)

project(node LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

find_package(zenohc REQUIRED)
find_package(zenohcxx REQUIRED)

add_executable(node src/node.cpp)
target_link_libraries(node PRIVATE zenohcxx::zenohc)
