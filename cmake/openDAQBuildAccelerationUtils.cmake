# Build acceleration: precompiled headers (PCH) and unity builds (several .cpp files compiled
# as one translation unit).
#
# Options: OPENDAQ_ENABLE_PCH, OPENDAQ_ENABLE_UNITY_TESTS, OPENDAQ_ENABLE_UNITY_BINDINGS and
# OPENDAQ_ENABLE_UNITY_LIBS, gated by OPENDAQ_ENABLE_BUILD_ACCELERATION and declared by
# opendaq_setup_common_build_options(). Every helper is a no-op when its option is off.
#
# Rules for sources in a unity build, where files can see each other's file-level names:
#   1. Put file-private helpers and types in a namespace unique to the file. static and
#      anonymous namespaces do not help, since the merged files are one translation unit.
#   2. Keep using-directives (using namespace daq;) at global scope, outside that namespace.
#   3. Exclude a file that must stay alone (defines main(), clashes with a sibling):
#          set_source_files_properties(test_app.cpp PROPERTIES SKIP_UNITY_BUILD_INCLUSION ON)
#   4. Headers declaring explicit template specializations go in the opendaq_target_pch() list,
#      so they are seen before any use; without a PCH they are prepended to every unity file.

include_guard(GLOBAL)

macro(opendaq_setup_build_acceleration_options)
    option(OPENDAQ_ENABLE_BUILD_ACCELERATION "Precompiled headers and unity builds" ON)
    option(OPENDAQ_ENABLE_PCH "Use precompiled headers" ON)
    option(OPENDAQ_ENABLE_UNITY_TESTS "Unity builds for test targets" ON)
    option(OPENDAQ_ENABLE_UNITY_BINDINGS "Unity builds for generated language bindings" ON)
    option(OPENDAQ_ENABLE_UNITY_LIBS "Unity builds for libraries" ON)

    _opendaq_report_build_acceleration()
endmacro()

# Whether an OPENDAQ_ENABLE_* option is in effect: it and the master switch are on.
function(_opendaq_acceleration_enabled OPTION_NAME OUT_VAR)
    if (OPENDAQ_ENABLE_BUILD_ACCELERATION AND ${OPTION_NAME})
        set(${OUT_VAR} TRUE PARENT_SCOPE)
    else()
        set(${OUT_VAR} FALSE PARENT_SCOPE)
    endif()
endfunction()

function(_opendaq_report_build_acceleration)
    get_property(REPORTED GLOBAL PROPERTY OPENDAQ_BUILD_ACCELERATION_REPORTED)
    if (REPORTED)
        return()
    endif()
    set_property(GLOBAL PROPERTY OPENDAQ_BUILD_ACCELERATION_REPORTED TRUE)

    opendaq_pch_in_use(PCH_IN_USE)
    set(ENABLED "")
    if (PCH_IN_USE)
        list(APPEND ENABLED "precompiled headers")
    endif()
    foreach(KIND tests bindings libs)
        string(TOUPPER ${KIND} KIND_UPPER)
        _opendaq_acceleration_enabled(OPENDAQ_ENABLE_UNITY_${KIND_UPPER} UNITY_ENABLED)
        if (UNITY_ENABLED)
            list(APPEND ENABLED "unity ${KIND}")
        endif()
    endforeach()

    if (ENABLED)
        list(JOIN ENABLED ", " ENABLED)
        message(STATUS "Build acceleration: ${ENABLED}")
    else()
        message(STATUS "Build acceleration: off")
    endif()

    _opendaq_acceleration_enabled(OPENDAQ_ENABLE_PCH PCH_ENABLED)
    if (PCH_ENABLED AND NOT PCH_IN_USE)
        message(STATUS "Precompiled headers are not applied with the ${CMAKE_CXX_COMPILER_ID} compiler")
    endif()
endfunction()

# icx emits catchable-type records without the copy constructor for exceptions thrown from
# inside a PCH; std::exception_ptr then copies them bitwise and double-frees the message.
function(opendaq_pch_in_use OUT_VAR)
    _opendaq_acceleration_enabled(OPENDAQ_ENABLE_PCH PCH_ENABLED)
    if (PCH_ENABLED AND NOT CMAKE_CXX_COMPILER_ID STREQUAL "IntelLLVM")
        set(${OUT_VAR} TRUE PARENT_SCOPE)
    else()
        set(${OUT_VAR} FALSE PARENT_SCOPE)
    endif()
endfunction()

function(_opendaq_unity_include_first TARGET_NAME)
    set(CODE "")
    foreach(HEADER IN LISTS ARGN)
        string(APPEND CODE "#include ${HEADER}\n")
    endforeach()
    set_property(TARGET ${TARGET_NAME} APPEND_STRING PROPERTY UNITY_BUILD_CODE_BEFORE_INCLUDE "${CODE}")
endfunction()

