macro(opendaq_try_add_subdirectory DIR)
    if(IS_DIRECTORY "${CMAKE_CURRENT_LIST_DIR}/${DIR}" AND EXISTS "${CMAKE_CURRENT_LIST_DIR}/${DIR}/CMakeLists.txt")
        add_subdirectory("${DIR}")
    endif()
endmacro(opendaq_try_add_subdirectory)

macro(opendaq_setup_module_project REPO_OPTION_PREFIX REPO_NAME)
    opendaq_setup_repo_version("${REPO_OPTION_PREFIX}" ${REPO_NAME} "module_version")

    if(NOT DEFINED ${REPO_OPTION_PREFIX}_VERSION)
        if(DEFINED OPENDAQ_PACKAGE_VERSION)
            set(${REPO_OPTION_PREFIX}_VERSION ${OPENDAQ_PACKAGE_VERSION})
            message(WARNING "Module version was not specified - will use openDAQ version instead: ${OPENDAQ_PACKAGE_VERSION}")
        else()
            message(FATAL_ERROR "Module project version was not specified and openDAQ version is unknown - specify module version using -D${${REPO_OPTION_PREFIX}_VERSION} or via module_version file in module project root dir")
        endif()
    endif()

    project(${REPO_NAME} VERSION ${${REPO_OPTION_PREFIX}_VERSION} LANGUAGES CXX)

    opendaq_setup_build_mode(${REPO_OPTION_PREFIX} ${REPO_NAME})
    if(NOT ${REPO_OPTION_PREFIX}_BUILDING_AS_SUBMODULE)
        opendaq_setup_repo(${REPO_OPTION_PREFIX})
    endif()

    if(EXISTS "${CMAKE_CURRENT_LIST_DIR}/cmake/ModuleOptions.cmake")
        include(${CMAKE_CURRENT_LIST_DIR}/cmake/ModuleOptions.cmake)
    endif()

    if (NOT DEFINED OPENDAQ_SDK_NAME)
        set(OPENDAQ_SDK_NAME openDAQ)
    endif()

    if (NOT DEFINED OPENDAQ_SDK_TARGET_NAME)
        set(OPENDAQ_SDK_TARGET_NAME opendaq)
    endif()

    if (NOT DEFINED OPENDAQ_SDK_TARGET_NAMESPACE)
        set(OPENDAQ_SDK_TARGET_NAMESPACE daq)
    endif()
endmacro(opendaq_setup_module_project)

macro(opendaq_setup_module_subfolders REPO_OPTION_PREFIX)
    add_subdirectory(external)
    opendaq_try_add_subdirectory(shared)
    add_subdirectory(modules)

    if (OPENDAQ_ENABLE_TESTS AND ${REPO_OPTION_PREFIX}_BUILDING_AS_SUBMODULE OR ${REPO_OPTION_PREFIX}_ENABLE_TESTS AND NOT ${REPO_OPTION_PREFIX}_BUILDING_AS_SUBMODULE)
        opendaq_try_add_subdirectory(tests)
    endif()
    if (${REPO_OPTION_PREFIX}_ENABLE_EXAMPLE_APP)
        opendaq_try_add_subdirectory(examples)
    endif()
    opendaq_try_add_subdirectory(docs)
endmacro(opendaq_setup_module_subfolders)

macro(opendaq_setup_module_default_dependencies REPO_OPTION_PREFIX)
    if (NOT ${REPO_OPTION_PREFIX}_BUILDING_AS_SUBMODULE)
        set(OPENDAQ_REF "main")

        set(OPENDAQ_REF_FILE "${CMAKE_CURRENT_LIST_DIR}/opendaq_ref")
        if (EXISTS "${OPENDAQ_REF_FILE}")
            file(READ "${OPENDAQ_REF_FILE}" FILE_CONTENT)
            string(STRIP "${FILE_CONTENT}" FILE_CONTENT)
            if (FILE_CONTENT)
                set(OPENDAQ_REF "${FILE_CONTENT}")
            endif()
        endif()

        opendaq_resolve_sdk_dependency("${OPENDAQ_REF}")
    endif()

    opendaq_suppress_ext_lib_warnings()

    if (NOT ${REPO_OPTION_PREFIX}_BUILDING_AS_SUBMODULE AND ${REPO_OPTION_PREFIX}_ENABLE_TESTS)
        if (NOT TARGET gtest)
            set(GTest_REQUIREDVERSION "1.12.1")

            find_package(GTest GLOBAL ${GTest_REQUIREDVERSION})
            if(GTest_FOUND)
                message(STATUS "Found GTest: ${GTest_VERSION} ${GTest_CONFIG}")
            else()
                message(STATUS "Fetching GTest version ${GTest_REQUIREDVERSION}")

                include(FetchContent)
                opendaq_get_custom_fetch_content_params(GTest FC_PARAMS)

                set(GTest_WITH_POST_BUILD_UNITTEST OFF)
                set(GTest_WITH_TESTS OFF)

                set(BUILD_GMOCK OFF)
                set(INSTALL_GTEST OFF)
                set(gtest_force_shared_crt ON)
                FetchContent_Declare(
                    GTest
                    URL https://github.com/google/googletest/archive/release-${GTest_REQUIREDVERSION}.zip
                    URL_HASH SHA256=24564e3b712d3eb30ac9a85d92f7d720f60cc0173730ac166f27dda7fed76cb2
                    ${FC_PARAMS}
                )
                FetchContent_MakeAvailable(GTest)
            endif()
        endif()
    endif()

    if (NOT ${REPO_OPTION_PREFIX}_BUILDING_AS_SUBMODULE)
        if (EXISTS "Boost.cmake")
            include(Boost.cmake)
            opendaq_setup_boost()
        elif (NOT openDAQ_FOUND)
            opendaq_setup_boost()
        endif()
    endif()
endmacro(opendaq_setup_module_default_dependencies)

macro(opendaq_resolve_sdk_dependency VERSION)
    include(FetchContent)
    find_package(openDAQ $(VERSION} GLOBAL)
    if (NOT openDAQ_FOUND)
        set(OPENDAQ_ENABLE_TESTS OFF CACHE BOOL "" FORCE)

        FetchContent_Declare(
            openDAQ
            GIT_REPOSITORY https://github.com/openDAQ/openDAQ.git
            GIT_TAG ${VERSION}
            GIT_PROGRESS   ON
            SOURCE_DIR ${FETCHCONTENT_EXTERNALS_DIR}/src/openDAQ
        )
        FetchContent_MakeAvailable(openDAQ)
    else()
        message(STATUS "Found installed openDAQ version: ${openDAQ_VERSION}")
        set(OPENDAQ_PACKAGE_VERSION "${openDAQ_VERSION}")
    endif()
endmacro()
