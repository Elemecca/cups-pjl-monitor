cmake_minimum_required(VERSION 2.8)

# include our modules in the search path
list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/CMake")

# set the root directory for ExternalProject
set_property(DIRECTORY
    PROPERTY EP_BASE "${CMAKE_SOURCE_DIR}/external"
)

project(cups-pjl-monitor C)

find_package(CUPS REQUIRED)

add_executable(monitor
    src/main.c
)
target_link_libraries(monitor CUPS)
set_target_properties(monitor PROPERTIES
    OUTPUT_NAME pjl
)

option(BUILD_TESTING "Whether to build the test files" ON)
if(BUILD_TESTING)
    find_package(PythonInterp REQUIRED VERSION 2.7)
    find_program(ENV_EXECUTABLE env)

    add_custom_target(check
        VERBATIM COMMAND
            "${ENV_EXECUTABLE}"
            "TEST_MONITOR_EXEC=$<TARGET_FILE:monitor>"
            "${PYTHON_EXECUTABLE}"
            -m unittest
            discover -s test -v -b
        USES_TERMINAL
    )
endif()


install(
    TARGETS monitor RUNTIME
    DESTINATION "${CUPS_SERVERBIN}/monitor"
    PERMISSIONS
        OWNER_READ OWNER_EXECUTE OWNER_WRITE
        GROUP_READ GROUP_EXECUTE
        WORLD_READ WORLD_EXECUTE
)
