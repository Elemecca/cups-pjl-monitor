cmake_minimum_required(VERSION 2.8)

add_library(tap INTERFACE)
target_sources(tap INTERFACE
    "${CMAKE_SOURCE_DIR}/external/libtap/tap.c"
)
target_include_directories(tap INTERFACE
    "${CMAKE_SOURCE_DIR}/external/libtap"
)

function(add_tap target)
    add_executable("${target}" ${ARGN})
    target_link_libraries("${target}" PRIVATE tap)
endfunction()


add_tap(print_data.t
    print_data/test.c
)
