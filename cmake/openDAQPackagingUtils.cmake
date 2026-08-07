##
## Package naming and build metadata for openDAQ projects.
##
##   opendaq_detect_settings()             what the build is        settings + custom
##   opendaq_detect_package()              what is being packaged   name and version
##   opendaq_compose_package_triplet()     <arch>-<platform>-…      from the settings
##   opendaq_compose_package_file_name()   <name>-<version>-…       for CPACK_PACKAGE_FILE_NAME
##   opendaq_write_metadata(OUTPUT <p>)    the JSON
##
## Detect finds facts, compose derives from them, write serializes. A composed part can be
## given per argument; what is not given comes from the detected values.
##
## The metadata is plain CPACK_OPENDAQ_META_* variables, one per field, the suffix naming the
## section and the field it becomes. A section is written when any of its fields has a value:
##
##   CPACK_OPENDAQ_META_PACKAGE_*    NAME, VERSION, VERSION_SUFFIX, TRIPLET   what this package is
##   CPACK_OPENDAQ_META_SETTINGS_*   OS, ARCH, COMPILER, …       Conan vocabulary, exactly
##   CPACK_OPENDAQ_META_CUSTOM_*     PLATFORM, GLIBC             build axes Conan has no words for
##
## A project reads or sets any of them directly. CPACK_ is also the only prefix that survives
## into CPackConfig.cmake, so a cpack run sees them and can name a package of its own
## (see opendaq_cpack_options.cmake).
##

set(CPACK_OPENDAQ_PROJECT_CONFIG "${CMAKE_CURRENT_LIST_DIR}/opendaq_cpack_options.cmake"
    CACHE INTERNAL "CPack project config naming the package per cpack run")
set(CPACK_OPENDAQ_UTILS_MODULE "${CMAKE_CURRENT_LIST_FILE}"
    CACHE INTERNAL "This module, for the CPack project config to include")

