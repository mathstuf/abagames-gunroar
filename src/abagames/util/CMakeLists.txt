set(util_srcs
    actor.d
    iterator.d
    logger.d
    math.d
    prefmanager.d
    rand.d
    tokenizer.d
    vector.d)

add_library(gr_util STATIC
    ${util_srcs})
set_target_properties(gr_util
    PROPERTIES
        ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
        LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")

add_subdirectory(sdl)
