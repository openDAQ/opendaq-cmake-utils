function(opendaq_set_output_lib_name LIB_NAME MAJOR_VERSION)
    set(TEMP_NAME ${LIB_NAME})

    opendaq_is_64bit_build(BUILD_64Bit) # THIS DOES NOT WORK PROPERLY WITH FORCED 32 bit BUILD
    if (BUILD_64Bit)
        set(TEMP_NAME "${TEMP_NAME}-64")
    else()
        set(TEMP_NAME "${TEMP_NAME}-32")
    endif()
    set(TEMP_NAME "${TEMP_NAME}-${MAJOR_VERSION}")
    set_target_properties(${LIB_NAME} PROPERTIES OUTPUT_NAME ${TEMP_NAME})

    if (WIN32 AND (CMAKE_COMPILER_IS_GNUCXX OR CMAKE_COMPILER_IS_CLANGXX))
        set_target_properties(${LIB_NAME} PROPERTIES PREFIX "")
    endif()
endfunction()

function (opendaq_set_module_properties MODULE_NAME LIB_MAJOR_VERSION)
    set(options "SKIP_INSTALL")
    set(oneValueArgs "")
    set(multiValueArgs "")
    cmake_parse_arguments(OPENDAQ_SET_MODULE_PARAMS "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

	if (NOT DEFINED OPENDAQ_MODULE_SUFFIX)
		set(OPENDAQ_MODULE_SUFFIX ".module${CMAKE_SHARED_LIBRARY_SUFFIX}")
	endif()
	
    set_target_properties(${MODULE_NAME} PROPERTIES SUFFIX ${OPENDAQ_MODULE_SUFFIX})
    target_compile_definitions(${MODULE_NAME} PRIVATE BUILDING_SHARED_LIBRARY
                                                      OPENDAQ_TRACK_SHARED_LIB_OBJECT_COUNT
                                                      OPENDAQ_MODULE_EXPORTS
    )
    opendaq_set_output_lib_name(${MODULE_NAME} ${LIB_MAJOR_VERSION})

    if (NOT ${OPENDAQ_SET_MODULE_PARAMS_SKIP_INSTALL})
        install(TARGETS ${MODULE_NAME}
                RUNTIME
                    DESTINATION ${CMAKE_INSTALL_BINDIR}/modules
                    COMPONENT ${SDK_NAME}_${MODULE_NAME}_Runtime
                LIBRARY
                    DESTINATION ${CMAKE_INSTALL_LIBDIR}/modules
                    COMPONENT          ${SDK_NAME}_${MODULE_NAME}_Runtime
                    NAMELINK_COMPONENT ${SDK_NAME}_${MODULE_NAME}_Development
                ARCHIVE
                    DESTINATION ${CMAKE_INSTALL_LIBDIR}/modules
                    COMPONENT ${SDK_NAME}_${MODULE_NAME}_Development
                PUBLIC_HEADER
                    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/${MODULE_NAME}
                    COMPONENT ${SDK_NAME}_${MODULE_NAME}_Development
        )
    endif()
endfunction()

function(opendaq_is_64bit_build ARGS) # used in main repo does not work properly
    set(BUILD_64Bit Off)

    if("${CMAKE_SIZEOF_VOID_P}" EQUAL 8)
        set(BUILD_64Bit On)
    endif()

    if (UNIX AND CMAKE_SYSTEM_PROCESSOR MATCHES "^aarch64$")  # arm architecture 64bit
        set(BUILD_64Bit On)
    endif()

    set(${ARGS} ${BUILD_64Bit} PARENT_SCOPE)
endfunction()

function(opendaq_prepend_path PATH FILES)
  foreach(SOURCE_FILE ${${FILES}})
    set(MODIFIED ${MODIFIED} "${PATH}/${SOURCE_FILE}")
  endforeach()

  set(${FILES} ${MODIFIED} PARENT_SCOPE)
endfunction()

function(opendaq_get_current_folder_name OUTFOLDER)
    get_filename_component(FOLDER ${CMAKE_CURRENT_SOURCE_DIR} NAME)
    set(${OUTFOLDER} ${FOLDER} PARENT_SCOPE)
endfunction()

function(set_cmake_folder_context OUTFOLDER)
    get_current_folder_name(TARGET_FOLDER_NAME)

    if (ARGC GREATER 1)
        list(APPEND CMAKE_MESSAGE_CONTEXT ${ARGV1})
    else()
        list(APPEND CMAKE_MESSAGE_CONTEXT ${TARGET_FOLDER_NAME})
    endif()

    set(CMAKE_MESSAGE_CONTEXT ${CMAKE_MESSAGE_CONTEXT} PARENT_SCOPE)
    if (ARGC GREATER 1)
        set(CMAKE_FOLDER "${CMAKE_FOLDER}/${ARGV1}" PARENT_SCOPE)
    else()
        set(CMAKE_FOLDER "${CMAKE_FOLDER}/${TARGET_FOLDER_NAME}" PARENT_SCOPE)
    endif()
    set(${OUTFOLDER} ${TARGET_FOLDER_NAME} PARENT_SCOPE)
endfunction()

function(opendaq_prepend_include SUBFOLDER SOURCE_FILES)
    list(TRANSFORM ${SOURCE_FILES} PREPEND "../include/${SUBFOLDER}/")
    set( ${SOURCE_FILES} ${${SOURCE_FILES}} PARENT_SCOPE )
endfunction()

function(opendaq_create_version_header LIB_NAME OUTPUT_DIR HEADER_PREFIX GENERATE_RC GENERATE_HEADER)
    set(TEMPLATE_DIR ${CMAKE_CURRENT_FUNCTION_LIST_DIR}/version)

    if (GENERATE_HEADER)
        set(VERSION_HEADER ${OUTPUT_DIR}/${HEADER_PREFIX}version.h)

        string(TOUPPER ${LIB_NAME} UPPERCASE_LIB_NAME)
        configure_file(${TEMPLATE_DIR}/version.h.in ${VERSION_HEADER})
    endif()

    if (WIN32 AND GENERATE_RC)
        set(VERSION_RC ${OUTPUT_DIR}/version.rc)

        get_target_property(TARGET_SUFFIX ${LIB_NAME} SUFFIX)
        get_target_property(ORIGINAL_OUTPUT_NAME ${LIB_NAME} OUTPUT_NAME)

        if (TARGET_SUFFIX)
            set(LIB_TARGET_TYPE ${TARGET_SUFFIX})
        else()
            get_target_property(TARGET_TYPE ${LIB_NAME} TYPE)
            if (TARGET_TYPE STREQUAL "EXECUTABLE")
                set(LIB_TARGET_TYPE ${CMAKE_EXECUTABLE_SUFFIX})
            elseif (TARGET_TYPE STREQUAL "STATIC_LIBRARY")
                set(LIB_TARGET_TYPE ${CMAKE_STATIC_LIBRARY_SUFFIX})
            else()
                set(LIB_TARGET_TYPE ${CMAKE_SHARED_LIBRARY_SUFFIX})
            endif()
        endif()

        configure_file(${TEMPLATE_DIR}/version.rc.in ${VERSION_RC})
    endif()

    target_sources(${LIB_NAME} PRIVATE ${VERSION_HEADER} ${VERSION_RC})
endfunction()

function(create_version_header LIB_NAME)
    set(INCLUDE_FOLDER_NAME ${TARGET_FOLDER_NAME})

    set(options ONLY_RC NO_RC)
    set(oneValueArgs INCLUDE_FOLDER HEADER_NAME_PREFIX)
    set(multiValueArgs VARIANTS)
    cmake_parse_arguments(GENERATE_VERSION "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    set(INCLUDE_FOLDER_NAME ${TARGET_FOLDER_NAME})
    if (DEFINED GENERATE_VERSION_INCLUDE_FOLDER)
        set(INCLUDE_FOLDER_NAME ${GENERATE_VERSION_INCLUDE_FOLDER})
        set(HEADER_NAME_PREFIX "${TARGET_FOLDER_NAME}_")
    endif()

    if (DEFINED GENERATE_VERSION_HEADER_NAME_PREFIX)
        set(HEADER_NAME_PREFIX ${GENERATE_VERSION_HEADER_NAME_PREFIX})
    endif()
    string(STRIP "${HEADER_NAME_PREFIX}" HEADER_NAME_PREFIX)

    set(GENERATE_HEADER ON)

    if (NOT MSVC)
        set(GENERATE_RC OFF)
    else()
        set(GENERATE_RC ON)
    endif()

    if (GENERATE_VERSION_NO_RC)
        set(GENERATE_RC OFF)
    endif()

    if (GENERATE_VERSION_ONLY_RC)
        set(GENERATE_HEADER OFF)
    endif()

    set(LIB_HEADERS_DIR ../include/${INCLUDE_FOLDER_NAME})

    opendaq_create_version_header(
        ${LIB_NAME}
        ${CMAKE_CURRENT_BINARY_DIR}/${LIB_HEADERS_DIR}
        "${HEADER_NAME_PREFIX}"
        ${GENERATE_RC}
        ${GENERATE_HEADER}
    )
endfunction()

function(use_compiler_cache)
    if((NOT CMAKE_CURRENT_SOURCE_DIR STREQUAL CMAKE_SOURCE_DIR) OR (NOT OPENDAQ_USE_CCACHE))
        return()
    endif()

    find_program(CCACHE_PROGRAM ccache)
    if(NOT CCACHE_PROGRAM)
        message(STATUS "CCache not found!")
        return()
    endif()

    set(ccacheEnv
        CCACHE_BASEDIR=${CMAKE_SOURCE_DIR}
        CCACHE_CPP2=true
        CCACHE_SLOPPINESS=pch_defines,time_macros
    )

    if(CMAKE_GENERATOR MATCHES "Ninja|Makefiles")
#    if(CMAKE_GENERATOR MATCHES "Ninja|Makefiles|Visual Studio")
#      - currently only Ninja / Makefiles supports MSVC
        message(STATUS "Using CCache: ${CCACHE_PROGRAM}")

        foreach(lang IN ITEMS C CXX OBJC OBJCXX CUDA)
            set(CMAKE_${lang}_COMPILER_LAUNCHER
                ${CMAKE_COMMAND} -E env ${ccacheEnv} ${CCACHE_PROGRAM}
                PARENT_SCOPE
            )
        endforeach()
    elseif(CMAKE_GENERATOR STREQUAL Xcode)
        message(STATUS "Using CCache with XCode: ${CCACHE_PROGRAM}")

        foreach(lang IN ITEMS C CXX)
            set(launch${lang} ${CMAKE_BINARY_DIR}/launch-${lang})
            file(WRITE ${launch${lang}} "#!/bin/bash\n\n")

            foreach(keyVal IN LISTS ccacheEnv)
                file(APPEND ${launch${lang}} "export ${keyVal}\n")
            endforeach()

            file(APPEND ${launch${lang}}
                "exec \"${CCACHE_PROGRAM}\" \"${CMAKE_${lang}_COMPILER}\" \"$@\"\n")

            execute_process(COMMAND chmod a+rx ${launch${lang}})
        endforeach()

        set(CMAKE_XCODE_ATTRIBUTE_CC ${launchC} PARENT_SCOPE)
        set(CMAKE_XCODE_ATTRIBUTE_CXX ${launchCXX} PARENT_SCOPE)
        set(CMAKE_XCODE_ATTRIBUTE_LD ${launchC} PARENT_SCOPE)
        set(CMAKE_XCODE_ATTRIBUTE_LDPLUSPLUS ${launchCXX} PARENT_SCOPE)
    endif()
endfunction()
