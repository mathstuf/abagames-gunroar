/*
 * $Id: ship.d,v 1.4 2005/09/11 00:47:40 kenta Exp $
 *
 * Copyright 2005 Kenta Cho. Some rights reserved.
 */
module abagames.gr.ship;

private import std.math;
private import gl3n.linalg;
private import abagames.util.rand;
private import abagames.util.math;
private import abagames.util.support.gl;
private import abagames.util.sdl.pad;
private import abagames.util.sdl.twinstick;
private import abagames.util.sdl.touch;
private import abagames.util.sdl.accelerometer;
private import abagames.util.sdl.mouse;
private import abagames.util.sdl.recordableinput;
private import abagames.util.sdl.shaderprogram;
private import abagames.util.sdl.shape;
private import abagames.gr.field;
private import abagames.gr.gamemanager;
private import abagames.gr.screen;
private import abagames.gr.particle;
private import abagames.gr.letter;
private import abagames.gr.shot;
private import abagames.gr.enemy;
private import abagames.gr.stagemanager;
private import abagames.gr.soundmanager;
private import abagames.gr.prefmanager;
private import abagames.gr.shape;
private import abagames.gr.accelerometerandtouch;
private import abagames.gr.mouseandpad;

/**
 * Player's ship.
 */
public class Ship {
 private:
  static ShaderProgram program;
  static GLuint vao;
  static GLuint[2] vbo;
  static const float SCROLL_SPEED_BASE = 0.01f;
  static const float SCROLL_SPEED_MAX = 0.1f;
  static const float SCROLL_START_Y = 2.5f;
  Field field;
  Boat[2] boat;
  int gameMode;
  int boatNum;
  InGameState gameState;
  float scrollSpeed, _scrollSpeedBase;
  vec2 _midstPos, _higherPos, _lowerPos, _nearPos, _nearVel;
  BaseShape bridgeShape;

  invariant() {
    assert(boatNum >= 1 && boatNum <= boat.length);
    assert(scrollSpeed > 0);
    assert(_scrollSpeedBase > 0);
  }

  public this(Pad pad, TwinStick twinStick, Touch touch, Mouse mouse, Accelerometer accelerometer,
              RecordableAccelerometerAndTouch accelerometerAndTouch, RecordableMouseAndPad mouseAndPad,
              Field field, Screen screen,
              SparkPool sparks, SmokePool smokes, FragmentPool fragments, WakePool wakes) {
    this.field = field;
    Boat.init();
    int i = 0;
    foreach (ref Boat b; boat) {
      b = new Boat(i, this, pad, twinStick, touch, mouse, accelerometer, accelerometerAndTouch, mouseAndPad,
                   field, screen, sparks, smokes, fragments, wakes);
      i++;
    }
    boatNum = 1;
    scrollSpeed = _scrollSpeedBase = SCROLL_SPEED_BASE;
    _midstPos = vec2(0);
    _higherPos = vec2(0);
    _lowerPos = vec2(0);
    _nearPos = vec2(0);
    _nearVel = vec2(0);
    bridgeShape = new BaseShape(0.3f, 0.2f, 0.1f, BaseShape.ShapeType.BRIDGE, 0.3f, 0.7f, 0.7f);

    program = new ShaderProgram;
    program.setVertexShader(
      "uniform mat4 projmat;\n"
      "uniform mat4 rotmat;\n"
      "\n"
      "attribute float pos;\n"
      "attribute vec4 color;\n"
      "\n"
      "varying vec4 f_color;\n"
      "\n"
      "void main() {\n"
      "  gl_Position = projmat * rotmat * vec4(pos, 0, 0, 1);\n"
      "  f_color = color;\n"
      "}\n"
    );
    program.setFragmentShader(
      "uniform float brightness;\n"
      "\n"
      "varying vec4 f_color;\n"
      "\n"
      "void main() {\n"
      "  vec4 brightness4 = vec4(vec3(brightness), 1);\n"
      "  gl_FragColor = f_color * vec4(vec3(brightness), 1);\n"
      "}\n"
    );
    GLint posLoc = 0;
    GLint colorLoc = 1;
    program.bindAttribLocation(posLoc, "pos");
    program.bindAttribLocation(colorLoc, "color");
    program.link();
    program.use();

    glGenBuffers(2, vbo.ptr);
    glGenVertexArrays(1, &vao);

    static const float[] VTX = [
      0,
      0.5f,
      1,
    ];
    static const float[] COLOR = [
      0.5f, 0.5f, 0.9f, 0.8f,
      0.5f, 0.5f, 0.9f, 0.3f,
      0.5f, 0.5f, 0.9f, 0.8f
    ];

    glBindVertexArray(vao);

    glBindBuffer(GL_ARRAY_BUFFER, vbo[0]);
    glBufferData(GL_ARRAY_BUFFER, VTX.length * float.sizeof, VTX.ptr, GL_STATIC_DRAW);

    glVertexAttribPointer(posLoc, 1, GL_FLOAT, GL_FALSE, 0, null);
    glEnableVertexAttribArray(posLoc);

    glBindBuffer(GL_ARRAY_BUFFER, vbo[1]);
    glBufferData(GL_ARRAY_BUFFER, COLOR.length * float.sizeof, COLOR.ptr, GL_STATIC_DRAW);

    glVertexAttribPointer(colorLoc, 4, GL_FLOAT, GL_FALSE, 0, null);
    glEnableVertexAttribArray(colorLoc);
  }

  public void setRandSeed(long seed) {
    Boat.setRandSeed(seed);
  }

  public void close() {
    foreach (Boat b; boat)
      b.close();

    glDeleteVertexArrays(1, &vao);
    glDeleteBuffers(2, vbo.ptr);
    program.close();
  }

  public void setShots(ShotPool shots) {
    foreach (Boat b; boat)
      b.setShots(shots);
  }

  public void setEnemies(EnemyPool enemies) {
    foreach (Boat b; boat)
      b.setEnemies(enemies);
  }

  public void setStageManager(StageManager stageManager) {
    foreach (Boat b; boat)
      b.setStageManager(stageManager);
  }

