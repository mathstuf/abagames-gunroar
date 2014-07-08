configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/paths.d.in"
    "${CMAKE_CURRENT_BINARY_DIR}/paths.d"
    @ONLY)

set(util_support_srcs
    gl.d
    "${CMAKE_CURRENT_BINARY_DIR}/paths.d")

add_library(gr_util_support STATIC
    ${util_support_srcs})
target_link_libraries(gr_util_support
    Derelict::${gl_impl})
if (GUNROAR_ANDROID)
    target_link_libraries(gr_util_support
        Derelict::sdl2)
endif ()
set_target_properties(gr_util_support
    PROPERTIES
        ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
        LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")
