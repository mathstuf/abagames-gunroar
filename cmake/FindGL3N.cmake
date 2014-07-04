set(components)

find_path("GL3N_INCLUDE_DIR"
    NAMES "gl3n/util.d"
    PATHS "${CMAKE_SYSTEM_ROOT}/include/d"
          "/usr/include/d"
    DOC   "The include directory for GL3N")

find_library("GL3N_LIBRARY"
    NAMES "gl3n"
    PATHS "${CMAKE_SYSTEM_ROOT}/lib"
          "/usr/lib64"
    DOC   "The GL3N library")
if (GL3N_LIBRARY MATCHES "\\${CMAKE_STATIC_LIBRARY_SUFFIX}$")
    set(libtype "STATIC")
else ()
    set(libtype "SHARED")
endif ()

add_library("gl3n" "${libtype}" IMPORTED)
set_property(TARGET "gl3n"
    PROPERTY
        INTERFACE_INCLUDE_DIRECTORIES "${GL3N_INCLUDE_DIR}")
set_property(TARGET "gl3n"
    PROPERTY
        IMPORTED_LOCATION "${GL3N_LIBRARY}")

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(GL3N
    FOUND_VAR GL3N_FOUND
    REQUIRED_VARS GL3N_INCLUDE_DIR GL3N_LIBRARY)
