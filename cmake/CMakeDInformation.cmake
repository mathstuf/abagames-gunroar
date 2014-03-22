if (UNIX)
    set(CMAKE_D_OUTPUT_EXTENSION ".o")
else ()
    set(CMAKE_D_OUTPUT_EXTENSION ".obj")
endif ()

set(_INCLUDED_FILE 0)

if (CMAKE_D_COMPILER_ID)
    include("Compiler/${CMAKE_D_COMPILER_D}-D" OPTIONAL)
endif ()

set(CMAKE_BASE_NAME)
get_filename_component(CMAKE_BASE_NAME "${CMAKE_D_COMPILER}" NAME_WE)

# load a hardware specific file, mostly useful for embedded compilers
if (CMAKE_SYSTEM_PROCESSOR)
    if(CMAKE_D_COMPILER_ID)
        include("Platform/${CMAKE_SYSTEM_NAME}-${CMAKE_D_COMPILER_ID}-C-${CMAKE_SYSTEM_PROCESSOR}" OPTIONAL
            RESULT_VARIABLE _INCLUDED_FILE)
    endif ()
    if (NOT _INCLUDED_FILE)
        include("Platform/${CMAKE_SYSTEM_NAME}-${CMAKE_BASE_NAME}-${CMAKE_SYSTEM_PROCESSOR}" OPTIONAL)
    endif ()
endif ()

if (CMAKE_D_COMPILER_ID)
    include("Platform/${CMAKE_SYSTEM_NAME}-${CMAKE_D_COMPILER_ID}-D" OPTIONAL
        RESULT_VARIABLE _INCLUDED_FILE)
endif()
if (NOT _INCLUDED_FILE)
    include("Platform/${CMAKE_SYSTEM_NAME}-${CMAKE_BASE_NAME}" OPTIONAL
        RESULT_VARIABLE _INCLUDED_FILE)
endif ()

if (NOT _INCLUDED_FILE)
    include("Platform/${CMAKE_SYSTEM_NAME}" OPTIONAL)
endif ()

if (CMAKE_D_SIZEOF_DATA_PTR)
    foreach (f IN LISTS CMAKE_D_ABI_FILES)
        include(${f})
    endforeach ()
    unset(CMAKE_D_ABI_FILES)
endif ()

# This should be included before the _INIT variables are
# used to initialize the cache.  Since the rule variables
# have if blocks on them, users can still define them here.
# But, it should still be after the platform file so changes can
# be made to those values.

if (CMAKE_USER_MAKE_RULES_OVERRIDE)
  # Save the full path of the file so try_compile can use it.
  include("${CMAKE_USER_MAKE_RULES_OVERRIDE}"
      RESULT_VARIABLE _override)
  set(CMAKE_USER_MAKE_RULES_OVERRIDE "${_override}")
endif ()

if (CMAKE_USER_MAKE_RULES_OVERRIDE_D)
  # Save the full path of the file so try_compile can use it.
  include("${CMAKE_USER_MAKE_RULES_OVERRIDE_D}"
      RESULT_VARIABLE _override)
  set(CMAKE_USER_MAKE_RULES_OVERRIDE_D "${_override}")
endif ()

# for most systems a module is the same as a shared library
# so unless the variable CMAKE_MODULE_EXISTS is set just
# copy the values from the LIBRARY variables
if (NOT CMAKE_MODULE_EXISTS)
    set(CMAKE_SHARED_MODULE_D_FLAGS ${CMAKE_SHARED_LIBRARY_D_FLAGS})
    set(CMAKE_SHARED_MODULE_CREATE_D_FLAGS ${CMAKE_SHARED_LIBRARY_CREATE_D_FLAGS})
endif ()

set(CMAKE_D_FLAGS_INIT "$ENV{DFLAGS} ${CMAKE_D_FLAGS_INIT}")
# avoid just having a space as the initial value for the cache
if (CMAKE_D_FLAGS_INIT STREQUAL " ")
    set(CMAKE_D_FLAGS_INIT)
endif ()
set (CMAKE_D_FLAGS "${CMAKE_D_FLAGS_INIT}"
    CACHE STRING "Flags used by the compiler during all build types.")

if (NOT CMAKE_NOT_USING_CONFIG_FLAGS)
    # default build type is none
    if (NOT CMAKE_NO_BUILD_TYPE)
        set(CMAKE_BUILD_TYPE "${CMAKE_BUILD_TYPE_INIT}"
            CACHE STRING "Choose the type of build, options are: None (CMAKE_D_FLAGS used) Debug Release RelWithDebInfo MinSizeRel.")
    endif ()
    set(CMAKE_D_FLAGS_DEBUG "${CMAKE_D_FLAGS_DEBUG_INIT}"
        CACHE STRING "Flags used by the compiler during debug builds.")
    set(CMAKE_D_FLAGS_MINSIZEREL "${CMAKE_D_FLAGS_MINSIZEREL_INIT}"
        CACHE STRING "Flags used by the compiler during release builds for minimum size.")
    set(CMAKE_D_FLAGS_RELEASE "${CMAKE_D_FLAGS_RELEASE_INIT}"
        CACHE STRING "Flags used by the compiler during release builds.")
    set(CMAKE_D_FLAGS_RELWITHDEBINFO "${CMAKE_D_FLAGS_RELWITHDEBINFO_INIT}"
        CACHE STRING "Flags used by the compiler during release builds with debug info.")
