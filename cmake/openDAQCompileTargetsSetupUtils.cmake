macro(opendaq_setup_gnu_and_clang_common_flags REPO_OPTION_PREFIX)
    if (UNIX)
        # hide all symbols expect those specifically exported with PUBLIC_EXPORT macro
        if (APPLE)
          # not possible on Mac, should be done per library
        else()
          set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -Wl,--exclude-libs,ALL")
        endif()
        set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fvisibility=hidden -fvisibility-inlines-hidden")
        set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fvisibility=hidden")
    endif()

    if (NOT MSVC)
        if (NOT WIN32)
            set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -pthread")
        endif()

        if(OPENDAQ_FORCE_COMPILE_32BIT)
            set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -m32")
            set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -m32")
            set(CMAKE_ASM_FLAGS "${CMAKE_ASM_FLAGS} -m32")

            # Linux GCC (and clang?) 32-bit specific flags
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

    # Treat warnings as errors if ${REPO_OPTION_PREFIX}_<DEBUG|RELEASE>_WARNINGS_AS_ERRORS is ON
    add_compile_options($<$<AND:$<OR:$<AND:$<CONFIG:Debug>,$<BOOL:${${REPO_OPTION_PREFIX}_DEBUG_WARNINGS_AS_ERRORS}>>,$<AND:$<NOT:$<CONFIG:Debug>>,$<BOOL:${${REPO_OPTION_PREFIX}_RELEASE_WARNINGS_AS_ERRORS}>>>,$<COMPILE_LANGUAGE:C,CXX>>:-Werror>)
endmacro()

macro(opendaq_setup_gnu_compiler_flags REPO_OPTION_PREFIX)
    opendaq_setup_gnu_and_clang_common_flags(${REPO_OPTION_PREFIX})

    set(GCC_W_NO_EXTRA "-Wno-comment -Wno-unused-parameter -Wno-missing-field-initializers")
    set(GCC_W_NO_WALL "-Wno-unknown-pragmas -Wno-parentheses -Wno-misleading-indentation -Wno-unused-variable -Wno-switch -Wno-maybe-uninitialized -Wno-psabi")
    set(GCC_CHARSET_FLAGS "-fexec-charset=UTF-8 -finput-charset=UTF-8")
    #set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -pedantic -Wall -Wextra ${GCC_W_NO_EXTRA} ${GCC_W_NO_WALL} ${GCC_W_NO_PEDANTIC} -Werror=return-type")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Wextra ${GCC_W_NO_EXTRA} ${GCC_W_NO_WALL} ${GCC_W_NO_PEDANTIC} -Werror=return-type ${GCC_CHARSET_FLAGS}")

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
    
    if (OPENDAQ_FORCE_LLD_LINKER)
        set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fuse-ld=lld")
    endif()
endmacro()

macro(opendaq_setup_msvc_compiler_flags REPO_OPTION_PREFIX)
    if (NOT CMAKE_COMPILER_IS_CLANGXX)
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

        if (NOT OPENDAQ_MSVC_SINGLE_PROCESS_BUILD)
            # Build with multiple processes
            # https://learn.microsoft.com/en-us/cpp/build/reference/mp-build-with-multiple-processes
            add_compile_options($<$<COMPILE_LANGUAGE:C,CXX>:/MP>)
        endif()

        # Treat warnings as errors if OPENDAQ_<DEBUG|RELEASE>_WARNINGS_AS_ERRORS is ON
        add_compile_options($<$<AND:$<OR:$<AND:$<CONFIG:Debug>,$<BOOL:${${REPO_OPTION_PREFIX}_DEBUG_WARNINGS_AS_ERRORS}>>,$<AND:$<NOT:$<CONFIG:Debug>>,$<BOOL:${${REPO_OPTION_PREFIX}_RELEASE_WARNINGS_AS_ERRORS}>>>,$<COMPILE_LANGUAGE:C,CXX>>:/WX>)

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

    set(FLEX_FLAGS "--wincompat")
endmacro()

macro(opendaq_setup_clang_compiler_flags REPO_OPTION_PREFIX)
    opendaq_setup_gnu_and_clang_common_flags(${REPO_OPTION_PREFIX})

    # MinGW Clang does not support TLS so try emulating it
    if (MINGW)
        add_compile_options(-femulated-tls)
    endif()

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
endmacro()

macro(opendaq_setup_compiler_flags REPO_OPTION_PREFIX)
    if(OPENDAQ_LINK_RUNTIME_STATICALLY)
        opendaq_set_runtime(STATIC)
    endif()

    if (CMAKE_COMPILER_IS_GNUCXX)
        opendaq_setup_gnu_compiler_flags(${REPO_OPTION_PREFIX})
    endif()

    if (MSVC)
        opendaq_setup_msvc_compiler_flags(${REPO_OPTION_PREFIX})
    endif()

    if (CMAKE_COMPILER_IS_CLANGXX)
        opendaq_setup_clang_compiler_flags(${REPO_OPTION_PREFIX})
    endif()
