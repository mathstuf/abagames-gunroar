find_package(Derelict REQUIRED
    COMPONENTS
        opengl3
        sdl2
        util)
include_directories("${CMAKE_CURRENT_SOURCE_DIR}")
add_subdirectory(abagames)

if (GUNROAR_ANDROID)
    add_subdirectory(android)
endif ()
