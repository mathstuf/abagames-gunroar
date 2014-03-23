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

add_subdirectory(sdl)
