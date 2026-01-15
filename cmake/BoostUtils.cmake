function(opendaq_add_required_boost_libs)
    if(NOT ARGN)
        message(FATAL_ERROR "opendaq_add_required_boost_libs() called with no input list of libraries")
    endif()

    foreach(lib IN LISTS ARGN)
        set_property(GLOBAL APPEND PROPERTY BOOST_REQUIRED_LIBS ${lib})
    endforeach()
endfunction(opendaq_add_required_boost_libs)

function(opendaq_add_required_boost_headers)
    if(NOT ARGN)
        message(FATAL_ERROR "opendaq_add_required_boost_headers() called with no input list of headers")
    endif()

    foreach(hdr IN LISTS ARGN)
        set_property(GLOBAL APPEND PROPERTY BOOST_REQUIRED_HEADERS ${hdr})
    endforeach()
endfunction(opendaq_add_required_boost_headers)

function(opendaq_setup_boost)
    # fallback to defaults if options are not defined e.g. when building with installed opendaq
    if (NOT DEFINED OPENDAQ_LINK_3RD_PARTY_LIBS_STATICALY)
        set(OPENDAQ_LINK_3RD_PARTY_LIBS_STATICALY ON)
    endif()

    if (NOT DEFINED OPENDAQ_LINK_RUNTIME_STATICALLY)
        set(OPENDAQ_LINK_RUNTIME_STATICALLY OFF)
    endif()

    if (OPENDAQ_LINK_3RD_PARTY_LIBS_STATICALY)
        set(BUILD_SHARED_LIBS OFF)
        set(Boost_USE_STATIC_LIBS ON CACHE BOOL "")
        message(STATUS "Linking Boost statically")
    else()
        set(BUILD_SHARED_LIBS ON)
        set(Boost_USE_STATIC_LIBS OFF CACHE BOOL "")
        message(STATUS "Linking Boost dynamically")
    endif()

    set(Boost_USE_MULTITHREADED ON)
    set(Boost_USE_STATIC_RUNTIME ${OPENDAQ_LINK_RUNTIME_STATICALLY})
    set(Boost_NO_WARN_NEW_VERSIONS ON)

    if (OPENDAQ_LINK_RUNTIME_STATICALLY)
        set(BOOST_RUNTIME_LINK static)
    else()
        set(BOOST_RUNTIME_LINK shared)
    endif()

    if (BUILD_ARM)
        if (BUILD_64Bit)
            set(CONTEXT_ARCHITECTURE arm64)
        else()
            set(CONTEXT_ARCHITECTURE arm)
        endif()

        message(STATUS "CMAKE_COMPILER_IS_GNUCXX: ${CMAKE_COMPILER_IS_GNUCXX}")

        if (CMAKE_COMPILER_IS_GNUCXX)
            # Need C++ compiler to pre-process ASM files
            set(CMAKE_ASM_COMPILER ${CMAKE_CXX_COMPILER})
            set(CMAKE_ASM_FLAGS "-x assembler-with-cpp" CACHE STRING "")
        endif()

        set(BOOST_CONTEXT_ABI aapcs CACHE STRING "Boost.Context binary format (elf, mach-o, pe, xcoff)")
        set(BOOST_CONTEXT_ARCHITECTURE ${CONTEXT_ARCHITECTURE} CACHE STRING "Boost.Context architecture (arm, arm64, loongarch64, mips32, mips64, ppc32, ppc64, riscv64, s390x, i386, x86_64, combined)")
    endif()

    if (NOT BOOST_INCLUDE_LIBRARIES)
        get_property(NEEDED_LIBRARIES GLOBAL PROPERTY BOOST_REQUIRED_LIBS)
        list(REMOVE_DUPLICATES NEEDED_LIBRARIES)

        set(BOOST_INCLUDE_LIBRARIES "${NEEDED_LIBRARIES}"
            CACHE STRING
            "List of libraries to build (default: all but excluded and incompatible)"
        )
    endif()

    opendaq_dependency(
        NAME                Boost
        REQUIRED_VERSION    1.71.0
        URL                 https://github.com/boostorg/boost/releases/download/boost-1.82.0/boost-1.82.0.tar.xz
        URL_HASH            SHA256=fd60da30be908eff945735ac7d4d9addc7f7725b1ff6fcdcaede5262d511d21e
        EXPECT_TARGET       Boost::headers
        OVERRIDE_FIND_PACKAGE
    )

    if (Boost_FETCHED)
        message("Boost FETCHED")

        # dont treat warnings as errors
        set(BOOST_TARGETS
            boost_container
            boost_thread
        )
        foreach(BOOST_TARGET ${BOOST_TARGETS})
            if (TARGET ${BOOST_TARGET})
                if(CMAKE_CXX_COMPILER_ID MATCHES "MSVC")
                    target_compile_options(${BOOST_TARGET} PRIVATE /WX-)
                else()
                    target_compile_options(${BOOST_TARGET} PRIVATE -Wno-error)
                endif()
            endif()
        endforeach()

        get_property(boost_hdrs_set GLOBAL PROPERTY BOOST_REQUIRED_HEADERS SET)
        get_property(boost_hdrs GLOBAL PROPERTY BOOST_REQUIRED_HEADERS)

        if (boost_hdrs_set AND boost_hdrs)
            list(REMOVE_DUPLICATES boost_hdrs)
            add_library(daq::boost_headers INTERFACE IMPORTED GLOBAL)
            foreach(boost_hdr ${boost_hdrs})
                if (TARGET Boost::${boost_hdr})
                    get_target_property(include_dirs Boost::${boost_hdr} INTERFACE_INCLUDE_DIRECTORIES)
                    target_include_directories(daq::boost_headers INTERFACE "${include_dirs}")
                endif()
            endforeach()
        endif()
    endif()

    if (Boost_FOUND)
        foreach(BOOST_TARGET ${BOOST_INCLUDE_LIBRARIES})
            if (NOT TARGET Boost::${BOOST_TARGET} AND NOT TARGET boost_${BOOST_TARGET})
                add_library(Boost::${BOOST_TARGET} ALIAS Boost::headers)
            endif()
        endforeach()
    endif()
endfunction(opendaq_setup_boost)
