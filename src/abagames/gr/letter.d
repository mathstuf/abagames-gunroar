/*
 * $Id: letter.d,v 1.1.1.1 2005/06/18 00:46:00 kenta Exp $
 *
 * Copyright 2005 Kenta Cho. Some rights reserved.
 */
module abagames.gr.letter;

private import std.math;
private import opengl;
private import abagames.util.sdl.displaylist;
private import abagames.gr.screen;

/**
 * Letters.
 */
public class Letter {
 public:
  static DisplayList displayList;
  static const float LETTER_WIDTH = 2.1f;
  static const float LETTER_HEIGHT = 3.0f;
  static const int LINE_COLOR = 2;
  static const int POLY_COLOR = 3;
  static const int COLOR_NUM = 4;
 private:
  static const float[][] COLOR_RGB = [[1, 1, 1], [0.9, 0.7, 0.5]];
  static const int LETTER_NUM = 44;
  static const int DISPLAY_LIST_NUM = LETTER_NUM * COLOR_NUM;

  public static void init() {
    displayList = new DisplayList(DISPLAY_LIST_NUM);
    displayList.resetList();
    for (int j = 0; j < COLOR_NUM; j++) {
      for (int i = 0; i < LETTER_NUM; i++) {
        displayList.newList();
        setLetter(i, j);
        displayList.endList();
      }
    }
  }

  public static void close() {
    displayList.close();
  }

  public static float getWidth(int n ,float s) {
    return n * s * LETTER_WIDTH;
  }

  public static float getHeight(float s) {
    return s * LETTER_HEIGHT;
  }

  public static void drawLetter(int n, int c) {
    displayList.call(n + c * LETTER_NUM);
  }

  private static void drawLetter(int n, float x, float y, float s, float d, int c) {
    glPushMatrix();
    glTranslatef(x, y, 0);
    glScalef(s, s, s);
    glRotatef(d, 0, 0, 1);
    displayList.call(n + c * LETTER_NUM);
    glPopMatrix();
  }

  private static void drawLetterRev(int n, float x, float y, float s, float d, int c) {
    glPushMatrix();
    glTranslatef(x, y, 0);
    glScalef(s, -s, s);
    glRotatef(d, 0, 0, 1);
    displayList.call(n + c * LETTER_NUM);
    glPopMatrix();
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

  public static void drawString(char[] str, float lx, float y, float s,
                                int d = Direction.TO_RIGHT, int cl = 0,
                                bool rev = false, float od = 0) {
    lx += LETTER_WIDTH * s / 2;
    y += LETTER_HEIGHT * s / 2;
    float x = lx;
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
    }
    ld += od;
    foreach (char c; str) {
      if (c != ' ') {
        idx = convertCharToInt(c);
        if (rev)
          drawLetterRev(idx, x, y, s, ld, cl);
        else
          drawLetter(idx, x, y, s, ld, cl);
      }
      if (od == 0) {
        switch(d) {
        case Direction.TO_RIGHT:
          x += s * LETTER_WIDTH;
          break;
        case Direction.TO_DOWN:
          y += s * LETTER_WIDTH;
          break;
        case Direction.TO_LEFT:
          x -= s * LETTER_WIDTH;
          break;
        case Direction.TO_UP:
          y -= s * LETTER_WIDTH;
          break;
        }
      } else {
        x += cos(ld * PI / 180) * s * LETTER_WIDTH;
        y += sin(ld * PI / 180) * s * LETTER_WIDTH;
      }
    }
  }

  public static void drawNum(int num, float lx, float y, float s,
                             int cl = 0, int dg = 0,
                             int headChar = -1, int floatDigit = -1) {
    lx += LETTER_WIDTH * s / 2;
    y += LETTER_HEIGHT * s / 2;
    int n = num;
    float x = lx;
    float ld = 0;
    int digit = dg;
    int fd = floatDigit;
    for (;;) {
      if (fd <= 0) {
        drawLetter(n % 10, x, y, s, ld, cl);
        x -= s * LETTER_WIDTH;
      } else {
        drawLetter(n % 10, x, y + s * LETTER_WIDTH * 0.25f, s * 0.5f, ld, cl);
        x -= s * LETTER_WIDTH * 0.5f;
      }
      n /= 10;
      digit--;
      fd--;
      if (n <= 0 && digit <= 0 && fd < 0)
        break;
      if (fd == 0) {
        drawLetter(36, x, y + s * LETTER_WIDTH * 0.25f, s * 0.5f, ld, cl);
        x -= s * LETTER_WIDTH * 0.5f;
      }
    }
    if (headChar >= 0)
      drawLetter(headChar, x + s * LETTER_WIDTH * 0.2f, y + s * LETTER_WIDTH * 0.2f,
                 s * 0.6f, ld, cl);
  }

