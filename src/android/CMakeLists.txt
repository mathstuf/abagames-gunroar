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
find_program(ADB_COMMAND
    NAMES adb
    DOC   "Path to the adb command")

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

add_custom_target(android-ndk ALL
    DEPENDS
        SDL
        SDL_mixer
        android-libs)
add_custom_command(
    TARGET  android-ndk
    COMMAND $<$<CONFIG:Debug>:NDK_DEBUG=1>
            "${NDK_BUILD_COMMAND}"
    WORKING_DIRECTORY
            "${CMAKE_CURRENT_SOURCE_DIR}/jni"
    COMMENT "Building the APK")

add_custom_target(android-res ALL)
add_custom_command(
    TARGET  android-res
    COMMAND "${CMAKE_COMMAND}" -E make_directory
            "${CMAKE_CURRENT_SOURCE_DIR}/assets"
    COMMAND "${CMAKE_COMMAND}" -E make_directory
            "${CMAKE_CURRENT_SOURCE_DIR}/assets/replay"
    COMMAND "${CMAKE_COMMAND}" -E create_symlink
            "${CMAKE_SOURCE_DIR}/sounds"
            "${CMAKE_CURRENT_SOURCE_DIR}/assets/sounds"
    COMMAND "${CMAKE_COMMAND}" -E create_symlink
            "${CMAKE_SOURCE_DIR}/images"
            "${CMAKE_CURRENT_SOURCE_DIR}/assets/images"
    COMMENT "Linking resources")

set(buildtype "$<$<CONFIG:Debug>:debug>$<$<NOT:$<CONFIG:Debug>>:release>")

add_custom_target(android-apk
    DEPENDS
        android-libs
        android-ndk
        android-res)
add_custom_command(
    TARGET  android-apk
    COMMAND "${ANT_COMMAND}" "${buildtype}"
    WORKING_DIRECTORY
            "${CMAKE_CURRENT_SOURCE_DIR}"
    COMMENT "Building the APK")

add_custom_target(android ALL
    DEPENDS
        android-apk)

add_custom_target(android-install
    DEPENDS
        android)
add_custom_command(
    TARGET  android-install
    COMMAND "${ADB_COMMAND}" install
            -r
            "${CMAKE_BINARY_DIR}/android/gunroar-${buildtype}.apk"
    COMMENT "Installing the APK")
