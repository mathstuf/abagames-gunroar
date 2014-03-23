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
private import abagames.util.vector;
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

  public void initSDL() {
    // Initialize Derelict.
    DerelictSDL2.load();
    DerelictGL.load(); // We use deprecated features.
    // Initialize SDL.
    if (SDL_Init(SDL_INIT_VIDEO) < 0) {
      throw new SDLInitFailedException(
        "Unable to initialize SDL: " ~ to!string(SDL_GetError()));
    }
    // Create an OpenGL screen.
    Uint32 videoFlags;
    if (_windowMode) {
      videoFlags = SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE;
    } else {
      videoFlags = SDL_WINDOW_OPENGL | SDL_WINDOW_FULLSCREEN_DESKTOP;
    }
    _window = SDL_CreateWindow("",
        SDL_WINDOWPOS_UNDEFINED, SDL_WINDOW_OPENGL,
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
    resized(_width, _height);
    SDL_ShowCursor(SDL_DISABLE);
    init();
  }

  // Reset a viewport when the screen is resized.
  public void screenResized() {
    glViewport(0, 0, _width, _height);
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    float aspect = cast(GLfloat) width / cast(GLfloat) height;
    float ymax = _nearPlane * tan(45.0f * PI / 360.0);
    float ymin = -ymax;
    float xmin = ymin * aspect;
    float xmax = ymax * aspect;
    glFrustum(xmin, xmax, ymin, ymax, _nearPlane, _farPlane);
    glFrustum(-_nearPlane,
              _nearPlane,
              -_nearPlane * cast(GLfloat) _height / cast(GLfloat) _width,
              _nearPlane * cast(GLfloat) _height / cast(GLfloat) _width,
              0.1f, _farPlane);
    glMatrixMode(GL_MODELVIEW);
  }

  public void resized(int w, int h) {
    _width = w;
    _height = h;
    screenResized();
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
    glClear(GL_COLOR_BUFFER_BIT);
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

  public static void glVertex(Vector v) {
    glVertex3f(v.x, v.y, 0);
  }

  public static void glVertex(Vector3 v) {
    glVertex3f(v.x, v.y, v.z);
  }

  public static void glTranslate(Vector v) {
    glTranslatef(v.x, v.y, 0);
  }

  public static void glTranslate(Vector3 v) {
    glTranslatef(v.x, v.y, v.z);
  }

  public static void setColor(float r, float g, float b, float a = 1) {
    glColor4f(r * _brightness, g * _brightness, b * _brightness, a);
  }

  public static void setClearColor(float r, float g, float b, float a = 1) {
    glClearColor(r * _brightness, g * _brightness, b * _brightness, a);
  }

  public static float brightness(float v) {
    return _brightness = v;
  }
}
