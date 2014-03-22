/*
 * $Id: bullet.d,v 1.1.1.1 2005/06/18 00:46:00 kenta Exp $
 *
 * Copyright 2005 Kenta Cho. Some rights reserved.
 */
module abagames.gr.bullet;

private import std.math;
private import std.c.stdarg;
private import opengl;
private import abagames.util.actor;
private import abagames.util.vector;
private import abagames.util.math;
private import abagames.util.sdl.shape;
private import abagames.gr.gamemanager;
private import abagames.gr.field;
private import abagames.gr.ship;
private import abagames.gr.screen;
private import abagames.gr.enemy;
private import abagames.gr.shot;
private import abagames.gr.particle;
private import abagames.gr.crystal;
private import abagames.gr.shape;

/**
 * Enemy's bullets.
 */
public class Bullet: Actor {
 private:
  GameManager gameManager;
  Field field;
  Ship ship;
  SmokePool smokes;
  WakePool wakes;
  CrystalPool crystals;
  Vector pos;
  Vector ppos;
  float deg, speed;
  float trgDeg, trgSpeed;
  float size;
  int cnt;
  float range;
  bool _destructive;
  BulletShape shape;
  int _enemyIdx;

  invariant {
    assert(pos.x < 15 && pos.x > -15);
    assert(pos.y < 40 && pos.y > -20);
    assert(ppos.x < 15 && ppos.x > -15);
    assert(ppos.y < 40 && ppos.y > -20);
    assert(deg <>= 0);
    assert(trgDeg <>= 0);
    assert(speed > -5 && speed < 10);
    assert(trgSpeed >= 0 && trgSpeed < 10);
    assert(size > 0 && size < 10);
    assert(range > -20);
  }

  public this() {
    pos = new Vector;
    ppos = new Vector;
    shape = new BulletShape;
    deg = trgDeg = 0;
    speed = trgSpeed = 1;
    size = 1;
    range = 1;
  }

  public override void init(Object[] args) {
    gameManager = cast(GameManager) args[0];
    field = cast(Field) args[1];
    ship = cast(Ship) args[2];
    smokes = cast(SmokePool) args[3];
    wakes = cast(WakePool) args[4];
    crystals = cast(CrystalPool) args[5];
  }

  public void set(int enemyIdx,
                  Vector p, float deg,
                  float speed, float size, int shapeType, float range,
                  float startSpeed = 0, float startDeg = -99999,
                  bool destructive = false) {
    if (!field.checkInOuterFieldExceptTop(p))
      return;
    _enemyIdx = enemyIdx;
    ppos.x = pos.x = p.x;
    ppos.y = pos.y = p.y;
    this.speed = startSpeed;
    if (startDeg == -99999)
      this.deg = deg;
    else
      this.deg = startDeg;
    trgDeg = deg;
    trgSpeed = speed;
    this.size = size;
    this.range = range;
    _destructive = destructive;
    shape.set(shapeType);
    shape.size = size;
    cnt = 0;
    exists = true;
  }

  public override void move() {
    ppos.x = pos.x;
    ppos.y = pos.y;
    if (cnt < 30) {
      speed += (trgSpeed - speed) * 0.066f;
      float md = trgDeg - deg;
      Math.normalizeDeg(md);
      deg += md * 0.066f;
      if (cnt == 29) {
        speed = trgSpeed;
        deg = trgDeg;
      }
    }
    if (field.checkInOuterField(pos))
      gameManager.addSlowdownRatio(speed * 0.24f);
    float mx = sin(deg) * speed;
    float my = cos(deg) * speed;
    pos.x += mx;
    pos.y += my;
    pos.y -= field.lastScrollY;
    if (ship.checkBulletHit(pos, ppos) || !field.checkInOuterFieldExceptTop(pos)) {
      remove();
      return;
    }
    cnt++;
    range -= speed;
    if (range <= 0)
      startDisappear();
    if (field.getBlock(pos) >= Field.ON_BLOCK_THRESHOLD)
      startDisappear();
  }

  public void startDisappear() {
    if (field.getBlock(pos) >= 0) {
      Smoke s = smokes.getInstanceForced();
      s.set(pos, sin(deg) * speed * 0.2f, cos(deg) * speed * 0.2f, 0,
            Smoke.SmokeType.SAND, 30, size * 0.5f);
    } else {
      Wake w = wakes.getInstanceForced();
      w.set(pos, deg, speed, 60, size * 3, true);
    }
    remove();
  }

  public void changeToCrystal() {
    Crystal c = crystals.getInstance();
    if (c)
      c.set(pos);
    remove();
  }

  public void remove() {
    exists = false;
  }

  public override void draw() {
    if (!field.checkInOuterField(pos))
      return;
    glPushMatrix();
    Screen.glTranslate(pos);
    if (_destructive) {
      glRotatef(cnt * 13, 0, 0, 1);
    } else {
      glRotatef(-deg * 180 / PI, 0, 0, 1);
      glRotatef(cnt * 13, 0, 1, 0);
    }
    shape.draw();
    glPopMatrix();
  }

  public void checkShotHit(Vector p, Collidable s, Shot shot) {
    float ox = fabs(pos.x - p.x), oy = fabs(pos.y - p.y);
    if (ox + oy < 0.5f) {
    //if (shape.checkCollision(ox, oy, s)) {
      shot.removeHitToBullet();
      Smoke s = smokes.getInstance();
      if (s)
        s.set(pos, sin(deg) * speed, cos(deg) * speed, 0,
              Smoke.SmokeType.SPARK, 30, size * 0.5f);
      remove();
    }
  }

  public bool destructive() {
    return _destructive;
  }

  public int enemyIdx() {
    return _enemyIdx;
  }
}

public class BulletPool: ActorPool!(Bullet) {
  public this(int n, Object[] args) {
    super(n, args);
  }

  public int removeIndexedBullets(int idx) {
    int n = 0;
    foreach (Bullet b; actor) {
      if (b.exists && b.enemyIdx == idx) {
        b.changeToCrystal();
        n++;
      }
    }
    return n;
  }

  public void checkShotHit(Vector pos, Collidable shape, Shot shot) {
    foreach (Bullet b; actor)
      if (b.exists && b.destructive)
        b.checkShotHit(pos, shape, shot);
  }
}
