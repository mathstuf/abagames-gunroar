/*
 * $Id: letter.d,v 1.1.1.1 2005/06/18 00:46:00 kenta Exp $
 *
 * Copyright 2005 Kenta Cho. Some rights reserved.
 */
module abagames.gr.letter;

private import std.math;
private import gl3n.linalg;
private import abagames.util.support.gl;
private import abagames.util.sdl.shaderprogram;
private import abagames.util.math;
private import abagames.gr.screen;

/**
 * Letters.
 */
public class Letter {
 public:
  static const float LETTER_WIDTH = 2.1f;
  static const float LETTER_HEIGHT = 3.0f;
  static const int COLOR0 = 0;
  static const int COLOR1 = 1;
  static const int LINE_COLOR = 2;
  static const int POLY_COLOR = 3;
  static const int COLOR_NUM = 4;
 private:
  static const vec3[] COLOR_RGB = [vec3(1, 1, 1), vec3(0.9, 0.7, 0.5)];
  static ShaderProgram program;
  static GLuint vao;
  static GLuint vbo;

  public static void init() {
    program = new ShaderProgram;
    program.setVertexShader(
      "uniform mat4 projmat;\n"
      "uniform mat4 boxmat;\n"
      "uniform mat4 drawmat;\n"
      "uniform vec2 size;\n"
      "\n"
      "attribute vec2 pos;\n"
      "\n"
      "void main() {\n"
      "  gl_Position = projmat * drawmat * boxmat * vec4(pos * size, 0, 1);\n"
      "}\n"
    );
    program.setFragmentShader(
      "uniform vec4 color;\n"
      "uniform float brightness;\n"
      "\n"
      "void main() {\n"
      "  gl_FragColor = color * vec4(vec3(brightness), 1);\n"
      "}\n"
    );
    GLint posLoc = 0;
    program.bindAttribLocation(posLoc, "pos");
    program.link();
    program.use();

    glGenBuffers(1, &vbo);
    glGenVertexArrays(1, &vao);

    static const float[] BUF = [
      /*
      pos */
      -0.5f,   0,
      -0.33f, -0.5f,
       0.33f, -0.5f,
       0.5f,   0,
       0.33f,  0.5f,
      -0.33f,  0.5f
    ];
    enum POS = 0;
    enum BUFSZ = 2;

    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, BUF.length * float.sizeof, BUF.ptr, GL_STATIC_DRAW);

    glBindVertexArray(vao);

