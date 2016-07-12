cmake_minimum_required(VERSION 2.8)

list(APPEND CMAKE_MODULE_PATH CMake)

project(cups-pjl-monitor C)

find_package(CUPS REQUIRED)

add_executable(pjl
    src/pjl.c
)
target_link_libraries(pjl CUPS)

install(
    TARGETS pjl RUNTIME
    DESTINATION "${CUPS_SERVERBIN}/monitor"
    PERMISSIONS
        OWNER_READ OWNER_EXECUTE OWNER_WRITE
        GROUP_READ GROUP_EXECUTE
        WORLD_READ WORLD_EXECUTE
)
