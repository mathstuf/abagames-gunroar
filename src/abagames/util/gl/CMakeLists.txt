set(util_gl_srcs
    gl.d)

add_library(gr_util_gl STATIC
    ${util_gl_srcs})
target_link_libraries(gr_util_gl
    Derelict::${gl_impl})
set_target_properties(gr_util_gl
    PROPERTIES
        ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
        LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")
