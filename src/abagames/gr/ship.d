/*
 * $Id: ship.d,v 1.4 2005/09/11 00:47:40 kenta Exp $
 *
 * Copyright 2005 Kenta Cho. Some rights reserved.
 */
module abagames.gr.ship;

private import std.math;
private import opengl;
private import abagames.util.vector;
private import abagames.util.rand;
private import abagames.util.math;
private import abagames.util.sdl.pad;
private import abagames.util.sdl.twinstick;
private import abagames.util.sdl.mouse;
private import abagames.util.sdl.recordableinput;
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
private import abagames.gr.mouseandpad;

/**
 * Player's ship.
 */
public class Ship {
 private:
  static const float SCROLL_SPEED_BASE = 0.01f;
  static const float SCROLL_SPEED_MAX = 0.1f;
  static const float SCROLL_START_Y = 2.5f;
  Field field;
  Boat[2] boat;
  int gameMode;
  int boatNum;
  InGameState gameState;
  float scrollSpeed, _scrollSpeedBase;
  Vector _midstPos, _higherPos, _lowerPos, _nearPos, _nearVel;
  BaseShape bridgeShape;

  invariant {
    assert(boatNum >= 1 && boatNum <= boat.length);
    assert(scrollSpeed > 0);
    assert(_scrollSpeedBase > 0);
  }

  public this(Pad pad, TwinStick twinStick, Mouse mouse, RecordableMouseAndPad mouseAndPad,
              Field field, Screen screen,
              SparkPool sparks, SmokePool smokes, FragmentPool fragments, WakePool wakes) {
    this.field = field;
    Boat.init();
    int i = 0;
    foreach (inout Boat b; boat) {
      b = new Boat(i, this, pad, twinStick, mouse, mouseAndPad,
                   field, screen, sparks, smokes, fragments, wakes);
      i++;
    }
    boatNum = 1;
    scrollSpeed = _scrollSpeedBase = SCROLL_SPEED_BASE;
    _midstPos = new Vector;
    _higherPos = new Vector;
    _lowerPos = new Vector;
    _nearPos = new Vector;
    _nearVel = new Vector;
    bridgeShape = new BaseShape(0.3f, 0.2f, 0.1f, BaseShape.ShapeType.BRIDGE, 0.3f, 0.7f, 0.7f);
  }

  public void setRandSeed(long seed) {
    Boat.setRandSeed(seed);
  }

