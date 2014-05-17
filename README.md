Gunroar
=======

A modernization of [gunroar][gunroar] so that it works with recent versions of
its dependencies (OpenGL, SDL). Instead of the custom code originally used, the
[Derelict][derelict] project is used instead.

Building
========

Building this port requires a patched CMake with D support. The branch I am
using is on [my Github fork of CMake][cmake-d].

Android
=======

Building for Android requires building a patched NDK toolchain with GDC
support. LDC support has not been attempted.

To build a custom toolchain, get a [patched GDC][gdc-android] (only 4.8
supported at the moment), the [Android NDK][ndk] (only r9d has been tested so
far), and an [NDK toolchain build environment][ndk-build].

Once the toolchain sources have been downloaded, patch the GCC using GDC's
`setup-gcc.sh` script. Then edit the NDK's `build-gcc.sh` script to add
`--enable-languages=d` to the configure flags. Currently, `android-13` is the
target for the Android build, so that should be the targeted platform when
building the toolchain.

One change that I've needed to make for D support is to change the `ld` linker
to point to `ld.bfd` instead of `ld.gold` due to `__data_start` being undefined
otherwise (it looks like a linker script is not executed when using `ld.gold`,
but only with GDC; GCC is fine).

Once the toolchain is built, build all of the required Derelict libraries
(Util, SDL2, and GL3) configure a CMake build using a `CMAKE_TOOLCHAIN_FILE`
argument pointing to a CMake script setting the compiler, linker, archiver,
etc. just built above. An example file is provided in the repository as
`src/android/toolchain.cmake` which just needs a few variables set. SDL and
SDL\_mixer will be downloaded and built using the NDK.

[gunroar]: http://www.asahi-net.or.jp/~cs8k-cyu/windows/gr_e.html
[derelict]: https://github.com/DerelictOrg
[cmake-d]: https://github.com/mathstuf/CMake/tree/d_support
[gdc-android]: https://github.com/mathstuf/GDC/tree/android/gdc-4.8
[ndk]: https://developer.android.com/tools/sdk/ndk/index.html
[ndk-build]: http://recursify.com/blog/2013/08/08/building-an-android-ndk-toolchain
