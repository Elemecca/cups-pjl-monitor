cmake_minimum_required(VERSION 2.8)

# include our modules in the search path
list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/CMake")

# set the root directory for ExternalProject
set_property(DIRECTORY
    PROPERTY EP_BASE "${CMAKE_SOURCE_DIR}/external"
)

project(cups-pjl-monitor C)

find_package(CUPS REQUIRED)

find_package(BISON REQUIRED VERSION 2.5)



# set up an output directory for generated sources
set(SOURCE_OUTPUT_DIR "${CMAKE_CURRENT_BINARY_DIR}/gen")



# no-empty-rule needed for compat with Bison 2.5
if(NOT "${BISON_VERSION}" VERSION_LESS "3.0")
    string(APPEND BISON_EXTRA_ARGS -Wno-empty-rule)
endif()

add_custom_command(
    OUTPUT
        "${SOURCE_OUTPUT_DIR}/status.yy.c"
        "${SOURCE_OUTPUT_DIR}/status.yy.h"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${SOURCE_OUTPUT_DIR}"
    COMMAND "${BISON_EXECUTABLE}"
        "-Wall" "-Werror" ${BISON_EXTRA_ARGS}
        "--output=${SOURCE_OUTPUT_DIR}/status.yy.c"
        "--defines=${SOURCE_OUTPUT_DIR}/status.yy.h"
        "--report=all"
        "--report-file=${SOURCE_OUTPUT_DIR}/status.yy.log"
        "${CMAKE_CURRENT_SOURCE_DIR}/src/status.y"
    VERBATIM
    MAIN_DEPENDENCY "src/status.y"
    COMMENT "Generating Bison parser gen/status.yy.c"
)

add_executable(monitor
    src/main.c
    "${SOURCE_OUTPUT_DIR}/status.yy.c"
)
target_link_libraries(monitor CUPS)
set_target_properties(monitor PROPERTIES
    OUTPUT_NAME pjl

    # necessary because status.yy.h and status.h are in different dirs
    COMPILE_FLAGS "-I${CMAKE_CURRENT_SOURCE_DIR}/src -I${SOURCE_OUTPUT_DIR}"
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
