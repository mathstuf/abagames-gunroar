set(components)

list(APPEND components alure)
set(alure_libname ALURE)
set(alure_file alure)

list(APPEND components assimp3)
set(assimp3_libname ASSIMP3)
set(assimp3_file assimp)

list(APPEND components devil)
set(devil_libname IL)
set(devil_file il)

list(APPEND components freeglut)
set(freeglut_libname FG)
set(freeglut_file glut)

list(APPEND components freeimage)
set(freeimage_libname FI)
set(freeimage_file freeimage)

list(APPEND components freetype)
set(freetype_libname FT)
set(freetype_file ft)

list(APPEND components glfw3)
set(glfw3_libname GLFW3)
set(glfw3_file glfw3)

list(APPEND components lua)
set(lua_libname Lua)
set(lua_file lua)

list(APPEND components openal)
set(openal_libname AL)
set(openal_file al)

list(APPEND components ode)
set(ode_libname ODE)
set(ode_file ode)

list(APPEND components opengl3)
set(opengl3_libname GL3)
set(opengl3_file gl)

list(APPEND components ogg)
set(ogg_libname OGG)
set(ogg_file ogg)

list(APPEND components physfs)
set(physfs_libname PHYSFS)
set(physfs_file physfs)

list(APPEND components pq)
set(pq_libname PQ)
set(pq_file pq)

list(APPEND components sdl2)
set(sdl2_libname SDL2)
set(sdl2_file sdl)

list(APPEND components sfml2)
set(sfml2_libname SFML2)
set(sfml2_file system)

list(APPEND components util)
set(util_libname Util)
set(util_file exception)

list(APPEND components vorbis)
set(vorbis_libname Vorbis)
set(vorbis_file vorbis)

find_path("Derelict_INCLUDE_DIR"
    NAMES "derelict/util/exception.d"
    PATHS "${CMAKE_SYSTEM_ROOT}/include/d"
          "/usr/include/d"
    DOC   "The include directory for Derelict")

function (find_derelict_library component)
    list(FIND components "${component}" index)
    if (index EQUAL -1)
        message(FATAL_ERROR "${component} is not a recognized Derelict component")
    endif ()

    find_file(_derelict_sentinel
        NAMES "derelict/${component}/${${component}_file}.d"
        HINTS "${Derelict_INCLUDE_DIR}"
        PATHS "/usr/include/d"
        DOC   "The include path for the Derelict ${component} library")
    if (_derelict_sentinel)
        set("Derelict_${component}_FOUND" TRUE
            PARENT_SCOPE)
    endif ()
    unset(_derelict_sentinel CACHE)

    set(libtype "INTERFACE")
    if (${component}_libname)
        find_library("Derelict_${component}_LIBRARY"
            NAMES "Derelict${${component}_libname}"
            PATHS "${CMAKE_SYSTEM_ROOT}/lib"
                  "/usr/lib64"
            DOC   "The Derelict ${component} library")
        if (Derelict_${component}_LIBRARY MATCHES "\\.${CMAKE_STATIC_LIBRARY_SUFFIX}$")
            set(libtype "STATIC")
        else ()
            set(libtype "SHARED")
        endif ()
    endif ()

    add_library("Derelict::${component}" "${libtype}" IMPORTED)
    set_property(TARGET "Derelict::${component}"
        PROPERTY
            INTERFACE_INCLUDE_DIRECTORIES "${Derelict_INCLUDE_DIR}")
    if (${component}_libname)
        set_property(TARGET "Derelict::${component}"
            PROPERTY
                IMPORTED_LOCATION "${Derelict_${component}_LIBRARY}")
        set_property(TARGET "Derelict::${component}"
            PROPERTY
                IMPORTED_LINK_INTERFACE_LIBRARIES
                                  "${CMAKE_DL_LIBS}")
    endif ()
endfunction ()

if (Derelict_FIND_COMPONENTS)
    foreach (component IN LISTS Derelict_FIND_COMPONENTS)
        find_derelict_library("${component}")
    endforeach ()
endif ()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(Derelict
    FOUND_VAR Derelict_FOUND
    REQUIRED_VARS Derelict_INCLUDE_DIR
    HANDLE_COMPONENTS)
