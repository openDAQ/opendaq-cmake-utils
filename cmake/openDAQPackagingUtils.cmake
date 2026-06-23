##
## Triplet detection and package naming for openDAQ projects.
##
## Usage:
##   include(openDAQPackagingUtils)
##   opendaq_detect_triplet()
##   opendaq_generate_package_name(VERSION ${PROJECT_VERSION})
##
## After opendaq_detect_triplet():
##   OPENDAQ_TRIPLET_ARCH         — x86_64, armv8, x86, armv7
##   OPENDAQ_TRIPLET_OS           — linux, macos, windows (manylinux_* inside a manylinux container)
##   OPENDAQ_TRIPLET_COMPILER     — gcc, apple-clang, msvc, clang, intel-cc
##   OPENDAQ_TRIPLET_COMPILER_VER — major version (MSVC: toolset version)
##   OPENDAQ_TRIPLET_BUILD_TYPE   — release, debug, relwithdebinfo, minsizerel
##   OPENDAQ_TRIPLET              — <arch>-<os>-<compiler>-<ver>-<build_type>
##
## After opendaq_generate_package_name():
##   OPENDAQ_PACKAGE_NAME         — <project>-<version>-<triplet>
##

function(opendaq_detect_triplet)
    # OS (Conan settings.os, lowercase)
    string(TOLOWER "${CMAKE_SYSTEM_NAME}" _os)
    if(_os STREQUAL "darwin")
        set(_os "macos")
    elseif(_os STREQUAL "linux" AND DEFINED ENV{AUDITWHEEL_POLICY})
        # manylinux containers export their glibc baseline (e.g. manylinux_2_28),
        # which distinguishes the binary from a generic "linux" build.
        set(_os "$ENV{AUDITWHEEL_POLICY}")
    endif()

    # Architecture (Conan settings.arch)
    if(CMAKE_SIZEOF_VOID_P EQUAL 8)
        if(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64|arm64|ARM64")
            set(_arch "armv8")
        else()
            set(_arch "x86_64")
        endif()
    else()
        if(CMAKE_SYSTEM_PROCESSOR MATCHES "arm|ARM")
            set(_arch "armv7")
        else()
            set(_arch "x86")
        endif()
    endif()

    # Compiler (Conan settings.compiler) and major version
    if(MSVC)
        set(_compiler "msvc")
        set(_compiler_ver "${MSVC_TOOLSET_VERSION}")
    elseif(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
        set(_compiler "gcc")
    elseif(CMAKE_CXX_COMPILER_ID STREQUAL "AppleClang")
        set(_compiler "apple-clang")
    elseif(CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
        set(_compiler "clang")
    elseif(CMAKE_CXX_COMPILER_ID STREQUAL "Intel" OR CMAKE_CXX_COMPILER_ID STREQUAL "IntelLLVM")
        set(_compiler "intel-cc")
    else()
        string(TOLOWER "${CMAKE_CXX_COMPILER_ID}" _compiler)
    endif()
    if(NOT MSVC)
        string(REGEX REPLACE "^([0-9]+).*" "\\1" _compiler_ver "${CMAKE_CXX_COMPILER_VERSION}")
    endif()

    # Build type (lowercase); multi-config generators default to "release"
    if(CMAKE_BUILD_TYPE)
        string(TOLOWER "${CMAKE_BUILD_TYPE}" _build_type)
    else()
        set(_build_type "release")
    endif()

    set(OPENDAQ_TRIPLET_ARCH         "${_arch}"         PARENT_SCOPE)
    set(OPENDAQ_TRIPLET_OS           "${_os}"           PARENT_SCOPE)
    set(OPENDAQ_TRIPLET_COMPILER     "${_compiler}"     PARENT_SCOPE)
    set(OPENDAQ_TRIPLET_COMPILER_VER "${_compiler_ver}" PARENT_SCOPE)
    set(OPENDAQ_TRIPLET_BUILD_TYPE   "${_build_type}"   PARENT_SCOPE)
    set(OPENDAQ_TRIPLET "${_arch}-${_os}-${_compiler}-${_compiler_ver}-${_build_type}" PARENT_SCOPE)
endfunction()

function(opendaq_generate_package_name)
    set(oneValueArgs VERSION NAME)
    cmake_parse_arguments(ARG "" "${oneValueArgs}" "" ${ARGN})

    if(NOT DEFINED ARG_VERSION)
        message(FATAL_ERROR "opendaq_generate_package_name() requires VERSION")
    endif()

    if(DEFINED ARG_NAME)
        set(_name "${ARG_NAME}")
    else()
        string(TOLOWER "${PROJECT_NAME}" _name)
    endif()

    if(NOT DEFINED OPENDAQ_TRIPLET)
        message(FATAL_ERROR "opendaq_generate_package_name(): call opendaq_detect_triplet() first")
    endif()

    set(OPENDAQ_PACKAGE_NAME "${_name}-${ARG_VERSION}-${OPENDAQ_TRIPLET}" PARENT_SCOPE)
endfunction()
