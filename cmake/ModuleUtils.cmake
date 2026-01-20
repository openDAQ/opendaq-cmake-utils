macro(try_add_subdirectory DIR)
    if(IS_DIRECTORY "${DIR}" AND EXISTS "${DIR}/CMakeLists.txt")
        add_subdirectory("${DIR}")
    endif()
endmacro(try_add_subdirectory)

macro(setup_module_project REPO_OPTION_PREFIX REPO_NAME)
    setup_repo_version("${REPO_OPTION_PREFIX}" ${REPO_NAME} "module_version")

    if (NOT DEFINED ${REPO_OPTION_PREFIX}_VERSION AND DEFINED OPENDAQ_PACKAGE_VERSION)
        set(${REPO_OPTION_PREFIX}_VERSION ${OPENDAQ_PACKAGE_VERSION})
    endif()

    project(${REPO_NAME} VERSION ${${REPO_OPTION_PREFIX}_VERSION} LANGUAGES CXX)

    setup_build_mode(${REPO_OPTION_PREFIX} ${REPO_NAME})
    if (NOT ${REPO_OPTION_PREFIX}_BUILDING_AS_SUBMODULE)
        setup_repo(${REPO_OPTION_PREFIX})
    endif()

    include(cmake/ModuleOptions.cmake)

    if (NOT DEFINED OPENDAQ_SDK_NAME)
        set(OPENDAQ_SDK_NAME openDAQ)
    endif()

    if (NOT DEFINED OPENDAQ_SDK_TARGET_NAME)
        set(OPENDAQ_SDK_TARGET_NAME opendaq)
    endif()

    if (NOT DEFINED OPENDAQ_SDK_TARGET_NAMESPACE)
        set(OPENDAQ_SDK_TARGET_NAMESPACE daq)
    endif()
endmacro(setup_module_project)

macro(setup_module_subfolders REPO_OPTION_PREFIX)
    try_add_add_subdirectory(external)
    try_add_subdirectory(shared)
    add_subdirectory(modules)

    if (${REPO_OPTION_PREFIX}_BUILDING_AS_SUBMODULE AND OPENDAQ_ENABLE_TESTS OR ${REPO_OPTION_PREFIX}_ENABLE_TESTS)
        try_add_add_subdirectory(tests)
    endif()
    if (${REPO_OPTION_PREFIX}_ENABLE_EXAMPLE_APP)
        try_add_add_subdirectory(examples)
    endif()
    try_add_add_subdirectory(docs)
endmacro(setup_module_subfolders)

macro(setup_module_boost_dependencies REPO_OPTION_PREFIX)
    if (NOT ${REPO_OPTION_PREFIX}_BUILDING_AS_SUBMODULE)
        include(boost.cmake)
        opendaq_setup_boost()
    endif()
endmacro(setup_module_boost_dependencies)
