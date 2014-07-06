set(CMAKE_SYSTEM_NAME Android)
set(CMAKE_CROSSCOMPILING 1)

########################################################################
# Fill these variables in for your system.
########################################################################
set(ndkdir "NDK_DIR-NOTFOUND")
set(host "linux-x86_64")

set(android_target 13)
set(target "arm-linux-androideabi")
set(toolchain "${target}-4.9")

set(basedir "${ndkdir}/toolchains/${toolchain}/prebuilt/${host}")

set(CMAKE_D_COMPILER "${basedir}/bin/${target}-gdc")
set(CMAKE_AR "${basedir}/bin/${target}-ar"
    CACHE "" FILEPATH)
set(CMAKE_NM "${basedir}/bin/${target}-nm"
    CACHE "" FILEPATH)
set(CMAKE_OBJCOPY "${basedir}/bin/${target}-objcopy"
    CACHE "" FILEPATH)
set(CMAKE_OBJDUMP "${basedir}/bin/${target}-objdump"
    CACHE "" FILEPATH)
set(CMAKE_RANLIB "${basedir}/bin/${target}-ranlib"
    CACHE "" FILEPATH)

set(CMAKE_FIND_ROOT_PATH "${ndkdir}/platforms/android-${android_target}/arch-arm")

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
