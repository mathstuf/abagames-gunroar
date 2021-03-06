/*
 * $Id: field.d,v 1.3 2005/09/11 00:47:40 kenta Exp $
 *
 * Copyright 2005 Kenta Cho. Some rights reserved.
 */
module abagames.gr.field;

private import std.math;
private import gl3n.linalg;
private import abagames.util.rand;
private import abagames.util.math;
private import abagames.util.support.gl;
private import abagames.util.sdl.shaderprogram;
private import abagames.gr.screen;
private import abagames.gr.stagemanager;
private import abagames.gr.ship;

public struct PlatformPos {
  vec2 pos;
  float deg;
  bool used;
};

/**
 * Game field.
 */
public class Field {
 public:
  static const int BLOCK_SIZE_X = 20;
  static const int BLOCK_SIZE_Y = 64;
  static const int ON_BLOCK_THRESHOLD = 1;
  static const int NEXT_BLOCK_AREA_SIZE = 16;
 private:
  static const float SIDEWALL_X1 = 18;
  static const float SIDEWALL_X2 = 9.3f;
  static const float SIDEWALL_Y = 15;
  static const uint TIME_COLOR_INDEX = 5;
  static const float TIME_CHANGE_RATIO = 0.00033f;
  StageManager stageManager;
  Ship ship;
  Rand rand;
  vec2 _size, _outerSize;
  static const int SCREEN_BLOCK_SIZE_X = 20;
  static const int SCREEN_BLOCK_SIZE_Y = 24;
  static const float BLOCK_WIDTH = 1;
  int[BLOCK_SIZE_Y][BLOCK_SIZE_X] block;
  struct Panel {
    float x, y, z;
    int ci;
    float or, og, ob;
  };
  static const float PANEL_WIDTH = 1.8f;
  static const float PANEL_HEIGHT_BASE = 0.66f;
  Panel[BLOCK_SIZE_Y][BLOCK_SIZE_X] panel;
  int nextBlockY;
  float screenY, blockCreateCnt;
  float _lastScrollY;
  vec2 screenPos;
  PlatformPos[SCREEN_BLOCK_SIZE_X * NEXT_BLOCK_AREA_SIZE] platformPos;
  int platformPosNum;
  float[3][6][TIME_COLOR_INDEX] baseColorTime = [
    [[0.15f, 0.15f, 0.3f], [0.25f, 0.25f, 0.5f], [0.35f, 0.35f, 0.45f],
     [0.6f, 0.7f, 0.35f], [0.45f, 0.8f, 0.3f], [0.2f, 0.6f, 0.1f]],
    [[0.1f, 0.1f, 0.3f], [0.2f, 0.2f, 0.5f], [0.3f, 0.3f, 0.4f],
     [0.5f, 0.65f, 0.35f], [0.4f, 0.7f, 0.3f], [0.1f, 0.5f, 0.1f]],
    [[0.1f, 0.1f, 0.3f], [0.2f, 0.2f, 0.5f], [0.3f, 0.3f, 0.4f],
     [0.5f, 0.65f, 0.35f], [0.4f, 0.7f, 0.3f], [0.1f, 0.5f, 0.1f]],
    [[0.2f, 0.15f, 0.25f], [0.35f, 0.2f, 0.4f], [0.5f, 0.35f, 0.45f],
     [0.7f, 0.6f, 0.3f], [0.6f, 0.65f, 0.25f], [0.2f, 0.45f, 0.1f]],
    [[0.0f, 0.0f, 0.1f], [0.1f, 0.1f, 0.3f], [0.2f, 0.2f, 0.3f],
     [0.2f, 0.3f, 0.15f], [0.2f, 0.2f, 0.1f], [0.0f, 0.15f, 0.0f]],
    ];
  float[3][6] baseColor;
  float time;
  ShaderProgram sideProgram;
  GLuint vaoSide;
  ShaderProgram panelProgram;
  GLuint vaoPanel;
  GLuint vbo;