  public static void drawNumSign(int num, float lx, float ly, float s, int cl = 0,
                                 int headChar = -1, int floatDigit = -1) {
    float x = lx;
    float y = ly;
    int n = num;
    int fd = floatDigit;
    for (;;) {
      if (fd <= 0) {
        drawLetterRev(n % 10, x, y, s, 0, cl);
        x -= s * LETTER_WIDTH;
      } else {
        drawLetterRev(n % 10, x, y - s * LETTER_WIDTH * 0.25f, s * 0.5f, 0, cl);
        x -= s * LETTER_WIDTH * 0.5f;
      }
      n /= 10;
      if (n <= 0)
        break;
      fd--;
      if (fd == 0) {
        drawLetterRev(36, x, y - s * LETTER_WIDTH * 0.25f, s * 0.5f, 0, cl);
        x -= s * LETTER_WIDTH * 0.5f;
      }
    }
    if (headChar >= 0)
      drawLetterRev(headChar, x + s * LETTER_WIDTH * 0.2f, y - s * LETTER_WIDTH * 0.2f,
                    s * 0.6f, 0, cl);
  }

  public static void drawTime(int time, float lx, float y, float s, int cl = 0) {
    int n = time;
    if (n < 0)
      n = 0;
    float x = lx;
    for (int i = 0; i < 7; i++) {
      if (i != 4) {
        drawLetter(n % 10, x, y, s, Direction.TO_RIGHT, cl);
        n /= 10;
      } else {
        drawLetter(n % 6, x, y, s, Direction.TO_RIGHT, cl);
        n /= 6;
      }
      if ((i & 1) == 1 || i == 0) {
        switch (i) {
        case 3:
          drawLetter(41, x + s * 1.16f, y, s, Direction.TO_RIGHT, cl);
          break;
        case 5:
          drawLetter(40, x + s * 1.16f, y, s, Direction.TO_RIGHT, cl);
          break;
        default:
          break;
        }
        x -= s * LETTER_WIDTH;
      } else {
        x -= s * LETTER_WIDTH * 1.3f;
      }
      if (n <= 0)
        break;
    }
  }

  private static void setLetter(int idx, int c) {
    float x, y, length, size, t;
    float deg;
    for (int i = 0;; i++) {
      deg = cast(int) spData[idx][i][4];
      if (deg > 99990) break;
      x = -spData[idx][i][0];
      y = -spData[idx][i][1];
      size = spData[idx][i][2];
      length = spData[idx][i][3];
      y *= 0.9;
      size *= 1.4;
      length *= 1.05;
      x = -x;
      y = y;
      deg %= 180;
      if (c == LINE_COLOR)
        setBoxLine(x, y, size, length, deg);
      else if (c == POLY_COLOR)
        setBoxPoly(x, y, size, length, deg);
      else
        setBox(x, y, size, length, deg,
                COLOR_RGB[c][0], COLOR_RGB[c][1], COLOR_RGB[c][2]);
    }
  }

  private static void setBox(float x, float y, float width, float height, float deg,
                             float r, float g, float b) {
    glPushMatrix();
    glTranslatef(x - width / 2, y - height / 2, 0);
    glRotatef(deg, 0, 0, 1);
    Screen.setColor(r, g, b, 0.5);
    glBegin(GL_TRIANGLE_FAN);
    setBoxPart(width, height);
    glEnd();
    Screen.setColor(r, g, b);
    glBegin(GL_LINE_LOOP);
    setBoxPart(width, height);
    glEnd();
    glPopMatrix();
  }

  private static void setBoxLine(float x, float y, float width, float height, float deg) {
    glPushMatrix();
    glTranslatef(x - width / 2, y - height / 2, 0);
    glRotatef(deg, 0, 0, 1);
    glBegin(GL_LINE_LOOP);
    setBoxPart(width, height);
    glEnd();
    glPopMatrix();
  }

