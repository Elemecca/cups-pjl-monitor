cmake_minimum_required(VERSION 2.8)

list(APPEND CMAKE_MODULE_PATH CMake)

project(cups-pjl-monitor C)

find_package(CUPS REQUIRED)

add_executable(monitor
    src/main.c
)
target_link_libraries(monitor CUPS)
set_target_properties(monitor PROPERTIES
    OUTPUT_NAME pjl
)

install(
    TARGETS monitor RUNTIME
    DESTINATION "${CUPS_SERVERBIN}/monitor"
    PERMISSIONS
        OWNER_READ OWNER_EXECUTE OWNER_WRITE
        GROUP_READ GROUP_EXECUTE
        WORLD_READ WORLD_EXECUTE
)
