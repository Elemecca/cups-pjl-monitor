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
    find_program(PROVE_EXECUTABLE prove)

    add_custom_target(check
        VERBATIM COMMAND
            "${PROVE_EXECUTABLE}"
            "--exec" "" # our tests are compiled, call them directly
            "--shuffle"
            "--state" "save"
            "test/"
        USES_TERMINAL
    )

    add_subdirectory(test)
endif()


install(
    TARGETS monitor RUNTIME
    DESTINATION "${CUPS_SERVERBIN}/monitor"
    PERMISSIONS
        OWNER_READ OWNER_EXECUTE OWNER_WRITE
        GROUP_READ GROUP_EXECUTE
        WORLD_READ WORLD_EXECUTE
)
