/*
 * $Id: screen3d.d,v 1.1.1.1 2005/06/18 00:46:00 kenta Exp $
 *
 * Copyright 2005 Kenta Cho. Some rights reserved.
 */
module abagames.util.sdl.screen3d;

private import std.math;
private import std.conv;
private import std.string;
private import derelict.sdl2.sdl;
private import derelict.opengl3.gl;
private import gl3n.linalg;
private import abagames.util.sdl.screen;
private import abagames.util.sdl.sdlexception;

/**
 * SDL screen handler(3D, OpenGL).
 */
public class Screen3D: Screen, SizableScreen {
 private:
  static float _brightness = 1;
  float _farPlane = 1000;
  float _nearPlane = 0.1;
  int _width = 640;
  int _height = 480;
  bool _windowMode = false;
  SDL_Window* _window = null;

  protected abstract void init();
  protected abstract void close();

  public mat4 initSDL() {
    // Initialize Derelict.
    DerelictSDL2.load();
    DerelictGL.load(); // We use deprecated features.
    // Initialize SDL.
    version (Android) {
      // Already initialized at this point.
    } else {
      if (SDL_Init(SDL_INIT_VIDEO) < 0) {
        throw new SDLInitFailedException(
          "Unable to initialize SDL: " ~ to!string(SDL_GetError()));
      }
    }
    // Create an OpenGL screen.
    Uint32 videoFlags;
    if (_windowMode) {
      videoFlags = SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE;
    } else {
      videoFlags = SDL_WINDOW_OPENGL | SDL_WINDOW_FULLSCREEN_DESKTOP;
    }
    _window = SDL_CreateWindow("",
        SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
        _width, _height, videoFlags);
    if (_window == null) {
      throw new SDLInitFailedException
        ("Unable to create SDL screen: " ~ to!string(SDL_GetError()));
    }
    SDL_GL_CreateContext(_window);
    // Reload GL now to get any features.
    DerelictGL.reload();
    glViewport(0, 0, width, height);
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    mat4 windowmat = resized(_width, _height);
    SDL_ShowCursor(SDL_DISABLE);
    init();
    return windowmat;
  }

  // Reset a viewport when the screen is resized.
  public mat4 screenResized() {
    const float ratio = cast(float) _height / cast(float) _width;
    return mat4.perspective(
      -_nearPlane, _nearPlane,
      -_nearPlane * ratio, _nearPlane * ratio,
      0.1f, _farPlane);
  }

  public mat4 resized(int w, int h) {
    _width = w;
    _height = h;
    return screenResized();
  }

  public void closeSDL() {
    close();
    SDL_ShowCursor(SDL_ENABLE);
  }

  public void flip() {
    handleError();
    SDL_GL_SwapWindow(_window);
  }

  public void clear() {
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);
  }

  public void handleError() {
    GLenum error = glGetError();
    if (error == GL_NO_ERROR)
      return;
    closeSDL();
    throw new Exception("OpenGL error(" ~ to!string(error) ~ ")");
  }

  protected void setCaption(string name) {
    SDL_SetWindowTitle(_window, std.string.toStringz(name));
  }

  public bool windowMode(bool v) {
    return _windowMode = v;
  }

  public bool windowMode() {
    return _windowMode;
  }

  public int width(int v) {
    return _width = v;
  }

  public int width() {
    return _width;
  }

  public int height(int v) {
    return _height = v;
  }

  public int height() {
    return _height;
  }

  public static void setClearColor(float r, float g, float b, float a = 1) {
    glClearColor(r * _brightness, g * _brightness, b * _brightness, a);
  }

  public static float brightness(float v) {
    return _brightness = v;
  }

  public static float brightness() {
    return _brightness;
  }
}