  public void setGameState(InGameState gameState) {
    this.gameState = gameState;
    foreach (Boat b; boat)
      b.setGameState(gameState);
  }

  public void start(int gameMode) {
    this.gameMode = gameMode;
    if (gameMode == InGameState.GameMode.DOUBLE_PLAY ||
        gameMode == InGameState.GameMode.DOUBLE_PLAY_TOUCH)
      boatNum = 2;
    else
      boatNum = 1;
    _scrollSpeedBase = SCROLL_SPEED_BASE;
    for (int i = 0; i < boatNum; i++)
      boat[i].start(gameMode);
    _midstPos.x = _midstPos.y = 0;
    _higherPos.x = _higherPos.y = 0;
    _lowerPos.x = _lowerPos.y = 0;
    _nearPos.x = _nearPos.y = 0;
    _nearVel.x = _nearVel.y = 0;
    restart();
  }

  public void restart() {
    scrollSpeed = _scrollSpeedBase;
    for (int i = 0; i < boatNum; i++)
      boat[i].restart();
  }

  public void move() {
    field.scroll(scrollSpeed);
    float sf = false;
    for (int i = 0; i < boatNum; i++) {
      boat[i].move();
      if (boat[i].hasCollision &&
          boat[i].pos.x > field.size.x / 3 && boat[i].pos.y < -field.size.y / 4 * 3)
        sf = true;
    }
    if (sf)
        gameState.shrinkScoreReel();
    if (higherPos.y >= SCROLL_START_Y)
      scrollSpeed += (SCROLL_SPEED_MAX - scrollSpeed) * 0.1f;
    else
      scrollSpeed += (_scrollSpeedBase - scrollSpeed) * 0.1f;
    _scrollSpeedBase += (SCROLL_SPEED_MAX - _scrollSpeedBase) * 0.00001f;
  }

  public bool checkBulletHit(vec2 p, vec2 pp) {
    for (int i = 0; i < boatNum; i++)
      if (boat[i].checkBulletHit(p, pp))
        return true;
    return false;
  }

  public void clearBullets() {
    gameState.clearBullets();
  }

  public void destroyed() {
    for (int i = 0; i < boatNum; i++)
      boat[i].destroyedBoat();
  }

  public void draw(mat4 view) {
    for (int i = 0; i < boatNum; i++)
      boat[i].draw(view);
    if ((gameMode == InGameState.GameMode.DOUBLE_PLAY ||
         gameMode == InGameState.GameMode.DOUBLE_PLAY_TOUCH) && boat[0].hasCollision) {
      program.use();

      float dist = distance(boat[0].pos, boat[1].pos);
      mat4 rotmat = mat4.identity;
      rotmat.scale(dist, 0, 0);
      rotmat.rotate(degAmongBoats, vec3(0, 0, 1));
      rotmat.translate(boat[0].pos.x, boat[0].pos.y, 0);

      program.setUniform("projmat", view);
      program.setUniform("rotmat", rotmat);
      program.setUniform("brightness", Screen.brightness);

      glBindVertexArray(vao);
      glDrawArrays(GL_LINE_STRIP, 0, 3);

      mat4 model = mat4.identity;
      model.rotate(degAmongBoats, vec3(0, 0, 1));
      model.translate(midstPos.x, midstPos.y, 0);

      bridgeShape.draw(view, model);
    }
  }

  public void drawFront(mat4 view) {
    for (int i = 0; i < boatNum; i++)
      boat[i].drawFront(view);
  }

  public void drawShape(mat4 view, mat4 model) {
    boat[0].drawShape(view, model);
  }

  public float scrollSpeedBase() {
    return _scrollSpeedBase;
  }

  public void setReplayMode(float turnSpeed, bool reverseFire) {
    foreach (Boat b; boat)
      b.setReplayMode(turnSpeed, reverseFire);
  }

  public void unsetReplayMode() {
    foreach (Boat b; boat)
      b.unsetReplayMode();
  }

  public bool replayMode() {
    return boat[0].replayMode();
  }

  public vec2 midstPos() {
    _midstPos.x = _midstPos.y = 0;
    for (int i = 0; i < boatNum; i++) {
      _midstPos.x += boat[i].pos.x;
      _midstPos.y += boat[i].pos.y;
    }
    // FIXME: Why does _midstPos /= boatNum not work?
    _midstPos.x /= boatNum;
    _midstPos.y /= boatNum;
    return _midstPos;
  }

  public vec2 higherPos() {
    _higherPos.y = -99999;
    for (int i = 0; i < boatNum; i++) {
      if (boat[i].pos.y > _higherPos.y) {
        _higherPos.x = boat[i].pos.x;
        _higherPos.y = boat[i].pos.y;
      }
    }
    return _higherPos;
  }

  public vec2 lowerPos() {
    _lowerPos.y = 99999;
    for (int i = 0; i < boatNum; i++) {
      if (boat[i].pos.y < _lowerPos.y) {
        _lowerPos.x = boat[i].pos.x;
        _lowerPos.y = boat[i].pos.y;
      }
    }
    return _lowerPos;
  }

  public vec2 nearPos(vec2 p) {
    float dist = 99999;
    for (int i = 0; i < boatNum; i++) {
      if (boat[i].pos.fastdist(p) < dist) {
        dist = boat[i].pos.fastdist(p);
        _nearPos.x = boat[i].pos.x;
        _nearPos.y = boat[i].pos.y;
      }
    }
    return _nearPos;
  }

  public vec2 nearVel(vec2 p) {
    float dist = 99999;
    for (int i = 0; i < boatNum; i++) {
      if (boat[i].pos.fastdist(p) < dist) {
        dist = boat[i].pos.fastdist(p);
        _nearVel.x = boat[i].vel.x;
        _nearVel.y = boat[i].vel.y;
      }
    }
    return _nearVel;
  }

  public float distAmongBoats() {
    return boat[0].pos.fastdist(boat[1].pos);
  }

  public float degAmongBoats() {
    if (distAmongBoats < 0.1f)
      return 0;
    else
      return atan2(boat[0].pos.x - boat[1].pos.x, boat[0].pos.y - boat[1].pos.y);
  }
}

