macro(opendaq_setup_repo_version VAR_PREFIX REPO_NAME VERSION_FILE)
    if (EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${VERSION_FILE}")
        file(READ "${VERSION_FILE}" repo_version)
        string(STRIP "${repo_version}" repo_version)
        string(REGEX REPLACE "^([0-9]+\\.[0-9]+\\.[0-9]+).*" "\\1" repo_version_major_minor_patch "${repo_version}")
        set(${VAR_PREFIX}_VERSION "${repo_version_major_minor_patch}")
        message(STATUS "${REPO_NAME} version ${${VAR_PREFIX}_VERSION}")
    else()
        message(FATAL_ERROR "${VERSION_FILE} file not found")
    endif()
endmacro(opendaq_setup_repo_version)


macro(opendaq_setup_32bit_build_linux_system_flags REPO_OPTION_PREFIX)
    if(${REPO_OPTION_PREFIX}_FORCE_COMPILE_32BIT AND CMAKE_HOST_SYSTEM_NAME STREQUAL "Linux")
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
    endif()
endmacro(opendaq_setup_32bit_build_linux_system_flags)


macro(opendaq_setup_build_mode REPO_OPTION_PREFIX REPO_NAME)
    list(APPEND CMAKE_MESSAGE_CONTEXT ${REPO_NAME})
    set(CMAKE_MESSAGE_CONTEXT_SHOW ON CACHE BOOL "Show CMake message context")

    if (${CMAKE_SOURCE_DIR} STREQUAL ${CMAKE_BINARY_DIR})
        message(FATAL_ERROR "In-source build is not supported! Please choose a separate build directory e.g.: /build/x64/msvc")
    endif()

    if (NOT DEFINED ROOT_DIR)
        get_filename_component(ROOT_DIR "${CMAKE_SOURCE_DIR}" REALPATH)
        message(STATUS "Set Root cmake dir to ${ROOT_DIR}")
    endif()

    if (NOT ${PROJECT_SOURCE_DIR} STREQUAL ${ROOT_DIR})
        message(STATUS "Building as submodule")
        set(${REPO_OPTION_PREFIX}_BUILDING_AS_SUBMODULE ON CACHE INTERNAL "Building ${REPO_NAME} as submodule")
    else()
        message(STATUS "Building standalone")
        set(${REPO_OPTION_PREFIX}_BUILDING_AS_SUBMODULE OFF CACHE INTERNAL "Building ${REPO_NAME} standalone")
        set_property(GLOBAL PROPERTY PREDEFINED_TARGETS_FOLDER ".CMakePredefinedTargets")
        set_property(GLOBAL PROPERTY USE_FOLDERS ON)

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

        string(TIMESTAMP CONFIGURE_DATE)
        string(TIMESTAMP CURRENT_YEAR "%Y")
    endif()
endmacro(opendaq_setup_build_mode)

macro(opendaq_setup_repo REPO_OPTION_PREFIX)
    if (NOT DEFINED PROJECT_SOURCE_DIR)
        message(FATAL_ERROR "Must be run inside a project()")
    endif()

    set(FETCHCONTENT_EXTERNALS_DIR ${ROOT_DIR}/build/__external CACHE PATH "FetchContent folder prefix")

    set(CMAKE_INSTALL_DEBUG_LIBRARIES ON)

    include(CheckCompilerFlag)
    include(CheckLinkerFlag)
    include(CMakeDependentOption)
    include(GNUInstallDirs)
    include(CMakePrintHelpers)
    include(InstallRequiredSystemLibraries)

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

    # All install targets from within the project should eventually specify the component name.
    # This changes the default name for all the targets without an explicit name ("Unspecified").
    # The component "Unspecified" is a bit special and makes it hard to be excluded.
    # Ideally we would just avoid installing all external components and we wouldn't need setting this at all.
    set(CMAKE_INSTALL_DEFAULT_COMPONENT_NAME "External")

    if(APPLE)
        set(LIB_LOAD_ORIGIN @loader_path)
    else()
        set(LIB_LOAD_ORIGIN $ORIGIN)
    endif()

    file(RELATIVE_PATH RPATH_DIR
        ${CMAKE_CURRENT_BINARY_DIR}/${CMAKE_INSTALL_BINDIR}
        ${CMAKE_CURRENT_BINARY_DIR}/${CMAKE_INSTALL_LIBDIR}
    )

    # allow CMAKE_INSTALL_RPATH to be cleared from the command line
    if (NOT DEFINED CMAKE_INSTALL_RPATH)
        set(CMAKE_INSTALL_RPATH ${LIB_LOAD_ORIGIN} ${LIB_LOAD_ORIGIN}/${RPATH_DIR})
    endif()

    # Options
    option(${REPO_OPTION_PREFIX}_DISABLE_DEBUG_POSTFIX "Disable debug ('-debug') postfix" OFF)
    option(${REPO_OPTION_PREFIX}_DEBUG_WARNINGS_AS_ERRORS "Treat debug warnings as errors" OFF)
    option(${REPO_OPTION_PREFIX}_RELEASE_WARNINGS_AS_ERRORS "Treat release warnings as errors" ON)
    option(${REPO_OPTION_PREFIX}_ENABLE_TESTS "Enable testing for ${REPO_OPTION_PREFIX}" ON)
    option(${REPO_OPTION_PREFIX}_ENABLE_EXAMPLE_APP "Enable example applications for ${REPO_OPTION_PREFIX}" ON)

    if (NOT MSVC)
        option(${REPO_OPTION_PREFIX}_FORCE_COMPILE_32BIT "Compile 32Bit on non MSVC" OFF)
    endif()

    if (MSVC)
        option(${REPO_OPTION_PREFIX}_MSVC_SINGLE_PROCESS_BUILD "Do not include /MP compile option." OFF)
    endif()

    option(${REPO_OPTION_PREFIX}_ALWAYS_FETCH_DEPENDENCIES "Ignore any installed libraries and always build all dependencies from source" ON)
    option(${REPO_OPTION_PREFIX}_DISABLE_DEBUG_POSTFIX "Disable debug ('-debug') postfix" OFF)
    option(${REPO_OPTION_PREFIX}_DEBUG_WARNINGS_AS_ERRORS "Treat debug warnings as errors" OFF)
    option(${REPO_OPTION_PREFIX}_RELEASE_WARNINGS_AS_ERRORS "Treat release warnings as errors" ON)
    option(${REPO_OPTION_PREFIX}_USE_CCACHE "Use compiler cache driver if available" ON)

    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
    set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

    if (CMAKE_CXX_COMPILER_ID MATCHES "^(Clang|IntelLLVM)$")
        set(CMAKE_COMPILER_IS_CLANGXX On CACHE INTERNAL "Compiler is LLVM")
        message(STATUS "Compiler is LLVM")
    endif ()

    if (UNIX AND (CMAKE_COMPILER_IS_CLANGXX OR CMAKE_COMPILER_IS_GNUXX))
        # hide all symbols expect those specifically exported with PUBLIC_EXPORT macro
        if (APPLE)
          # not possible on Mac, should be done per library
        else()
          set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -Wl,--exclude-libs,ALL")
        endif()
        set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fvisibility=hidden -fvisibility-inlines-hidden")
        set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fvisibility=hidden -fvisibility-inlines-hidden")
    endif()

    set_property(GLOBAL PROPERTY USE_FOLDERS ON)

    if (UNIX AND CMAKE_SYSTEM_PROCESSOR MATCHES "^arm.*$")  #e.g. armv7l
        set(BUILD_ARM On CACHE INTERNAL "Build for ARM architecture")
    endif()

    if (UNIX AND CMAKE_SYSTEM_PROCESSOR MATCHES "^aarch.*$")  #e.g. aarch64
        set(BUILD_ARM On CACHE INTERNAL "Build for ARM architecture")
    endif()

    set(BUILD_64Bit Off)

    if("${CMAKE_SIZEOF_VOID_P}" EQUAL 8)
        set(BUILD_64Bit On)
    endif()

    if (UNIX AND CMAKE_SYSTEM_PROCESSOR MATCHES "^aarch64$")  # arm architecture 64bit
        set(BUILD_64Bit On)
    endif()

    if(BUILD_64Bit OR BUILD_ARM)
        message(STATUS "Position independent code flag is set")
        set(CMAKE_POSITION_INDEPENDENT_CODE ON)
    else()
        message(STATUS "Position independent code flag is not set")
    endif()

    if(NOT CMAKE_DEBUG_POSTFIX AND NOT ${REPO_OPTION_PREFIX}_DISABLE_DEBUG_POSTFIX)
      set(CMAKE_DEBUG_POSTFIX -debug)
    endif()

    set(CMAKE_CXX_STANDARD 17)

    if (WIN32)
        set(MIN_WINDOWS_VERSION 0x0601)
        add_compile_definitions(NOMINMAX
                                _WIN32_WINNT=${MIN_WINDOWS_VERSION} # Windows 7 Compat
        )

        add_compile_definitions(UNICODE _UNICODE)
    endif()

    if ((CMAKE_COMPILER_IS_GNUCXX OR CMAKE_COMPILER_IS_CLANGXX) AND NOT MSVC)
        option(${REPO_OPTION_PREFIX}_FORCE_LLD_LINKER "Force the use of the fast LLVM LLD linker" OFF)

        if (NOT WIN32)
            set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -pthread")
        endif()

        if(${REPO_OPTION_PREFIX}_FORCE_COMPILE_32BIT)
            set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -m32")
            set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -m32")
            set(CMAKE_ASM_FLAGS "${CMAKE_ASM_FLAGS} -m32")
            set(BUILD_64Bit OFF)

            # Linux GCC 32-bit specific flags
            if(CMAKE_SYSTEM_NAME STREQUAL "Linux" AND CMAKE_COMPILER_IS_GNUCXX)
                set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fPIC -ffloat-store")
                set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fPIC")
            endif()
        endif()

        # The flag -fuse-ld=lld is needed on MinGW where the default linker is hardly usable.
        # It is not available on macOS (it is ignored though, unless you pass -Werror).
        # It might be default on Linux distros, but it might not be always available.
        # The following code just says "use LLD whenever it seems feasible".
        check_linker_flag(CXX "-fuse-ld=lld" COMPILER_SUPPORTS_LLD_LINKER)
        if(COMPILER_SUPPORTS_LLD_LINKER)
            set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -fuse-ld=lld")
            set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -fuse-ld=lld")
            set(CMAKE_MODULE_LINKER_FLAGS "${CMAKE_MODULE_LINKER_FLAGS} -fuse-ld=lld")
            message(STATUS "LLD Linker enabled")
        endif()
    endif()

    if (CMAKE_COMPILER_IS_GNUCXX)
        set(GCC_W_NO_EXTRA "-Wno-comment -Wno-unused-parameter -Wno-missing-field-initializers")
        set(GCC_W_NO_WALL "-Wno-unknown-pragmas -Wno-parentheses -Wno-misleading-indentation -Wno-unused-variable -Wno-switch -Wno-maybe-uninitialized -Wno-psabi")
        set(GCC_CHARSET_FLAGS "-fexec-charset=UTF-8 -finput-charset=UTF-8")
        #set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -pedantic -Wall -Wextra ${GCC_W_NO_EXTRA} ${GCC_W_NO_WALL} ${GCC_W_NO_PEDANTIC} -Werror=return-type")
        set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Wextra ${GCC_W_NO_EXTRA} ${GCC_W_NO_WALL} ${GCC_W_NO_PEDANTIC} -Werror=return-type ${GCC_CHARSET_FLAGS}")

        # Treat warnings as errors if ${REPO_OPTION_PREFIX}_<DEBUG|RELEASE>_WARNINGS_AS_ERRORS is ON
        add_compile_options($<$<OR:$<AND:$<CONFIG:Debug>,$<BOOL:${${REPO_OPTION_PREFIX}_DEBUG_WARNINGS_AS_ERRORS}>>,$<AND:$<NOT:$<CONFIG:Debug>>,$<BOOL:${${REPO_OPTION_PREFIX}_RELEASE_WARNINGS_AS_ERRORS}>>>:-Werror>)

        set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -g -ggdb")
        if (MINGW)
            set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -Wl,--exclude-all-symbols")
        endif()

        if (APPLE)
            set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -Wl,-undefined,error")
        else()
            set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -Wl,--no-undefined")
        endif()

        if (WIN32 AND NOT BUILD_64Bit)
            set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -mfpmath=sse -msse2")
        endif()

        if (NOT (WIN32 OR APPLE))
            if (NOT DEFINED HAVE_SPLIT_DWARF)
                check_compiler_flag(CXX "-gsplit-dwarf" HAVE_SPLIT_DWARF)
            endif()

            if (HAVE_SPLIT_DWARF)
                # Only add for debug builds, but could also expand the
                # generator expression to add for RelWithDebInfo too
                add_compile_options("$<$<CONFIG:Debug>:-gsplit-dwarf>")
            endif()
        endif()

        if (${REPO_OPTION_PREFIX}_FORCE_LLD_LINKER)
            set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fuse-ld=lld")
        endif()
    endif()

    if(CMAKE_COMPILER_IS_CLANGXX)
        # MinGW Clang does not support TLS so try emulating it
        if (MINGW)
            add_compile_options(-femulated-tls)
        endif()
    endif()

    if (${REPO_OPTION_PREFIX}_FORCE_LLD_LINKER)
        message(STATUS "Forcing the use of LLVM LLD linker. Make sure it is installed and available.")
    endif()

    if (MSVC AND NOT CMAKE_COMPILER_IS_CLANGXX)
        # As above CMAKE_CXX_STANDARD but for VS
        add_compile_options($<$<COMPILE_LANGUAGE:CXX>:/std:c++17>)

        foreach (flag IN ITEMS
            # Set source and execution character sets to UTF-8
            # https://learn.microsoft.com/en-us/cpp/build/reference/utf-8-set-source-and-executable-character-sets-to-utf-8
            /utf-8
            # Display level 1, level 2, and level 3 warnings, and all level 4 (informational) warnings that aren't off by default.
            # https://learn.microsoft.com/en-us/cpp/build/reference/compiler-option-warning-level
            /W4
            # data member 'member1' will be initialized after data member 'member2'
            # https://learn.microsoft.com/en-us/cpp/error-messages/compiler-warnings/c5038
            /w15038
            # Supress warnings
            # https://learn.microsoft.com/en-us/cpp/build/reference/compiler-option-warning-level
            #
            # 'class1' : inherits 'class2::member' via dominance
            # https://learn.microsoft.com/en-us/cpp/error-messages/compiler-warnings/compiler-warning-level-2-c4250
            /wd4250
            # Your code uses a function, class member, variable, or typedef that's marked deprecated.
            # https://learn.microsoft.com/en-us/cpp/error-messages/compiler-warnings/compiler-warning-level-3-c4996
            /wd4996
            # declaration of 'identifier' hides class member
            # https://learn.microsoft.com/en-us/cpp/error-messages/compiler-warnings/compiler-warning-level-4-c4458
            /wd4458
            # nonstandard extension used : nameless struct/union
            # https://learn.microsoft.com/en-us/cpp/error-messages/compiler-warnings/compiler-warning-level-4-c4201
            /wd4201
            # unreachable code
            # https://learn.microsoft.com/en-us/cpp/error-messages/compiler-warnings/compiler-warning-level-4-c4702
            /wd4702
            # declaration of 'identifier' hides global declaration
            # https://learn.microsoft.com/en-us/cpp/error-messages/compiler-warnings/compiler-warning-level-4-c4459
            /wd4459
            # 'function' : unreferenced local function has been removed
            # https://learn.microsoft.com/en-us/cpp/error-messages/compiler-warnings/compiler-warning-level-4-c4505
            /wd4505
            # conditional expression is constant
            # https://learn.microsoft.com/en-us/cpp/error-messages/compiler-warnings/compiler-warning-level-4-c4127
            /wd4127
            # assignment within conditional expression
            # https://learn.microsoft.com/en-us/cpp/error-messages/compiler-warnings/compiler-warning-level-4-c4706
            /wd4706
        )
            add_compile_options($<$<COMPILE_LANGUAGE:C,CXX>:${flag}>)
        endforeach()

            # Maintain binary compatibilty with older msvc runtime environments
            # https://github.com/microsoft/STL/wiki/Changelog
            add_compile_definitions(_DISABLE_CONSTEXPR_MUTEX_CONSTRUCTOR)

        if (NOT ${REPO_OPTION_PREFIX}_MSVC_SINGLE_PROCESS_BUILD)
            # Build with multiple processes
            # https://learn.microsoft.com/en-us/cpp/build/reference/mp-build-with-multiple-processes
            add_compile_options($<$<COMPILE_LANGUAGE:C,CXX>:/MP>)
        endif()

        # Treat warnings as errors if ${REPO_OPTION_PREFIX}_<DEBUG|RELEASE>_WARNINGS_AS_ERRORS is ON
        add_compile_options($<$<OR:$<AND:$<CONFIG:Debug>,$<BOOL:${${REPO_OPTION_PREFIX}_DEBUG_WARNINGS_AS_ERRORS}>>,$<AND:$<NOT:$<CONFIG:Debug>>,$<BOOL:${${REPO_OPTION_PREFIX}_RELEASE_WARNINGS_AS_ERRORS}>>>:/WX>)

        if (MSVC_VERSION GREATER_EQUAL 1910)
            # /Zc:__cplusplus forces MSVC to use the correct value of __cplusplus macro (otherwise always C++98)
            add_compile_options($<$<COMPILE_LANGUAGE:CXX>:/Zc:__cplusplus>)
            if (CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
                # /Zf (Faster PDB generation) is not supported by ClangCL
                set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} /Zf")
            endif()

            # Produce diagnostic messages with exact location
            add_compile_options($<$<COMPILE_LANGUAGE:C,CXX>:/diagnostics:caret>)
        endif()

        set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} /ignore:4221")
        set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} /ignore:4221")
        set(CMAKE_STATIC_LINKER_FLAGS "${CMAKE_STATIC_LINKER_FLAGS} /ignore:4221")

        set(CMAKE_EXE_LINKER_FLAGS_RELWITHDEBINFO    "${CMAKE_EXE_LINKER_FLAGS}    /DEBUG /OPT:REF /OPT:ICF")
        set(CMAKE_MODULE_LINKER_FLAGS_RELWITHDEBINFO "${CMAKE_MODULE_LINKER_FLAGS} /DEBUG /OPT:REF /OPT:ICF")
        set(CMAKE_SHARED_LINKER_FLAGS_RELWITHDEBINFO "${CMAKE_SHARED_LINKER_FLAGS} /DEBUG /OPT:REF /OPT:ICF")
        set(CMAKE_STATIC_LINKER_FLAGS_RELWITHDEBINFO "${CMAKE_STATIC_LINKER_FLAGS} /DEBUG /OPT:REF /OPT:ICF")
    endif()

    if (MSVC)
        set(FLEX_FLAGS "--wincompat")
    endif()

    set(THREADS_PREFER_PTHREAD_FLAG ON)
    find_package(Threads REQUIRED)

    add_compile_definitions(BOOST_ALL_NO_LIB=1)

    opendaq_use_compiler_cache()

    if (WIN32)
        add_compile_definitions(WIN32_LEAN_AND_MEAN)
    endif()

    if(CMAKE_COMPILER_IS_CLANGXX)
        set(CLANG_FLAGS "\
            -Wno-unused-variable \
            -Wno-missing-braces \
            -Wno-unused-function \
            -Wno-logical-op-parentheses \
            -Wno-unused-variable \
            -Werror=return-type \
            -Wno-deprecated-declarations \
            -Wno-undef \
            -Wno-incompatible-pointer-types \
            -Wno-unused-parameter \
            -Wno-misleading-indentation \
            -Wno-missing-field-initializers"
        )

        # Append Intel-LLVM-specific suppressions
        if (CMAKE_CXX_COMPILER_ID MATCHES "IntelLLVM")
            set(CLANG_FLAGS "${CLANG_FLAGS} \
                -Xclang -Rno-debug-disables-optimization \
                -Wno-deprecated-literal-operator \
                -Wno-self-assign-overloaded"
            )
        endif()

        if (CMAKE_CXX_COMPILER_ID MATCHES "IntelLLVM" AND MSVC)
            message(STATUS "IntelLLVM Compiler is detected but MSVC is also set")
            # cmd-line options might be mixed - suppress warnings
            set(CLANG_FLAGS "${CLANG_FLAGS} \
                -Xclang -Wno-unknown-argument \
                -Wno-unused-command-line-argument"
            )
            # suppress warning in MSVC toolchain header file
            set(CLANG_FLAGS "${CLANG_FLAGS} \
                -Xclang -Wno-delete-non-abstract-non-virtual-dtor"
            )
            # Use precise floating-point model to avoid aggressive optimizations
            set(CLANG_FLAGS "${CLANG_FLAGS} /fp:precise")
        endif ()

        set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${CLANG_FLAGS}")
        set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${CLANG_FLAGS}")

        # Treat warnings as errors if ${REPO_OPTION_PREFIX}_<DEBUG|RELEASE>_WARNINGS_AS_ERRORS is ON
        add_compile_options($<$<OR:$<AND:$<CONFIG:Debug>,$<BOOL:${${REPO_OPTION_PREFIX}_DEBUG_WARNINGS_AS_ERRORS}>>,$<AND:$<NOT:$<CONFIG:Debug>>,$<BOOL:${${REPO_OPTION_PREFIX}_RELEASE_WARNINGS_AS_ERRORS}>>>:-Werror>)
    endif()

    if (${REPO_OPTION_PREFIX}_ENABLE_TESTS)
        message(STATUS "Unit tests are ENABLED")
        enable_testing()
    else()
        message(STATUS "Unit tests are DISABLED")
    endif()

    find_package(Git REQUIRED)
