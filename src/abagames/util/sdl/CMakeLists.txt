set(util_sdl_srcs
    accelerometer.d
    displaylist.d
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
    shape.d
    sound.d
    texture.d
    touch.d
    twinstick.d)

add_library(gr_util_sdl STATIC
    ${util_sdl_srcs})
target_link_libraries(gr_util_sdl
    gr_util
    gl3n
    Derelict::opengl3
    Derelict::sdl2
    Derelict::util)
set_target_properties(gr_util_sdl
    PROPERTIES
        ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
        LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")