public class Boat {
 private:
  static ShaderProgram sightProgram;
  static ShaderProgram lineProgram;
  static GLuint[2] vao;
  static GLuint[3] vbo;
  static const int RESTART_CNT = 300;
  static const int INVINCIBLE_CNT = 228;
  static const float HIT_WIDTH = 0.02f;
  static const int FIRE_INTERVAL = 2;
  static const int FIRE_INTERVAL_MAX = 4;
  static const int FIRE_LANCE_INTERVAL = 15;
  static const float SPEED_BASE = 0.15f;
  static const float TURN_RATIO_BASE = 0.2f;
  static const float SLOW_TURN_RATIO = 0;
  static const float TURN_CHANGE_RATIO = 0.5f;
  static Rand rand;
  static PadState padInput;
  static TwinStickState stickInput;
  static TouchState touchInput;
  static AccelerometerState accelerometerInput;
  static MouseState mouseInput;
  RecordablePad pad;
  RecordableTwinStick twinStick;
  RecordableTouch touch;
  RecordableMouse mouse;
  RecordableAccelerometer accelerometer;
  RecordableAccelerometerAndTouch accelerometerAndTouch;
  RecordableMouseAndPad mouseAndPad;
  Field field;
  Screen screen;
  ShotPool shots;
  SparkPool sparks;
  SmokePool smokes;
  FragmentPool fragments;
  WakePool wakes;
  EnemyPool enemies;
  StageManager stageManager;
  InGameState gameState;
  vec2 _pos;
  vec2 firePos;
  float deg;
  float speed;
  float turnRatio;
  BaseShape _shape;
  BaseShape bridgeShape;
  int fireCnt;
  int fireSprCnt;
  float fireInterval;
  float fireSprDeg;
  int fireLanceCnt;
  float fireDeg;
  bool aPressed, bPressed;
  int cnt;
  bool onBlock;
  vec2 _vel;
  vec2 refVel;
  int shieldCnt;
  ShieldShape shieldShape;
  bool _replayMode;
  float turnSpeed;
  bool reverseFire;
  int gameMode;
  float ax, ay;
  float vx, vy;
  int idx;
  Ship ship;

  invariant() {
    assert(_pos.x < 15 && _pos.x > -15);
    assert(_pos.y < 20 && _pos.y > -20);
    assert(firePos.x < 15 && firePos.x > -15);
    assert(firePos.y < 20 && firePos.y > -20);
    assert(!deg.isNaN);
    assert(speed >= 0 && speed <= SPEED_BASE);
    assert(turnRatio >= 0 && turnRatio <= TURN_RATIO_BASE);
    assert(turnSpeed >= 0);
    assert(fireInterval >= FIRE_INTERVAL);
    assert(!fireSprDeg.isNaN);
    assert(cnt >= -RESTART_CNT);
    assert(_vel.x < 2 && _vel.x > -2);
    assert(_vel.y < 2 && _vel.y > -2);
    assert(refVel.x < 1 && refVel.x > -1);
    assert(refVel.y < 1 && refVel.y > -1);
    assert(shieldCnt >= 0);
  }

  public static void init() {
    rand = new Rand;

    sightProgram = new ShaderProgram;
    sightProgram.setVertexShader(
      "uniform mat4 projmat;\n"
      "uniform vec2 pos;\n"
      "uniform float size;\n"
      "\n"
      "attribute vec2 sizeFactor;\n"
      "\n"
      "void main() {\n"
      "  vec4 pos4 = vec4(pos + size * sizeFactor, 0, 1);\n"
      "  gl_Position = projmat * pos4;\n"
      "}\n"
    );
    sightProgram.setFragmentShader(
      "uniform float brightness;\n"
      "uniform vec4 color;\n"
      "\n"
      "void main() {\n"
      "  vec4 brightness4 = vec4(vec3(brightness), 1);\n"
      "  gl_FragColor = color * brightness4;\n"
      "}\n"
    );
    GLint sizeFactorLoc = 0;
    sightProgram.bindAttribLocation(sizeFactorLoc, "sizeFactor");
    sightProgram.link();
    sightProgram.use();

    glGenBuffers(3, vbo.ptr);
    glGenVertexArrays(2, vao.ptr);

    static const float[] SIZEFACTOR = [
      -1,    -0.5f,
      -1,    -1,
      -0.5f, -1,

       1,    -0.5f,
       1,    -1,
       0.5f, -1,

       1,     0.5f,
       1,     1,
       0.5f,  1,

      -1,     0.5f,
      -1,     1,
      -0.5f,  1
    ];

    glBindVertexArray(vao[0]);

    glBindBuffer(GL_ARRAY_BUFFER, vbo[0]);
    glBufferData(GL_ARRAY_BUFFER, SIZEFACTOR.length * float.sizeof, SIZEFACTOR.ptr, GL_STATIC_DRAW);

    glVertexAttribPointer(sizeFactorLoc, 2, GL_FLOAT, GL_FALSE, 0, null);
    glEnableVertexAttribArray(sizeFactorLoc);

    lineProgram = new ShaderProgram;
    lineProgram.setVertexShader(
      "uniform mat4 projmat;\n"
      "uniform vec2 pos;\n"
      "uniform float deg;\n"
      "\n"
      "attribute float rotFactor;\n"
      "attribute vec4 color;\n"
      "\n"
      "varying vec4 f_color;\n"
      "\n"
      "void main() {\n"
      "  vec2 rot = 20. * rotFactor * vec2(sin(deg), cos(deg));\n"
      "  vec4 pos4 = vec4(pos + rot, 0, 1);\n"
      "  gl_Position = projmat * pos4;\n"
      "  f_color = color;\n"
      "}\n"
    );
    lineProgram.setFragmentShader(
      "uniform float brightness;\n"
      "\n"
      "varying vec4 f_color;\n"
      "\n"
      "void main() {\n"
      "  gl_FragColor = f_color * vec4(vec3(brightness), 1);\n"
      "}\n"
    );
    GLint rotFactorLoc = 0;
    GLint colorLoc = 1;
    lineProgram.bindAttribLocation(rotFactorLoc, "rotFactor");
    lineProgram.bindAttribLocation(colorLoc, "color");
    lineProgram.link();
    lineProgram.use();

    glBindVertexArray(vao[1]);

    static const float[] ROTFACTOR = [
      0,
      1
    ];

    glBindBuffer(GL_ARRAY_BUFFER, vbo[1]);
    glBufferData(GL_ARRAY_BUFFER, ROTFACTOR.length * float.sizeof, ROTFACTOR.ptr, GL_STATIC_DRAW);

    glVertexAttribPointer(rotFactorLoc, 1, GL_FLOAT, GL_FALSE, 0, null);
    glEnableVertexAttribArray(rotFactorLoc);

    static const float[] COLOR = [
      0.5f, 0.9f, 0.7f, 0.4f,
      0.5f, 0.9f, 0.7f, 0.8f
    ];

    glBindBuffer(GL_ARRAY_BUFFER, vbo[2]);
    glBufferData(GL_ARRAY_BUFFER, COLOR.length * float.sizeof, COLOR.ptr, GL_STATIC_DRAW);

    glVertexAttribPointer(colorLoc, 4, GL_FLOAT, GL_FALSE, 0, null);
    glEnableVertexAttribArray(colorLoc);
  }

