##
## Run by cpack on every invocation (CPACK_PROJECT_CONFIG_FILE), the only moment that knows
## which package is being produced. Names it and rewrites the `package` section of the
## metadata; the rest of the document comes from the configure step untouched.
##
##     cpack --preset ... -D CPACK_OPENDAQ_META_PACKAGE_NAME=opendaq-modules
##
## Without the -D the package keeps the name from the configure step.
##
## A project with a config file of its own keeps the slot and includes this one:
##
##     include("${CPACK_OPENDAQ_PROJECT_CONFIG}")
##

include("${CPACK_OPENDAQ_UTILS_MODULE}")

opendaq_detect_package()
opendaq_compose_package_file_name()

opendaq_write_metadata(OUTPUT "${CPACK_PACKAGE_DIRECTORY}/staging-meta.json")