##
## opendaq_detect_settings()
##   Detects what the build is: the Conan settings, plus the axes Conan cannot express.
##
##   Sets (the CPACK_OPENDAQ_META_ prefix is omitted below):
##     SETTINGS_OS                 — Linux / Macos / Windows (manylinux -> Linux)
##     SETTINGS_OS_VERSION         — macOS deployment target, else ""
##     SETTINGS_ARCH               — x86_64 / armv8 / x86 / armv7
##     SETTINGS_COMPILER           — gcc / apple-clang / msvc / clang / intel-cc
##     SETTINGS_COMPILER_VERSION   — Conan form (MSVC: MSVC_VERSION/10 = "193")
##     SETTINGS_COMPILER_TOOLSET   — MSVC: "v143", else ""
##     SETTINGS_COMPILER_CPPSTD    — "17", or "gnu17" with extensions (non-MSVC)
##     SETTINGS_COMPILER_LIBCXX    — libstdc++11 / libstdc++ / libc++, "" on Windows
##     SETTINGS_COMPILER_RUNTIME   — MSVC: dynamic / static, else ""
##     SETTINGS_BUILD_TYPE         — Release / Debug / RelWithDebInfo / MinSizeRel
##     CUSTOM_PLATFORM             — linux / manylinux_* / macos / windows
##     CUSTOM_GLIBC                — Linux compat floor "2.31", else ""
##
function(opendaq_detect_settings)
    # platform: manylinux is not plain linux
    string(TOLOWER "${CMAKE_SYSTEM_NAME}" _platform)
    if(_platform STREQUAL "darwin")
        set(_platform "macos")
    elseif(_platform STREQUAL "linux" AND DEFINED ENV{AUDITWHEEL_POLICY})
        set(_platform "$ENV{AUDITWHEEL_POLICY}")
    endif()

    # Conan os (capitalized; manylinux -> Linux)
    if(_platform STREQUAL "macos")
        set(_os "Macos")
    elseif(_platform STREQUAL "windows")
        set(_os "Windows")
    else()
        set(_os "Linux")
    endif()

    # os.version: macOS deployment target
    set(_os_version "")
    if(_os STREQUAL "Macos")
        set(_os_version "${CMAKE_OSX_DEPLOYMENT_TARGET}")
    endif()

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

    # MSVC has two version forms: Conan's (193) and the toolset (143) the triplet uses
    set(_toolset "")
    if(MSVC)
        set(_compiler "msvc")
        math(EXPR _compiler_ver "${MSVC_VERSION} / 10")   # 1939 -> 193
        set(_toolset "v${MSVC_TOOLSET_VERSION}")          # v143
    else()
        if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
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
        string(REGEX REPLACE "^([0-9]+).*" "\\1" _compiler_ver "${CMAKE_CXX_COMPILER_VERSION}")
    endif()

    # compiler.cppstd: gcc/clang default to -std=gnu++NN, hence the gnu prefix
    set(_cppstd "")
    if(CMAKE_CXX_STANDARD)
        set(_cppstd "${CMAKE_CXX_STANDARD}")
        if(NOT MSVC AND (NOT DEFINED CMAKE_CXX_EXTENSIONS OR CMAKE_CXX_EXTENSIONS))
            set(_cppstd "gnu${_cppstd}")
        endif()
    endif()

    # compiler.libcxx: omitted on Windows, where the C++ runtime is the MSVC one
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

    # compiler.runtime: Windows only, CMake defaults to the DLL runtime
    set(_runtime "")
    if(_os STREQUAL "Windows")
        if(CMAKE_MSVC_RUNTIME_LIBRARY AND NOT CMAKE_MSVC_RUNTIME_LIBRARY MATCHES "DLL")
            set(_runtime "static")
        else()
            set(_runtime "dynamic")
        endif()
    endif()

    # build_type, capitalized; multi-config generators default to Release
    set(_bt "Release")
    if(CMAKE_BUILD_TYPE)
        string(TOLOWER "${CMAKE_BUILD_TYPE}" _bt_lower)
        if(_bt_lower STREQUAL "debug")
            set(_bt "Debug")
        elseif(_bt_lower STREQUAL "relwithdebinfo")
            set(_bt "RelWithDebInfo")
        elseif(_bt_lower STREQUAL "minsizerel")
            set(_bt "MinSizeRel")
        endif()
    endif()

    # custom.glibc: the host glibc, which in a manylinux image is its policy baseline
    set(_glibc "")
    if(_os STREQUAL "Linux")
        execute_process(COMMAND getconf GNU_LIBC_VERSION
                        OUTPUT_VARIABLE _libc_out
                        OUTPUT_STRIP_TRAILING_WHITESPACE
                        ERROR_QUIET)
        string(REGEX MATCH "[0-9]+\\.[0-9]+" _glibc "${_libc_out}")
    endif()

    set(CPACK_OPENDAQ_META_SETTINGS_OS               "${_os}"           PARENT_SCOPE)
    set(CPACK_OPENDAQ_META_SETTINGS_OS_VERSION       "${_os_version}"   PARENT_SCOPE)
    set(CPACK_OPENDAQ_META_SETTINGS_ARCH             "${_arch}"         PARENT_SCOPE)
    set(CPACK_OPENDAQ_META_SETTINGS_COMPILER         "${_compiler}"     PARENT_SCOPE)
    set(CPACK_OPENDAQ_META_SETTINGS_COMPILER_VERSION "${_compiler_ver}" PARENT_SCOPE)
    set(CPACK_OPENDAQ_META_SETTINGS_COMPILER_TOOLSET "${_toolset}"      PARENT_SCOPE)
    set(CPACK_OPENDAQ_META_SETTINGS_COMPILER_CPPSTD  "${_cppstd}"       PARENT_SCOPE)
    set(CPACK_OPENDAQ_META_SETTINGS_COMPILER_LIBCXX  "${_libcxx}"       PARENT_SCOPE)
    set(CPACK_OPENDAQ_META_SETTINGS_COMPILER_RUNTIME "${_runtime}"      PARENT_SCOPE)
    set(CPACK_OPENDAQ_META_SETTINGS_BUILD_TYPE       "${_bt}"           PARENT_SCOPE)
    set(CPACK_OPENDAQ_META_CUSTOM_PLATFORM           "${_platform}"     PARENT_SCOPE)
    set(CPACK_OPENDAQ_META_CUSTOM_GLIBC              "${_glibc}"        PARENT_SCOPE)
endfunction()

##
## opendaq_detect_package()
##   Finds what is being packaged.
##
##   name:    CPACK_OPENDAQ_META_PACKAGE_NAME > lowercase PROJECT_NAME
##   version: CPACK_OPENDAQ_META_PACKAGE_VERSION > PROJECT_VERSION
##
##   Both are read back from the variables they set: a project sets them before calling, a
##   cpack run with -D. The version suffix is not detected -- see
##   opendaq_compose_package_file_name().
##
##   Sets: CPACK_OPENDAQ_META_PACKAGE_NAME, CPACK_OPENDAQ_META_PACKAGE_VERSION
##
function(opendaq_detect_package)
    if(CPACK_OPENDAQ_META_PACKAGE_NAME)
        set(_name "${CPACK_OPENDAQ_META_PACKAGE_NAME}")
    else()
        string(TOLOWER "${PROJECT_NAME}" _name)
    endif()

    if(CPACK_OPENDAQ_META_PACKAGE_VERSION)
        set(_version "${CPACK_OPENDAQ_META_PACKAGE_VERSION}")
    else()
        set(_version "${PROJECT_VERSION}")
    endif()

    if(NOT _name OR NOT _version)
        message(FATAL_ERROR "opendaq_detect_package(): no package name or version to work with")
    endif()

    set(CPACK_OPENDAQ_META_PACKAGE_NAME    "${_name}"    PARENT_SCOPE)
    set(CPACK_OPENDAQ_META_PACKAGE_VERSION "${_version}" PARENT_SCOPE)
