set(CMAKE_POLICY_VERSION_MINIMUM 3.5)
cmake_minimum_required(VERSION 3.24)

project(opendaq_cmake_utils
    VERSION 1.0.0
    LANGUAGES NONE
)

list(APPEND CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake")

include(SetupUtils)
include(openDAQUtils)
include(DependencyUtils)
include(Resources)
include(BoostUtils)
