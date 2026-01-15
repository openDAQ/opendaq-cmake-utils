function(opendaq_append_required_boost_components)
    if(NOT ARGN)
        message(FATAL_ERROR "opendaq_append_required_boost_components() called with no input list")
    endif()

    foreach(COMPONENT_ENTRY IN LISTS ARGN)
        set_property(GLOBAL APPEND PROPERTY OPENDAQ_REQUIRED_BOOST_COMPONENTS ${COMPONENT_ENTRY})
        message(STATUS "Append boost ${COMPONENT_ENTRY} to required components")
    endforeach()
endfunction()

function(opendaq_append_required_boost_headers)
    if(NOT ARGN)
        message(FATAL_ERROR "opendaq_append_required_boost_headers() called with no input list")
    endif()

    foreach(HEADER_ENTRY IN LISTS ARGN)
        set_property(GLOBAL APPEND PROPERTY OPENDAQ_REQUIRED_BOOST_HEADERS ${HEADER_ENTRY})
        message(STATUS "Append boost ${HEADER_ENTRY} to required headers")
    endforeach()
endfunction()

function(opendaq_complete_boost_dependency)
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

    get_property(NEEDED_COMPONENTS GLOBAL PROPERTY OPENDAQ_REQUIRED_BOOST_COMPONENTS)

    list(REMOVE_DUPLICATES NEEDED_COMPONENTS)

    if(NOT DEFINED CACHE{OPENDAQ_BOOST_INITIALIZED})
        foreach(NEEDED_COMPONENT IN LISTS NEEDED_COMPONENTS)
            message(STATUS "Enable boost ${NEEDED_COMPONENT} component")
        endforeach()
    endif()

    set(OPENDAQ_BOOST_INITIALIZED TRUE CACHE INTERNAL "Boost initialized marker")

    set(BOOST_INCLUDE_LIBRARIES "${NEEDED_COMPONENTS}"
        CACHE STRING
        "List of Boost libraries to build"
        FORCE
    )

    set(OPENDAQ_BOOST_REQUIRED_VERSION "1.82.0"
        CACHE STRING
        "Boost version required for openDAQ"
    )

    set(OPENDAQ_BOOST_DOWNLOAD_URL "https://github.com/boostorg/boost/releases/download/boost-1.82.0/boost-1.82.0.tar.xz"
        CACHE STRING
        "Boost archive download URL"
    )

    set(OPENDAQ_BOOST_DOWNLOAD_URL_HASH "SHA256=fd60da30be908eff945735ac7d4d9addc7f7725b1ff6fcdcaede5262d511d21e"
        CACHE STRING
        "Boost archive download URL HASH"
    )

    opendaq_dependency(
        NAME                Boost
        REQUIRED_VERSION    "${OPENDAQ_BOOST_REQUIRED_VERSION}"
        URL                 "${OPENDAQ_BOOST_DOWNLOAD_URL}"
        URL_HASH            "${OPENDAQ_BOOST_DOWNLOAD_URL_HASH}"
        EXPECT_TARGET       Boost::headers
        OVERRIDE_FIND_PACKAGE
    )

    if (Boost_FETCHED)
        message("Boost FETCHED")

        # don't treat warnings as errors
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

        get_property(boost_hdrs_is_set GLOBAL PROPERTY OPENDAQ_REQUIRED_BOOST_HEADERS SET)
        get_property(boost_hdrs GLOBAL PROPERTY OPENDAQ_REQUIRED_BOOST_HEADERS)

        if (boost_hdrs_is_set AND boost_hdrs AND NOT TARGET daq::boost_headers)
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
endfunction()