  public void close() {
    foreach (Boat b; boat)
      b.close();
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
    if (gameMode == InGameState.GameMode.DOUBLE_PLAY)
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

  public bool checkBulletHit(Vector p, Vector pp) {
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

  public void draw() {
    for (int i = 0; i < boatNum; i++)
      boat[i].draw();
    if (gameMode == InGameState.GameMode.DOUBLE_PLAY && boat[0].hasCollision) {
      Screen.setColor(0.5f, 0.5f, 0.9f, 0.8f);
      glBegin(GL_LINE_STRIP);
      glVertex2f(boat[0].pos.x, boat[0].pos.y);
      Screen.setColor(0.5f, 0.5f, 0.9f, 0.3f);
      glVertex2f(midstPos.x, midstPos.y);
      Screen.setColor(0.5f, 0.5f, 0.9f, 0.8f);
      glVertex2f(boat[1].pos.x, boat[1].pos.y);
      glEnd();
      glPushMatrix();
      Screen.glTranslate(midstPos);
      glRotatef(-degAmongBoats * 180 / PI, 0, 0, 1);
      bridgeShape.draw();
      glPopMatrix();
    }
  }

  public void drawFront() {
    for (int i = 0; i < boatNum; i++)
      boat[i].drawFront();
  }
  
  public void drawShape() {
    boat[0].drawShape();
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

  public Vector midstPos() {
    _midstPos.x = _midstPos.y = 0;
    for (int i = 0; i < boatNum; i++) {
      _midstPos.x += boat[i].pos.x;
      _midstPos.y += boat[i].pos.y;
    }
    _midstPos /= boatNum;
    return _midstPos;
  }

  public Vector higherPos() {
    _higherPos.y = -99999;
    for (int i = 0; i < boatNum; i++) {
      if (boat[i].pos.y > _higherPos.y) {
        _higherPos.x = boat[i].pos.x;
        _higherPos.y = boat[i].pos.y;
      }
    }
    return _higherPos;
  }

  public Vector lowerPos() {
    _lowerPos.y = 99999;
    for (int i = 0; i < boatNum; i++) {
      if (boat[i].pos.y < _lowerPos.y) {
        _lowerPos.x = boat[i].pos.x;
        _lowerPos.y = boat[i].pos.y;
      }
    }
    return _lowerPos;
  }

  public Vector nearPos(Vector p) {
    float dist = 99999;
    for (int i = 0; i < boatNum; i++) {
      if (boat[i].pos.dist(p) < dist) {
        dist = boat[i].pos.dist(p);
        _nearPos.x = boat[i].pos.x;
        _nearPos.y = boat[i].pos.y;
      }
    }
    return _nearPos;
  }

  public Vector nearVel(Vector p) {
    float dist = 99999;
    for (int i = 0; i < boatNum; i++) {
      if (boat[i].pos.dist(p) < dist) {
        dist = boat[i].pos.dist(p);
        _nearVel.x = boat[i].vel.x;
        _nearVel.y = boat[i].vel.y;
      }
    }
    return _nearVel;
  }

  public float distAmongBoats() {
    return boat[0].pos.dist(boat[1].pos);
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
  static MouseState mouseInput;
  RecordablePad pad;
  RecordableTwinStick twinStick;
  RecordableMouse mouse;
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
  Vector _pos;
  Vector firePos;
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
  Vector _vel;
  Vector refVel;
  int shieldCnt;
  ShieldShape shieldShape;
  bool _replayMode;
  float turnSpeed;
  bool reverseFire;
  int gameMode;
  float vx, vy;
  int idx;
  Ship ship;

  invariant {
    assert(_pos.x < 15 && _pos.x > -15);
    assert(_pos.y < 20 && _pos.y > -20);
    assert(firePos.x < 15 && firePos.x > -15);
    assert(firePos.y < 20 && firePos.y > -20);
    assert(deg <>= 0);
    assert(speed >= 0 && speed <= SPEED_BASE);
    assert(turnRatio >= 0 && turnRatio <= TURN_RATIO_BASE);
    assert(turnSpeed >= 0);
    assert(fireInterval >= FIRE_INTERVAL);
    assert(fireSprDeg <>= 0);
    assert(cnt >= -RESTART_CNT);
    assert(_vel.x < 2 && _vel.x > -2);
    assert(_vel.y < 2 && _vel.y > -2);
    assert(refVel.x < 1 && refVel.x > -1);
    assert(refVel.y < 1 && refVel.y > -1);
    assert(shieldCnt >= 0);
  }

  public static void init() {
    rand = new Rand;
  }

  public static void setRandSeed(long seed) {
    rand.setSeed(seed);
  }

  public this(int idx, Ship ship,
              Pad pad, TwinStick twinStick, Mouse mouse, RecordableMouseAndPad mouseAndPad,
              Field field, Screen screen,
              SparkPool sparks, SmokePool smokes, FragmentPool fragments, WakePool wakes) {
    this.idx = idx;
    this.ship = ship;
    this.pad = cast(RecordablePad) pad;
    this.twinStick = cast(RecordableTwinStick) twinStick;
    this.mouse = cast(RecordableMouse) mouse;
    this.mouseAndPad = mouseAndPad;
    this.field = field;
    this.screen = screen;
    this.sparks = sparks;
    this.smokes = smokes;
    this.fragments = fragments;
    this.wakes = wakes;
    _pos = new Vector;
    firePos = new Vector;
    _vel = new Vector;
    refVel = new Vector;
    switch (idx) {
    case 0:
      _shape = new BaseShape(0.7f, 0.6f, 0.6f, BaseShape.ShapeType.SHIP_ROUNDTAIL, 0.5f, 0.7f, 0.5f);
      bridgeShape = new BaseShape(0.3f, 0.6f, 0.6f, BaseShape.ShapeType.BRIDGE, 0.3f, 0.7f, 0.3f);
      break;
    case 1:
      _shape = new BaseShape(0.7f, 0.6f, 0.6f, BaseShape.ShapeType.SHIP_ROUNDTAIL, 0.4f, 0.3f, 0.8f);
      bridgeShape = new BaseShape(0.3f, 0.6f, 0.6f, BaseShape.ShapeType.BRIDGE, 0.2f, 0.3f, 0.6f);
      break;
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
    if (gameMode == InGameState.GameMode.DOUBLE_PLAY) {
      switch (idx) {
      case 0:
        _pos.x = -field.size.x * 0.5f;
        break;
      case 1:
        _pos.x = field.size.x * 0.5f;
        break;
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
    mouseInput = mouse.getNullState();
  }

  public void restart() {
    switch (gameMode) {
    case InGameState.GameMode.NORMAL:
      fireCnt = 99999;
      fireInterval = 99999;
      break;
    case InGameState.GameMode.TWIN_STICK:
    case InGameState.GameMode.DOUBLE_PLAY:
    case InGameState.GameMode.MOUSE:
      fireCnt = 0;
      fireInterval = FIRE_INTERVAL;
      break;
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
    vx = vy = 0;
    switch (gameMode) {
    case InGameState.GameMode.NORMAL:
      moveNormal();
      break;
    case InGameState.GameMode.TWIN_STICK:
      moveTwinStick();
      break;
    case InGameState.GameMode.DOUBLE_PLAY:
      moveDoublePlay();
      break;
    case InGameState.GameMode.MOUSE:
      moveMouse();
      break;
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
      if (!onBlock)
        if (cnt <= 0)
          onBlock = true;
        else {
          if (field.checkInField(_pos.x, _pos.y - field.lastScrollY)) {
            _pos.x = px;
            _pos.y = py;
          } else {
            destroyed();
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
    case InGameState.GameMode.DOUBLE_PLAY:
      fireDobulePlay();
      break;
    case InGameState.GameMode.MOUSE:
      fireMouse();
      break;
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
      if (pos.dist(he.pos) < 0.1f)
        rd = 0;
      else
        rd = atan2(_pos.x - he.pos.x, _pos.y - he.pos.y);
      assert(rd <>= 0);
      float sz = he.size;
      refVel.x = sin(rd) * sz * 0.1f;
      refVel.y = cos(rd) * sz * 0.1f;
      float rs = refVel.vctSize;
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
    if (vx != 0 || vy != 0) {
      float ad = atan2(vx, vy);
      assert(ad <>= 0);
      Math.normalizeDeg(ad);
      ad -= deg;
      Math.normalizeDeg(ad);
      deg += ad * turnRatio * turnSpeed;
      Math.normalizeDeg(deg);
    }
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
    if (vx != 0 || vy != 0) {
      float ad = atan2(vx, vy);
      assert(ad <>= 0);
      Math.normalizeDeg(ad);
      ad -= deg;
      Math.normalizeDeg(ad);
      deg += ad * turnRatio * turnSpeed;
      Math.normalizeDeg(deg);
    }
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
    }
    if (vx != 0 || vy != 0) {
      float ad = atan2(vx, vy);
      assert(ad <>= 0);
      Math.normalizeDeg(ad);
      ad -= deg;
      Math.normalizeDeg(ad);
      deg += ad * turnRatio * turnSpeed;
      Math.normalizeDeg(deg);
    }
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
    if (vx != 0 || vy != 0) {
      float ad = atan2(vx, vy);
      assert(ad <>= 0);
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
      float td;
      switch (foc) {
      case -1:
        td = fireSprDeg * (fireSprCnt / 2 % 4 + 1) * 0.2f;
        break;
      case 1:
        td = -fireSprDeg * (fireSprCnt / 2 % 4 + 1) * 0.2f;
        break;
      }
      fireSprCnt++;
      s = shots.getInstance();
      if (s)
        s.set(firePos, fireDeg + td);
      Smoke sm = smokes.getInstanceForced();
      float sd = fireDeg + td / 2;
      sm.set(firePos, sin(sd) * Shot.SPEED * 0.33f, cos(sd) * Shot.SPEED * 0.33f, 0,
             Smoke.SmokeType.SPARK, 10, 0.33f);
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
    if (fabs(stickInput.right.x) + fabs(stickInput.right.y) > 0.01f) {
      fireDeg = atan2(stickInput.right.x, stickInput.right.y);
      assert(fireDeg <>= 0);
      if (fireCnt <= 0) {
        SoundManager.playSe("shot.wav");
        int foc = (fireSprCnt % 2) * 2 - 1;
        float rsd = stickInput.right.vctSize;
        if (rsd > 1)
          rsd = 1;
        fireSprDeg = 1 - rsd + 0.05f;
        firePos.x = _pos.x + cos(fireDeg + PI) * 0.2f * foc;
        firePos.y = _pos.y - sin(fireDeg + PI) * 0.2f * foc;
        fireCnt = cast(int) fireInterval;
        float td;
        switch (foc) {
        case -1:
          td = fireSprDeg * (fireSprCnt / 2 % 4 + 1) * 0.2f;
          break;
        case 1:
          td = -fireSprDeg * (fireSprCnt / 2 % 4 + 1) * 0.2f;
          break;
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
    } else {
      fireDeg = 99999;
    }
    fireCnt--;
  }

  private void fireDobulePlay() {
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

  private void fireMouse() {
    float fox = mouseInput.x - _pos.x;
    float foy = mouseInput.y - _pos.y;
    if (fabs(fox) < 0.01f)
      fox = 0.01f;
    if (fabs(foy) < 0.01f)
      foy = 0.01f;
    fireDeg = atan2(fox, foy);
    assert(fireDeg <>= 0);
    if (mouseInput.button & (MouseState.Button.LEFT | MouseState.Button.RIGHT)) {
      if (fireCnt <= 0) {
        SoundManager.playSe("shot.wav");
        int foc = (fireSprCnt % 2) * 2 - 1;
        float rsd = stickInput.right.vctSize;
        float fstd = 0.05f;
        if (mouseInput.button & MouseState.Button.RIGHT)
          fstd += 0.5f;
        fireSprDeg += (fstd - fireSprDeg) * 0.16f;
        firePos.x = _pos.x + cos(fireDeg + PI) * 0.2f * foc;
        firePos.y = _pos.y - sin(fireDeg + PI) * 0.2f * foc;
        fireCnt = cast(int) fireInterval;
        float td;
        switch (foc) {
        case -1:
          td = fireSprDeg * (fireSprCnt / 2 % 4 + 1) * 0.2f;
          break;
        case 1:
          td = -fireSprDeg * (fireSprCnt / 2 % 4 + 1) * 0.2f;
          break;
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
    }
    fireCnt--;
  }

  public bool checkBulletHit(Vector p, Vector pp) {
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

  public void draw() {
    if (cnt < -INVINCIBLE_CNT)
      return;
    if (fireDeg < 99999) {
      Screen.setColor(0.5f, 0.9f, 0.7f, 0.4f);
      glBegin(GL_LINE_STRIP);
      glVertex2f(_pos.x, _pos.y);
      Screen.setColor(0.5f, 0.9f, 0.7f, 0.8f);
      glVertex2f(_pos.x + sin(fireDeg) * 20, _pos.y + cos(fireDeg) * 20);
      glEnd();
    }
    if (cnt < 0 && (-cnt % 32) < 16)
      return;
    glPushMatrix();
    Screen.glTranslate(pos);
    glRotatef(-deg * 180 / PI, 0, 0, 1);
    _shape.draw();
    bridgeShape.draw();
    if (shieldCnt > 0) {
      float ss = 0.66f;
      if (shieldCnt < 120)
        ss *= cast(float) shieldCnt / 120;
      glScalef(ss, ss, ss);
      glRotatef(shieldCnt * 5, 0, 0, 1);
      shieldShape.draw();
    }
    glPopMatrix();
  }

  public void drawFront() {
    if (cnt < -INVINCIBLE_CNT)
      return;
    if (gameMode == InGameState.GameMode.MOUSE) {
      Screen.setColor(0.7f, 0.9f, 0.8f, 1.0f);
      Screen.lineWidth(2);
      drawSight(mouseInput.x, mouseInput.y, 0.3f);
      float ss = 0.9f - 0.8f * ((cnt + 1024) % 32) / 32;
      Screen.setColor(0.5f, 0.9f, 0.7f, 0.8f);
      drawSight(mouseInput.x, mouseInput.y, ss);
      Screen.lineWidth(1);
    }
  }

  private void drawSight(float x, float y, float size) {
    glBegin(GL_LINE_STRIP);
    glVertex2f(x - size, y - size * 0.5f);
    glVertex2f(x - size, y - size);
    glVertex2f(x - size * 0.5f, y - size);
    glEnd();
    glBegin(GL_LINE_STRIP);
    glVertex2f(x + size, y - size * 0.5f);
    glVertex2f(x + size, y - size);
    glVertex2f(x + size * 0.5f, y - size);
    glEnd();
    glBegin(GL_LINE_STRIP);
    glVertex2f(x + size, y + size * 0.5f);
    glVertex2f(x + size, y + size);
    glVertex2f(x + size * 0.5f, y + size);
    glEnd();
    glBegin(GL_LINE_STRIP);
    glVertex2f(x - size, y + size * 0.5f);
    glVertex2f(x - size, y + size);
    glVertex2f(x - size * 0.5f, y + size);
    glEnd();
  }

  public void drawShape() {
    _shape.draw();
    bridgeShape.draw();
  }

  public void clearBullets() {
    gameState.clearBullets();
  }

  public Vector pos() {
    return _pos;
  }

  public Vector vel() {
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
