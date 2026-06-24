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

    # Name resolution: explicit NAME arg > OPENDAQ_PACKAGE_NAME_OVERRIDE (a cache var the
    # reusable injects per job, so one repo can produce several named stagings -- core,
    # c-bindings, wrappers -- from one CMakeLists) > lowercase PROJECT_NAME.
    if(DEFINED ARG_NAME)
        set(_name "${ARG_NAME}")
    elseif(DEFINED OPENDAQ_PACKAGE_NAME_OVERRIDE)
        set(_name "${OPENDAQ_PACKAGE_NAME_OVERRIDE}")
    else()
        string(TOLOWER "${PROJECT_NAME}" _name)
    endif()

    if(NOT DEFINED OPENDAQ_TRIPLET)
        message(FATAL_ERROR "opendaq_generate_package_name(): call opendaq_detect_triplet() first")
    endif()

    set(OPENDAQ_PACKAGE_BASENAME "${_name}" PARENT_SCOPE)
    set(OPENDAQ_PACKAGE_NAME "${_name}-${ARG_VERSION}-${OPENDAQ_TRIPLET}" PARENT_SCOPE)
endfunction()

##
## Detects the Conan-shaped staging settings (beyond the triplet) for the sidecar.
## Requires opendaq_detect_triplet() first. Reuses OPENDAQ_TRIPLET_* (no re-detection
## of arch/compiler/build_type). Fields that do not apply are left empty -> omitted by
## opendaq_write_staging_meta().
##
## Sets:
##   OPENDAQ_PLATFORM                   — os-segment (linux / manylinux_* / macos / windows)
##   OPENDAQ_SETTINGS_OS                — Linux / Macos / Windows (manylinux -> Linux)
##   OPENDAQ_SETTINGS_OS_VERSION        — macOS deployment target, else ""
##   OPENDAQ_SETTINGS_ARCH
##   OPENDAQ_SETTINGS_COMPILER
##   OPENDAQ_SETTINGS_COMPILER_VERSION  — Conan form (MSVC: MSVC_VERSION/10 = "193")
##   OPENDAQ_SETTINGS_COMPILER_TOOLSET  — MSVC: "v143", else "" (bridge to the slug's "143")
##   OPENDAQ_SETTINGS_COMPILER_CPPSTD   — "17", or "gnu17" with extensions (non-MSVC)
##   OPENDAQ_SETTINGS_COMPILER_LIBCXX   — libstdc++11 / libstdc++ / libc++, "" on MSVC
##   OPENDAQ_SETTINGS_COMPILER_RUNTIME  — MSVC: dynamic / static, else ""
##   OPENDAQ_SETTINGS_BUILD_TYPE        — Release / Debug / RelWithDebInfo / MinSizeRel
##   OPENDAQ_CUSTOM_GLIBC               — Linux compat floor "2.28", else ""
##
function(opendaq_detect_settings)
    if(NOT DEFINED OPENDAQ_TRIPLET)
        message(FATAL_ERROR "opendaq_detect_settings(): call opendaq_detect_triplet() first")
    endif()

    # platform = the triplet os-segment as-is (carries the manylinux distinction)
    set(_platform "${OPENDAQ_TRIPLET_OS}")

    # Conan os (capitalized; manylinux -> Linux)
    if(OPENDAQ_TRIPLET_OS STREQUAL "macos")
        set(_os "Macos")
    elseif(OPENDAQ_TRIPLET_OS STREQUAL "windows")
        set(_os "Windows")
    else()
        set(_os "Linux")   # linux or manylinux_*
    endif()

    # os.version — macOS deployment target (the macOS compat floor)
    set(_os_version "")
    if(_os STREQUAL "Macos")
        set(_os_version "${CMAKE_OSX_DEPLOYMENT_TARGET}")
    endif()

    # compiler.version (Conan form) + MSVC toolset bridge
    set(_toolset "")
    if(MSVC)
        math(EXPR _compiler_ver "${MSVC_VERSION} / 10")   # 1939 -> 193
        set(_toolset "v${MSVC_TOOLSET_VERSION}")          # v143
    else()
        set(_compiler_ver "${OPENDAQ_TRIPLET_COMPILER_VER}")
    endif()

    # compiler.cppstd. CMake leaves C++ extensions ON by default for gcc/clang
    # (-std=gnu++NN); only MSVC, or an explicit CMAKE_CXX_EXTENSIONS=OFF, gives plain NN.
    set(_cppstd "")
    if(CMAKE_CXX_STANDARD)
        set(_cppstd "${CMAKE_CXX_STANDARD}")
        if(NOT MSVC AND (NOT DEFINED CMAKE_CXX_EXTENSIONS OR CMAKE_CXX_EXTENSIONS))
            set(_cppstd "gnu${_cppstd}")
        endif()
    endif()

    # compiler.libcxx. macOS -> libc++, Linux -> libstdc++*. Omitted on Windows:
    # both MSVC and clang there target the MSVC C++ runtime, not libstdc++/libc++.
    set(_libcxx "")
    if(_os STREQUAL "Macos")
        set(_libcxx "libc++")
    elseif(_os STREQUAL "Linux")
        set(_libcxx "libstdc++11")   # new ABI by default
        get_directory_property(_defs COMPILE_DEFINITIONS)
        if("${_defs};${CMAKE_CXX_FLAGS}" MATCHES "_GLIBCXX_USE_CXX11_ABI=0")
            set(_libcxx "libstdc++")
        endif()
        if(CMAKE_CXX_FLAGS MATCHES "-stdlib=libc\\+\\+")
            set(_libcxx "libc++")
        endif()
    endif()

    # compiler.runtime (Windows only -- MSVC and clang both link the MSVC runtime;
    # CMake's default is the DLL runtime -> dynamic).
    set(_runtime "")
    if(_os STREQUAL "Windows")
        if(CMAKE_MSVC_RUNTIME_LIBRARY AND NOT CMAKE_MSVC_RUNTIME_LIBRARY MATCHES "DLL")
            set(_runtime "static")
        else()
            set(_runtime "dynamic")
        endif()
    endif()

    # build_type (capitalized) from the lowercase triplet form
    set(_bt "${OPENDAQ_TRIPLET_BUILD_TYPE}")
    if(_bt STREQUAL "release")
        set(_bt "Release")
    elseif(_bt STREQUAL "debug")
        set(_bt "Debug")
    elseif(_bt STREQUAL "relwithdebinfo")
        set(_bt "RelWithDebInfo")
    elseif(_bt STREQUAL "minsizerel")
        set(_bt "MinSizeRel")
    endif()

    # custom.glibc (Linux only) — the compat floor.
    # getconf reports the host glibc; inside a manylinux container that IS the policy
    # baseline (the image is built on a distro with exactly that glibc), so one
    # unconditional query covers both generic-linux and manylinux.
    set(_glibc "")
    if(_os STREQUAL "Linux")
        execute_process(COMMAND getconf GNU_LIBC_VERSION
                        OUTPUT_VARIABLE _libc_out
                        OUTPUT_STRIP_TRAILING_WHITESPACE
                        ERROR_QUIET)
        string(REGEX MATCH "[0-9]+\\.[0-9]+" _glibc "${_libc_out}")
    endif()

    set(OPENDAQ_PLATFORM                  "${_platform}"                  PARENT_SCOPE)
    set(OPENDAQ_SETTINGS_OS               "${_os}"                        PARENT_SCOPE)
    set(OPENDAQ_SETTINGS_OS_VERSION       "${_os_version}"                PARENT_SCOPE)
    set(OPENDAQ_SETTINGS_ARCH             "${OPENDAQ_TRIPLET_ARCH}"       PARENT_SCOPE)
    set(OPENDAQ_SETTINGS_COMPILER         "${OPENDAQ_TRIPLET_COMPILER}"   PARENT_SCOPE)
    set(OPENDAQ_SETTINGS_COMPILER_VERSION "${_compiler_ver}"             PARENT_SCOPE)
    set(OPENDAQ_SETTINGS_COMPILER_TOOLSET "${_toolset}"                   PARENT_SCOPE)
    set(OPENDAQ_SETTINGS_COMPILER_CPPSTD  "${_cppstd}"                    PARENT_SCOPE)
    set(OPENDAQ_SETTINGS_COMPILER_LIBCXX  "${_libcxx}"                    PARENT_SCOPE)
    set(OPENDAQ_SETTINGS_COMPILER_RUNTIME "${_runtime}"                   PARENT_SCOPE)
    set(OPENDAQ_SETTINGS_BUILD_TYPE       "${_bt}"                        PARENT_SCOPE)
    set(OPENDAQ_CUSTOM_GLIBC              "${_glibc}"                     PARENT_SCOPE)
