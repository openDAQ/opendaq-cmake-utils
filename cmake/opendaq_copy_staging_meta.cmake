# CPack post-build hook: copy the staging metadata next to the package(s) cpack
# just built, i.e. into CPACK_PACKAGE_DIRECTORY. Registered by opendaq_write_staging_meta().
if(DEFINED CPACK_OPENDAQ_STAGING_META_FILE AND EXISTS "${CPACK_OPENDAQ_STAGING_META_FILE}")
    file(COPY "${CPACK_OPENDAQ_STAGING_META_FILE}" DESTINATION "${CPACK_PACKAGE_DIRECTORY}")
endif()
