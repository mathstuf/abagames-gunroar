set(util_sdl_srcs
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
    twinstick.d)

add_library(gr_util_sdl STATIC
    ${util_sdl_srcs})
target_link_libraries(gr_util_sdl
    DerelictGL3
    DerelictSDL2
    DerelictUtil)