  invariant() {
    assert(_lastScrollY >= 0 && _lastScrollY < 10);
    assert(screenPos.x < 15 && screenPos.x > -15);
    assert(screenPos.y < 40 && screenPos.y > -20);
    assert(platformPosNum >= 0 && platformPosNum <= SCREEN_BLOCK_SIZE_X * NEXT_BLOCK_AREA_SIZE);
    assert(time >= 0 && time < TIME_COLOR_INDEX);
  }

  public this() {
    rand = new Rand();
    _size = vec2(SCREEN_BLOCK_SIZE_X / 2 * 0.9f, SCREEN_BLOCK_SIZE_Y / 2 * 0.8f);
    _outerSize = vec2(SCREEN_BLOCK_SIZE_X / 2, SCREEN_BLOCK_SIZE_Y / 2);
    screenPos = vec2(0);
    foreach (ref PlatformPos pp; platformPos)
      pp.pos = vec2(0);
    _lastScrollY = 0;
    platformPosNum = 0;
    time = 0;

    setupSideWalls();
  }

  public void close() {
    glDeleteVertexArrays(1, &vaoSide);
    sideProgram.close();

    glDeleteVertexArrays(1, &vaoPanel);
    panelProgram.close();

    glDeleteBuffers(1, &vbo);
  }

  public void setRandSeed(long s) {
    rand.setSeed(s);
  }

  public void setStageManager(StageManager sm) {
    stageManager = sm;
  }

  public void setShip(Ship sp) {
    ship = sp;
  }

  public void start() {
    _lastScrollY = 0;
    nextBlockY = 0;
    screenY = NEXT_BLOCK_AREA_SIZE;
    blockCreateCnt = 0;
    for (int y = 0; y < BLOCK_SIZE_Y; y++) {
      for (int x = 0; x < BLOCK_SIZE_X; x++) {
        block[x][y] = -3;
        createPanel(x, y);
      }
    }
    time = rand.nextFloat(TIME_COLOR_INDEX);
  }

  private void createPanel(int x, int y) {
    Panel* p = &(panel[x][y]);
    p.x = rand.nextFloat(1) - 0.75f;
    p.y = rand.nextFloat(1) - 0.75f;
    p.z = block[x][y] * PANEL_HEIGHT_BASE + rand.nextFloat(PANEL_HEIGHT_BASE);
    p.ci = block[x][y] + 3;
    p.or = 1 + rand.nextSignedFloat(0.1f);
    p.og = 1 + rand.nextSignedFloat(0.1f);
    p.ob = 1 + rand.nextSignedFloat(0.1f);
    p.or *= 0.33f;
    p.og *= 0.33f;
    p.ob *= 0.33f;
  }

  public void scroll(float my, bool isDemo = false) {
    _lastScrollY = my;
    screenY -= my;
    if (screenY < 0)
      screenY += BLOCK_SIZE_Y;
    blockCreateCnt -= my;
    if (blockCreateCnt < 0) {
      stageManager.gotoNextBlockArea();
      int bd;
      if (stageManager.bossMode)
        bd = 0;
      else
        bd = stageManager.blockDensity;
      createBlocks(bd);
      if (!isDemo) {
        stageManager.addBatteries(platformPos, platformPosNum);
      }
      gotoNextBlockArea();
    }
  }