  public static void setRandSeed(long seed) {
    rand.setSeed(seed);
  }

  public this(int idx, Ship ship,
              Pad pad, TwinStick twinStick, Touch touch, Mouse mouse, Accelerometer accelerometer,
              RecordableAccelerometerAndTouch accelerometerAndTouch, RecordableMouseAndPad mouseAndPad,
              Field field, Screen screen,
              SparkPool sparks, SmokePool smokes, FragmentPool fragments, WakePool wakes) {
    this.idx = idx;
    this.ship = ship;
    this.pad = cast(RecordablePad) pad;
    this.twinStick = cast(RecordableTwinStick) twinStick;
    this.touch = cast(RecordableTouch) touch;
    this.mouse = cast(RecordableMouse) mouse;
    this.accelerometer = cast(RecordableAccelerometer) accelerometer;
    this.accelerometerAndTouch = accelerometerAndTouch;
    this.mouseAndPad = mouseAndPad;
    this.field = field;
    this.screen = screen;
    this.sparks = sparks;
    this.smokes = smokes;
    this.fragments = fragments;
    this.wakes = wakes;
    _pos = vec2(0);
    firePos = vec2(0);
    _vel = vec2(0);
    refVel = vec2(0);
    switch (idx) {
    case 0:
      _shape = new BaseShape(0.7f, 0.6f, 0.6f, BaseShape.ShapeType.SHIP_ROUNDTAIL, 0.5f, 0.7f, 0.5f);
      bridgeShape = new BaseShape(0.3f, 0.6f, 0.6f, BaseShape.ShapeType.BRIDGE, 0.3f, 0.7f, 0.3f);
      break;
    case 1:
      _shape = new BaseShape(0.7f, 0.6f, 0.6f, BaseShape.ShapeType.SHIP_ROUNDTAIL, 0.4f, 0.3f, 0.8f);
      bridgeShape = new BaseShape(0.3f, 0.6f, 0.6f, BaseShape.ShapeType.BRIDGE, 0.2f, 0.3f, 0.6f);
      break;
    default:
      assert(0);
    }
    deg = 0;
    speed = 0;
    turnRatio = 0;
    turnSpeed = 1;
    fireInterval = FIRE_INTERVAL;
    fireSprDeg = 0;
    cnt = 0;
    shieldCnt = 0;
    shieldShape = new ShieldShape;
  }

  public void close() {
    _shape.close();
    bridgeShape.close();
    shieldShape.close();

    if (sightProgram !is null) {
      glDeleteVertexArrays(2, vao.ptr);
      glDeleteBuffers(3, vbo.ptr);
      sightProgram.close();
      sightProgram = null;
      lineProgram.close();
      lineProgram = null;
    }
  }

  public void setShots(ShotPool shots) {
    this.shots = shots;
  }

  public void setEnemies(EnemyPool enemies) {
    this.enemies = enemies;
  }

  public void setStageManager(StageManager stageManager) {
    this.stageManager = stageManager;
  }

  public void setGameState(InGameState gameState) {
    this.gameState = gameState;
  }

  public void start(int gameMode) {
    this.gameMode = gameMode;
    if (gameMode == InGameState.GameMode.DOUBLE_PLAY ||
        gameMode == InGameState.GameMode.DOUBLE_PLAY_TOUCH) {
      switch (idx) {
      case 0:
        _pos.x = -field.size.x * 0.5f;
        break;
      case 1:
        _pos.x = field.size.x * 0.5f;
        break;
      default:
        assert(0);
      }
    } else {
      _pos.x = 0;
    }
    _pos.y = -field.size.y * 0.8f;
    firePos.x = firePos.y = 0;
    _vel.x = _vel.y = 0;
    deg = 0;
    speed = SPEED_BASE;
    turnRatio = TURN_RATIO_BASE;
    cnt = -INVINCIBLE_CNT;
    aPressed = bPressed = true;
    padInput = pad.getNullState();
    stickInput = twinStick.getNullState();
    touchInput = touch.getNullState();
    mouseInput = mouse.getNullState();
  }

  public void restart() {
    switch (gameMode) {
    case InGameState.GameMode.NORMAL:
    case InGameState.GameMode.TOUCH:
      fireCnt = 99999;
      fireInterval = 99999;
      break;
    case InGameState.GameMode.TWIN_STICK:
    case InGameState.GameMode.DOUBLE_PLAY:
    case InGameState.GameMode.DOUBLE_PLAY_TOUCH:
    case InGameState.GameMode.TILT:
    case InGameState.GameMode.MOUSE:
      fireCnt = 0;
      fireInterval = FIRE_INTERVAL;
      break;
    default:
      assert(0);
    }
    fireSprCnt = 0;
    fireSprDeg = 0.5f;
    fireLanceCnt = 0;
    if (field.getBlock(_pos) >= 0)
      onBlock = true;
    else
      onBlock = false;
    refVel.x = refVel.y = 0;
    shieldCnt = 20 * 60;
  }

