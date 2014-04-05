cmake_minimum_required(VERSION 2.8.12)
list(APPEND CMAKE_MODULE_PATH
    "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

project(gunroar D)

# TODO: Remove this once androideabi builds are available.
option(GUNROAR_ANDROID "Build for Android" OFF)
if (GUNROAR_ANDROID)
    # FIXME: Currently only good for GDC.
    set(CMAKE_D_FLAGS
        "${CMAKE_D_FLAGS} -fversion=ABAGames_Android")
endif ()

get_filename_component(CMAKE_SYSTEM_ROOT "${CMAKE_D_COMPILER}" DIRECTORY)
get_filename_component(CMAKE_SYSTEM_ROOT "${CMAKE_SYSTEM_ROOT}" DIRECTORY)

include_directories(SYSTEM "${CMAKE_SYSTEM_ROOT}/include/d")

add_subdirectory(src)
