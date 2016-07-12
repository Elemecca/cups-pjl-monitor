#.rst:
# FindCUPS
# --------
#
# Try to find the Cups printing system
#
# Once done this will define
#
# ::
#
#   CUPS_FOUND - system has Cups
#   CUPS_INCLUDE_DIR - the Cups include directory
#   CUPS_LIBRARIES - Libraries needed to use Cups
#   CUPS_VERSION_STRING - version of Cups found (since CMake 2.8.8)
#   Set CUPS_REQUIRE_IPP_DELETE_ATTRIBUTE to TRUE if you need a version which
#   features this function (i.e. at least 1.1.19)

#=============================================================================
# Copyright 2016 Sam Hanes <sam@maltera.com>
#
# Distributed under the OSI-approved BSD License (the "License");
# see accompanying file COPYING.txt for details.
#
# This software is distributed WITHOUT ANY WARRANTY; without even the
# implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the License for more information.
#=============================================================================
# (To distribute this file outside of CMake, substitute the full
#  License text for the above reference.)

cmake_minimum_required(VERSION 2.8)


find_program(CUPS_CONFIG_EXECUTABLE cups-config)
mark_as_advanced(CUPS_CONFIG_EXECUTABLE)

function(_cups_config outvar)
    execute_process(
        COMMAND "${CUPS_CONFIG_EXECUTABLE}" ${ARGN}
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_QUIET
    )

    string(STRIP "${output}" output)

    if(NOT result EQUAL 0)
        set("${outvar}" "${outvar}-NOTFOUND" PARENT_SCOPE)
    else()
        set("${outvar}" "${output}" PARENT_SCOPE)
    endif()
endfunction()

if(CUPS_CONFIG_EXECUTABLE)
    _cups_config(CUPS_VERSION "--version")
    set(CUPS_VERSION_STRING "${CUPS_VERSION}")

    _cups_config(CUPS_CFLAGS "--cflags")
    string(REPLACE " " ";" _cups_cflags "${CUPS_CFLAGS}")
    foreach(flag IN LISTS _cups_cflags)
        if(flag MATCHES "^-I(.+)$")
            list(APPEND CUPS_INCLUDE_DIRS "${CMAKE_MATCH_1}")
            message("INCLUDE_DIR '${CMAKE_MATCH_1}'")
        else()
            list(APPEND CUPS_CFLAGS_OTHER "${flag}")
            message("CFLAG '${flag}'")
        endif()
    endforeach()
    unset(_cups_cflags)

    _cups_config(CUPS_LDFLAGS "--ldflags" "--libs")
    string(REPLACE "\n" " " CUPS_LDFLAGS "${CUPS_LDFLAGS}")
    string(REPLACE " " ";" _cups_ldflags "${CUPS_LDFLAGS}")
    foreach(flag IN LISTS _cups_ldflags)
        if(flag STREQUAL "-lcups")
            # ignore, this is added later
        elseif(flag MATCHES "^-l(.+)$")
            list(APPEND CUPS_LIBRARIES "${CMAKE_MATCH_1}")
            list(APPEND CUPS_LINK_LIBRARIES "${CMAKE_MATCH_1}")
            message("LIB '${CMAKE_MATCH_1}'")
        elseif(flag MATCHES "^-L(.+)$")
            list(APPEND CUPS_LIB_DIRS "${CMAKE_MATCH_1}")
            list(APPEND CUPS_LINK_LIBRARIES "${flag}")
            message("LIB_DIR '${CMAKE_MATCH_1}'")
        else()
            list(APPEND CUPS_LDFLAGS_OTHER "${flag}")
            list(APPEND CUPS_LINK_LIBRARIES "${flag}")
            message("LDFLAG '${flag}'")
        endif()
    endforeach()
    unset(_cups_ldflags)

    _cups_config(CUPS_DATADIR    "--datadir")
    _cups_config(CUPS_SERVERBIN  "--serverbin")
    _cups_config(CUPS_SERVERROOT "--serverroot")
endif()
unset(_cups_config)


find_library(CUPS_LIBRARY
    NAMES cups
    HINTS ${CUPS_LIB_DIRS}
)
mark_as_advanced(CUPS_LIBRARY)
if(CUPS_LIBRARY)
    list(INSERT CUPS_LIBRARIES 0 ${CUPS_LIBRARY})
endif()


find_path(CUPS_INCLUDE_DIR
    NAMES cups/cups.h
    HINTS ${CUPS_INCLUDE_DIRS}
)
mark_as_advanced(CUPS_INCLUDE_DIR)
if(CUPS_INCLUDE_DIR)
    list(INSERT CUPS_INCLUDE_DIRS 0 ${CUPS_INCLUDE_DIR})
endif()


include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(CUPS
    REQUIRED_VARS
        CUPS_LIBRARY
        CUPS_INCLUDE_DIR
        CUPS_VERSION
    VERSION_VAR CUPS_VERSION
)


if(CUPS_FOUND)
    message(
        "IMPORTED_LOCATION '${CUPS_LIBRARY}'\n"
        "INTERFACE_INCLUDE_DIRECTORIES '${CUPS_INCLUDE_DIRS}'\n"
        "INTERFACE_COMPILE_OPTIONS '${CUPS_CFLAGS_OTHER}'\n"
        "INTERFACE_LINK_LIBRARIES '${CUPS_LINK_LIBRARIES}'\n"
    )

    add_library(CUPS SHARED IMPORTED)
    set_target_properties(CUPS PROPERTIES
        IMPORTED_LOCATION "${CUPS_LIBRARY}"
        INTERFACE_INCLUDE_DIRECTORIES "${CUPS_INCLUDE_DIRS}"
        INTERFACE_COMPILE_OPTIONS "${CUPS_CFLAGS_OTHER}"
        INTERFACE_LINK_LIBRARIES "${CUPS_LINK_LIBRARIES}"
    )
endif()
