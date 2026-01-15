# set SDK identity values
set(OPENDAQ_SDK_NAME "openDAQ" CACHE INTERNAL "openDAQ SDK project name")
set(OPENDAQ_SDK_TARGET_NAME "opendaq" CACHE INTERNAL "openDAQ SDK target library name")
set(OPENDAQ_SDK_TARGET_NAMESPACE "daq" CACHE INTERNAL "openDAQ SDK namespace")

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

include(openDAQBaseUtils)
include(openDAQEarlySetupUtils)
include(openDAQCompileTargetsSetupUtils)
include(openDAQBuildOptionsUtils)
include(openDAQDependencyUtils)
include(openDAQResourcesUtils)
include(openDAQBoostLibraryUtils)
include(openDAQModuleUtils)

opendaq_read_file_contents("${CMAKE_CURRENT_LIST_DIR}/version" OPENDAQ_CMAKE_UTILS_VERSION)
message(STATUS "openDAQ cmake utilities version ${OPENDAQ_CMAKE_UTILS_VERSION}")
