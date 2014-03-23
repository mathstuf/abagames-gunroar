/*
 * $Id: screen.d,v 1.1.1.1 2005/06/18 00:46:00 kenta Exp $
 *
 * Copyright 2005 Kenta Cho. Some rights reserved.
 */
module abagames.gr.screen;

private import std.math;
private import derelict.opengl3.gl;
private import abagames.util.rand;
private import abagames.util.sdl.screen3d;
private import abagames.util.sdl.luminous;

private static float mag(float x, float y, float z) {
  return sqrt(x * x + y * y + z * z);
}

private static void normalize(ref float x, ref float y, ref float z) {
  float d = mag(x, y, z);
  x /= d;
  y /= d;
  z /= d;
}

private static float dot2(
    float x1, float y1,
    float x2, float y2) {
  return x1 * x2 - y1 * y2;
}

private static void cross(
    ref float x, ref float y, ref float z,
    float x1, float y1, float z1,
    float x2, float y2, float z2) {
  x = dot2(y1, z1, z2, y2);
  y = dot2(z1, x1, x2, z2);
  z = dot2(x1, y1, y2, x2);
}

/**
 * Initialize an OpenGL and set the caption.
 * Handle a luminous screen and a viewpoint.
 */
public class Screen: Screen3D {
 private:
  string CAPTION = "Gunroar";
  static Rand rand;
  static float lineWidthBase;
  LuminousScreen luminousScreen;
  float _luminosity = 0;
  int screenShakeCnt;
  float screenShakeIntense;

  invariant() {
    assert(_luminosity >= 0 && _luminosity <= 1);
    assert(screenShakeCnt >= 0 && screenShakeCnt < 120);
    assert(screenShakeIntense >= 0 && screenShakeIntense < 1);
  }

  public static this() {
    rand = new Rand;
  }

  public static void setRandSeed(long seed) {
    rand.setSeed(seed);
  }

  public this() {
    _luminosity = 0;
    screenShakeCnt = 0;
    screenShakeIntense = 0;
  }

  protected override void init() {
    setCaption(CAPTION);
    glLineWidth(1);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE);
    glEnable(GL_BLEND);
    glEnable(GL_LINE_SMOOTH);
    glDisable(GL_TEXTURE_2D);
    glDisable(GL_COLOR_MATERIAL);
    glDisable(GL_CULL_FACE);
    glDisable(GL_DEPTH_TEST);
    glDisable(GL_LIGHTING);
    setClearColor(0, 0, 0, 1);
    if (_luminosity > 0) {
      luminousScreen = new LuminousScreen;
      luminousScreen.init(_luminosity, width, height);
    } else {
      luminousScreen = null;
    }
    screenResized();
  }

  public override void close() {
    if (luminousScreen)
      luminousScreen.close();
  }

  public bool startRenderToLuminousScreen() {
    if (!luminousScreen)
      return false;
    luminousScreen.startRender();
    return true;
  }

  public void endRenderToLuminousScreen() {
    if (luminousScreen)
      luminousScreen.endRender();
  }

  public void drawLuminous() {
    if (luminousScreen)
      luminousScreen.draw();
  }

  public override void resized(int width, int height) {
    if (luminousScreen)
      luminousScreen.resized(width, height);
    super.resized(width, height);
  }

  public override void screenResized() {
    super.screenResized();
    float lw = (cast(float) width / 640 + cast(float) height / 480) / 2;
    if (lw < 1)
      lw = 1;
    else if (lw > 4)
      lw = 4;
    lineWidthBase = lw;
    lineWidth(1);
  }

  public static void lineWidth(int w) {
    glLineWidth(cast(int) (lineWidthBase * w));
  }

  public override void clear() {
    glClear(GL_COLOR_BUFFER_BIT);
  }

  public static void viewOrthoFixed() {
    glMatrixMode(GL_PROJECTION);
    glPushMatrix();
    glLoadIdentity();
    glOrtho(0, 640, 480, 0, -1, 1);
    glMatrixMode(GL_MODELVIEW);
    glPushMatrix();
    glLoadIdentity();
  }

  public static void viewPerspective() {
    glMatrixMode(GL_PROJECTION);
    glPopMatrix();
    glMatrixMode(GL_MODELVIEW);
    glPopMatrix();
  }

  public void setEyepos() {
    float ex, ey, ez;
    float lx, ly, lz;
    ex = ey = 0;
    ez = 13.0f;
    lx = ly = lz = 0;
    if (screenShakeCnt > 0) {
      float mx = rand.nextSignedFloat(screenShakeIntense * (screenShakeCnt + 4));
      float my = rand.nextSignedFloat(screenShakeIntense * (screenShakeCnt + 4));
      ex += mx;
      ey += my;
      lx += mx;
      ly += my;
    }

    glMatrixMode(GL_MODELVIEW);
    float fx, fy, fz;
    fx = lx - ex;
    fy = ly - ey;
    fz = lz - ez;
    normalize(fx, fy, fz);
    float sx, sy, sz;
    cross(sx, sy, sz,
          fx, fy, fz,
          0., 1., 0.);
    normalize(sx, sy, sz);
    float ux, uy, uz;
    cross(ux, uy, uz,
          sx, sy, sz,
          fx, fy, fz);
    normalize(ux, uy, uz);
    float[] matrix = [
      sx, ux, -fx, 0.,
      sy, uy, -fy, 0.,
      sz, uz, -fz, 0.,
      0., 0., 0., 1.];
    glLoadIdentity();
    glLoadMatrixf(matrix.ptr);
    glTranslatef(ex, ey, ez);
  }

  public void setScreenShake(int cnt, float its) {
    screenShakeCnt = cnt;
    screenShakeIntense = its;
  }

  public void move() {
    if (screenShakeCnt > 0)
      screenShakeCnt--;
  }

  public float luminosity(float v) {
    return _luminosity = v;
  }

  public static void setColorForced(float r, float g, float b, float a = 1) {
    glColor4f(r, g, b, a);
  }
}
