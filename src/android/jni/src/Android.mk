LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

LOCAL_MODULE := main

SDL_PATH := ../SDL
SDL_MIXER_PATH := ../SDL_mixer

LOCAL_C_INCLUDES := $(SDL_PATH)/include $(SDL_MIXER_PATH)/include

LOCAL_SRC_FILES := SDL_android_main.c

LOCAL_SHARED_LIBRARIES := SDL2 SDL2_mixer gunroar_main

LOCAL_LDLIBS := -lGLESv1_CM -lGLESv2

include $(BUILD_SHARED_LIBRARY)
