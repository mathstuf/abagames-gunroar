/*
 * $Id: luminous.d,v 1.1.1.1 2005/06/18 00:46:00 kenta Exp $
 *
 * Copyright 2005 Kenta Cho. Some rights reserved.
 */
module abagames.util.sdl.luminous;

private import std.math;
private import std.string;
private import opengl;
private import abagames.util.actor;

/**
 * Luminous effect texture.
 */
public class LuminousScreen {
 private:
  const float TEXTURE_SIZE_MIN = 0.02f;
  const float TEXTURE_SIZE_MAX = 0.98f;
  GLuint luminousTexture;
  const int LUMINOUS_TEXTURE_WIDTH_MAX = 64;
  const int LUMINOUS_TEXTURE_HEIGHT_MAX = 64;
  GLuint td[LUMINOUS_TEXTURE_WIDTH_MAX * LUMINOUS_TEXTURE_HEIGHT_MAX * 4 * uint.sizeof];
  int luminousTextureWidth = 64, luminousTextureHeight = 64;
  int screenWidth, screenHeight;
  float luminosity;

  public void init(float luminosity, int width, int height) {
    makeLuminousTexture();
    this.luminosity = luminosity;
    resized(width, height);
  }

  private void makeLuminousTexture() {
    uint *data = td;
    int i;
    memset(data, 0, luminousTextureWidth * luminousTextureHeight * 4 * uint.sizeof);
    glGenTextures(1, &luminousTexture);
    glBindTexture(GL_TEXTURE_2D, luminousTexture);
    glTexImage2D(GL_TEXTURE_2D, 0, 4, luminousTextureWidth, luminousTextureHeight, 0,
		 GL_RGBA, GL_UNSIGNED_BYTE, data);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  }

  public void resized(int width, int height) {
    screenWidth = width;
    screenHeight = height;
  }

  public void close() {
    glDeleteTextures(1, &luminousTexture);
  }

  public void startRender() {
    glViewport(0, 0, luminousTextureWidth, luminousTextureHeight);
  }

  public void endRender() {
    glBindTexture(GL_TEXTURE_2D, luminousTexture);
    glCopyTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 
                     0, 0, luminousTextureWidth, luminousTextureHeight, 0);
    glViewport(0, 0, screenWidth, screenHeight);
  }

  private void viewOrtho() {
    glMatrixMode(GL_PROJECTION);
    glPushMatrix();
    glLoadIdentity();
    glOrtho(0, screenWidth, screenHeight, 0, -1, 1);
    glMatrixMode(GL_MODELVIEW);
    glPushMatrix();
    glLoadIdentity();
  }

  private void viewPerspective() {
    glMatrixMode(GL_PROJECTION);
    glPopMatrix();
    glMatrixMode(GL_MODELVIEW);
    glPopMatrix();
  }

  //private int lmOfs[5][2] = [[0, 0], [1, 0], [-1, 0], [0, 1], [0, -1]];
  //private const float lmOfsBs = 5;
  private float lmOfs[2][2] = [[-2, -1], [2, 1]];
  private const float lmOfsBs = 3;

  public void draw() {
    glEnable(GL_TEXTURE_2D);
    glBindTexture(GL_TEXTURE_2D, luminousTexture);
    viewOrtho();
    glColor4f(1, 0.8, 0.9, luminosity);
    glBegin(GL_QUADS);
    //for (int i = 0; i < 5; i++) {
    //for (int i = 1; i < 5; i++) {
    for (int i = 0; i < 2; i++) {
      glTexCoord2f(TEXTURE_SIZE_MIN, TEXTURE_SIZE_MAX);
      glVertex2f(0 + lmOfs[i][0] * lmOfsBs, 0 + lmOfs[i][1] * lmOfsBs);
      glTexCoord2f(TEXTURE_SIZE_MIN, TEXTURE_SIZE_MIN);
      glVertex2f(0 + lmOfs[i][0] * lmOfsBs, screenHeight + lmOfs[i][1] * lmOfsBs);
      glTexCoord2f(TEXTURE_SIZE_MAX, TEXTURE_SIZE_MIN);
      glVertex2f(screenWidth + lmOfs[i][0] * lmOfsBs, screenHeight + lmOfs[i][0] * lmOfsBs);
      glTexCoord2f(TEXTURE_SIZE_MAX, TEXTURE_SIZE_MAX);
      glVertex2f(screenWidth + lmOfs[i][0] * lmOfsBs, 0 + lmOfs[i][0] * lmOfsBs);
    }
    glEnd();
    viewPerspective();
    glDisable(GL_TEXTURE_2D);
  }
}

/**
 * Actor with the luminous effect.
 */
public class LuminousActor: Actor {
  public abstract void drawLuminous();
}

/**
 * Actor pool for the LuminousActor.
 */
public class LuminousActorPool(T): ActorPool!(T) {
  public this(int n, Object[] args) {
    createActors(n, args);
  }

  public void drawLuminous() {
    for (int i = 0; i < actor.length; i++)
      if (actor[i].exists)
        actor[i].drawLuminous();
  }
}