endfunction()

##
## opendaq_write_staging_meta(VERSION <ver> OUTPUT <path>)
##   Writes the staging sidecar (staging-meta.json). Pure formatting -- no detection,
##   no name composition: reuses OPENDAQ_PACKAGE_NAME / OPENDAQ_PACKAGE_BASENAME from
##   opendaq_generate_package_name() and OPENDAQ_SETTINGS_* from opendaq_detect_settings()
##   (called here if not already). VERSION is the sidecar's `version` field (the semantic
##   version, which may differ from the version embedded in the package name, e.g. +sha).
##   Empty settings/custom fields are omitted, not emitted.
##
function(opendaq_write_staging_meta)
    set(oneValueArgs VERSION OUTPUT)
    cmake_parse_arguments(ARG "" "${oneValueArgs}" "" ${ARGN})

    if(NOT DEFINED ARG_VERSION)
        message(FATAL_ERROR "opendaq_write_staging_meta() requires VERSION")
    endif()
    if(NOT DEFINED ARG_OUTPUT)
        message(FATAL_ERROR "opendaq_write_staging_meta() requires OUTPUT")
    endif()
    if(NOT DEFINED OPENDAQ_PACKAGE_NAME)
        message(FATAL_ERROR "opendaq_write_staging_meta(): call opendaq_generate_package_name() first")
    endif()
    if(NOT DEFINED OPENDAQ_SETTINGS_OS)
        opendaq_detect_settings()
    endif()

    set(_name "${OPENDAQ_PACKAGE_BASENAME}")
    set(_archive "${OPENDAQ_PACKAGE_NAME}.tar.gz")
    set(_media "application/vnd.opendaq.staging.layer.v1.tar+gzip")

    # package block (all four always present)
    set(_pkg "")
    list(APPEND _pkg "    \"name\": \"${_name}\"")
    list(APPEND _pkg "    \"version\": \"${ARG_VERSION}\"")
    list(APPEND _pkg "    \"platform\": \"${OPENDAQ_PLATFORM}\"")
    list(APPEND _pkg "    \"archive\": \"${_archive}\"")
    string(JOIN ",\n" _pkg_block ${_pkg})

    # settings block (omit empty fields)
    set(_s "")
    list(APPEND _s "    \"os\": \"${OPENDAQ_SETTINGS_OS}\"")
    if(OPENDAQ_SETTINGS_OS_VERSION)
        list(APPEND _s "    \"os.version\": \"${OPENDAQ_SETTINGS_OS_VERSION}\"")
    endif()
    list(APPEND _s "    \"arch\": \"${OPENDAQ_SETTINGS_ARCH}\"")
    list(APPEND _s "    \"compiler\": \"${OPENDAQ_SETTINGS_COMPILER}\"")
    list(APPEND _s "    \"compiler.version\": \"${OPENDAQ_SETTINGS_COMPILER_VERSION}\"")
    if(OPENDAQ_SETTINGS_COMPILER_TOOLSET)
        list(APPEND _s "    \"compiler.toolset\": \"${OPENDAQ_SETTINGS_COMPILER_TOOLSET}\"")
    endif()
    if(OPENDAQ_SETTINGS_COMPILER_LIBCXX)
        list(APPEND _s "    \"compiler.libcxx\": \"${OPENDAQ_SETTINGS_COMPILER_LIBCXX}\"")
    endif()
    if(OPENDAQ_SETTINGS_COMPILER_CPPSTD)
        list(APPEND _s "    \"compiler.cppstd\": \"${OPENDAQ_SETTINGS_COMPILER_CPPSTD}\"")
    endif()
    if(OPENDAQ_SETTINGS_COMPILER_RUNTIME)
        list(APPEND _s "    \"compiler.runtime\": \"${OPENDAQ_SETTINGS_COMPILER_RUNTIME}\"")
    endif()
    list(APPEND _s "    \"build_type\": \"${OPENDAQ_SETTINGS_BUILD_TYPE}\"")
    string(JOIN ",\n" _settings_block ${_s})

    # assemble
    set(_json "{\n")
    string(APPEND _json "  \"schema\": 1,\n")
    string(APPEND _json "  \"media-type\": \"${_media}\",\n")
    string(APPEND _json "  \"package\": {\n${_pkg_block}\n  },\n")
    string(APPEND _json "  \"settings\": {\n${_settings_block}\n  }")
    if(OPENDAQ_CUSTOM_GLIBC)
        string(APPEND _json ",\n  \"custom\": {\n    \"glibc\": \"${OPENDAQ_CUSTOM_GLIBC}\"\n  }")
    endif()
    string(APPEND _json "\n}\n")

    file(WRITE "${ARG_OUTPUT}" "${_json}")
    message(STATUS "Wrote staging sidecar: ${ARG_OUTPUT}")
