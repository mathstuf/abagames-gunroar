LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

LOCAL_MODULE    := gunroar_main
LOCAL_SRC_FILES := libgr_main.so

include $(PREBUILT_SHARED_LIBRARY)
