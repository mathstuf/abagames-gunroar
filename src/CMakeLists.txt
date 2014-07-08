set(gl_impl opengl3)
if (GUNROAR_ANDROID)
    set(gl_impl gles)
endif ()

find_package(GL3N REQUIRED)
find_package(Derelict REQUIRED
    COMPONENTS
        ${gl_impl}
        sdl2
        util)
include_directories("${CMAKE_CURRENT_SOURCE_DIR}")
include_directories("${CMAKE_CURRENT_BINARY_DIR}")
add_subdirectory(abagames)

if (GUNROAR_ANDROID)
    add_subdirectory(android)
endif ()