endfunction()

##
## opendaq_setup_packaging(VERSION <v> [NAME <n>] [SIDECAR <path>] [GENERATOR <g>] [NO_CPACK])
##   One-call packaging setup: detect triplet, compose package name, write the staging
##   sidecar, and set CPACK_PACKAGE_FILE_NAME. Unless NO_CPACK, also set CPACK_GENERATOR
##   (default TGZ) and call include(CPack).
##
##   A MACRO (not a function), so all variables land in the CALLER scope -- with NO_CPACK
##   the caller can add its own CPACK_* config and call include(CPack) itself (CPack freezes
##   the config, so it must be the last step; e.g. core's installer config).
##
##   Module (runtime-only):  opendaq_setup_packaging(VERSION ${module_version})
##   Core (installers):      opendaq_setup_packaging(VERSION ${VER} NAME opendaq NO_CPACK)
##                           # ... set(CPACK_GENERATOR ...) / CPACK_NSIS_* / ... ; include(CPack)
##
macro(opendaq_setup_packaging)
    cmake_parse_arguments(_OSP "NO_CPACK" "VERSION;NAME;SIDECAR;GENERATOR" "" ${ARGN})

    if(NOT DEFINED _OSP_VERSION)
        message(FATAL_ERROR "opendaq_setup_packaging() requires VERSION")
    endif()
    if(NOT DEFINED _OSP_SIDECAR)
        set(_OSP_SIDECAR "${CMAKE_BINARY_DIR}/staging-meta.json")
    endif()
    if(NOT DEFINED _OSP_GENERATOR)
        set(_OSP_GENERATOR "TGZ")
    endif()

    opendaq_detect_triplet()
    if(DEFINED _OSP_NAME)
        opendaq_generate_package_name(VERSION "${_OSP_VERSION}" NAME "${_OSP_NAME}")
    else()
        opendaq_generate_package_name(VERSION "${_OSP_VERSION}")
    endif()
    opendaq_write_staging_meta(VERSION "${_OSP_VERSION}" OUTPUT "${_OSP_SIDECAR}")

    set(CPACK_PACKAGE_FILE_NAME "${OPENDAQ_PACKAGE_NAME}")

    if(NOT _OSP_NO_CPACK)
        set(CPACK_GENERATOR "${_OSP_GENERATOR}")
        include(CPack)
    endif()
endmacro()