function(_opendaq_pch_compile_options TARGET_NAME)
    if (CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
        # Required for ccache to cache compilations that use a GCC PCH.
        target_compile_options(${TARGET_NAME} PRIVATE -fpch-preprocess)

        # Declarations from a PCH lose their system-header status, so -Wdangling-reference
        # fires in third-party code.
        if (CMAKE_CXX_COMPILER_VERSION VERSION_GREATER_EQUAL 13)
            target_compile_options(${TARGET_NAME} PRIVATE -Wno-dangling-reference)
        endif()
    endif()
endfunction()

# opendaq_target_pch(<target> <header>...)
function(opendaq_target_pch TARGET_NAME)
    opendaq_pch_in_use(PCH_IN_USE)
    if (PCH_IN_USE)
        target_precompile_headers(${TARGET_NAME} PRIVATE ${ARGN})
        _opendaq_pch_compile_options(${TARGET_NAME})
    else()
        _opendaq_unity_include_first(${TARGET_NAME} ${ARGN})
    endif()
endfunction()

# opendaq_target_pch_reuse(<target> <donor>): both must compile with the same flags.
function(opendaq_target_pch_reuse TARGET_NAME DONOR_NAME)
    opendaq_pch_in_use(PCH_IN_USE)
    if (PCH_IN_USE)
        target_precompile_headers(${TARGET_NAME} REUSE_FROM ${DONOR_NAME})
        _opendaq_pch_compile_options(${TARGET_NAME})
    endif()
endfunction()

# opendaq_target_pch_group(<target> <group> <header>...)
# The first target of a group builds the PCH, later ones reuse it.
function(opendaq_target_pch_group TARGET_NAME GROUP_NAME)
    opendaq_pch_in_use(PCH_IN_USE)
    if (NOT PCH_IN_USE)
        _opendaq_unity_include_first(${TARGET_NAME} ${ARGN})
        return()
    endif()

    get_property(DONOR GLOBAL PROPERTY OPENDAQ_PCH_GROUP_${GROUP_NAME})
    if (DONOR)
        opendaq_target_pch_reuse(${TARGET_NAME} ${DONOR})
    else()
        opendaq_target_pch(${TARGET_NAME} ${ARGN})
        set_property(GLOBAL PROPERTY OPENDAQ_PCH_GROUP_${GROUP_NAME} ${TARGET_NAME})
    endif()
endfunction()

# opendaq_directory_pch(<donor> HEADERS <header>... LINK_LIBRARIES <target>... [EXCLUDE <regex>])
# One PCH for the executables defined so far in the current directory: a stub executable
# <donor> linked against LINK_LIBRARIES builds it, the others reuse it. Skips targets matching
# EXCLUDE (e.g. C targets) and targets that already have a PCH.
function(opendaq_directory_pch DONOR_NAME)
    cmake_parse_arguments(PCH "" "EXCLUDE" "HEADERS;LINK_LIBRARIES" ${ARGN})

    opendaq_pch_in_use(PCH_IN_USE)
    if (NOT PCH_IN_USE)
        return()
    endif()

    set(STUB ${CMAKE_CURRENT_BINARY_DIR}/${DONOR_NAME}_stub.cpp)
    file(CONFIGURE OUTPUT ${STUB} CONTENT "int main()\n{\n    return 0;\n}\n")
    add_executable(${DONOR_NAME} ${STUB})
    set_target_properties(${DONOR_NAME} PROPERTIES RUNTIME_OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR})
    target_link_libraries(${DONOR_NAME} PRIVATE ${PCH_LINK_LIBRARIES})
    opendaq_target_pch(${DONOR_NAME} ${PCH_HEADERS})

    get_property(TARGETS DIRECTORY PROPERTY BUILDSYSTEM_TARGETS)
    foreach(TARGET_NAME IN LISTS TARGETS)
        if (TARGET_NAME STREQUAL DONOR_NAME)
            continue()
        endif()
        if (PCH_EXCLUDE AND TARGET_NAME MATCHES "${PCH_EXCLUDE}")
            continue()
        endif()
        get_target_property(TARGET_TYPE ${TARGET_NAME} TYPE)
        if (NOT TARGET_TYPE STREQUAL "EXECUTABLE")
            continue()
        endif()
        get_target_property(OWN_PCH ${TARGET_NAME} PRECOMPILE_HEADERS)
        get_target_property(OWN_REUSE ${TARGET_NAME} PRECOMPILE_HEADERS_REUSE_FROM)
        if (OWN_PCH OR OWN_REUSE)
            continue()
        endif()
        opendaq_target_pch_reuse(${TARGET_NAME} ${DONOR_NAME})
    endforeach()
endfunction()

function(_opendaq_target_unity OPTION_NAME TARGET_NAME)
    cmake_parse_arguments(UNITY "" "BATCH_SIZE" "" ${ARGN})

    _opendaq_acceleration_enabled(${OPTION_NAME} UNITY_ENABLED)
    if (NOT UNITY_ENABLED)
        return()
    endif()

    if (NOT UNITY_BATCH_SIZE)
        set(UNITY_BATCH_SIZE 12)
    endif()

    set_target_properties(${TARGET_NAME} PROPERTIES
        UNITY_BUILD ON
        UNITY_BUILD_BATCH_SIZE ${UNITY_BATCH_SIZE}
    )

    if (MSVC)
        # Merged translation units exceed the object section limit (C1128).
        target_compile_options(${TARGET_NAME} PRIVATE /bigobj)
    endif()

    # Every merged source is "outside the main input file" to GCC.
    if (CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
        target_compile_options(${TARGET_NAME} PRIVATE -Wno-subobject-linkage)
    endif()
endfunction()

# opendaq_target_unity_<tests|bindings|libs>(<target> [BATCH_SIZE <n>])
function(opendaq_target_unity_tests TARGET_NAME)
    _opendaq_target_unity(OPENDAQ_ENABLE_UNITY_TESTS ${TARGET_NAME} ${ARGN})
endfunction()

function(opendaq_target_unity_bindings TARGET_NAME)
    _opendaq_target_unity(OPENDAQ_ENABLE_UNITY_BINDINGS ${TARGET_NAME} ${ARGN})
endfunction()

function(opendaq_target_unity_libs TARGET_NAME)
    _opendaq_target_unity(OPENDAQ_ENABLE_UNITY_LIBS ${TARGET_NAME} ${ARGN})
endfunction()
