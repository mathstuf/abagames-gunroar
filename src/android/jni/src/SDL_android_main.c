/*
    SDL_android_main.c, placed in the public domain by Sam Lantinga  3/13/14
*/
#include "../SDL/src/SDL_internal.h"

#ifdef __ANDROID__

/* Include the SDL main definition header */
#include "SDL_main.h"

/*******************************************************************************
                 Functions called by JNI
*******************************************************************************/
#include <jni.h>
#include <android/log.h>

/* Called before SDL_main() to initialize JNI bindings in SDL library */
extern void SDL_Android_Init(JNIEnv* env, jclass cls);

/* Start up the SDL app */
int Java_org_libsdl_app_SDLActivity_nativeInit(JNIEnv* env, jclass cls,
        jint width, jint height)
{
    /* This interface could expand with ABI negotiation, calbacks, etc. */
    SDL_Android_Init(env, cls);

    SDL_SetMainReady();

    /* Run the application code! */
    int status;
    char width_str[20];
    char height_str[20];
    snprintf(width_str, 20, "%d", width);
    snprintf(height_str, 20, "%d", height);
    char *argv[5];
    argv[0] = SDL_strdup("SDL_app");
    argv[1] = SDL_strdup("-res");
    argv[2] = SDL_strdup(width_str);
    argv[3] = SDL_strdup(height_str);
    argv[4] = NULL;

    status = SDL_main(4, argv);

    /* Do not issue an exit or the whole application will terminate instead of just the SDL thread */
    /* exit(status); */

    return status;
}

void android_log(const char* msg)
{
    __android_log_write(ANDROID_LOG_DEFAULT, "gunroar", msg);
}

#endif /* __ANDROID__ */

/* vi: set ts=4 sw=4 expandtab: */
