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
    Derelict::opengl3
    Derelict::sdl2
    Derelict::util)
