LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

LOCAL_MODULE := main

SDL_PATH := ../SDL

LOCAL_C_INCLUDES       := $(SDL_PATH)/include
LOCAL_SRC_FILES        := SDL_android_main.c
LOCAL_SHARED_LIBRARIES := SDL2 SDL2_mixer gunroar_main

include $(BUILD_SHARED_LIBRARY)