  public void move() {
    float px = _pos.x, py = _pos.y;
    cnt++;
    ax = ay = 0;
    vx = vy = 0;
    switch (gameMode) {
    case InGameState.GameMode.NORMAL:
      moveNormal();
      break;
    case InGameState.GameMode.TWIN_STICK:
      moveTwinStick();
      break;
    case InGameState.GameMode.TOUCH:
      moveTouch();
      break;
    case InGameState.GameMode.DOUBLE_PLAY:
      moveDoublePlay();
      break;
    case InGameState.GameMode.DOUBLE_PLAY_TOUCH:
      moveDoublePlayTouch();
      break;
    case InGameState.GameMode.TILT:
      moveTilt();
      break;
    case InGameState.GameMode.MOUSE:
      moveMouse();
      break;
    default:
      assert(0);
    }
    if (gameState.isGameOver) {
      clearBullets();
      if (cnt < -INVINCIBLE_CNT)
        cnt = -RESTART_CNT;
    } else if (cnt < -INVINCIBLE_CNT) {
      clearBullets();
    }
    vx *= speed;
    vy *= speed;
    vx += refVel.x;
    vy += refVel.y;
    refVel *= 0.9f;
    if (field.checkInField(_pos.x, _pos.y - field.lastScrollY))
      _pos.y -= field.lastScrollY;
    if ((onBlock || field.getBlock(_pos.x + vx, _pos.y) < 0) &&
        field.checkInField(_pos.x + vx, _pos.y)) {
      _pos.x += vx;
      _vel.x = vx;
    } else {
      _vel.x = 0;
      refVel.x = 0;
    }
    bool srf = false;
    if ((onBlock || field.getBlock(px, _pos.y + vy) < 0) &&
        field.checkInField(_pos.x, _pos.y + vy)) {
      _pos.y += vy;
      _vel.y = vy;
    } else {
      _vel.y = 0;
      refVel.y = 0;
    }
    if (field.getBlock(_pos.x, _pos.y) >= 0) {
      if (!onBlock) {
        if (cnt <= 0) {
          onBlock = true;
        } else {
          if (field.checkInField(_pos.x, _pos.y - field.lastScrollY)) {
            _pos.x = px;
            _pos.y = py;
          } else {
            destroyed();
          }
        }
      }
    } else {
      onBlock = false;
    }
    switch (gameMode) {
    case InGameState.GameMode.NORMAL:
      fireNormal();
      break;
    case InGameState.GameMode.TWIN_STICK:
      fireTwinStick();
      break;
    case InGameState.GameMode.TOUCH:
      fireTouch();
      break;
    case InGameState.GameMode.DOUBLE_PLAY:
    case InGameState.GameMode.DOUBLE_PLAY_TOUCH:
      fireDouble();
      break;
    case InGameState.GameMode.TILT:
      fireTilt();
      break;
    case InGameState.GameMode.MOUSE:
      fireMouse();
      break;
    default:
      assert(0);
    }
    if (cnt % 3 == 0 && cnt >= -INVINCIBLE_CNT) {
      float sp;
      if (vx != 0 || vy != 0)
        sp = 0.4f;
      else
        sp = 0.2f;
      sp *= 1 + rand.nextSignedFloat(0.33f);
      sp *= SPEED_BASE;
      _shape.addWake(wakes, _pos, deg, sp);
    }
    Enemy he = enemies.checkHitShip(pos.x, pos.y);
    if (he) {
      float rd;
      if (pos.fastdist(he.pos) < 0.1f)
        rd = 0;
      else
        rd = atan2(_pos.x - he.pos.x, _pos.y - he.pos.y);
      assert(!rd.isNaN);
      float sz = he.size;
      refVel.x = sin(rd) * sz * 0.1f;
      refVel.y = cos(rd) * sz * 0.1f;
      float rs = refVel.length;
      if (rs > 1) {
        refVel.x /= rs;
        refVel.y /= rs;
      }
    }
    if (shieldCnt > 0)
      shieldCnt--;
  }

  private void moveNormal() {
    if (!_replayMode) {
      padInput = pad.getState();
    } else {
      try {
        padInput = pad.replay();
      } catch (NoRecordDataException e) {
        gameState.isGameOver = true;
        padInput = pad.getNullState();
      }
    }
    if (gameState.isGameOver || cnt < -INVINCIBLE_CNT)
      padInput.clear();
    if (padInput.dir & PadState.Dir.UP)
      vy = 1;
    if (padInput.dir & PadState.Dir.DOWN)
      vy = -1;
    if (padInput.dir & PadState.Dir.RIGHT)
      vx = 1;
    if (padInput.dir & PadState.Dir.LEFT)
      vx = -1;
    if (vx != 0 && vy != 0) {
      vx *= 0.7f;
      vy *= 0.7f;
    }
    moveRelative();
  }

  private void moveTwinStick() {
    if (!_replayMode) {
      stickInput = twinStick.getState();
    } else {
      try {
        stickInput = twinStick.replay();
      } catch (NoRecordDataException e) {
        gameState.isGameOver = true;
        stickInput = twinStick.getNullState();
      }
    }
    if (gameState.isGameOver || cnt < -INVINCIBLE_CNT)
      stickInput.clear();
    vx = stickInput.left.x;
    vy = stickInput.left.y;
    moveRelative();
  }

  private void moveTouch() {
    if (!_replayMode) {
      touchInput = touch.getState();
    } else {
      try {
        touchInput = touch.replay();
      } catch (NoRecordDataException e) {
        gameState.isGameOver = true;
        touchInput = touch.getNullState();
      }
    }
    if (gameState.isGameOver || cnt < -INVINCIBLE_CNT)
      touchInput.clear();
    vec2 location = touchInput.getPrimaryTouch(gameState.movementRegion());
    location -= gameState.movementRegion().center();
    vx = location.x;
    vy = location.y;
    moveRelative();
  }