endmacro()

macro(opendaq_ignore_compiler_warnings)
    if (MSVC AND NOT CMAKE_COMPILER_IS_CLANGXX)
        add_compile_options($<$<COMPILE_LANGUAGE:C,CXX>:/WX->)
    else()
        add_compile_options($<$<COMPILE_LANGUAGE:C,CXX>:-Wno-error>)
    endif()
endmacro()

# Sets common cmake variables that affect openDAQ SDK or openDAQ module targets build process
# Should be included by any openDAQ root-level project (openDAQ SDK itself or openDAQ module) to apply settings to all underlying compile targets
macro(opendaq_common_compile_targets_settings)
    if (NOT DEFINED PROJECT_SOURCE_DIR)
        message(FATAL_ERROR "Must be run inside a cmake project")
    endif()
    
    # Clang compiler manual detection
    if (CMAKE_CXX_COMPILER_ID MATCHES "^(Clang|IntelLLVM)$")
        set(CMAKE_COMPILER_IS_CLANGXX On CACHE INTERNAL "Compiler is LLVM")
        message(STATUS "Compiler is LLVM")
    endif()
    
    if (UNIX AND CMAKE_SYSTEM_PROCESSOR MATCHES "^arm.*$")  #e.g. armv7l
        set(BUILD_ARM On CACHE INTERNAL "Build for ARM architecture")
    endif()

    if (UNIX AND CMAKE_SYSTEM_PROCESSOR MATCHES "^aarch.*$")  #e.g. aarch64
        set(BUILD_ARM On CACHE INTERNAL "Build for ARM architecture")
    endif()
    
    opendaq_is_64bit_build(BUILD_64Bit)
    set(BUILD_64Bit ${BUILD_64Bit} CACHE INTERNAL "Build in 64-bit mode")

    if(BUILD_64Bit OR BUILD_ARM)
        set(OPENDAQ_FPIC On CACHE INTERNAL "Set Position independent code flag")
        set(CMAKE_POSITION_INDEPENDENT_CODE ON)
    else()
        set(OPENDAQ_FPIC Off CACHE INTERNAL "Set Position independent code flag")
    endif()
    message(STATUS "Setting -fPIC to ${OPENDAQ_FPIC}")
    
    # module suffix
    if (NOT DEFINED OPENDAQ_MODULE_SUFFIX)
        set(OPENDAQ_MODULE_SUFFIX ".module${CMAKE_SHARED_LIBRARY_SUFFIX}")
    endif()
    if (NOT DEFINED CACHE{OPENDAQ_MODULE_SUFFIX})
        set(OPENDAQ_MODULE_SUFFIX ${OPENDAQ_MODULE_SUFFIX} CACHE INTERNAL "Default DLL/SO extension")
    endif()
    message(STATUS "Default Module extension: ${OPENDAQ_MODULE_SUFFIX}")
    add_compile_definitions(OPENDAQ_MODULE_SUFFIX="${OPENDAQ_MODULE_SUFFIX}")

    include(CheckCompilerFlag)
    include(CheckLinkerFlag)

    set(CMAKE_INSTALL_DEBUG_LIBRARIES ON)
    include(InstallRequiredSystemLibraries)

    include(GNUInstallDirs)
    file(RELATIVE_PATH RPATH_DIR
        ${CMAKE_CURRENT_BINARY_DIR}/${CMAKE_INSTALL_BINDIR}
        ${CMAKE_CURRENT_BINARY_DIR}/${CMAKE_INSTALL_LIBDIR}
    )
    if(APPLE)
        set(LIB_LOAD_ORIGIN @loader_path)
    else()
        set(LIB_LOAD_ORIGIN $ORIGIN)
    endif()
    # allow CMAKE_INSTALL_RPATH to be cleared from the command line
    if (NOT DEFINED CMAKE_INSTALL_RPATH)
        set(CMAKE_INSTALL_RPATH ${LIB_LOAD_ORIGIN} ${LIB_LOAD_ORIGIN}/${RPATH_DIR})
    endif()

    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
    set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
    
    if(NOT CMAKE_DEBUG_POSTFIX AND NOT OPENDAQ_DISABLE_DEBUG_POSTFIX)
        set(CMAKE_DEBUG_POSTFIX -debug)
    endif()

    set(CMAKE_CXX_STANDARD 17)

    if (WIN32)
        set(MIN_WINDOWS_VERSION 0x0601)
        add_compile_definitions(NOMINMAX
                                _WIN32_WINNT=${MIN_WINDOWS_VERSION} # Windows 7 Compat
        )
        add_compile_definitions(UNICODE _UNICODE)
        add_compile_definitions(WIN32_LEAN_AND_MEAN)
    endif()

    set(THREADS_PREFER_PTHREAD_FLAG ON)
    find_package(Threads REQUIRED)  

    opendaq_use_compiler_cache()

    find_package(Git REQUIRED)
endmacro()
