/*
 * $Id: luminous.d,v 1.1.1.1 2005/06/18 00:46:00 kenta Exp $
 *
 * Copyright 2005 Kenta Cho. Some rights reserved.
 */
module abagames.util.sdl.luminous;

private import std.math;
private import std.c.string;
private import gl3n.linalg;
private import abagames.util.actor;
private import abagames.util.support.gl;
private import abagames.util.sdl.shaderprogram;

/**
 * Luminous effect texture.
 */
public class LuminousScreen {
 private:
  static const float TEXTURE_SIZE_MIN = 0.02f;
  static const float TEXTURE_SIZE_MAX = 0.98f;
  GLuint luminousTexture;
  static const int LUMINOUS_TEXTURE_WIDTH_MAX = 64;
  static const int LUMINOUS_TEXTURE_HEIGHT_MAX = 64;
  GLuint[LUMINOUS_TEXTURE_WIDTH_MAX * LUMINOUS_TEXTURE_HEIGHT_MAX * 4 * uint.sizeof] td;
  int luminousTextureWidth = 64, luminousTextureHeight = 64;
  int screenWidth, screenHeight;
  float luminosity;
  ShaderProgram program;
  GLuint[2] vao;
  GLuint vbo;

  //private int lmOfs[5][2] = [[0, 0], [1, 0], [-1, 0], [0, 1], [0, -1]];
  //private const float lmOfsBs = 5;
  //private static float lmOfs[2][2] = [[-2, -1], [2, 1]];
  private static const float lmOfs_a0 = -2;
  private static const float lmOfs_a1 = -1;
  private static const float lmOfs_b0 =  2;
  private static const float lmOfs_b1 =  1;
  private static const float lmOfsBs = 3;

  public void init(float luminosity, int width, int height) {
    makeLuminousTexture();
    this.luminosity = luminosity;

    program = new ShaderProgram;
    program.setVertexShader(
      "uniform mat4 projmat;\n"
      "uniform float luminousFactor;\n"
      "uniform vec2 screenSize;\n"
      "\n"
      "attribute vec2 screenFactor;\n"
      "attribute vec2 pos;\n"
      "attribute vec2 tex;\n"
      "\n"
      "varying vec2 f_tc;\n"
      "\n"
      "void main() {\n"
      "  vec2 screenOffset = screenSize * screenFactor;\n"
      "  gl_Position = projmat * vec4(screenOffset + pos * luminousFactor, 0, 1);\n"
      "  f_tc = tex;\n"
      "}\n"
    );
    program.setFragmentShader(
      "uniform sampler2D sampler;\n"
      "uniform vec4 color;\n"
      "\n"
      "varying vec2 f_tc;\n"
      "\n"
      "void main() {\n"
      "  gl_FragColor = texture2D(sampler, f_tc) * color;\n"
      "}\n"
    );
    GLint screenFactorLoc = 0;
    GLint posLoc = 1;
    GLint texLoc = 2;
    program.bindAttribLocation(screenFactorLoc, "screenFactor");
    program.bindAttribLocation(posLoc, "pos");
    program.bindAttribLocation(texLoc, "tex");
    program.link();
    program.use();

    program.setUniform("color", 1, 0.8, 0.9, luminosity);
    program.setUniform("sampler", 0);
    program.setUniform("luminousFactor", lmOfsBs);

    glGenBuffers(1, &vbo);
    glGenVertexArrays(2, vao.ptr);

    static const float[] BUF = [
      /*
      screenFactor, pos,                pos,                tex */
      0, 0,         lmOfs_a0, lmOfs_a1, lmOfs_b0, lmOfs_b1, TEXTURE_SIZE_MIN, TEXTURE_SIZE_MAX,
      0, 1,         lmOfs_a0, lmOfs_a1, lmOfs_b0, lmOfs_b1, TEXTURE_SIZE_MIN, TEXTURE_SIZE_MIN,
      1, 1,         lmOfs_a0, lmOfs_a0, lmOfs_b0, lmOfs_b0, TEXTURE_SIZE_MAX, TEXTURE_SIZE_MIN,
      1, 0,         lmOfs_a0, lmOfs_a0, lmOfs_b0, lmOfs_b0, TEXTURE_SIZE_MAX, TEXTURE_SIZE_MAX
    ];
    enum SCREENFACTOR = 0;
    enum POS1 = 2;
    enum POS2 = 4;
    enum TEX = 6;
    enum BUFSZ = 8;

    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, BUF.length * float.sizeof, BUF.ptr, GL_STATIC_DRAW);

    glBindVertexArray(vao[0]);

    vertexAttribPointer(screenFactorLoc, 2, BUFSZ, SCREENFACTOR);
    glEnableVertexAttribArray(screenFactorLoc);

    vertexAttribPointer(posLoc, 2, BUFSZ, POS1);
    glEnableVertexAttribArray(posLoc);

    vertexAttribPointer(texLoc, 2, BUFSZ, TEX);
    glEnableVertexAttribArray(texLoc);

    glBindVertexArray(vao[1]);

    vertexAttribPointer(screenFactorLoc, 2, BUFSZ, SCREENFACTOR);
    glEnableVertexAttribArray(screenFactorLoc);

    vertexAttribPointer(posLoc, 2, BUFSZ, POS2);
    glEnableVertexAttribArray(posLoc);

    vertexAttribPointer(texLoc, 2, BUFSZ, TEX);
    glEnableVertexAttribArray(texLoc);

    resized(width, height);
  }

  private void makeLuminousTexture() {
    uint *data = &td[0];
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

    loadScreenData();
  }

  public void close() {
    glDeleteTextures(1, &luminousTexture);
    glDeleteVertexArrays(2, vao.ptr);
    glDeleteBuffers(1, &vbo);
    program.close();
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

  private void loadScreenData() {
    program.use();

    mat4 view = mat4.orthographic(0, screenWidth, screenHeight, 0, -1, 1);
    program.setUniform("projmat", view);
    program.setUniform("screenSize", screenWidth, screenHeight);
  }

  public void draw(mat4 /*view*/) {
    glEnable(GL_TEXTURE_2D);

    program.use();

    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, luminousTexture);

    program.useVao(vao[0]);
    glDrawArrays(GL_TRIANGLE_FAN, 0, 4);

    program.useVao(vao[1]);
    glDrawArrays(GL_TRIANGLE_FAN, 0, 4);

    glDisable(GL_TEXTURE_2D);
  }
}

/**
 * Actor with the luminous effect.
 */
public class LuminousActor: Actor {
  public abstract void drawLuminous(mat4 view);
}

/**
 * Actor pool for the LuminousActor.
 */
public class LuminousActorPool(T): ActorPool!(T) {
  public this(int n, Object[] args) {
    createActors(n, args);
  }

  public void drawLuminous(mat4 view) {
    for (int i = 0; i < actor.length; i++)
      if (actor[i].exists)
        actor[i].drawLuminous(view);
  }
}