    vertexAttribPointer(posLoc, 2, BUFSZ, POS);
    glEnableVertexAttribArray(posLoc);
  }

  public static void close() {
    glDeleteVertexArrays(1, &vao);
    glDeleteBuffers(1, &vbo);
    program.close();
  }

  public static float getWidth(int n ,float s) {
    return n * s * LETTER_WIDTH;
  }

  public static float getHeight(float s) {
    return s * LETTER_HEIGHT;
  }

  public static void setColor(vec4 color) {
    program.use();

    program.setUniform("color", color);
  }

  public static void drawLetter(mat4 view, int n, int c) {
    drawLetter(view, n, vec2(0), 1, 0, c);
  }

  private static void drawLetter(mat4 view, int n, vec2 p, float s, float d, int c) {
    drawLetter(view, n, p, s, 1, d, c);
  }

  private static void drawLetterRev(mat4 view, int n, vec2 p, float s, float d, int c) {
    drawLetter(view, n, p, s, -1, d, c);
  }

  private static void drawLetter(mat4 view, int n, vec2 p, float s, int f, float d, int c) {
    program.use();

    program.setUniform("projmat", view);
    program.setUniform("brightness", Screen.brightness);

    mat4 draw = mat4.identity;
    draw.rotate(-d / 180 * PI, vec3(0, 0, 1));
    draw.scale(s, s * f, s);
    draw.translate(p.x, p.y, 0);
    program.setUniform("drawmat", draw);

    program.useVao(vao);
    setLetter(n, c);
  }

  public static enum Direction {
    TO_RIGHT, TO_DOWN, TO_LEFT, TO_UP,
  }

  public static int convertCharToInt(char c) {
    int idx;
    if (c >= '0' && c <='9') {
      idx = c - '0';
    } else if (c >= 'A' && c <= 'Z') {
      idx = c - 'A' + 10;
    } else if (c >= 'a' && c <= 'z') {
      idx = c - 'a' + 10;
    } else if (c == '.') {
      idx = 36;
    } else if (c == '-') {
      idx = 38;
    } else if (c == '+') {
      idx = 39;
    } else if (c == '_') {
      idx = 37;
    } else if (c == '!') {
      idx = 42;
    } else if (c == '/') {
      idx = 43;
    }
    return idx;
  }

  public static void drawString(mat4 view, string str, vec2 p, float s,
                                int d = Direction.TO_RIGHT, int cl = Letter.COLOR0,
                                bool rev = false, float od = 0) {
    p += vec2(LETTER_WIDTH, LETTER_HEIGHT) * s / 2;
    int idx;
    float ld;
    switch (d) {
    case Direction.TO_RIGHT:
      ld = 0;
      break;
    case Direction.TO_DOWN:
      ld = 90;
      break;
    case Direction.TO_LEFT:
      ld = 180;
      break;
    case Direction.TO_UP:
      ld = 270;
      break;
    default:
      assert(0);
    }
    ld += od;
    foreach (char c; str) {
      if (c != ' ') {
        idx = convertCharToInt(c);
        if (rev)
          drawLetterRev(view, idx, p, s, ld, cl);
        else
          drawLetter(view, idx, p, s, ld, cl);
      }
      if (od == 0) {
        switch(d) {
        case Direction.TO_RIGHT:
          p.x += s * LETTER_WIDTH;
          break;
        case Direction.TO_DOWN:
          p.y += s * LETTER_WIDTH;
          break;
        case Direction.TO_LEFT:
          p.x -= s * LETTER_WIDTH;
          break;
        case Direction.TO_UP:
          p.y -= s * LETTER_WIDTH;
          break;
        default:
          assert(0);
        }
      } else {
        p += sincos(ld * PI / 180).yx * s * LETTER_WIDTH;
      }
    }
  }

  public static void drawNum(mat4 view, int num, vec2 p, float s,
                             int cl = Letter.COLOR0, int dg = 0,
                             int headChar = -1, int floatDigit = -1) {
    p += vec2(LETTER_WIDTH, LETTER_HEIGHT) * s / 2;
    int n = num;
    float ld = 0;
    int digit = dg;
    int fd = floatDigit;
    for (;;) {
      if (fd <= 0) {
        drawLetter(view, n % 10, p, s, ld, cl);
        p.x -= s * LETTER_WIDTH;
      } else {
        drawLetter(view, n % 10, p + vec2(0, s * LETTER_WIDTH * 0.25f), s * 0.5f, ld, cl);
        p.x -= s * LETTER_WIDTH * 0.5f;
      }
      n /= 10;
      digit--;
      fd--;
      if (n <= 0 && digit <= 0 && fd < 0)
        break;
      if (fd == 0) {
        drawLetter(view, 36, p + vec2(0, s * LETTER_WIDTH * 0.25f), s * 0.5f, ld, cl);
        p.x -= s * LETTER_WIDTH * 0.5f;
      }
    }
    if (headChar >= 0)
      drawLetter(view, headChar, p + vec2(s * LETTER_WIDTH * 0.2f),
                 s * 0.6f, ld, cl);
  }

  public static void drawNumSign(mat4 view, int num, vec2 l, float s, int cl = Letter.COLOR0,
                                 int headChar = -1, int floatDigit = -1) {
    vec2 p = l;
    int n = num;
    int fd = floatDigit;
    for (;;) {
      if (fd <= 0) {
        drawLetterRev(view, n % 10, p, s, 0, cl);
        p.x -= s * LETTER_WIDTH;
      } else {
        drawLetterRev(view, n % 10, p - vec2(0, s * LETTER_WIDTH * 0.25f), s * 0.5f, 0, cl);
        p.x -= s * LETTER_WIDTH * 0.5f;
      }
      n /= 10;
      if (n <= 0)
        break;
      fd--;
      if (fd == 0) {
        drawLetterRev(view, 36, p - vec2(0, s * LETTER_WIDTH * 0.25f), s * 0.5f, 0, cl);
        p.x -= s * LETTER_WIDTH * 0.5f;
      }
    }
    if (headChar >= 0)
      drawLetterRev(view, headChar, p + vec2(1, -1) * s * LETTER_WIDTH * 0.2f,
                    s * 0.6f, 0, cl);
  }

  public static void drawTime(mat4 view, int time, vec2 p, float s, int cl = Letter.COLOR0) {
    int n = time;
    if (n < 0)
      n = 0;
    for (int i = 0; i < 7; i++) {
      if (i != 4) {
        drawLetter(view, n % 10, p, s, Direction.TO_RIGHT, cl);
        n /= 10;
      } else {
        drawLetter(view, n % 6, p, s, Direction.TO_RIGHT, cl);
        n /= 6;
      }
      if ((i & 1) == 1 || i == 0) {
        switch (i) {
        case 3:
          drawLetter(view, 41, p + vec2(s * 1.16f, 0), s, Direction.TO_RIGHT, cl);
          break;
        case 5:
          drawLetter(view, 40, p + vec2(s * 1.16f, 0), s, Direction.TO_RIGHT, cl);
          break;
        default:
          break;
        }
        p.x -= s * LETTER_WIDTH;
      } else {
        p.x -= s * LETTER_WIDTH * 1.3f;
      }
      if (n <= 0)
        break;
    }
  }

  private static void setLetter(int idx, int c) {
    vec2 p;
    float length, size, t;
    float deg;
    for (int i = 0;; i++) {
      deg = spData[idx][i].angle;
      if (deg > 99990) break;
      p = -spData[idx][i].pos;
      size = spData[idx][i].size;
      length = spData[idx][i].length;
      size *= 1.4;
      length *= 1.05;
      p.x *= -1;
      p.y *= 0.9;
      deg %= 180;
      if (c == LINE_COLOR)
        setBoxLine(p, size, length, deg);
      else if (c == POLY_COLOR)
        setBoxPoly(p, size, length, deg);
      else
        setBox(p, size, length, deg, COLOR_RGB[c]);
    }
  }

  private static void setBox(vec2 p, float width, float height, float deg,
                             vec3 color) {
    setBoxMat(p, width, height, deg);

    program.setUniform("color", vec4(color, 0.5));
    setBoxPart(GL_TRIANGLE_FAN, width, height);

    program.setUniform("color", vec4(color, 1));
    setBoxPart(GL_LINE_LOOP, width, height);
  }

  private static void setBoxLine(vec2 p, float width, float height, float deg) {
    setBoxMat(p, width, height, deg);

    setBoxPart(GL_LINE_LOOP, width, height);
  }

  private static void setBoxPoly(vec2 p, float width, float height, float deg) {
    setBoxMat(p, width, height, deg);

    setBoxPart(GL_TRIANGLE_FAN, width, height);
  }

  private static void setBoxMat(vec2 p, float width, float height, float deg) {
    p -= vec2(width, height) / 2;

    mat4 box = mat4.identity;
    box.rotate(-deg / 180 * PI, vec3(0, 0, 1));
    box.translate(p.x, p.y, 0);
    program.setUniform("boxmat", box);
  }

  private static void setBoxPart(GLenum type, float width, float height) {
    program.setUniform("size", width, height);

    glDrawArrays(type, 0, 6);
  }

  private struct LD {
    vec2 pos;
    float size;
    float length;
    int angle;
  }
  private static const LD[16][44] spData =
    [[
     LD(vec2( 0,      1.15f), 0.65f, 0.3f, 0),
     LD(vec2(-0.6f,   0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0.6f,   0.55f), 0.65f, 0.3f, 90),
     LD(vec2(-0.6f,  -0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0.6f,  -0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0,     -1.15f), 0.65f, 0.3f, 0),
     LD(vec2( 0,      0),     0,     0,    99999),
    ],[
     LD(vec2( 0.5f,   0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0.5f,  -0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0,      0),     0,     0,    99999),
    ],[
     LD(vec2( 0,      1.15f), 0.65f, 0.3f, 0),
     LD(vec2( 0.65f,  0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0,      0),     0.65f, 0.3f, 0),
     LD(vec2(-0.65f, -0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0,     -1.15f), 0.65f, 0.3f, 0),
     LD(vec2( 0,      0),     0,     0,    99999),
    ],[
     LD(vec2( 0,      1.15f), 0.65f, 0.3f, 0),
     LD(vec2( 0.65f,  0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0,      0),     0.65f, 0.3f, 0),
     LD(vec2( 0.65f, -0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0,     -1.15f), 0.65f, 0.3f, 0),
     LD(vec2( 0,      0),     0,     0,    99999),
    ],[
     LD(vec2(-0.65f,  0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0.65f,  0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0,      0),     0.65f, 0.3f, 0),
     LD(vec2( 0.65f, -0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0,      0),     0,     0,    99999),
    ],[
     LD(vec2( 0,      1.15f), 0.65f, 0.3f, 0),
     LD(vec2(-0.65f,  0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0,      0),     0.65f, 0.3f, 0),
     LD(vec2( 0.65f, -0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0,     -1.15f), 0.65f, 0.3f, 0),
     LD(vec2( 0,      0),     0,     0,    99999),
    ],[
     LD(vec2( 0,      1.15f), 0.65f, 0.3f, 0),
     LD(vec2(-0.65f,  0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0,      0),     0.65f, 0.3f, 0),
     LD(vec2(-0.65f, -0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0.65f, -0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0,     -1.15f), 0.65f, 0.3f, 0),
     LD(vec2( 0,      0),     0,     0,    99999),
    ],[
     LD(vec2( 0,      1.15f), 0.65f, 0.3f, 0),
     LD(vec2( 0.65f,  0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0.65f, -0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0,      0),     0,     0,    99999),
    ],[
     LD(vec2( 0,      1.15f), 0.65f, 0.3f, 0),
     LD(vec2(-0.65f,  0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0.65f,  0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0,      0),     0.65f, 0.3f, 0),
     LD(vec2(-0.65f, -0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0.65f, -0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0,     -1.15f), 0.65f, 0.3f, 0),
     LD(vec2( 0,      0),     0,     0,    99999),
    ],[
     LD(vec2( 0,      1.15f), 0.65f, 0.3f, 0),
     LD(vec2(-0.65f,  0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0.65f,  0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0,      0),     0.65f, 0.3f, 0),
     LD(vec2( 0.65f, -0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0,     -1.15f), 0.65f, 0.3f, 0),
     LD(vec2( 0,      0),     0,     0,    99999),
    ],[//A
     LD(vec2( 0,      1.15f), 0.65f, 0.3f, 0),
     LD(vec2(-0.65f,  0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0.65f,  0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0,      0),     0.65f, 0.3f, 0),
     LD(vec2(-0.65f, -0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0.65f, -0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0,      0),     0,     0,    99999),
    ],[
     LD(vec2(-0.18f,  1.15f), 0.45f, 0.3f, 0),
     LD(vec2(-0.65f,  0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0.45f,  0.55f), 0.65f, 0.3f, 90),
     LD(vec2(-0.18f,  0),     0.45f, 0.3f, 0),
     LD(vec2(-0.65f, -0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0.65f, -0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0,     -1.15f), 0.65f, 0.3f, 0),
     LD(vec2( 0,      0),     0,     0,    99999),
    ],[
     LD(vec2( 0,      1.15f), 0.65f, 0.3f, 0),
     LD(vec2(-0.65f,  0.55f), 0.65f, 0.3f, 90),
     LD(vec2(-0.65f, -0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0,     -1.15f), 0.65f, 0.3f, 0),
     LD(vec2( 0,      0),     0,     0,    99999),
    ],[
     LD(vec2(-0.15f,  1.15f), 0.45f, 0.3f, 0),
     LD(vec2(-0.65f,  0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0.45f,  0.45f), 0.65f, 0.3f, 90),
     LD(vec2(-0.65f, -0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0.65f, -0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0,     -1.15f), 0.65f, 0.3f, 0),
     LD(vec2( 0,      0),     0,     0,    99999),
    ],[
     LD(vec2( 0,      1.15f), 0.65f, 0.3f, 0),
     LD(vec2(-0.65f,  0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0,      0),     0.65f, 0.3f, 0),
     LD(vec2(-0.65f, -0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0,     -1.15f), 0.65f, 0.3f, 0),
     LD(vec2( 0,      0),     0,     0,    99999),
    ],[//F
     LD(vec2( 0,      1.15f), 0.65f, 0.3f, 0),
     LD(vec2(-0.65f,  0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0,      0),     0.65f, 0.3f, 0),
     LD(vec2(-0.65f, -0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0,      0),     0,     0,    99999),
    ],[
     LD(vec2( 0,      1.15f), 0.65f, 0.3f, 0),
     LD(vec2(-0.65f,  0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0.05f,  0),     0.3f,  0.3f, 0),
     LD(vec2(-0.65f, -0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0.65f, -0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0,     -1.15f), 0.65f, 0.3f, 0),
     LD(vec2( 0,      0),     0,     0,    99999),
    ],[
     LD(vec2(-0.65f,  0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0.65f,  0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0,      0),     0.65f, 0.3f, 0),
     LD(vec2(-0.65f, -0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0.65f, -0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0,      0),     0,     0,    99999),
    ],[
     LD(vec2( 0,      0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0,     -0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0,      0),     0,     0,    99999),
    ],[
     LD(vec2( 0.65f,  0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0.65f, -0.55f), 0.65f, 0.3f, 90),
     LD(vec2(-0.7f,  -0.7f),  0.3f,  0.3f, 90),
     LD(vec2( 0,     -1.15f), 0.65f, 0.3f, 0),
     LD(vec2( 0,      0),     0,     0,    99999),
    ],[//K
     LD(vec2(-0.65f,  0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0.4f,   0.55f), 0.65f, 0.3f, 100),
     LD(vec2(-0.25f,  0),     0.45f, 0.3f, 0),
     LD(vec2(-0.65f, -0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0.6f,  -0.55f), 0.65f, 0.3f, 80),
     LD(vec2( 0,      0),     0,     0,    99999),
    ],[
     LD(vec2(-0.65f,  0.55f), 0.65f, 0.3f, 90),
     LD(vec2(-0.65f, -0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0,     -1.15f), 0.65f, 0.3f, 0),
     LD(vec2( 0,      0),     0,     0,    99999),
    ],[
     LD(vec2(-0.5f,   1.15f), 0.3f,  0.3f, 0),
     LD(vec2( 0.1f,   1.15f), 0.3f,  0.3f, 0),
     LD(vec2(-0.65f,  0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0.65f,  0.55f), 0.65f, 0.3f, 90),
     LD(vec2(-0.65f, -0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0.65f, -0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0,      0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0,     -0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0,      0),     0,     0,    99999),
    ],[
     LD(vec2( 0,      1.15f), 0.65f, 0.3f, 0),
     LD(vec2(-0.65f,  0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0.65f,  0.55f), 0.65f, 0.3f, 90),
     LD(vec2(-0.65f, -0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0.65f, -0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0,      0),     0,     0,    99999),
    ],[
     LD(vec2( 0,      1.15f), 0.65f, 0.3f, 0),
     LD(vec2(-0.65f,  0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0.65f,  0.55f), 0.65f, 0.3f, 90),
     LD(vec2(-0.65f, -0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0.65f, -0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0,     -1.15f), 0.65f, 0.3f, 0),
     LD(vec2( 0,      0),     0,     0,    99999),
    ],[//P
     LD(vec2( 0,      1.15f), 0.65f, 0.3f, 0),
     LD(vec2(-0.65f,  0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0.65f,  0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0,      0),     0.65f, 0.3f, 0),
     LD(vec2(-0.65f, -0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0,      0),     0,     0,    99999),
    ],[
     LD(vec2( 0,      1.15f), 0.65f, 0.3f, 0),
     LD(vec2(-0.65f,  0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0.65f,  0.55f), 0.65f, 0.3f, 90),
     LD(vec2(-0.65f, -0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0.65f, -0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0,     -1.15f), 0.65f, 0.3f, 0),
     LD(vec2( 0.05f, -0.55f), 0.45f, 0.3f, 60),
     LD(vec2( 0,      0),     0,     0,    99999),
    ],[
     LD(vec2( 0,      1.15f), 0.65f, 0.3f, 0),
     LD(vec2(-0.65f,  0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0.65f,  0.55f), 0.65f, 0.3f, 90),
     LD(vec2(-0.2f,   0),     0.45f, 0.3f, 0),
     LD(vec2(-0.65f, -0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0.45f, -0.55f), 0.65f, 0.3f, 80),
     LD(vec2( 0,      0),     0,     0,    99999),
    ],[
     LD(vec2( 0,      1.15f), 0.65f, 0.3f, 0),
     LD(vec2(-0.65f,  0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0,      0),     0.65f, 0.3f, 0),
     LD(vec2( 0.65f, -0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0,     -1.15f), 0.65f, 0.3f, 0),
     LD(vec2( 0,      0),     0,     0,    99999),
    ],[
     LD(vec2(-0.5f,   1.15f), 0.55f, 0.3f, 0),
     LD(vec2( 0.5f,   1.15f), 0.55f, 0.3f, 0),
     LD(vec2( 0.1f,   0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0.1f,  -0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0,      0),     0,     0,    99999),
    ],[//U
     LD(vec2(-0.65f,  0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0.65f,  0.55f), 0.65f, 0.3f, 90),
     LD(vec2(-0.65f, -0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0.65f, -0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0,     -1.15f), 0.65f, 0.3f, 0),
     LD(vec2( 0,      0),     0,     0,    99999),
    ],[
     LD(vec2(-0.65f,  0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0.65f,  0.55f), 0.65f, 0.3f, 90),
     LD(vec2(-0.5f,  -0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0.5f,  -0.55f), 0.65f, 0.3f, 90),
     LD(vec2(-0.1f,  -1.15f), 0.45f, 0.3f, 0),
     LD(vec2( 0,      0),     0,     0,    99999),
    ],[
     LD(vec2(-0.65f,  0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0.65f,  0.55f), 0.65f, 0.3f, 90),
     LD(vec2(-0.65f, -0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0.65f, -0.55f), 0.65f, 0.3f, 90),
     LD(vec2(-0.5f,  -1.15f), 0.3f,  0.3f, 0),
     LD(vec2( 0.1f,  -1.15f), 0.3f,  0.3f, 0),
     LD(vec2( 0,      0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0,     -0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0,      0),     0,     0,    99999),
    ],[
     LD(vec2(-0.4f,   0.6f),  0.85f, 0.3f, 360-120),
     LD(vec2( 0.4f,   0.6f),  0.85f, 0.3f, 360-60),
     LD(vec2(-0.4f,  -0.6f),  0.85f, 0.3f, 360-240),
     LD(vec2( 0.4f,  -0.6f),  0.85f, 0.3f, 360-300),
     LD(vec2( 0,      0),     0,     0,    99999),
    ],[
     LD(vec2(-0.4f,   0.6f),  0.85f, 0.3f, 360-120),
     LD(vec2( 0.4f,   0.6f),  0.85f, 0.3f, 360-60),
     LD(vec2(-0.1f,  -0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0,      0),     0,     0,    99999),
    ],[
     LD(vec2( 0,      1.15f), 0.65f, 0.3f, 0),
     LD(vec2( 0.3f,   0.4f),  0.65f, 0.3f, 120),
     LD(vec2(-0.3f,  -0.4f),  0.65f, 0.3f, 120),
     LD(vec2( 0,     -1.15f), 0.65f, 0.3f, 0),
     LD(vec2( 0,      0),     0,     0,    99999),
    ],[//.
     LD(vec2( 0,     -1.15f), 0.3f,  0.3f, 0),
     LD(vec2( 0,      0),     0,     0,    99999),
    ],[//_
     LD(vec2( 0,     -1.15f), 0.8f,  0.3f, 0),
     LD(vec2( 0,      0),     0,     0,    99999),
    ],[//-
     LD(vec2( 0,      0),     0.9f,  0.3f, 0),
     LD(vec2( 0,      0),     0,     0,    99999),
    ],[//+
     LD(vec2(-0.5f,   0),     0.45f, 0.3f, 0),
     LD(vec2( 0.45f,  0),     0.45f, 0.3f, 0),
     LD(vec2( 0.1f,   0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0.1f,  -0.55f), 0.65f, 0.3f, 90),
     LD(vec2( 0,      0),     0,     0,    99999),
    ],[//'
     LD(vec2( 0,      1.0f),  0.4f,  0.2f, 90),
     LD(vec2( 0,      0),     0,     0,    99999),
    ],[//''
     LD(vec2(-0.19f,  1.0f),  0.4f,  0.2f, 90),
     LD(vec2( 0.2f,   1.0f),  0.4f,  0.2f, 90),
     LD(vec2( 0,      0),     0,     0,    99999),
    ],[//!
     LD(vec2( 0.56f,  0.25f), 1.1f,  0.3f, 90),
     LD(vec2( 0,     -1.0f),  0.3f,  0.3f, 90),
     LD(vec2( 0,      0),     0,     0,    99999),
    ],[// /
     LD(vec2( 0.8f,   0),     1.75f, 0.3f, 120),
     LD(vec2( 0,      0),     0,     0,    99999),
    ]];
}