endmacro(opendaq_setup_repo)

macro(opendaq_suppress_ext_lib_warnings)
    if (MSVC AND NOT CMAKE_COMPILER_IS_CLANGXX)
        # As above CMAKE_CXX_STANDARD but for VS
        add_compile_options($<$<COMPILE_LANGUAGE:CXX>:/std:c++17>)

        # suppress warnings
        foreach (flag IN ITEMS
            # loss of data / precision, unsigned <--> signed
            #
            # 'argument' : conversion from 'type1' to 'type2', possible loss of data
            # https://learn.microsoft.com/en-us/cpp/error-messages/compiler-warnings/compiler-warning-level-2-c4244
            /wd4244
            # 'var' : conversion from 'size_t' to 'type', possible loss of data
            # https://learn.microsoft.com/en-us/cpp/error-messages/compiler-warnings/compiler-warning-level-3-c4267
            /wd4267
            # 'identifier' : unreferenced formal parameter
            # https://learn.microsoft.com/en-us/cpp/error-messages/compiler-warnings/compiler-warning-level-4-c4100
            /wd4100
        )
            add_compile_options($<$<COMPILE_LANGUAGE:C,CXX>:${flag}>)
        endforeach()
    endif()

    if (MSVC AND NOT CMAKE_COMPILER_IS_CLANGXX)
        add_compile_options($<$<COMPILE_LANGUAGE:C,CXX>:/WX->)
    else()
        add_compile_options($<$<COMPILE_LANGUAGE:C,CXX>:-Wno-error>)
    endif()
endmacro(opendaq_suppress_ext_lib_warnings)
