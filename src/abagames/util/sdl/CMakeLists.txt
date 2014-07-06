set(util_sdl_srcs
    accelerometer.d
    gamemanager.d
    input.d
    luminous.d
    mainloop.d
    mouse.d
    pad.d
    recordableinput.d
    screen.d
    screen3d.d
    sdlexception.d
    shaderprogram.d
    shape.d
    sound.d
    texture.d
    touch.d
    twinstick.d)

add_library(gr_util_sdl STATIC
    ${util_sdl_srcs})
target_link_libraries(gr_util_sdl
    gr_util
    gr_util_gl
    gl3n
    Derelict::sdl2
    Derelict::util)
set_target_properties(gr_util_sdl
    PROPERTIES
        ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
        LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")