  private void moveDoublePlay() {
    switch (idx) {
    case 0:
      if (!_replayMode) {
        stickInput = twinStick.getState();
      } else {
        try {
          stickInput = twinStick.replay();
        } catch (NoRecordDataException e) {
          gameState.isGameOver = true;
          stickInput = twinStick.getNullState();
        }
      }
      if (gameState.isGameOver || cnt < -INVINCIBLE_CNT)
        stickInput.clear();
      vx = stickInput.left.x;
      vy = stickInput.left.y;
      break;
    case 1:
      vx = stickInput.right.x;
      vy = stickInput.right.y;
      break;
    default:
      assert(0);
    }
    moveRelative();
  }

  private void moveDoublePlayTouch() {
    CircularTouchRegion boatRegion = new CircularTouchRegion(ship.boat[0]._pos, gameState.touchRadius());
    switch (idx) {
    case 0:
      if (!_replayMode) {
        touchInput = touch.getState();
      } else {
        try {
          touchInput = touch.replay();
        } catch (NoRecordDataException e) {
          gameState.isGameOver = true;
          touchInput = touch.getNullState();
        }
      }
      if (gameState.isGameOver || cnt < -INVINCIBLE_CNT)
        touchInput.clear();
      vec2 location = touchInput.getPrimaryTouch(boatRegion);
      location -= boatRegion.center();
      vx = location.x;
      vy = location.y;
      break;
    case 1:
      TouchRegion[1] ignores;
      ignores[0] = boatRegion;
      CircularTouchRegion secondBoatRegion = new CircularTouchRegion(ship.boat[1]._pos, gameState.touchRadius());
      vec2 location = touchInput.getSecondaryTouch(secondBoatRegion, ignores, 1);
      location -= secondBoatRegion.center();
      vx = location.x;
      vy = location.y;
      break;
    default:
      assert(0);
    }
    moveRelative();
  }

  private void moveTilt() {
    if (!_replayMode) {
      AccelerometerAndTouchState ats = accelerometerAndTouch.getState();
      accelerometerInput = ats.accelerometerState;
      touchInput = ats.touchState;
    } else {
      try {
        AccelerometerAndTouchState ats = accelerometerAndTouch.replay();
        accelerometerInput = ats.accelerometerState;
        touchInput = ats.touchState;
      } catch (NoRecordDataException e) {
        gameState.isGameOver = true;
        accelerometerInput = accelerometer.getNullState();
        touchInput = touch.getNullState();
      }
    }
    if (gameState.isGameOver || cnt < -INVINCIBLE_CNT) {
      accelerometerInput.clear();
      touchInput.clear();
    }
    ax = accelerometerInput.tilt.x;
    ay = accelerometerInput.tilt.y;
    vx += ax;
    vy += ay;
    moveRelative();
  }

  private void moveMouse() {
    if (!_replayMode) {
      MouseAndPadState mps = mouseAndPad.getState();
      padInput = mps.padState;
      mouseInput = mps.mouseState;
    } else {
      try {
        MouseAndPadState mps = mouseAndPad.replay();
        padInput = mps.padState;
        mouseInput = mps.mouseState;
      } catch (NoRecordDataException e) {
        gameState.isGameOver = true;
        padInput = pad.getNullState();
        mouseInput = mouse.getNullState();
      }
    }
    if (gameState.isGameOver || cnt < -INVINCIBLE_CNT) {
      padInput.clear();
      mouseInput.clear();
    }
    if (padInput.dir & PadState.Dir.UP)
      vy = 1;
    if (padInput.dir & PadState.Dir.DOWN)
      vy = -1;
    if (padInput.dir & PadState.Dir.RIGHT)
      vx = 1;
    if (padInput.dir & PadState.Dir.LEFT)
      vx = -1;
    if (vx != 0 && vy != 0) {
      vx *= 0.7f;
      vy *= 0.7f;
    }
    moveRelative();
  }

  private void moveRelative() {
    if (vx != 0 || vy != 0) {
      float ad = atan2(vx, vy);
      assert(!ad.isNaN);
      Math.normalizeDeg(ad);
      ad -= deg;
      Math.normalizeDeg(ad);
      deg += ad * turnRatio * turnSpeed;
      Math.normalizeDeg(deg);
    }
  }

  private void fireNormal() {
    if (padInput.button & PadState.Button.A) {
      turnRatio += (SLOW_TURN_RATIO - turnRatio) * TURN_CHANGE_RATIO;
      fireInterval = FIRE_INTERVAL;
      if (!aPressed) {
        fireCnt = 0;
        aPressed = true;
      }
    } else {
      turnRatio += (TURN_RATIO_BASE - turnRatio) * TURN_CHANGE_RATIO;
      aPressed = false;
      fireInterval *= 1.033f;
      if (fireInterval > FIRE_INTERVAL_MAX)
        fireInterval = 99999;
    }
    fireDeg = deg;
    if (reverseFire)
      fireDeg += PI;
    if (fireCnt <= 0) {
      SoundManager.playSe("shot.wav");
      Shot s = shots.getInstance();
      int foc = (fireSprCnt % 2) * 2 - 1;
      firePos.x = _pos.x + cos(fireDeg + PI) * 0.2f * foc;
      firePos.y = _pos.y - sin(fireDeg + PI) * 0.2f * foc;
      if (s)
        s.set(firePos, fireDeg);
      fireCnt = cast(int) fireInterval;

      fire(foc);
    }
    fireCnt--;
    if (padInput.button & PadState.Button.B) {
      if (!bPressed && fireLanceCnt <= 0 && !shots.existsLance()) {
        SoundManager.playSe("lance.wav");
        float fd = deg;
        if (reverseFire)
          fd += PI;
        Shot s = shots.getInstance();
        if (s)
          s.set(pos, fd, true);
        for (int i = 0; i < 4; i++) {
          Smoke sm = smokes.getInstanceForced();
          float sd = fd + rand.nextSignedFloat(1);
          sm.set(pos,
                 sin(sd) * Shot.LANCE_SPEED * i * 0.2f,
                 cos(sd) * Shot.LANCE_SPEED * i * 0.2f,
                 0, Smoke.SmokeType.SPARK, 15, 0.5f);
        }
        fireLanceCnt = FIRE_LANCE_INTERVAL;
      }
      bPressed = true;
    } else {
      bPressed = false;
    }
    fireLanceCnt--;
  }

