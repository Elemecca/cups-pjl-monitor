#.rst:
# FindCUPS
# --------
#
# Tries to find ``libcups``, the API for the C UNIX Printing System (CUPS).
# An imported target called ``CUPS`` will be defined along with these variables:
#
# .. variable:: CUPS_FOUND
#    Set if CUPS was found.
#
# .. variable:: CUPS_VERSION
#    The full version number of the CUPS installation as a string.
#    Provided by ``cups-config --version``.
#
# .. variable:: CUPS_VERSION_STRING
#    This variable is provided for backwards compatibility.
#    :variable:`CUPS_VERSION` should be used instead.
#
#
# .. variable:: CUPS_CFLAGS
#    The compiler options necessary for source files which include CUPS headers
#    as a space-delimited string.
#    Provided by ``cups-config --cflags``.
#    Projects should generally use
#      :variable:`CUPS_INCLUDE_DIRS` and
#      :variable:`CUPS_CFLAGS_OTHER`
#    instead.
#
# .. variable:: CUPS_INCLUDE_DIRS
#    A list of include directories needed for the CUPS headers. This
#    will always have at least one value even if the headers are all on the
#    system include path.
#
# .. variable:: CUPS_CFLAGS_OTHER
#    A list of any compiler options from :variable:`CUPS_CFLAGS` not
#    reflected in :variable:`CUPS_INCLUDE_DIRS`.
#
# .. variable:: CUPS_INCLUDE_DIR
#    The include directory containing ``cups/cups.h``.
#    This variable is provided for backwards compatibility.
#    :variable:`CUPS_INCLUDE_DIRS` should be used instead.
#
#
# .. variable:: CUPS_LDFLAGS
#    The linker options necessary to link with CUPS as a space-delimited string.
#    Provided by ``cups-config --ldflags --libs``.
#    Projects should generally use either
#      :variable:`CUPS_LINK_LIBRARIES`
#    or
#      :variable:`CUPS_LIBRARIES`,
#      :variable:`CUPS_LIB_DIRS`, and
#      :variable:`CUPS_LDFLAGS_OTHER`
#    instead.
#
# .. variable:: CUPS_LIBRARIES
#    A list of libraries needed to link with CUPS.
#
# .. variable:: CUPS_LIB_DIRS
#    A list of library directories needed for the libraries in
#    :variable:`CUPS_LIBRARIES`. This may be empty if all needed libraries are
#    on the system library path.
#
# .. variable:: CUPS_LDFLAGS_OTHER
#    A list of any linker options from :variable:`CUPS_LDFLAGS` not reflected in
#    :variable:`CUPS_LIBRARIES` or :variable:`CUPS_LIB_DIRS`.
#
# .. variable:: CUPS_LINK_LIBRARIES
#    :variable:`CUPS_LDFLAGS` reformatted as a list suitable for use with the
#    :command:`target_link_libraries` command or in the
#    :prop_tgt:`LINK_LIBRARIES` target property.
#
#
# .. variable:: CUPS_DATADIR
#    The default CUPS data directory.
#    Provided by ``cups-config --datadir``.
#
# .. variable:: CUPS_SERVERBIN
#    The CUPS binary directory where filters and backends are kept.
#    Provided by ``cups-config --serverbin``.
#
# .. variable:: CUPS_SERVERROOT
#    The default CUPS configuration file directory.
#    Provided by ``cups-config --serverroot``.

#=============================================================================
# Copyright 2016 Sam Hanes <sam@maltera.com>
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# 3. Neither the name of the copyright holder nor the names of its
#    contributors may be used to endorse or promote products derived from
#    this software without specific prior written permission.
#
# This software is provided by the copyright holders and contributors "as
# is" and any express or implied warranties, including, but not limited
# to, the implied warranties of merchantability and fitness for a
# particular purpose are disclaimed. In no event shall the copyright
# holder or contributors be liable for any direct, indirect, incidental,
# special, exemplary, or consequential damages (including, but not limited
# to, procurement of substitute goods or services; loss of use, data, or
# profits; or business interruption) however caused and on any theory of
# liability, whether in contract, strict liability, or tort (including
# negligence or otherwise) arising in any way out of the use of this
# software, even if advised of the possibility of such damage.
#=============================================================================

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
        else()
            list(APPEND CUPS_CFLAGS_OTHER "${flag}")
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
        elseif(flag MATCHES "^-L(.+)$")
            list(APPEND CUPS_LIB_DIRS "${CMAKE_MATCH_1}")
            list(APPEND CUPS_LINK_LIBRARIES "${flag}")
        else()
            list(APPEND CUPS_LDFLAGS_OTHER "${flag}")
            list(APPEND CUPS_LINK_LIBRARIES "${flag}")
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
    add_library(CUPS SHARED IMPORTED)
    set_target_properties(CUPS PROPERTIES
        IMPORTED_LOCATION "${CUPS_LIBRARY}"
        INTERFACE_INCLUDE_DIRECTORIES "${CUPS_INCLUDE_DIRS}"
        INTERFACE_COMPILE_OPTIONS "${CUPS_CFLAGS_OTHER}"
        INTERFACE_LINK_LIBRARIES "${CUPS_LINK_LIBRARIES}"
    )
endif()
