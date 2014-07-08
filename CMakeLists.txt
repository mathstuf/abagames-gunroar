cmake_minimum_required(VERSION 2.8.12)
list(APPEND CMAKE_MODULE_PATH
    "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

set(rc_lang)
if (WIN32)
    set(rc_lang RC)
endif ()

project(gunroar D ${rc_lang})

set(CMAKE_D_FLAGS
    "${CMAKE_D_FLAGS} -Wall")

option(GUNROAR_ANDROID "Build for Android" OFF)
if (GUNROAR_ANDROID)
    if (NOT CMAKE_D_COMPILER_ID STREQUAL "GNU")
        message(FATAL_ERROR "Only GDC is supported for Android builds")
    endif ()
endif ()

include(CMakeDependentOption)
cmake_dependent_option(GUNROAR_INSTALL "Whether to build an installable Gunroar or not" OFF
    "NOT GUNROAR_ANDROID" OFF)
if (GUNROAR_INSTALL)
    set(CMAKE_D_FLAGS
        "${CMAKE_D_FLAGS} ${CMAKE_D_VERSION_FLAG}GunroarInstall")
endif ()

get_filename_component(CMAKE_SYSTEM_ROOT "${CMAKE_D_COMPILER}" DIRECTORY)
get_filename_component(CMAKE_SYSTEM_ROOT "${CMAKE_SYSTEM_ROOT}" DIRECTORY)

include_directories(SYSTEM "${CMAKE_SYSTEM_ROOT}/include/d")

add_subdirectory(src)

if (WIN32)
    set(asset_suffix "")
else ()
    set(asset_suffix "/gunroar")
endif ()

install(
    DIRECTORY   "images" "sounds"
    DESTINATION "share${asset_suffix}"
    COMPONENT   runtime)

if (WIN32)
    # Nothing needed for the icon.
elseif (UNIX)
    install(
        FILES       "resource/gunroar.desktop"
        DESTINATION "share/applications"
        COMPONENT   runtime)
    install(
        FILES       "resource/gunroar.png"
        DESTINATION "share/icons/locolor/128x128"
        COMPONENT   runtime)
endif ()
