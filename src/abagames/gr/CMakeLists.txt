set(gr_srcs
    accelerometerandtouch.d
    bullet.d
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
    shaders.d
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
    gr_util_support
    gl3n
    Derelict::sdl2
    Derelict::util)
set_target_properties(gr
    PROPERTIES
        ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
        LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")

if (GUNROAR_ANDROID)
    find_library(ANDROID_LOG_LIBRARY
        NAMES log)
    add_library(gr_main SHARED
        boot.d)
    target_link_libraries(gr_main
        gr
        gr_util
        gr_util_sdl
        ${ANDROID_LOG_LIBRARY})
    set_target_properties(gr_main
        PROPERTIES
            ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
            LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
            RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")
else ()
    set(resource_files)
    if (WIN32)
        list(APPEND resource_files
            "${CMAKE_SOURCE_DIR}/resource/gunroar.def"
            "${CMAKE_SOURCE_DIR}/resource/gunroar.rc"
            "${CMAKE_SOURCE_DIR}/resource/gunroar.RES")
    endif ()
    add_executable(gunroar
        boot.d
        ${resource_files})
    target_link_libraries(gunroar
        gr
        gr_util
        gr_util_sdl)
    set_target_properties(gunroar
        PROPERTIES
            ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
            LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
            RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")
    install(
        TARGETS     gunroar
        DESTINATION bin
        COMPONENT   runtime)
endif ()