  private static void setBoxPoly(float x, float y, float width, float height, float deg) {
    glPushMatrix();
    glTranslatef(x - width / 2, y - height / 2, 0);
    glRotatef(deg, 0, 0, 1);
    glBegin(GL_TRIANGLE_FAN);
    setBoxPart(width, height);
    glEnd();
    glPopMatrix();
  }

  private static void setBoxPart(float width, float height) {
    glVertex3f(-width / 2, 0, 0);
    glVertex3f(-width / 3 * 1, -height / 2, 0);
    glVertex3f( width / 3 * 1, -height / 2, 0);
    glVertex3f( width / 2, 0, 0);
    glVertex3f( width / 3 * 1,  height / 2, 0);
    glVertex3f(-width / 3 * 1,  height / 2, 0);
  }
  
  private static float[5][16][] spData = 
    [[
     [0, 1.15f, 0.65f, 0.3f, 0],
     [-0.6f, 0.55f, 0.65f, 0.3f, 90], [0.6f, 0.55f, 0.65f, 0.3f, 90],
     [-0.6f, -0.55f, 0.65f, 0.3f, 90], [0.6f, -0.55f, 0.65f, 0.3f, 90],
     [0, -1.15f, 0.65f, 0.3f, 0],
     [0, 0, 0, 0, 99999],
    ],[
     [0.5f, 0.55f, 0.65f, 0.3f, 90],
     [0.5f, -0.55f, 0.65f, 0.3f, 90],
     [0, 0, 0, 0, 99999],
    ],[
     [0, 1.15f, 0.65f, 0.3f, 0],
     [0.65f, 0.55f, 0.65f, 0.3f, 90],
     [0, 0, 0.65f, 0.3f, 0],
     [-0.65f, -0.55f, 0.65f, 0.3f, 90],
     [0, -1.15f, 0.65f, 0.3f, 0],
     [0, 0, 0, 0, 99999],
    ],[
     [0, 1.15f, 0.65f, 0.3f, 0],
     [0.65f, 0.55f, 0.65f, 0.3f, 90],
     [0, 0, 0.65f, 0.3f, 0],
     [0.65f, -0.55f, 0.65f, 0.3f, 90],
     [0, -1.15f, 0.65f, 0.3f, 0],
     [0, 0, 0, 0, 99999],
    ],[
     [-0.65f, 0.55f, 0.65f, 0.3f, 90], [0.65f, 0.55f, 0.65f, 0.3f, 90],
     [0, 0, 0.65f, 0.3f, 0],
     [0.65f, -0.55f, 0.65f, 0.3f, 90],
     [0, 0, 0, 0, 99999],
    ],[
     [0, 1.15f, 0.65f, 0.3f, 0],
     [-0.65f, 0.55f, 0.65f, 0.3f, 90],
     [0, 0, 0.65f, 0.3f, 0],
     [0.65f, -0.55f, 0.65f, 0.3f, 90],
     [0, -1.15f, 0.65f, 0.3f, 0],
     [0, 0, 0, 0, 99999],
    ],[
     [0, 1.15f, 0.65f, 0.3f, 0],
     [-0.65f, 0.55f, 0.65f, 0.3f, 90],
     [0, 0, 0.65f, 0.3f, 0],
     [-0.65f, -0.55f, 0.65f, 0.3f, 90], [0.65f, -0.55f, 0.65f, 0.3f, 90],
     [0, -1.15f, 0.65f, 0.3f, 0],
     [0, 0, 0, 0, 99999],
    ],[
     [0, 1.15f, 0.65f, 0.3f, 0],
     [0.65f, 0.55f, 0.65f, 0.3f, 90],
     [0.65f, -0.55f, 0.65f, 0.3f, 90],
     [0, 0, 0, 0, 99999],
    ],[
     [0, 1.15f, 0.65f, 0.3f, 0],
     [-0.65f, 0.55f, 0.65f, 0.3f, 90], [0.65f, 0.55f, 0.65f, 0.3f, 90],
     [0, 0, 0.65f, 0.3f, 0],
     [-0.65f, -0.55f, 0.65f, 0.3f, 90], [0.65f, -0.55f, 0.65f, 0.3f, 90],
     [0, -1.15f, 0.65f, 0.3f, 0],
     [0, 0, 0, 0, 99999],
    ],[
     [0, 1.15f, 0.65f, 0.3f, 0],
     [-0.65f, 0.55f, 0.65f, 0.3f, 90], [0.65f, 0.55f, 0.65f, 0.3f, 90],
     [0, 0, 0.65f, 0.3f, 0],
     [0.65f, -0.55f, 0.65f, 0.3f, 90],
     [0, -1.15f, 0.65f, 0.3f, 0],
     [0, 0, 0, 0, 99999],
    ],[//A
     [0, 1.15f, 0.65f, 0.3f, 0],
     [-0.65f, 0.55f, 0.65f, 0.3f, 90], [0.65f, 0.55f, 0.65f, 0.3f, 90],
     [0, 0, 0.65f, 0.3f, 0],
     [-0.65f, -0.55f, 0.65f, 0.3f, 90], [0.65f, -0.55f, 0.65f, 0.3f, 90],
     [0, 0, 0, 0, 99999],
    ],[
     [-0.18f, 1.15f, 0.45f, 0.3f, 0],
     [-0.65f, 0.55f, 0.65f, 0.3f, 90], [0.45f, 0.55f, 0.65f, 0.3f, 90],
     [-0.18f, 0, 0.45f, 0.3f, 0],
     [-0.65f, -0.55f, 0.65f, 0.3f, 90], [0.65f, -0.55f, 0.65f, 0.3f, 90],
     [0, -1.15f, 0.65f, 0.3f, 0],
     [0, 0, 0, 0, 99999],
    ],[
     [0, 1.15f, 0.65f, 0.3f, 0],
     [-0.65f, 0.55f, 0.65f, 0.3f, 90],
     [-0.65f, -0.55f, 0.65f, 0.3f, 90],
     [0, -1.15f, 0.65f, 0.3f, 0],
     [0, 0, 0, 0, 99999],
    ],[
     [-0.15f, 1.15f, 0.45f, 0.3f, 0],
     [-0.65f, 0.55f, 0.65f, 0.3f, 90], [0.45f, 0.45f, 0.65f, 0.3f, 90],
     [-0.65f, -0.55f, 0.65f, 0.3f, 90], [0.65f, -0.55f, 0.65f, 0.3f, 90],
     [0, -1.15f, 0.65f, 0.3f, 0],
     [0, 0, 0, 0, 99999],
    ],[
     [0, 1.15f, 0.65f, 0.3f, 0],
     [-0.65f, 0.55f, 0.65f, 0.3f, 90],
     [0, 0, 0.65f, 0.3f, 0],
     [-0.65f, -0.55f, 0.65f, 0.3f, 90],
     [0, -1.15f, 0.65f, 0.3f, 0],
     [0, 0, 0, 0, 99999],
    ],[//F
     [0, 1.15f, 0.65f, 0.3f, 0],
     [-0.65f, 0.55f, 0.65f, 0.3f, 90],
     [0, 0, 0.65f, 0.3f, 0],
     [-0.65f, -0.55f, 0.65f, 0.3f, 90],
     [0, 0, 0, 0, 99999],
    ],[
     [0, 1.15f, 0.65f, 0.3f, 0],
     [-0.65f, 0.55f, 0.65f, 0.3f, 90],
     [0.05f, 0, 0.3f, 0.3f, 0],
     [-0.65f, -0.55f, 0.65f, 0.3f, 90], [0.65f, -0.55f, 0.65f, 0.3f, 90],
     [0, -1.15f, 0.65f, 0.3f, 0],
     [0, 0, 0, 0, 99999],
    ],[
     [-0.65f, 0.55f, 0.65f, 0.3f, 90], [0.65f, 0.55f, 0.65f, 0.3f, 90],
     [0, 0, 0.65f, 0.3f, 0],
     [-0.65f, -0.55f, 0.65f, 0.3f, 90], [0.65f, -0.55f, 0.65f, 0.3f, 90],
     [0, 0, 0, 0, 99999],
    ],[
     [0, 0.55f, 0.65f, 0.3f, 90],
     [0, -0.55f, 0.65f, 0.3f, 90],
     [0, 0, 0, 0, 99999],
    ],[
     [0.65f, 0.55f, 0.65f, 0.3f, 90],
     [0.65f, -0.55f, 0.65f, 0.3f, 90], [-0.7f, -0.7f, 0.3f, 0.3f, 90],
     [0, -1.15f, 0.65f, 0.3f, 0],
     [0, 0, 0, 0, 99999],
    ],[//K
     [-0.65f, 0.55f, 0.65f, 0.3f, 90], [0.4f, 0.55f, 0.65f, 0.3f, 100],
     [-0.25f, 0, 0.45f, 0.3f, 0],
     [-0.65f, -0.55f, 0.65f, 0.3f, 90], [0.6f, -0.55f, 0.65f, 0.3f, 80],
     [0, 0, 0, 0, 99999],
    ],[
     [-0.65f, 0.55f, 0.65f, 0.3f, 90],
     [-0.65f, -0.55f, 0.65f, 0.3f, 90],
     [0, -1.15f, 0.65f, 0.3f, 0],
     [0, 0, 0, 0, 99999],
    ],[
     [-0.5f, 1.15f, 0.3f, 0.3f, 0], [0.1f, 1.15f, 0.3f, 0.3f, 0],
     [-0.65f, 0.55f, 0.65f, 0.3f, 90], [0.65f, 0.55f, 0.65f, 0.3f, 90],
     [-0.65f, -0.55f, 0.65f, 0.3f, 90], [0.65f, -0.55f, 0.65f, 0.3f, 90],
     [0, 0.55f, 0.65f, 0.3f, 90],
     [0, -0.55f, 0.65f, 0.3f, 90],
     [0, 0, 0, 0, 99999],
    ],[
     [0, 1.15f, 0.65f, 0.3f, 0],
     [-0.65f, 0.55f, 0.65f, 0.3f, 90], [0.65f, 0.55f, 0.65f, 0.3f, 90],
     [-0.65f, -0.55f, 0.65f, 0.3f, 90], [0.65f, -0.55f, 0.65f, 0.3f, 90],
     [0, 0, 0, 0, 99999],
    ],[
     [0, 1.15f, 0.65f, 0.3f, 0],
     [-0.65f, 0.55f, 0.65f, 0.3f, 90], [0.65f, 0.55f, 0.65f, 0.3f, 90],
     [-0.65f, -0.55f, 0.65f, 0.3f, 90], [0.65f, -0.55f, 0.65f, 0.3f, 90],
     [0, -1.15f, 0.65f, 0.3f, 0],
     [0, 0, 0, 0, 99999],
    ],[//P
     [0, 1.15f, 0.65f, 0.3f, 0],
     [-0.65f, 0.55f, 0.65f, 0.3f, 90], [0.65f, 0.55f, 0.65f, 0.3f, 90],
     [0, 0, 0.65f, 0.3f, 0],
     [-0.65f, -0.55f, 0.65f, 0.3f, 90],
     [0, 0, 0, 0, 99999],
    ],[
     [0, 1.15f, 0.65f, 0.3f, 0],
     [-0.65f, 0.55f, 0.65f, 0.3f, 90], [0.65f, 0.55f, 0.65f, 0.3f, 90],
     [-0.65f, -0.55f, 0.65f, 0.3f, 90], [0.65f, -0.55f, 0.65f, 0.3f, 90],
     [0, -1.15f, 0.65f, 0.3f, 0],
     [0.05f, -0.55f, 0.45f, 0.3f, 60],
     [0, 0, 0, 0, 99999],
    ],[
     [0, 1.15f, 0.65f, 0.3f, 0],
     [-0.65f, 0.55f, 0.65f, 0.3f, 90], [0.65f, 0.55f, 0.65f, 0.3f, 90],
     [-0.2f, 0, 0.45f, 0.3f, 0],
     [-0.65f, -0.55f, 0.65f, 0.3f, 90], [0.45f, -0.55f, 0.65f, 0.3f, 80],
     [0, 0, 0, 0, 99999],
    ],[
     [0, 1.15f, 0.65f, 0.3f, 0],
     [-0.65f, 0.55f, 0.65f, 0.3f, 90],
     [0, 0, 0.65f, 0.3f, 0],
     [0.65f, -0.55f, 0.65f, 0.3f, 90],
     [0, -1.15f, 0.65f, 0.3f, 0],
     [0, 0, 0, 0, 99999],
    ],[
     [-0.5f, 1.15f, 0.55f, 0.3f, 0], [0.5f, 1.15f, 0.55f, 0.3f, 0],
     [0.1f, 0.55f, 0.65f, 0.3f, 90],
     [0.1f, -0.55f, 0.65f, 0.3f, 90],
     [0, 0, 0, 0, 99999],
    ],[//U
     [-0.65f, 0.55f, 0.65f, 0.3f, 90], [0.65f, 0.55f, 0.65f, 0.3f, 90],
     [-0.65f, -0.55f, 0.65f, 0.3f, 90], [0.65f, -0.55f, 0.65f, 0.3f, 90],
     [0, -1.15f, 0.65f, 0.3f, 0],
     [0, 0, 0, 0, 99999],
    ],[
     [-0.65f, 0.55f, 0.65f, 0.3f, 90], [0.65f, 0.55f, 0.65f, 0.3f, 90],
     [-0.5f, -0.55f, 0.65f, 0.3f, 90], [0.5f, -0.55f, 0.65f, 0.3f, 90],
     [-0.1f, -1.15f, 0.45f, 0.3f, 0],
     [0, 0, 0, 0, 99999],
    ],[
     [-0.65f, 0.55f, 0.65f, 0.3f, 90], [0.65f, 0.55f, 0.65f, 0.3f, 90],
     [-0.65f, -0.55f, 0.65f, 0.3f, 90], [0.65f, -0.55f, 0.65f, 0.3f, 90],
     [-0.5f, -1.15f, 0.3f, 0.3f, 0], [0.1f, -1.15f, 0.3f, 0.3f, 0],
     [0, 0.55f, 0.65f, 0.3f, 90],
     [0, -0.55f, 0.65f, 0.3f, 90],
     [0, 0, 0, 0, 99999],
    ],[
     [-0.4f, 0.6f, 0.85f, 0.3f, 360-120],
     [0.4f, 0.6f, 0.85f, 0.3f, 360-60],
     [-0.4f, -0.6f, 0.85f, 0.3f, 360-240],
     [0.4f, -0.6f, 0.85f, 0.3f, 360-300],
     [0, 0, 0, 0, 99999],
    ],[
     [-0.4f, 0.6f, 0.85f, 0.3f, 360-120],
     [0.4f, 0.6f, 0.85f, 0.3f, 360-60],
     [-0.1f, -0.55f, 0.65f, 0.3f, 90],
     [0, 0, 0, 0, 99999],
    ],[
     [0, 1.15f, 0.65f, 0.3f, 0],
     [0.3f, 0.4f, 0.65f, 0.3f, 120],
     [-0.3f, -0.4f, 0.65f, 0.3f, 120],
     [0, -1.15f, 0.65f, 0.3f, 0],
     [0, 0, 0, 0, 99999],
    ],[//.
     [0, -1.15f, 0.3f, 0.3f, 0],
     [0, 0, 0, 0, 99999],
    ],[//_
     [0, -1.15f, 0.8f, 0.3f, 0],
     [0, 0, 0, 0, 99999],
    ],[//-
     [0, 0, 0.9f, 0.3f, 0],
     [0, 0, 0, 0, 99999],
    ],[//+
     [-0.5f, 0, 0.45f, 0.3f, 0], [0.45f, 0, 0.45f, 0.3f, 0],
     [0.1f, 0.55f, 0.65f, 0.3f, 90],
     [0.1f, -0.55f, 0.65f, 0.3f, 90],
     [0, 0, 0, 0, 99999],
    ],[//'
     [0, 1.0f, 0.4f, 0.2f, 90],
     [0, 0, 0, 0, 99999],
    ],[//''
     [-0.19f, 1.0f, 0.4f, 0.2f, 90],
     [0.2f, 1.0f, 0.4f, 0.2f, 90],
     [0, 0, 0, 0, 99999],
    ],[//!
     [0.56f, 0.25f, 1.1f, 0.3f, 90],
     [0, -1.0f, 0.3f, 0.3f, 90],
     [0, 0, 0, 0, 99999],
    ],[// /
     [0.8f, 0, 1.75f, 0.3f, 120],
     [0, 0, 0, 0, 99999],
    ]];
}
