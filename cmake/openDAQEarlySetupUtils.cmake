# should be called before any project() to make effect
# TODO all variables seems to be relevant for being set via cmake toolchain approach
macro(opendaq_32bit_build_linux_early_setup)
    if (DEFINED PROJECT_SOURCE_DIR)
        message(FATAL_ERROR "Must be run before a project()")
    endif()

    set(CMAKE_C_FLAGS_INIT "${CMAKE_C_FLAGS_INIT} -m32" CACHE STRING "" FORCE)
    set(CMAKE_CXX_FLAGS_INIT "${CMAKE_CXX_FLAGS_INIT} -m32" CACHE STRING "" FORCE)
    set(CMAKE_ASM_FLAGS_INIT "${CMAKE_ASM_FLAGS_INIT} -m32" CACHE STRING "" FORCE)

    # Help CMake find 32-bit libraries
    list(APPEND CMAKE_LIBRARY_PATH /usr/lib/i386-linux-gnu)

    if(NOT CMAKE_SYSTEM_NAME)
        set(CMAKE_SYSTEM_NAME Linux CACHE STRING "" FORCE)
    endif()

    if(NOT CMAKE_SYSTEM_PROCESSOR)
        set(CMAKE_SYSTEM_PROCESSOR i386 CACHE STRING "" FORCE)
    endif()
endmacro()

# Can be safely called before `project()`
macro(opendaq_setup_common_cmake_policies)
    # CMP0074:
    # find_package() uses <PackageName>_ROOT variables as search hints.
    # This enables modern behavior where passing -D<PKG>_ROOT=/path works
    # without needing custom Find modules or CMAKE_PREFIX_PATH hacks.
    if (POLICY CMP0074)
        cmake_policy(SET CMP0074 NEW)
    endif()

    # CMP0076:
    # target_sources() allows relative paths to be interpreted
    # relative to the directory where target_sources() is called,
    # not the target's source directory. This makes modular CMakeLists
    # behave intuitively and avoids path bugs when targets are extended
    # from subdirectories.
    if (POLICY CMP0076)
        cmake_policy(SET CMP0076 NEW)
    endif()

    # CMP0077:
    # option() honors normal variables.
    # If a variable is set before calling option(), the option() command
    # will not overwrite it. This is critical for allowing toolchains,
    # CI, or parent projects to predefine options reliably.
    if (POLICY CMP0077)
        cmake_policy(SET CMP0077 NEW)
    endif()

    # CMP0135:
    # Ensures consistent timestamps for files downloaded or extracted
    # by ExternalProject and FetchContent. This avoids unnecessary
    # rebuilds caused by constantly changing file modification times.
    # Particularly important for reproducible builds and CI stability.
    if (POLICY CMP0135)
        cmake_policy(SET CMP0135 NEW)
    endif()
endmacro()

# Can be safely called before `project()`
macro(opendaq_common_early_setup)
    opendaq_setup_common_cmake_policies()
    set(CMAKE_MESSAGE_CONTEXT_SHOW ON CACHE BOOL "Show CMake message context")

    # In-source build is not supported for SDK nor modules
    if (${CMAKE_SOURCE_DIR} STREQUAL ${CMAKE_BINARY_DIR})
        message(FATAL_ERROR "In-source build is not supported! Please choose a separate build directory e.g.: /build/x64/msvc")
    endif()

    # save configuration start timestamp once to write it into all built libraries and modules metadata
    if(NOT DEFINED CONFIGURE_DATE)
        string(TIMESTAMP CONFIGURE_DATE)
    endif()

    if(NOT DEFINED CONFIGURE_DATE)
        string(TIMESTAMP CURRENT_YEAR "%Y")
    endif()

    set(FETCHCONTENT_EXTERNALS_DIR ${CMAKE_BINARY_DIR}/__external CACHE PATH "FetchContent folder prefix")
    set_property(GLOBAL PROPERTY USE_FOLDERS ON) # common IDE helper

    get_property(IS_MULTICONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
    message(STATUS "Platform: ${CMAKE_SYSTEM_PROCESSOR} | ${CMAKE_SYSTEM_NAME} ${CMAKE_SYSTEM_VERSION}")
    message(STATUS "Generator: ${CMAKE_GENERATOR} | ${CMAKE_GENERATOR_PLATFORM}")
    if (IS_MULTICONFIG)
        message(STATUS "Configuration types:")
        block()
            list(APPEND CMAKE_MESSAGE_INDENT "\t")
            foreach(CONFIG_TYPE ${CMAKE_CONFIGURATION_TYPES})
                message(STATUS ${CONFIG_TYPE})
            endforeach()
        endblock()
    else()
        message(STATUS "Build type: ${CMAKE_BUILD_TYPE}")
    endif()

    # the following includes completely independent from `project()` being defined or not therefore can be safely called before
    include(CMakeDependentOption)
    include(CMakePrintHelpers)

    # All install targets from within the project should eventually specify the component name.
    # This changes the default name for all the targets without an explicit name ("Unspecified").
    # The component "Unspecified" is a bit special and makes it hard to be excluded.
    # Ideally we would just avoid installing all external components and we wouldn't need setting this at all.
    set(CMAKE_INSTALL_DEFAULT_COMPONENT_NAME "External")
endmacro()

