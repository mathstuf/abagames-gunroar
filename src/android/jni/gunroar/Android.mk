LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

LOCAL_MODULE := derelict_util
LOCAL_SRC_FILES := libDerelictUtil.a

include $(PREBUILT_STATIC_LIBRARY)

include $(CLEAR_VARS)

LOCAL_MODULE := derelict_opengl3
LOCAL_SRC_FILES := libDerelictGL3.a

include $(PREBUILT_STATIC_LIBRARY)

include $(CLEAR_VARS)

LOCAL_MODULE := derelict_sdl2
LOCAL_SRC_FILES := libDerelictSDL2.a

include $(PREBUILT_STATIC_LIBRARY)

include $(CLEAR_VARS)

LOCAL_MODULE := gunroar_util
LOCAL_SRC_FILES := libgr_util.a

include $(PREBUILT_STATIC_LIBRARY)

include $(CLEAR_VARS)

LOCAL_MODULE := gunroar_util_sdl
LOCAL_SRC_FILES := libgr_util_sdl.a

include $(PREBUILT_STATIC_LIBRARY)

include $(CLEAR_VARS)

LOCAL_MODULE := gunroar
LOCAL_SRC_FILES := libgr.a

include $(PREBUILT_STATIC_LIBRARY)

include $(CLEAR_VARS)

LOCAL_MODULE := gunroar_main
LOCAL_SRC_FILES := libgr_main.a

include $(PREBUILT_STATIC_LIBRARY)