endif ()

if (CMAKE_D_STANDARD_LIBRARIES_INIT)
    set(CMAKE_D_STANDARD_LIBRARIES "${CMAKE_D_STANDARD_LIBRARIES_INIT}"
        CACHE STRING "Libraries linked by default with all D applications.")
    mark_as_advanced(CMAKE_D_STANDARD_LIBRARIES)
endif()

include(CMakeCommonLanguageInclude)

# now define the following rule variables

# CMAKE_D_CREATE_SHARED_LIBRARY
# CMAKE_D_CREATE_SHARED_MODULE
# CMAKE_D_COMPILE_OBJECT
# CMAKE_D_LINK_EXECUTABLE

# variables supplied by the generator at use time
# <TARGET>
# <TARGET_BASE> the target without the suffix
# <OBJECTS>
# <OBJECT>
# <LINK_LIBRARIES>
# <FLAGS>
# <LINK_FLAGS>

# C compiler information
# <CMAKE_D_COMPILER>
# <CMAKE_SHARED_LIBRARY_CREATE_D_FLAGS>
# <CMAKE_SHARED_MODULE_CREATE_D_FLAGS>
# <CMAKE_D_LINK_FLAGS>

# Static library tools
# <CMAKE_AR>
# <CMAKE_RANLIB>

# create a C shared library
if (NOT CMAKE_D_CREATE_SHARED_LIBRARY)
    set(CMAKE_D_CREATE_SHARED_LIBRARY
        "<CMAKE_D_COMPILER> <CMAKE_SHARED_LIBRARY_D_FLAGS> <LANGUAGE_COMPILE_FLAGS> <LINK_FLAGS> <CMAKE_SHARED_LIBRARY_CREATE_D_FLAGS> <SONAME_FLAG><TARGET_SONAME> -of=<TARGET> <OBJECTS> <LINK_LIBRARIES>")
endif ()

# create a C shared module just copy the shared library rule
if (NOT CMAKE_D_CREATE_SHARED_MODULE)
    set(CMAKE_D_CREATE_SHARED_MODULE ${CMAKE_D_CREATE_SHARED_LIBRARY})
endif ()

# Create a static archive incrementally for large object file counts.
# If CMAKE_D_CREATE_STATIC_LIBRARY is set it will override these.
if (NOT DEFINED CMAKE_D_ARCHIVE_CREATE)
    set(CMAKE_D_ARCHIVE_CREATE "<CMAKE_AR> cr <TARGET> <LINK_FLAGS> <OBJECTS>")
endif ()
if (NOT DEFINED CMAKE_D_ARCHIVE_APPEND)
    set(CMAKE_D_ARCHIVE_APPEND "<CMAKE_AR> r <TARGET> <LINK_FLAGS> <OBJECTS>")
endif ()
if (NOT DEFINED CMAKE_D_ARCHIVE_FINISH)
    set(CMAKE_D_ARCHIVE_FINISH "<CMAKE_RANLIB> <TARGET>")
endif ()

# compile a C file into an object file
if (NOT CMAKE_D_COMPILE_OBJECT)
    set(CMAKE_D_COMPILE_OBJECT
        "<CMAKE_D_COMPILER> <DEFINES> <FLAGS> -of=<OBJECT> -c <SOURCE>")
endif ()

if (NOT CMAKE_D_LINK_EXECUTABLE)
    set(CMAKE_D_LINK_EXECUTABLE
        "<CMAKE_D_COMPILER> <FLAGS> <CMAKE_D_LINK_FLAGS> <LINK_FLAGS> <OBJECTS> -of=<TARGET> <LINK_LIBRARIES>")
endif ()

if (NOT CMAKE_EXECUTABLE_RUNTIME_D_FLAG)
    set(CMAKE_EXECUTABLE_RUNTIME_D_FLAG ${CMAKE_SHARED_LIBRARY_RUNTIME_D_FLAG})
endif ()

if (NOT CMAKE_EXECUTABLE_RUNTIME_D_FLAG_SEP)
    set(CMAKE_EXECUTABLE_RUNTIME_D_FLAG_SEP ${CMAKE_SHARED_LIBRARY_RUNTIME_D_FLAG_SEP})
endif ()

if (NOT CMAKE_EXECUTABLE_RPATH_LINK_D_FLAG)
    set(CMAKE_EXECUTABLE_RPATH_LINK_D_FLAG ${CMAKE_SHARED_LIBRARY_RPATH_LINK_D_FLAG})
endif ()

mark_as_advanced(
    CMAKE_D_FLAGS
    CMAKE_D_FLAGS_DEBUG
    CMAKE_D_FLAGS_MINSIZEREL
    CMAKE_D_FLAGS_RELEASE
    CMAKE_D_FLAGS_RELWITHDEBINFO)
set(CMAKE_D_INFORMATION_LOADED 1)