  private void createBlocks(int groundDensity) {
    for (int y = nextBlockY; y < nextBlockY + NEXT_BLOCK_AREA_SIZE; y++) {
      int by = y % BLOCK_SIZE_Y;
      for (int bx = 0; bx < BLOCK_SIZE_X; bx++)
        block[bx][by] = -3;
    }
    platformPosNum = 0;
    int type = rand.nextInt(3);
    for (int i = 0; i < groundDensity; i++)
      addGround(type);
    for (int y = nextBlockY; y < nextBlockY + NEXT_BLOCK_AREA_SIZE; y++) {
      int by = y % BLOCK_SIZE_Y;
      for (int bx = 0; bx < BLOCK_SIZE_X; bx++) {
        if (y == nextBlockY || y == nextBlockY + NEXT_BLOCK_AREA_SIZE - 1)
          block[bx][by] = -3;
      }
    }
    for (int y = nextBlockY; y < nextBlockY + NEXT_BLOCK_AREA_SIZE; y++) {
      int by = y % BLOCK_SIZE_Y;
      for (int bx = 0; bx < BLOCK_SIZE_X - 1; bx++) {
        if (block[bx][by] == 0)
          if (countAroundBlock(bx, by) <= 1)
            block[bx][by] = -2;
      }
      for (int bx = BLOCK_SIZE_X - 1; bx >= 0; bx--) {
        if (block[bx][by] == 0)
          if (countAroundBlock(bx, by) <= 1)
            block[bx][by] = -2;
      }
      for (int bx = 0; bx < BLOCK_SIZE_X; bx++) {
        int b;
        int c = countAroundBlock(bx, by);
        if (block[bx][by] >= 0) {
          switch (c) {
          case 0:
            b = -2;
            break;
          case 1:
          case 2:
          case 3:
            b = 0;
            break;
          case 4:
            b = 2;
            break;
          default:
            assert(0);
          }
        } else {
          switch (c) {
          case 0:
            b = -3;
            break;
          case 1:
          case 2:
          case 3:
          case 4:
            b = -1;
            break;
          default:
            assert(0);
          }
        }
        block[bx][by] = b;
        if (b == -1 && bx >= 2 && bx < BLOCK_SIZE_X - 2) {
          float pd = calcPlatformDeg(bx, by);
          if (pd >= -PI * 2) {
            platformPos[platformPosNum].pos.x = bx;
            platformPos[platformPosNum].pos.y = by;
            platformPos[platformPosNum].deg = pd;
            platformPos[platformPosNum].used = false;
            platformPosNum++;
          }
        }
      }
    }
    for (int y = nextBlockY; y < nextBlockY + NEXT_BLOCK_AREA_SIZE; y++) {
      int by = y % BLOCK_SIZE_Y;
      for (int bx = 0; bx < BLOCK_SIZE_X; bx++) {
        if (block[bx][by] == -3) {
          if (countAroundBlock(bx, by, -1) > 0)
            block[bx][by] = -2;
        } else if (block[bx][by] == 2) {
          if (countAroundBlock(bx, by, 1) < 4)
            block[bx][by] = 1;
        }
        createPanel(bx, by);
      }
    }
  }

  private void addGround(int type) {
    int cx;
    switch (type) {
    case 0:
      cx = rand.nextInt(cast(int) (BLOCK_SIZE_X * 0.4f)) + cast(int) (BLOCK_SIZE_X * 0.1f);
      break;
    case 1:
      cx = rand.nextInt(cast(int) (BLOCK_SIZE_X * 0.4f)) + cast(int) (BLOCK_SIZE_X * 0.5f);
      break;
    case 2:
      if (rand.nextInt(2) == 0)
        cx = rand.nextInt(cast(int) (BLOCK_SIZE_X * 0.4f)) - cast(int) (BLOCK_SIZE_X * 0.2f);
      else
        cx = rand.nextInt(cast(int) (BLOCK_SIZE_X * 0.4f)) + cast(int) (BLOCK_SIZE_X * 0.8f);
      break;
    default:
      assert(0);
    }
    int cy = rand.nextInt(cast(int) (NEXT_BLOCK_AREA_SIZE * 0.6f)) + cast(int) (NEXT_BLOCK_AREA_SIZE * 0.2f);
    cy += nextBlockY;
    int w = rand.nextInt(cast(int) (BLOCK_SIZE_X * 0.33f)) + cast(int) (BLOCK_SIZE_X * 0.33f);
    int h = rand.nextInt(cast(int) (NEXT_BLOCK_AREA_SIZE * 0.24f)) + cast(int) (NEXT_BLOCK_AREA_SIZE * 0.33f);
    cx -= w / 2;
    cy -= h / 2;
    float wr, hr;
    for (int y = nextBlockY; y < nextBlockY + NEXT_BLOCK_AREA_SIZE; y++) {
      int by = y % BLOCK_SIZE_Y;
      for (int bx = 0; bx < BLOCK_SIZE_X; bx++) {
        if (bx >= cx && bx < cx + w && y >= cy && y < cy + h) {
          float o, to;
          wr = rand.nextFloat(0.2f) + 0.2f;
          hr = rand.nextFloat(0.3f) + 0.4f;
          o = (bx - cx) * wr + (y - cy) * hr;
          wr = rand.nextFloat(0.2f) + 0.2f;
          hr = rand.nextFloat(0.3f) + 0.4f;
          to = (cx + w - 1 - bx) * wr + (y - cy) * hr;
          if (to < o)
            o = to;
          wr = rand.nextFloat(0.2f) + 0.2f;
          hr = rand.nextFloat(0.3f) + 0.4f;
          to = (bx - cx) * wr + (cy + h - 1 - y) * hr;
          if (to < o)
            o = to;
          wr = rand.nextFloat(0.2f) + 0.2f;
          hr = rand.nextFloat(0.3f) + 0.4f;
          to = (cx + w - 1 - bx) * wr + (cy + h - 1 - y) * hr;
          if (to < o)
            o = to;
          if (o > 1)
            block[bx][by] = 0;
        }
      }
    }
  }

