####################################################################################################
# This function converts any file into C/C++ source code.
# Example:
# - input file: data.dat
# - output file: data.h
# - variable name declared in output file: DATA
# - data length: sizeof(DATA)
# opendaq_embed_resource("data.dat" "data.h" "DATA")
####################################################################################################

function(opendaq_embed_resource resource_file_name source_file_name variable_name)

    if(EXISTS "${source_file_name}")
        if("${source_file_name}" IS_NEWER_THAN "${resource_file_name}")
            return()
        endif()
    endif()

    file(READ "${resource_file_name}" hex_content HEX)

    string(REPEAT "[0-9a-f]" 32 pattern)
    string(REGEX REPLACE "(${pattern})" "\\1\n" content "${hex_content}")

    string(REGEX REPLACE "([0-9a-f][0-9a-f])" "0x\\1, " content "${content}")

    string(REGEX REPLACE ", $" "" content "${content}")

    set(array_definition "static const unsigned char ${variable_name}[] =\n{\n${content}\n};")

    set(source "// Auto generated file.\n${array_definition}\n")

    file(WRITE "${source_file_name}" "${source}")

endfunction()

function(opendaq_read_file_contents FILE_PATH OUT_FILE_CONTENTS)
    if (NOT EXISTS "${FILE_PATH}")
        message(FATAL_ERROR "Cannot read file contents: file ${FILE_PATH} not found")
    endif()

    file(READ "${FILE_PATH}" _FILE_CONTENTS)
    string(STRIP "${_FILE_CONTENTS}" _FILE_CONTENTS)

    if (_FILE_CONTENTS STREQUAL "")
        message(WARNING "File is empty: ${FILE_PATH}")
    endif()

    set(${OUT_FILE_CONTENTS} "${_FILE_CONTENTS}" PARENT_SCOPE)
endfunction()

function(opendaq_get_version_major_minor_patch VERSION_STRING OUT_VERSION_MAJOR_MINOR_PATCH)
    string(REGEX REPLACE "^([0-9]+\\.[0-9]+\\.[0-9]+).*" "\\1" _VERSION_MAJOR_MINOR_PATCH "${VERSION_STRING}")
    set(${OUT_VERSION_MAJOR_MINOR_PATCH} "${_VERSION_MAJOR_MINOR_PATCH}" PARENT_SCOPE)
endfunction()
