add_subdirectory(sdl)

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
target_link_libraries(gr_util
    gr_util_sdl)
