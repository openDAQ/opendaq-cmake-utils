include_guard(GLOBAL)

function(opendaq_set_cmake_mode MODE)
    if (NOT (MODE STREQUAL "MODERN" OR MODE STREQUAL "ANCIENT"))
        message(FATAL_ERROR "opendaq_set_cmake_mode() called with invalid mode \"${MODE}\"."
            " Use opendaq_set_cmake_mode(MODERN) or opendaq_set_cmake_mode(ANCIENT).")
    endif()
    set_property(GLOBAL PROPERTY ALLOW_BANNED_FUNCTIONS ${MODE})
endfunction()

function(opendaq_get_cmake_mode MODE)
    get_property(CMAKE_MODE GLOBAL PROPERTY ALLOW_BANNED_FUNCTIONS)
    set(${MODE} ${CMAKE_MODE} PARENT_SCOPE)
endfunction()

function(_opendaq_require_mode REQUIRED_MODE CALLER_FUNC_NAME)
    get_property(mode GLOBAL PROPERTY ALLOW_BANNED_FUNCTIONS)
    if (mode STREQUAL REQUIRED_MODE)
        return()
    endif()

    set(msg "${CALLER_FUNC_NAME}() requires \"${REQUIRED_MODE}\" mode. Current mode is \"${mode}\".")
    if (CALLER_FUNC_NAME STREQUAL "include_directories")
        string(APPEND msg " Use target_include_directories() instead.")
    elseif (CALLER_FUNC_NAME STREQUAL "add_definitions")
        string(APPEND msg " Use target_compile_definitions() or target_compile_options() instead.")
    elseif (CALLER_FUNC_NAME STREQUAL "link_directories")
        string(APPEND msg " Use target_link_directories() instead.")
    endif()

    message(FATAL_ERROR "${msg}")
endfunction()

function(include_directories)
    _opendaq_require_mode(ANCIENT ${CMAKE_CURRENT_FUNCTION})
    _include_directories(${ARGN})
endfunction()

function(add_definitions)
    _opendaq_require_mode(ANCIENT ${CMAKE_CURRENT_FUNCTION})
    _add_definitions(${ARGN})
endfunction()

function(link_directories)
    _opendaq_require_mode(ANCIENT ${CMAKE_CURRENT_FUNCTION})
    _link_directories(${ARGN})
endfunction()
