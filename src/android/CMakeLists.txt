include(ExternalProject)

find_program(PATCH_COMMAND
    NAMES patch
    DOC   "Path to the patch command")

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
                      # Turns off THUMB support since third-party libraries
                      # don't support it.
                      # https://bugzilla.libsdl.org/show_bug.cgi?id=2491
    PATCH_COMMAND     "${PATCH_COMMAND}" -p1 -n < "${CMAKE_CURRENT_SOURCE_DIR}/src/jni/SDL_mixer-arm.patch"
                      # Makes third-party libraries actually optional.
                      # Currently they require a patch (such as this); with
                      # this, Application.mk can override the defaults instead.
                      # https://bugzilla.libsdl.org/show_bug.cgi?id=2490
                   && "${PATCH_COMMAND}" -p1 -n < "${CMAKE_CURRENT_SOURCE_DIR}/src/jni/SDL_mixer-options.patch"
    CONFIGURE_COMMAND ""
    BUILD_COMMAND     ""
    INSTALL_COMMAND   "")

get_filename_component(Derelict_LIBRARY_PATH "${Derelict_util_PATH}" DIRECTORY)
set(gunroar_LIBRARY_PATH "${CMAKE_BINARY_DIR}/lib")

configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/ant.properties.in"
    "${CMAKE_CURRENT_SOURCE_DIR}/ant.properties"
    @ONLY)

find_program(NDK_BUILD_COMMAND
    NAMES ndk-build
    DOC   "Path to the ndk-build command")
find_program(ANT_COMMAND
    NAMES ant
    DOC   "Path to the ant command")

add_custom_target(android-ndk ALL
    DEPENDS
        SDL
        SDL_mixer)
add_custom_command(
    TARGET  android-ndk
    COMMAND "${NDK_BUILD_COMMAND}"
    WORKING_DIRECTORY
            "${CMAKE_CURRENT_SOURCE_DIR}/jni"
    COMMENT "Building the APK")

configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/android_install.cmake.in"
    "${CMAKE_BINARY_DIR}/android_install.cmake.genex"
    @ONLY)
file(GENERATE
    OUTPUT "${CMAKE_BINARY_DIR}/android_install.cmake"
    INPUT  "${CMAKE_BINARY_DIR}/android_install.cmake.genex")
add_custom_target(android-libs
    DEPENDS
        gr_main)
add_custom_command(
    TARGET  android-libs
    COMMAND "${CMAKE_COMMAND}"
            -P "${CMAKE_BINARY_DIR}/android_install.cmake"
    COMMENT "Installing libraries for the NDK")

add_custom_target(android-res ALL)
add_custom_command(
    TARGET  android-res
    COMMAND ${CMAKE_COMMAND} -E make_directory
            "${CMAKE_CURRENT_SOURCE_DIR}/assets"
    COMMAND ${CMAKE_COMMAND} -E make_directory
            "${CMAKE_CURRENT_SOURCE_DIR}/assets/replay"
    COMMAND ${CMAKE_COMMAND} -E create_symlink
            "${CMAKE_SOURCE_DIR}/sounds"
            "${CMAKE_CURRENT_SOURCE_DIR}/assets/sounds"
    COMMAND ${CMAKE_COMMAND} -E create_symlink
            "${CMAKE_SOURCE_DIR}/images"
            "${CMAKE_CURRENT_SOURCE_DIR}/assets/images"
    COMMENT "Linking resources")

set(buildtype $<$<CONFIG:Debug>:debug>$<$<NOT:$<CONFIG:Debug>>:release>)

add_custom_target(android-apk
    DEPENDS
        android-libs
        android-ndk
        android-res)
add_custom_command(
    TARGET  android-apk
    COMMAND "${ANT_COMMAND}" ${buildtype}
    WORKING_DIRECTORY
            "${CMAKE_CURRENT_SOURCE_DIR}"
    COMMENT "Building the APK")

add_custom_target(android ALL
    DEPENDS
        android-apk)