  private void gotoNextBlockArea() {
    blockCreateCnt += NEXT_BLOCK_AREA_SIZE;
    nextBlockY -= NEXT_BLOCK_AREA_SIZE;
    if (nextBlockY < 0)
      nextBlockY += BLOCK_SIZE_Y;
  }

  public int getBlock(vec2 p) {
    return getBlock(p.x, p.y);
  }

  public int getBlock(float x, float y) {
    y -= screenY - cast(int) screenY;
    int bx, by;
    bx = cast(int) ((x + BLOCK_WIDTH * SCREEN_BLOCK_SIZE_X / 2) / BLOCK_WIDTH);
    by = cast(int)screenY + cast(int) ((-y + BLOCK_WIDTH * SCREEN_BLOCK_SIZE_Y / 2) / BLOCK_WIDTH);
    if (bx < 0 || bx >= BLOCK_SIZE_X)
      return -1;
    if (by < 0)
      by += BLOCK_SIZE_Y;
    else if (by >= BLOCK_SIZE_Y)
      by -= BLOCK_SIZE_Y;
    return block[bx][by];
  }

  public vec2 convertToScreenPos(int bx, int y) {
    float oy = screenY - cast(int) screenY;
    int by = y - cast(int) screenY;
    if (by <= -BLOCK_SIZE_Y)
      by += BLOCK_SIZE_Y;
    if (by > 0)
      by -= BLOCK_SIZE_Y;
    screenPos.x = bx * BLOCK_WIDTH - BLOCK_WIDTH * SCREEN_BLOCK_SIZE_X / 2 + BLOCK_WIDTH / 2;
    screenPos.y = by * -BLOCK_WIDTH + BLOCK_WIDTH * SCREEN_BLOCK_SIZE_Y / 2 + oy - BLOCK_WIDTH / 2;
    return screenPos;
  }

  public void move() {
    time += TIME_CHANGE_RATIO;
    if (time >= TIME_COLOR_INDEX)
      time -= TIME_COLOR_INDEX;
  }

  private void setupSideWalls() {
    sideProgram = new ShaderProgram;
    sideProgram.setVertexShader(
      "uniform mat4 projmat;\n"
      "uniform vec4 flip;\n"
      "\n"
      "attribute vec2 pos;\n"
      "\n"
      "void main() {\n"
      "  gl_Position = projmat * (vec4(pos, 0, 1) * flip);\n"
      "}\n"
    );
    sideProgram.setFragmentShader(
      "uniform vec4 color;\n"
      "\n"
      "void main() {\n"
      "  gl_FragColor = color;\n"
      "}\n"
    );
    GLint posLoc = 0;
    sideProgram.bindAttribLocation(posLoc, "pos");
    sideProgram.link();
    sideProgram.use();

    sideProgram.setUniform("color", 0, 0, 0, 1);

    glGenBuffers(1, &vbo);

    static const float[] BUF = [
      /*
      sidewallPos,              panelPos */
      SIDEWALL_X1,  SIDEWALL_Y, 0,  0,
      SIDEWALL_X2,  SIDEWALL_Y, 1,  0,
      SIDEWALL_X2, -SIDEWALL_Y, 1, -1,
      SIDEWALL_X1, -SIDEWALL_Y, 0, -1
    ];
    enum SIDEWALLPOS = 0;
    enum PANELPOS = 2;
    enum BUFSZ = 4;

    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, BUF.length * float.sizeof, BUF.ptr, GL_STATIC_DRAW);