  private void fireTwinStick() {
    fireFromLocation(stickInput.right);
  }

  private void fireTouch() {
   vec2 location = touchInput.getPrimaryTouch(gameState.fireRegion());
   location -= gameState.fireRegion().center();
   vx = location.x;
   vy = location.y;

   fireFromLocation(location);
  }

  private void fireFromLocation(vec2 angle) {
   if (fabs(angle.x) + fabs(angle.y) > 0.01f) {
     fireDeg = atan2(angle.x, angle.y);
     assert(!fireDeg.isNaN);
     if (fireCnt <= 0) {
       SoundManager.playSe("shot.wav");
       int foc = (fireSprCnt % 2) * 2 - 1;
       float rsd = angle.length;
       if (rsd > 1)
         rsd = 1;
       fireSprDeg = 1 - rsd + 0.05f;
       firePos.x = _pos.x + cos(fireDeg + PI) * 0.2f * foc;
       firePos.y = _pos.y - sin(fireDeg + PI) * 0.2f * foc;
       fireCnt = cast(int) fireInterval;

       fire(foc);
     }
   } else {
     fireDeg = 99999;
   }
   fireCnt--;
  }

  private void fireDouble() {
    if (gameState.isGameOver || cnt < -INVINCIBLE_CNT)
      return;
    float dist = ship.distAmongBoats();
    fireInterval = FIRE_INTERVAL + 10.0f / (dist + 0.005f);
    if (dist < 2)
      fireInterval = 99999;
    else if (dist < 4)
      fireInterval *= 3;
    else if (dist < 6)
      fireInterval *= 1.6f;
    if (fireCnt > fireInterval)
      fireCnt = cast(int) fireInterval;
    if (fireCnt <= 0) {
      SoundManager.playSe("shot.wav");
      int foc = (fireSprCnt % 2) * 2 - 1;
      fireDeg = 0;//ship.degAmongBoats() + PI / 2;
      firePos.x = _pos.x + cos(fireDeg + PI) * 0.2f * foc;
      firePos.y = _pos.y - sin(fireDeg + PI) * 0.2f * foc;
      Shot s = shots.getInstance();
      if (s)
        s.set(firePos, fireDeg, false , 2);
      fireCnt = cast(int) fireInterval;
      Smoke sm = smokes.getInstanceForced();
      float sd = fireDeg;
      sm.set(firePos, sin(sd) * Shot.SPEED * 0.33f, cos(sd) * Shot.SPEED * 0.33f, 0,
             Smoke.SmokeType.SPARK, 10, 0.33f);
      if (idx == 0) {
        float fd = ship.degAmongBoats() + PI / 2;
        float td;
        switch (foc) {
        case -1:
          td = fireSprDeg * (fireSprCnt / 2 % 4 + 1) * 0.15f;
          break;
        case 1:
          td = -fireSprDeg * (fireSprCnt / 2 % 4 + 1) * 0.15f;
          break;
        default:
          assert(0);
        }
        firePos.x = ship.midstPos.x + cos(fd + PI) * 0.2f * foc;
        firePos.y = ship.midstPos.y - sin(fd + PI) * 0.2f * foc;
        s = shots.getInstance();
        if (s)
          s.set(firePos, fd, false, 2);
        s = shots.getInstance();
        if (s)
          s.set(firePos, fd + td, false , 2);
        sm = smokes.getInstanceForced();
        sm.set(firePos, sin(fd + td / 2) * Shot.SPEED * 0.33f, cos(fd + td / 2) * Shot.SPEED * 0.33f, 0,
               Smoke.SmokeType.SPARK, 10, 0.33f);
      }
      fireSprCnt++;
    }
    fireCnt--;
  }

  private void fireTilt() {
   CircularTouchRegion boatRegion = new CircularTouchRegion(ship.boat[0]._pos, gameState.touchRadius());
   vec2 location = touchInput.getPrimaryTouch(boatRegion);
   location -= boatRegion.center();
   vx = location.x;
   vy = location.y;

   fireFromLocation(location);
  }

  private void fireMouse() {
    float fox = mouseInput.x - _pos.x;
    float foy = mouseInput.y - _pos.y;
    if (fabs(fox) < 0.01f)
      fox = 0.01f;
    if (fabs(foy) < 0.01f)
      foy = 0.01f;
    fireDeg = atan2(fox, foy);
    assert(!fireDeg.isNaN);
    if (mouseInput.button & (MouseState.Button.LEFT | MouseState.Button.RIGHT)) {
      if (fireCnt <= 0) {
        SoundManager.playSe("shot.wav");
        int foc = (fireSprCnt % 2) * 2 - 1;
        float fstd = 0.05f;
        if (mouseInput.button & MouseState.Button.RIGHT)
          fstd += 0.5f;
        fireSprDeg += (fstd - fireSprDeg) * 0.16f;
        firePos.x = _pos.x + cos(fireDeg + PI) * 0.2f * foc;
        firePos.y = _pos.y - sin(fireDeg + PI) * 0.2f * foc;
        fireCnt = cast(int) fireInterval;

        fire(foc);
      }
    }
    fireCnt--;
  }

  private void fire(int foc) {
    float td;
    switch (foc) {
    case -1:
      td = fireSprDeg * (fireSprCnt / 2 % 4 + 1) * 0.2f;
      break;
    case 1:
      td = -fireSprDeg * (fireSprCnt / 2 % 4 + 1) * 0.2f;
      break;
    default:
      assert(0);
    }
    fireSprCnt++;
    Shot s = shots.getInstance();
    if (s)
      s.set(firePos, fireDeg + td / 2, false, 2);
    s = shots.getInstance();
    if (s)
      s.set(firePos, fireDeg + td, false, 2);
    Smoke sm = smokes.getInstanceForced();
    float sd = fireDeg + td / 2;
    sm.set(firePos, sin(sd) * Shot.SPEED * 0.33f, cos(sd) * Shot.SPEED * 0.33f, 0,
           Smoke.SmokeType.SPARK, 10, 0.33f);
  }