endfunction()

##
## opendaq_compose_package_triplet([ARCH <a>] [PLATFORM <p>] [COMPILER <c>]
##                                 [COMPILER_VERSION <v>] [BUILD_TYPE <b>]
##                                 [OUTPUT_VARIABLE <var>])
##   <arch>-<platform>-<compiler>-<version>-<build_type>, from the detected settings unless
##   a part is given. Not a plain copy of them: the os segment is the platform
##   (manylinux_2_28, not Linux) and MSVC contributes its toolset rather than its Conan
##   compiler version.
##
##   Calls opendaq_detect_settings() when the settings are not there yet.
##
##   Sets: CPACK_OPENDAQ_META_PACKAGE_TRIPLET, and OUTPUT_VARIABLE if given
##
function(opendaq_compose_package_triplet)
    cmake_parse_arguments(ARG "" "ARCH;PLATFORM;COMPILER;COMPILER_VERSION;BUILD_TYPE;OUTPUT_VARIABLE" "" ${ARGN})

    if(NOT CPACK_OPENDAQ_META_SETTINGS_ARCH)
        opendaq_detect_settings()
    endif()

    if(NOT DEFINED ARG_ARCH)
        set(ARG_ARCH "${CPACK_OPENDAQ_META_SETTINGS_ARCH}")
    endif()
    if(NOT DEFINED ARG_PLATFORM)
        set(ARG_PLATFORM "${CPACK_OPENDAQ_META_CUSTOM_PLATFORM}")
    endif()
    if(NOT DEFINED ARG_COMPILER)
        set(ARG_COMPILER "${CPACK_OPENDAQ_META_SETTINGS_COMPILER}")
    endif()
    if(NOT DEFINED ARG_COMPILER_VERSION)
        if(CPACK_OPENDAQ_META_SETTINGS_COMPILER_TOOLSET)
            string(REGEX REPLACE "^v" "" ARG_COMPILER_VERSION "${CPACK_OPENDAQ_META_SETTINGS_COMPILER_TOOLSET}")
        else()
            set(ARG_COMPILER_VERSION "${CPACK_OPENDAQ_META_SETTINGS_COMPILER_VERSION}")
        endif()
    endif()
    if(NOT DEFINED ARG_BUILD_TYPE)
        string(TOLOWER "${CPACK_OPENDAQ_META_SETTINGS_BUILD_TYPE}" ARG_BUILD_TYPE)
    endif()

    set(_triplet "${ARG_ARCH}-${ARG_PLATFORM}-${ARG_COMPILER}-${ARG_COMPILER_VERSION}-${ARG_BUILD_TYPE}")

    set(CPACK_OPENDAQ_META_PACKAGE_TRIPLET "${_triplet}" PARENT_SCOPE)
    if(DEFINED ARG_OUTPUT_VARIABLE)
        set(${ARG_OUTPUT_VARIABLE} "${_triplet}" PARENT_SCOPE)
    endif()
endfunction()

##
## opendaq_compose_package_file_name([BASENAME <b>] [VERSION <v>] [SUFFIX <s>] [TRIPLET <t>]
##                                   [OUTPUT_VARIABLE <var>])
##   <basename>-<version><suffix>-<triplet>, from the package and the triplet unless a part
##   is given. The extension is cpack's business.
##
##   SUFFIX is appended to the version verbatim, separator included -- "-<short sha>",
##   ".dev5", "+local". Nothing detects it: it comes from
##   CPACK_OPENDAQ_META_PACKAGE_VERSION_SUFFIX, which a project sets.
##
##   Sets: CPACK_PACKAGE_FILE_NAME, and OUTPUT_VARIABLE if given
##
function(opendaq_compose_package_file_name)
    cmake_parse_arguments(ARG "" "BASENAME;VERSION;SUFFIX;TRIPLET;OUTPUT_VARIABLE" "" ${ARGN})

    if(NOT DEFINED ARG_BASENAME)
        set(ARG_BASENAME "${CPACK_OPENDAQ_META_PACKAGE_NAME}")
    endif()
    if(NOT DEFINED ARG_VERSION)
        set(ARG_VERSION "${CPACK_OPENDAQ_META_PACKAGE_VERSION}")
    endif()
    if(NOT DEFINED ARG_SUFFIX)
        set(ARG_SUFFIX "${CPACK_OPENDAQ_META_PACKAGE_VERSION_SUFFIX}")
    endif()
    if(NOT DEFINED ARG_TRIPLET)
        set(ARG_TRIPLET "${CPACK_OPENDAQ_META_PACKAGE_TRIPLET}")
    endif()

    set(_file_name "${ARG_BASENAME}-${ARG_VERSION}${ARG_SUFFIX}-${ARG_TRIPLET}")

    set(CPACK_PACKAGE_FILE_NAME "${_file_name}" PARENT_SCOPE)
    if(DEFINED ARG_OUTPUT_VARIABLE)
        set(${ARG_OUTPUT_VARIABLE} "${_file_name}" PARENT_SCOPE)
    endif()
