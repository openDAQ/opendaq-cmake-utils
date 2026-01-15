# Allows to define project specific cmake options that customize openDAQ SDK or module project build process  

# Included just ones by the first project fetching opendaq-cmake-utils, usually openDAQ SDK itself or openDAQ module
include_guard(GLOBAL)

macro(opendaq_setup_project_specific_build_options REPO_OPTION_PREFIX)
    option(${REPO_OPTION_PREFIX}_DEBUG_WARNINGS_AS_ERRORS "Treat debug warnings as errors" OFF)
    option(${REPO_OPTION_PREFIX}_RELEASE_WARNINGS_AS_ERRORS "Treat release warnings as errors" ON)
endmacro()

macro(opendaq_setup_common_build_options)
    # Compiler independent cmake options
    option(OPENDAQ_DISABLE_DEBUG_POSTFIX "Disable debug ('-debug') postfix" OFF)
    option(OPENDAQ_ALWAYS_FETCH_DEPENDENCIES "Ignore any installed libraries and always build all dependencies from source" ON)
    option(OPENDAQ_USE_CCACHE "Use compiler cache driver if available" ON)

    # Runtime and default 3rd party library linking options
    option(OPENDAQ_LINK_RUNTIME_STATICALLY "Link the C++ runtime staticaly (embedd it)" OFF)
    option(OPENDAQ_LINK_3RD_PARTY_LIBS_STATICALY "Link the 3rd party libraries staticaly (embedd it)" ON)

    # Compiler dependent cmake options
    if (NOT MSVC)
        option(OPENDAQ_FORCE_COMPILE_32BIT "Compile 32Bit on non MSVC" OFF)
    endif()

    if (MSVC)
        option(OPENDAQ_MSVC_SINGLE_PROCESS_BUILD "Do not include /MP compile option." OFF)
    endif()

    if ((CMAKE_COMPILER_IS_GNUCXX OR CMAKE_COMPILER_IS_CLANGXX) AND NOT MSVC)
        option(OPENDAQ_FORCE_LLD_LINKER "Force the use of the fast LLVM LLD linker" OFF)
    endif()

    if (OPENDAQ_FORCE_LLD_LINKER)
        message(STATUS "Forcing the use of LLVM LLD linker. Make sure it is installed and available.")
    endif()
endmacro()