  public bool checkBulletHit(vec2 p, vec2 pp) {
    if (cnt <= 0)
      return false;
    float bmvx, bmvy, inaa;
    bmvx = pp.x;
    bmvy = pp.y;
    bmvx -= p.x;
    bmvy -= p.y;
    inaa = bmvx * bmvx + bmvy * bmvy;
    if (inaa > 0.00001) {
      float sofsx, sofsy, inab, hd;
      sofsx = _pos.x;
      sofsy = _pos.y;
      sofsx -= p.x;
      sofsy -= p.y;
      inab = bmvx * sofsx + bmvy * sofsy;
      if (inab >= 0 && inab <= inaa) {
        hd = sofsx * sofsx + sofsy * sofsy - inab * inab / inaa;
        if (hd >= 0 && hd <= HIT_WIDTH) {
          destroyed();
          return true;
        }
      }
    }
    return false;
  }

  private void destroyed() {
    if (cnt <= 0)
      return;
    if (shieldCnt > 0) {
      destroyedBoatShield();
      return;
    }
    ship.destroyed();
    gameState.shipDestroyed();
  }

  private void destroyedBoatShield() {
    for (int i = 0; i < 100; i++) {
      Spark sp = sparks.getInstanceForced();
      sp.set(pos, rand.nextSignedFloat(1), rand.nextSignedFloat(1),
             0.5f + rand.nextFloat(0.5f), 0.5f + rand.nextFloat(0.5f), 0,
             40 + rand.nextInt(40));
    }
    SoundManager.playSe("ship_shield_lost.wav");
    screen.setScreenShake(30, 0.02f);
    shieldCnt = 0;
    cnt = -INVINCIBLE_CNT / 2;
  }

  public void destroyedBoat() {
    for (int i = 0; i < 128; i++) {
      Spark sp = sparks.getInstanceForced();
      sp.set(pos, rand.nextSignedFloat(1), rand.nextSignedFloat(1),
             0.5f + rand.nextFloat(0.5f), 0.5f + rand.nextFloat(0.5f), 0,
             40 + rand.nextInt(40));
    }
    SoundManager.playSe("ship_destroyed.wav");
    for (int i = 0; i < 64; i++) {
      Smoke s = smokes.getInstanceForced();
      s.set(pos, rand.nextSignedFloat(0.2f), rand.nextSignedFloat(0.2f),
            rand.nextFloat(0.1f),
            Smoke.SmokeType.EXPLOSION, 50 + rand.nextInt(30), 1);
    }
    screen.setScreenShake(60, 0.05f);
    restart();
    cnt = -RESTART_CNT;
  }

  public bool hasCollision() {
    if (cnt < -INVINCIBLE_CNT)
      return false;
    else
      return true;
  }

  public void draw(mat4 view) {
    if (cnt < -INVINCIBLE_CNT)
      return;
    if (fireDeg < 99999) {
      lineProgram.use();

      lineProgram.setUniform("brightness", Screen.brightness);
      lineProgram.setUniform("pos", _pos);
      lineProgram.setUniform("deg", fireDeg);

      glBindVertexArray(vao[1]);
      glDrawArrays(GL_LINE_STRIP, 0, 2);
    }
    if (cnt < 0 && (-cnt % 32) < 16)
      return;

    mat4 model = mat4.identity;
    model.rotate(deg, vec3(0, 0, 1));
    model.translate(pos.x, pos.y, 0);

    _shape.draw(view, model);
    bridgeShape.draw(view, model);

    if (shieldCnt > 0) {
      float ss = 0.66f;
      if (shieldCnt < 120)
        ss *= cast(float) shieldCnt / 120;

      mat4 shield = mat4.identity;
      shield.scale(ss, ss, ss);
      shield.rotate(-shieldCnt * 5. / 180 * PI, vec3(0, 0, 1));

      shieldShape.draw(view, model * shield);
    }
  }

  public void drawFront(mat4 view) {
    if (cnt < -INVINCIBLE_CNT)
      return;
    if (gameMode == InGameState.GameMode.MOUSE) {
      sightProgram.use();

      sightProgram.setUniform("brightness", Screen.brightness);
      sightProgram.setUniform("projmat", view);

      Screen.lineWidth(2);

      sightProgram.setUniform("color", 0.7f, 0.9f, 0.8f, 1);
      drawSight(mouseInput.x, mouseInput.y, 0.3f);

      float ss = 0.9f - 0.8f * ((cnt + 1024) % 32) / 32;

      sightProgram.setUniform("color", 0.5f, 0.9f, 0.7f, 0.8f);
      drawSight(mouseInput.x, mouseInput.y, ss);

      Screen.lineWidth(1);
    }
  }

  private void drawSight(float x, float y, float size) {
    sightProgram.setUniform("pos", x, y);
    sightProgram.setUniform("size", size);

    glBindVertexArray(vao[0]);
    glDrawArrays(GL_LINE_STRIP, 0, 3);
    glDrawArrays(GL_LINE_STRIP, 3, 3);
    glDrawArrays(GL_LINE_STRIP, 6, 3);
    glDrawArrays(GL_LINE_STRIP, 9, 3);
  }

  public void drawShape(mat4 view, mat4 model) {
    _shape.draw(view, model);
    bridgeShape.draw(view, model);
  }

  public void clearBullets() {
    gameState.clearBullets();
  }

  public vec2 pos() {
    return _pos;
  }

  public vec2 vel() {
    return _vel;
  }

  public void setReplayMode(float turnSpeed, bool reverseFire) {
    _replayMode = true;
    this.turnSpeed = turnSpeed;
    this.reverseFire = reverseFire;
  }

  public void unsetReplayMode() {
    _replayMode = false;
    turnSpeed = GameManager.shipTurnSpeed;
    reverseFire = GameManager.shipReverseFire;
  }

  public bool replayMode() {
    return _replayMode;
  }
}
