cmake_minimum_required(VERSION 3.16)

project(zenoh_mesh LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

find_package(zenohc REQUIRED)
find_package(zenohcxx REQUIRED)

add_executable(byzantine3 byzantine3.cpp)
add_executable(byzantine4 byzantine4.cpp)

target_link_libraries(byzantine3
    PRIVATE zenohcxx::zenohc
)
target_link_libraries(byzantine4
    PRIVATE zenohcxx::zenohc
)