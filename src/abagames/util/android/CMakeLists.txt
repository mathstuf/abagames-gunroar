set(util_android_srcs
    assets.d
    storage.d)

add_library(gr_util_android STATIC
    ${util_android_srcs})
target_link_libraries(gr_util_android
    Derelict::android)
set_target_properties(gr_util_android
    PROPERTIES
        ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
        LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")
