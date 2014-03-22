/*
 * $Id: screen3d.d,v 1.1.1.1 2005/06/18 00:46:00 kenta Exp $
 *
 * Copyright 2005 Kenta Cho. Some rights reserved.
 */
module abagames.util.sdl.screen3d;

private import std.string;
private import SDL;
private import opengl;
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

  protected abstract void init();
  protected abstract void close();

  public void initSDL() {
    // Initialize SDL.
    if (SDL_Init(SDL_INIT_VIDEO) < 0) {
      throw new SDLInitFailedException(
        "Unable to initialize SDL: " ~ std.string.toString(SDL_GetError()));
    }
    // Create an OpenGL screen.
    Uint32 videoFlags;
    if (_windowMode) {
      videoFlags = SDL_OPENGL | SDL_RESIZABLE;
    } else {
      videoFlags = SDL_OPENGL | SDL_FULLSCREEN;
    } 
    if (SDL_SetVideoMode(_width, _height, 0, videoFlags) == null) {
      throw new SDLInitFailedException
        ("Unable to create SDL screen: " ~ std.string.toString(SDL_GetError()));
    }
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
    //gluPerspective(45.0f, cast(GLfloat) width / cast(GLfloat) height, nearPlane, farPlane);
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
    SDL_GL_SwapBuffers();
  }

  public void clear() {
    glClear(GL_COLOR_BUFFER_BIT);
  }

  public void handleError() {
    GLenum error = glGetError();
    if (error == GL_NO_ERROR)
      return;
    closeSDL();
    throw new Exception("OpenGL error(" ~ std.string.toString(error) ~ ")");
  }

  protected void setCaption(char[] name) {
    SDL_WM_SetCaption(std.string.toStringz(name), null);
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