    glGenVertexArrays(1, &vaoSide);

    glBindVertexArray(vaoSide);

    vertexAttribPointer(posLoc, 2, BUFSZ, SIDEWALLPOS);
    glEnableVertexAttribArray(posLoc);

    panelProgram = new ShaderProgram;

    panelProgram.setVertexShader(
      "uniform mat4 projmat;\n"
      "uniform vec2 s;\n"
      "uniform vec3 pos;\n"
      "uniform float diffFactor;\n"
      "\n"
      "attribute vec2 diff;\n"
      "\n"
      "void main() {\n"
      "  gl_Position = projmat * vec4(pos + vec3(diffFactor * diff + s, 0), 1);\n"
      "}\n"
    );
    panelProgram.setFragmentShader(
      "uniform vec3 color;\n"
      "uniform float brightness;\n"
      "\n"
      "void main() {\n"
      "  gl_FragColor = vec4(color * brightness, 1);\n"
      "}\n"
    );
    GLint diffLoc = 0;
    panelProgram.bindAttribLocation(diffLoc, "diff");
    panelProgram.link();
    panelProgram.use();

    glGenVertexArrays(1, &vaoPanel);

    glBindVertexArray(vaoPanel);

    vertexAttribPointer(diffLoc, 2, BUFSZ, PANELPOS);
    glEnableVertexAttribArray(diffLoc);
  }

  public void draw(mat4 view) {
    drawPanel(view);
  }

  public void drawSideWalls(mat4 view) {
    glDisable(GL_BLEND);

    sideProgram.use();

    sideProgram.setUniform("projmat", view);

    sideProgram.useVao(vaoSide);

    sideProgram.setUniform("flip", vec4(1, 1, 1, 1));
    glDrawArrays(GL_TRIANGLE_FAN, 0, 4);

    sideProgram.setUniform("flip", vec4(-1, 1, 1, 1));
    glDrawArrays(GL_TRIANGLE_FAN, 0, 4);

    glEnable(GL_BLEND);
  }

  private void drawPanel(mat4 view) {
    int ci = cast(int) time;
    int nci = ci + 1;
    if (nci >= TIME_COLOR_INDEX)
      nci = 0;
    float co = time - ci;
    for (int i = 0; i < 6; i++)
      for (int j = 0; j < 3; j++)
        baseColor[i][j] = baseColorTime[ci][i][j] * (1 - co) + baseColorTime[nci][i][j] * co;
    int by = cast(int) screenY;
    float oy = screenY - by;
    float sx;
    float sy = BLOCK_WIDTH * SCREEN_BLOCK_SIZE_Y / 2 + oy;
    by--;
    if (by < 0)
      by += BLOCK_SIZE_Y;
    sy += BLOCK_WIDTH;

    panelProgram.use();

    panelProgram.setUniform("projmat", view);
    panelProgram.setUniform("brightness", Screen.brightness);

    panelProgram.useVao(vaoPanel);

    for (int y = -1; y < SCREEN_BLOCK_SIZE_Y + NEXT_BLOCK_AREA_SIZE; y++) {
      if (by >= BLOCK_SIZE_Y)
        by -= BLOCK_SIZE_Y;
      sx = -BLOCK_WIDTH * SCREEN_BLOCK_SIZE_X / 2;

      for (int bx = 0; bx < SCREEN_BLOCK_SIZE_X; bx++) {
        Panel* p = &(panel[bx][by]);

        panelProgram.setUniform("s", sx, sy);

        panelProgram.setUniform("color", baseColor[p.ci][0] * p.or * 0.66f,
                                         baseColor[p.ci][1] * p.og * 0.66f,
                                         baseColor[p.ci][2] * p.ob * 0.66f);
        panelProgram.setUniform("pos", p.x, -p.y, p.z);
        panelProgram.setUniform("diffFactor", PANEL_WIDTH);

        glDrawArrays(GL_TRIANGLE_FAN, 0, 4);

        panelProgram.setUniform("color", baseColor[p.ci][0] * 0.33f,
                                         baseColor[p.ci][1] * 0.33f,
                                         baseColor[p.ci][2] * 0.33f);
        panelProgram.setUniform("pos", p.x, -p.y, 0f);
        panelProgram.setUniform("diffFactor", BLOCK_WIDTH);

        glDrawArrays(GL_TRIANGLE_FAN, 0, 4);

        sx += BLOCK_WIDTH;
      }
      sy -= BLOCK_WIDTH;
      by++;
    }
  }

  private static int[2][4] degBlockOfs = [[0, -1], [1, 0], [0, 1], [-1, 0]];

  private float calcPlatformDeg(int x, int y) {
    int d = rand.nextInt(4);
    for (int i = 0; i < 4; i++) {
      if (!checkBlock(x + degBlockOfs[d][0], y + degBlockOfs[d][1], -1, true)) {
        float pd = d * PI / 2;
        int ox = x + degBlockOfs[d][0];
        int oy = y + degBlockOfs[d][1];
        int td = d;
        td--;
        if (td < 0)
          td = 3;
        bool b1 = checkBlock(ox +  degBlockOfs[td][0], oy +  degBlockOfs[td][1], -1, true);
        td = d;
        td++;
        if (td >= 4)
          td = 0;
        bool b2 = checkBlock(ox +  degBlockOfs[td][0], oy +  degBlockOfs[td][1], -1, true);
        if (!b1 && b2)
          pd -= PI / 4;
        if (b1 && !b2)
          pd += PI / 4;
        Math.normalizeDeg(pd);
        return pd;
      }
      d++;
      if (d >= 4)
        d = 0;
    }
    return -99999;
  }

  public int countAroundBlock(int x, int y, int th = 0) {
    int c = 0;
    if (checkBlock(x, y - 1, th))
      c++;
    if (checkBlock(x + 1, y, th))
      c++;
    if (checkBlock(x, y + 1, th))
      c++;
    if (checkBlock(x - 1, y, th))
      c++;
    return c;
  }

  private bool checkBlock(int x, int y, int th = 0, bool outScreen = false) {
    if (x < 0 || x >= BLOCK_SIZE_X)
      return outScreen;
    int by = y;
    if (by < 0)
      by += BLOCK_SIZE_Y;
    if (by >= BLOCK_SIZE_Y)
      by -= BLOCK_SIZE_Y;
    return (block[x][by] >= th);
  }

  public bool checkInField(vec2 p) {
    return _size.contains(p);
  }

  public bool checkInField(float x, float y) {
    return _size.contains(x, y);
  }

  public bool checkInOuterField(vec2 p) {
    return _outerSize.contains(p);
  }

  public bool checkInOuterField(float x, float y) {
    return _outerSize.contains(x, y);
  }

  public bool checkInOuterHeightField(vec2 p) {
    if (p.x >= -_size.x && p.x <= _size.x && p.y >= -_outerSize.y && p.y <= _outerSize.y)
      return true;
    else
      return false;
  }

  public bool checkInFieldExceptTop(vec2 p) {
    if (p.x >= -_size.x && p.x <= _size.x && p.y >= -_size.y)
      return true;
    else
      return false;
  }

  public bool checkInOuterFieldExceptTop(vec2 p) {
    if (p.x >= -_outerSize.x && p.x <= _outerSize.x &&
        p.y >= -_outerSize.y && p.y <= _outerSize.y * 2)
      return true;
    else
      return false;
  }

  public vec2 size() {
    return _size;
  }

  public vec2 outerSize() {
    return _outerSize;
  }

  public float lastScrollY() {
    return _lastScrollY;
  }
}
