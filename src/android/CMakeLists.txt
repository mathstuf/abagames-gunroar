include(ExternalProject)

externalproject_add(SDL
    GIT_REPOSITORY    hg::http://hg.libsdl.org/SDL
    GIT_TAG           master
    SOURCE_DIR        "${CMAKE_CURRENT_SOURCE_DIR}/jni/SDL"
    CONFIGURE_COMMAND ""
    BUILD_COMMAND     ""
    INSTALL_COMMAND   "")
externalproject_add(SDL_mixer
    GIT_REPOSITORY    hg::http://hg.libsdl.org/SDL_mixer
    GIT_TAG           master
    SOURCE_DIR        "${CMAKE_CURRENT_SOURCE_DIR}/jni/SDL_mixer"
    CONFIGURE_COMMAND ""
    BUILD_COMMAND     ""
    INSTALL_COMMAND   "")

get_filename_component(Derelict_LIBRARY_PATH "${Derelict_util_PATH}" DIRECTORY)
set(gunroar_LIBRARY_PATH "${CMAKE_BINARY_DIR}/lib")

configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/jni/src/Android.mk.in"
    "${CMAKE_CURRENT_SOURCE_DIR}/jni/src/Android.mk"
    @ONLY)
configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/ant.properties.in"
    "${CMAKE_CURRENT_SOURCE_DIR}/ant.properties"
    @ONLY)
