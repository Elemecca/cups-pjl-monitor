cmake_minimum_required(VERSION 2.8)

list(APPEND CMAKE_MODULE_PATH CMake)

project(cups-pjl-monitor C)

find_package(CUPS)

add_executable(pjl
    src/pjl.c
)
target_link_libraries(pjl CUPS)
