include("${CMAKE_ROOT}/Modules/CMakeDetermineCompiler.cmake")

include("Platform/${CMAKE_SYSTEM_NAME}-D" OPTIONAL)
if (NOT CMAKE_D_COMPILER_NAMES)
    set(CMAKE_D_COMPILER_NAMES dmd)
endif ()

if (NOT CMAKE_D_COMPILER)
    set(CMAKE_D_COMPILER_INIT NOTFOUND)

    if ("$ENV{DC}" MATCHES ".+")
        get_filename_component(CMAKE_D_COMPILER_INIT "$ENV{DC}"
            PROGRAM
            PROGRAM_ARGS
            CMAKE_D_FLAGS_ENV_INIT)
        if (CMAKE_D_FLAGS_ENV_INIT)
            set(CMAKE_D_COMPILER_ARG1 "${CMAKE_D_FLAGS_ENV_INIT}"
                CACHE STRING "First argument to D compiler")
        endif ()
        if (NOT EXISTS CMAKE_D_COMPILER_INIT)
            message(FATAL_ERROR
                "Cound not find compiler set in environment variable DC:\n"
                "$ENV{DC}.")
        endif ()
    endif ()

    if (CMAKE_GENERATOR_DC)
        if (NOT CMAKE_D_COMPILER_INIT)
            set(CMAKE_D_COMPILER_INIT "${CMAKE_GENERATOR_CC}")
        endif ()
    endif ()

    if (NOT CMAKE_D_COMPILER_INIT)
        set(CMAKE_D_COMPILER_LIST ldc2 ldmd2 dmd gdc)
    endif ()

    _cmake_find_compiler(D)
endif ()

mark_as_advanced(CMAKE_D_COMPILER)

if (CMAKE_D_COMPILER MATCHES "dmd")
    set(CMAKE_D_COMPILER_ID "dmd")
elseif (CMAKE_D_COMPILER MATCHES "ldc")
    set(CMAKE_D_COMPILER_ID "ldc")
elseif (CMAKE_D_COMPILER MATCHES "gdc")
    set(CMAKE_D_COMPILER_ID "gdc")
endif ()

if (NOT _CMAKE_TOOLCHAIN_LOCATION)
    get_filename_component(_CMAKE_TOOLCHAIN_LOCATION "${CMAKE_D_COMPILER}" PATH)
endif ()

# TODO: Support cross compiling.

include(CMakeFindBinUtils)
configure_file(
    "${CMAKE_CURRENT_LIST_DIR}/CMakeDCompiler.cmake.in"
    "${CMAKE_PLATFORM_INFO_DIR}/CMakeDCompiler.cmake"
    @ONLY)
set(CMAKE_D_COMPILER_ENV_VAR "DC")
