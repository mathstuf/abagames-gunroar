set(gr_srcs
    bullet.d
    CMakeLists.txt
    crystal.d
    enemy.d
    field.d
    gamemanager.d
    letter.d
    mouse.d
    mouseandpad.d
    particle.d
    prefmanager.d
    reel.d
    replay.d
    screen.d
    shape.d
    ship.d
    shot.d
    soundmanager.d
    stagemanager.d
    title.d
    turret.d)

add_library(gr STATIC
    ${gr_srcs})
target_link_libraries(gr
    gr_util
    gr_util_sdl
    Derelict::opengl3
    Derelict::sdl2
    Derelict::util)

add_executable(gunroar
    boot.d)
target_link_libraries(gunroar
    gr
    gr_util
    gr_util_sdl)