endfunction()

##
## opendaq_write_metadata(OUTPUT <path>)
##   Writes the metadata to OUTPUT, and nothing else: installing or copying that file is the
##   caller's call. A field is written when it has a value, a section when any of its fields
##   does.
##
function(opendaq_write_metadata)
    cmake_parse_arguments(ARG "" "OUTPUT" "" ${ARGN})

    if(NOT DEFINED ARG_OUTPUT)
        message(FATAL_ERROR "opendaq_write_metadata() requires OUTPUT")
    endif()

    # append `"key": "value"` to <list>, unless the value is empty
    macro(_daq_meta_member list key value)
        if(NOT "${value}" STREQUAL "")
            list(APPEND ${list} "    \"${key}\": \"${value}\"")
        endif()
    endmacro()

    # no name, no package to describe
    set(_package "")
    if(CPACK_OPENDAQ_META_PACKAGE_NAME)
        _daq_meta_member(_package "name"           "${CPACK_OPENDAQ_META_PACKAGE_NAME}")
        _daq_meta_member(_package "version"        "${CPACK_OPENDAQ_META_PACKAGE_VERSION}")
        _daq_meta_member(_package "version.suffix" "${CPACK_OPENDAQ_META_PACKAGE_VERSION_SUFFIX}")
        _daq_meta_member(_package "triplet"        "${CPACK_OPENDAQ_META_PACKAGE_TRIPLET}")
    endif()

    set(_settings "")
    _daq_meta_member(_settings "os"               "${CPACK_OPENDAQ_META_SETTINGS_OS}")
    _daq_meta_member(_settings "os.version"       "${CPACK_OPENDAQ_META_SETTINGS_OS_VERSION}")
    _daq_meta_member(_settings "arch"             "${CPACK_OPENDAQ_META_SETTINGS_ARCH}")
    _daq_meta_member(_settings "compiler"         "${CPACK_OPENDAQ_META_SETTINGS_COMPILER}")
    _daq_meta_member(_settings "compiler.version" "${CPACK_OPENDAQ_META_SETTINGS_COMPILER_VERSION}")
    _daq_meta_member(_settings "compiler.toolset" "${CPACK_OPENDAQ_META_SETTINGS_COMPILER_TOOLSET}")
    _daq_meta_member(_settings "compiler.libcxx"  "${CPACK_OPENDAQ_META_SETTINGS_COMPILER_LIBCXX}")
    _daq_meta_member(_settings "compiler.cppstd"  "${CPACK_OPENDAQ_META_SETTINGS_COMPILER_CPPSTD}")
    _daq_meta_member(_settings "compiler.runtime" "${CPACK_OPENDAQ_META_SETTINGS_COMPILER_RUNTIME}")
    _daq_meta_member(_settings "build_type"       "${CPACK_OPENDAQ_META_SETTINGS_BUILD_TYPE}")

    set(_custom "")
    _daq_meta_member(_custom "platform" "${CPACK_OPENDAQ_META_CUSTOM_PLATFORM}")
    _daq_meta_member(_custom "glibc"    "${CPACK_OPENDAQ_META_CUSTOM_GLIBC}")

    set(_sections "")
    foreach(_section package settings custom)
        if(_${_section})
            string(JOIN ",\n" _members ${_${_section}})
            list(APPEND _sections "  \"${_section}\": {\n${_members}\n  }")
        endif()
    endforeach()
    string(JOIN ",\n" _body ${_sections})

    set(_json "{\n")
    string(APPEND _json "  \"schema\": 1,\n")
    string(APPEND _json "  \"media-type\": \"application/vnd.opendaq.staging.layer.v1.tar+gzip\",\n")
    string(APPEND _json "${_body}\n")
    string(APPEND _json "}\n")

    file(WRITE "${ARG_OUTPUT}" "${_json}")
    message(STATUS "Wrote metadata: ${ARG_OUTPUT}")
endfunction()
