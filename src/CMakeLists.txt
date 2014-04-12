set(extra_components)
if (GUNROAR_ANDROID)
    list(APPEND extra_components
        android)
endif ()

find_package(Derelict REQUIRED
    COMPONENTS
        opengl3
        sdl2
        util
        ${extra_components})
include_directories("${CMAKE_CURRENT_SOURCE_DIR}")
add_subdirectory(abagames)

if (GUNROAR_ANDROID)
    add_subdirectory(android)
endif ()
