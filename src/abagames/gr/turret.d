/*
 * $Id: turret.d,v 1.3 2005/07/17 11:02:46 kenta Exp $
 *
 * Copyright 2005 Kenta Cho. Some rights reserved.
 */
module abagames.gr.turret;

private import std.math;
private import opengl;
private import abagames.util.vector;
private import abagames.util.actor;
private import abagames.util.rand;
private import abagames.util.math;
private import abagames.util.sdl.shape;
private import abagames.gr.field;
private import abagames.gr.bullet;
private import abagames.gr.ship;
private import abagames.gr.screen;
private import abagames.gr.particle;
private import abagames.gr.shot;
private import abagames.gr.shape;
private import abagames.gr.enemy;
private import abagames.gr.soundmanager;

/**
 * Turret mounted on a deck of an enemy ship.
 */
public class Turret {
 private:
  static Rand rand;
  static Vector damagedPos;
  Field field;
  BulletPool bullets;
  Ship ship;
  SparkPool sparks;
  SmokePool smokes;
  FragmentPool fragments;
  TurretSpec spec;
  Vector pos;
  float deg, baseDeg;
  int cnt;
  int appCnt;
  int startCnt;
  int shield;
  bool damaged;
  int destroyedCnt;
  int damagedCnt;
  float bulletSpeed;
  int burstCnt;
  Enemy parent;

  invariant {
    assert(pos.x < 15 && pos.x > -15);
    assert(pos.y < 60 && pos.y > -40);
    assert(deg <>= 0);
    assert(baseDeg <>= 0);
    assert(bulletSpeed > 0);
  }

  public static void init() {
    rand = new Rand;
    damagedPos = new Vector;
  }

  public static void setRandSeed(long seed) {
    rand.setSeed(seed);
  }

  public this(Field field, BulletPool bullets, Ship ship,
              SparkPool sparks, SmokePool smokes, FragmentPool fragments,
              Enemy parent) {
    this.field = field;
    this.bullets = bullets;
    this.ship = ship;
    this.sparks = sparks;
    this.smokes = smokes;
    this.fragments = fragments;
    this.parent = parent;
    pos = new Vector;
    deg = baseDeg = 0;
    bulletSpeed = 1;
  }

  public void start(TurretSpec spec) {
    this.spec = spec;
    shield = spec.shield;
    appCnt = cnt = startCnt = 0;
    deg = baseDeg = 0;
    damaged = false;
    damagedCnt = 0;
    destroyedCnt = -1;
    bulletSpeed = 1;
    burstCnt = 0;
  }

  public bool move(float x, float y, float d, float bulletFireSpeed = 0, float bulletFireDeg = -99999) {
    pos.x = x;
    pos.y = y;
    baseDeg = d;
    if (destroyedCnt >= 0) {
      destroyedCnt++;
      int itv = 5 + destroyedCnt / 12;
      if (itv < 60 && destroyedCnt % itv == 0) {
        Smoke s = smokes.getInstance();
        if (s)
          s.set(pos, 0, 0, 0.01f + rand.nextFloat(0.01f), Smoke.SmokeType.FIRE, 90 + rand.nextInt(30), spec.size);
      }
      return false;
    }
    float td = baseDeg + deg;
    Vector shipPos = ship.nearPos(pos);
    Vector shipVel = ship.nearVel(pos);
    float ax = shipPos.x - pos.x;
    float ay = shipPos.y - pos.y;
    if (spec.lookAheadRatio != 0) {
      float rd = pos.dist(shipPos) / spec.speed * 1.2f;
      ax += shipVel.x * spec.lookAheadRatio * rd;
      ay += shipVel.y * spec.lookAheadRatio * rd;
    }
    float ad;
    if (fabs(ax) + fabs(ay) < 0.1f)
      ad = 0;
    else
      ad = atan2(ax, ay);
    assert(ad <>= 0);
    float od = td - ad;
    Math.normalizeDeg(od);
    float ts;
    if (cnt >= 0)
      ts = spec.turnSpeed;
    else
      ts = spec.turnSpeed * spec.burstTurnRatio;
    if (fabs(od) <= ts)
      deg = ad - baseDeg;
    else if (od > 0)
      deg -= ts;
    else
      deg += ts;
    Math.normalizeDeg(deg);
    if (deg > spec.turnRange)
      deg = spec.turnRange;
    else if (deg < -spec.turnRange)
      deg = -spec.turnRange;
    cnt++;
    if (field.checkInField(pos) || (parent.isBoss && cnt % 4 == 0))
      appCnt++;
    if (cnt >= spec.interval) {
      if (spec.blind || (fabs(od) <= spec.turnSpeed &&
                         pos.dist(shipPos) < spec.maxRange * 1.1f &&
                         pos.dist(shipPos) > spec.minRange)) {
        cnt = -(spec.burstNum - 1) * spec.burstInterval;
        bulletSpeed = spec.speed;
        burstCnt = 0;
      }
    }
    if (cnt <= 0 && -cnt % spec.burstInterval == 0 &&
        ((spec.invisible && field.checkInField(pos)) ||
         (spec.invisible && parent.isBoss && field.checkInOuterField(pos)) ||
         (!spec.invisible && field.checkInFieldExceptTop(pos))) &&
        pos.dist(shipPos) > spec.minRange) {
      float bd = baseDeg + deg;
      Smoke s = smokes.getInstance();
      if (s)
        s.set(pos, sin(bd) * bulletSpeed, cos(bd) * bulletSpeed, 0,
              Smoke.SmokeType.SPARK, 20, spec.size * 2);
      int nw = spec.nway;
      if (spec.nwayChange && burstCnt % 2 == 1)
        nw--;
      bd -= spec.nwayAngle * (nw - 1) / 2;
      for (int i = 0; i < nw; i++) {
        Bullet b = bullets.getInstance();
        if (!b)
          break;
        b.set(parent.index,
              pos, bd, bulletSpeed, spec.size * 3, spec.bulletShape, spec.maxRange,
              bulletFireSpeed, bulletFireDeg, spec.bulletDestructive);
        bd += spec.nwayAngle;
      }
      bulletSpeed += spec.speedAccel;
      burstCnt++;
    }
    damaged = false;
    if (damagedCnt > 0)
      damagedCnt--;
    startCnt++;
    return true;
  }

  public void draw() {
    if (spec.invisible)
      return;
    glPushMatrix();
    if (destroyedCnt < 0 && damagedCnt > 0) {
      damagedPos.x = pos.x + rand.nextSignedFloat(damagedCnt * 0.015f);
      damagedPos.y = pos.y + rand.nextSignedFloat(damagedCnt * 0.015f);
      Screen.glTranslate(damagedPos);
    } else {
      Screen.glTranslate(pos);
    }
    glRotatef(-(baseDeg + deg) * 180 / PI, 0, 0, 1);
    if (destroyedCnt >= 0)
      spec.destroyedShape.draw();
    else if (!damaged)
      spec.shape.draw();
    else
      spec.damagedShape.draw();
    glPopMatrix();
    if (destroyedCnt >= 0)
      return;
    if (appCnt > 120)
      return;
    float a = 1 - cast(float) appCnt / 120;
    if (startCnt < 12)
      a = cast(float) startCnt / 12;
    float td = baseDeg + deg;
    if (spec.nway <= 1) {
      glBegin(GL_LINE_STRIP);
      Screen.setColor(0.9f, 0.1f, 0.1f, a);
      glVertex2f(pos.x + sin(td) * spec.minRange, pos.y + cos(td) * spec.minRange);
      Screen.setColor(0.9f, 0.1f, 0.1f, a * 0.5f);
      glVertex2f(pos.x + sin(td) * spec.maxRange, pos.y + cos(td) * spec.maxRange);
      glEnd();
    } else {
      td -= spec.nwayAngle * (spec.nway - 1) / 2;
      glBegin(GL_LINE_STRIP);
      Screen.setColor(0.9f, 0.1f, 0.1f, a * 0.75f);
      glVertex2f(pos.x + sin(td) * spec.minRange, pos.y + cos(td) * spec.minRange);
      Screen.setColor(0.9f, 0.1f, 0.1f, a * 0.25f);
      glVertex2f(pos.x + sin(td) * spec.maxRange, pos.y + cos(td) * spec.maxRange);
      glEnd();
      glBegin(GL_QUADS);
      for (int i = 0; i < spec.nway - 1; i++) {
        Screen.setColor(0.9f, 0.1f, 0.1f, a * 0.3f);
        glVertex2f(pos.x + sin(td) * spec.minRange, pos.y + cos(td) * spec.minRange);
        Screen.setColor(0.9f, 0.1f, 0.1f, a * 0.05f);
        glVertex2f(pos.x + sin(td) * spec.maxRange, pos.y + cos(td) * spec.maxRange);
        td += spec.nwayAngle;
        glVertex2f(pos.x + sin(td) * spec.maxRange, pos.y + cos(td) * spec.maxRange);
        Screen.setColor(0.9f, 0.1f, 0.1f, a * 0.3f);
        glVertex2f(pos.x + sin(td) * spec.minRange, pos.y + cos(td) * spec.minRange);
      }
      glEnd();
      glBegin(GL_LINE_STRIP);
      Screen.setColor(0.9f, 0.1f, 0.1f, a * 0.75f);
      glVertex2f(pos.x + sin(td) * spec.minRange, pos.y + cos(td) * spec.minRange);
      Screen.setColor(0.9f, 0.1f, 0.1f, a * 0.25f);
      glVertex2f(pos.x + sin(td) * spec.maxRange, pos.y + cos(td) * spec.maxRange);
      glEnd();
    }
  }

  public bool checkCollision(float x, float y, Collidable c, Shot shot) {
    if (destroyedCnt >= 0 || spec.invisible)
      return false;
    float ox = fabs(pos.x - x), oy = fabs(pos.y - y);
    if (spec.shape.checkCollision(ox, oy, c)) {
      addDamage(shot.damage);
      return true;
    }
    return false;
  }

  public void addDamage(int n) {
    shield -= n;
    if (shield <= 0)
      destroyed();
    damaged = true;
    damagedCnt = 10;
  }

  public void destroyed() {
    SoundManager.playSe("turret_destroyed.wav");
    destroyedCnt = 0;
    for (int i = 0; i < 6; i++) {
      Smoke s = smokes.getInstanceForced();
      s.set(pos, rand.nextSignedFloat(0.1f), rand.nextSignedFloat(0.1f), rand.nextFloat(0.04f),
            Smoke.SmokeType.EXPLOSION, 30 + rand.nextInt(20), spec.size * 1.5f);
    }
    for (int i = 0; i < 32; i++) {
      Spark sp = sparks.getInstanceForced();
      sp.set(pos, rand.nextSignedFloat(0.5f), rand.nextSignedFloat(0.5f),
             0.5f + rand.nextFloat(0.5f), 0.5f + rand.nextFloat(0.5f), 0, 30 + rand.nextInt(30));
    }
    for (int i = 0; i < 7; i++) {
      Fragment f = fragments.getInstanceForced();
      f.set(pos, rand.nextSignedFloat(0.25f), rand.nextSignedFloat(0.25f), 0.05f + rand.nextFloat(0.05f),
            spec.size * (0.5f + rand.nextFloat(0.5f)));
    }
    switch (spec.type) {
    case TurretSpec.TurretType.MAIN:
      parent.increaseMultiplier(2);
      parent.addScore(40);
      break;
    case TurretSpec.TurretType.SUB:
    case TurretSpec.TurretType.SUB_DESTRUCTIVE:
      parent.increaseMultiplier(1);
      parent.addScore(20);
      break;
    }
  }

  public void remove() {
    if (destroyedCnt < 0)
      destroyedCnt = 999;
  }
}

/**
 * Turret specification changing according to a rank(difficulty).
 */
public class TurretSpec {
 public:
  static enum TurretType {
    MAIN, SUB, SUB_DESTRUCTIVE, SMALL, MOVING, DUMMY,
  };
  int type;
  int interval;
  float speed;
  float speedAccel;
  float minRange, maxRange;
  float turnSpeed, turnRange;
  int burstNum, burstInterval;
  float burstTurnRatio;
  bool blind;
  float lookAheadRatio;
  int nway;
  float nwayAngle;
  bool nwayChange;
  int bulletShape;
  bool bulletDestructive;
  int shield;
  bool invisible;
  TurretShape shape, damagedShape, destroyedShape;
 private:
  float _size;

  invariant {
    assert(type >= 0);
    assert(interval > 0);
    assert(speed > 0);
    assert(speedAccel < 1 && speedAccel > -1);
    assert(minRange >= 0);
    assert(maxRange >= 0);
    assert(turnSpeed >= 0);
    assert(turnRange >= 0);
    assert(burstNum >= 1);
    assert(burstInterval >= 1);
    assert(burstTurnRatio >= 0 && burstTurnRatio <= 1);
    assert(lookAheadRatio >= 0 && lookAheadRatio <= 1);
    assert(nway >= 1);
    assert(nwayAngle >= 0);
    assert(bulletShape >= 0);
    assert(shield >= 0);
    assert(_size > 0 && _size < 10);
  }

  public this() {
    shape = new TurretShape(TurretShape.TurretShapeType.NORMAL);
    damagedShape = new TurretShape(TurretShape.TurretShapeType.DAMAGED);
    destroyedShape = new TurretShape(TurretShape.TurretShapeType.DESTROYED);
    init();
  }

  private void init() {
    type = 0;
    interval = 99999;
    speed = 1;
    speedAccel = 0;
    minRange = 0;
    maxRange = 99999;
    turnSpeed = 99999;
    turnRange = 99999;
    burstNum = 1;
    burstInterval = 99999;
    burstTurnRatio = 0;
    blind = false;
    lookAheadRatio = 0;
    nway = 1;
    nwayAngle = 0;
    nwayChange = false;
    bulletShape = BulletShape.BulletShapeType.NORMAL;
    bulletDestructive = false;
    shield = 99999;
    invisible = false;
    _size = 1;
  }

  public void setParam(TurretSpec ts) {
    type = ts.type;
    interval = ts.interval;
    speed = ts.speed;
    speedAccel = ts.speedAccel;
    minRange = ts.minRange;
    maxRange = ts.maxRange;
    turnSpeed = ts.turnSpeed;
    turnRange = ts.turnRange;
    burstNum = ts.burstNum;
    burstInterval = ts.burstInterval;
    burstTurnRatio = ts.burstTurnRatio;
    blind = ts.blind;
    lookAheadRatio = ts.lookAheadRatio;
    nway = ts.nway;
    nwayAngle = ts.nwayAngle;
    nwayChange = ts.nwayChange;
    bulletShape = ts.bulletShape;
    bulletDestructive = ts.bulletDestructive;
    shield = ts.shield;
    invisible = ts.invisible;
    size = ts.size;
  }

  public void setParam(float rank, int type, Rand rand) {
    init();
    this.type = type;
    if (type == TurretType.DUMMY) {
      invisible = true;
      return;
    }
    float rk = rank;
    switch (type) {
    case TurretType.SMALL:
      minRange = 8;
      bulletShape = BulletShape.BulletShapeType.SMALL;
      blind = true;
      invisible = true;
      break;
    case TurretType.MOVING:
      minRange = 6;
      bulletShape = BulletShape.BulletShapeType.MOVING_TURRET;
      blind = true;
      invisible = true;
      turnSpeed = 0;
      maxRange = 9 + rand.nextFloat(12);
      rk *= (10.0f / sqrt(maxRange));
      break;
    default:
      maxRange = 9 + rand.nextFloat(16);
      minRange = maxRange / (4 + rand.nextFloat(0.5f));
      if (type == TurretType.SUB || type == TurretType.SUB_DESTRUCTIVE) {
        maxRange *= 0.72f;
        minRange *= 0.9f;
      }
      rk *= (10.0f / sqrt(maxRange));
      if (rand.nextInt(4) == 0) {
        float lar = rank * 0.1f;
        if (lar > 1)
          lar = 1;
        lookAheadRatio = rand.nextFloat(lar / 2) + lar / 2;
        rk /= (1 + lookAheadRatio * 0.3f);
      }
      if (rand.nextInt(3) == 0 && lookAheadRatio == 0) {
        blind = false;
        rk *= 1.5f;
      } else {
        blind = true;
      }
      turnRange = PI / 4 + rand.nextFloat(PI / 4);
      turnSpeed = 0.005f + rand.nextFloat(0.015f);
      if (type == TurretType.MAIN)
        turnRange *= 1.2f;
      if (rand.nextInt(4) == 0)
        burstTurnRatio = rand.nextFloat(0.66f) + 0.33f;
      break;
    }
    burstInterval = 6 + rand.nextInt(8);
    switch (type) {
    case TurretType.MAIN:
      size = 0.42f + rand.nextFloat(0.05f);
      float br = (rk * 0.3f) * (1 + rand.nextSignedFloat(0.2f));
      float nr = (rk * 0.33f) * rand.nextFloat(1);
      float ir = (rk * 0.1f) * (1 + rand.nextSignedFloat(0.2f));
      burstNum = cast(int) br + 1;
      nway = cast(int) (nr * 0.66f + 1);
      interval = cast(int) (120.0f / (ir * 2 + 1)) + 1;
      float sr = rk - burstNum + 1 - (nway - 1) / 0.66f - ir;
      if (sr < 0)
        sr = 0;
      speed = sqrt(sr * 0.6f);
      assert(speed <>= 0);
      speed *= 0.12f;
      shield = 20;
      break;
    case TurretType.SUB:
      size = 0.36f + rand.nextFloat(0.025f);
      float br = (rk * 0.4f) * (1 + rand.nextSignedFloat(0.2f));
      float nr = (rk * 0.2f) * rand.nextFloat(1);
      float ir = (rk * 0.2f) * (1 + rand.nextSignedFloat(0.2f));
      burstNum = cast(int) br + 1;
      nway = cast(int) (nr * 0.66f + 1);
      interval = cast(int) (120.0f / (ir * 2 + 1)) + 1;
      float sr = rk - burstNum + 1 - (nway - 1) / 0.66f - ir;
      if (sr < 0)
        sr = 0;
      speed = sqrt(sr * 0.7f);
      assert(speed <>= 0);
      speed *= 0.2f;
      shield = 12;
      break;
    case TurretType.SUB_DESTRUCTIVE:
      size = 0.36f + rand.nextFloat(0.025f);
      float br = (rk * 0.4f) * (1 + rand.nextSignedFloat(0.2f));
      float nr = (rk * 0.2f) * rand.nextFloat(1);
      float ir = (rk * 0.2f) * (1 + rand.nextSignedFloat(0.2f));
      burstNum = cast(int) br * 2 + 1;
      nway = cast(int) (nr * 0.66f + 1);
      interval = cast(int) (60.0f / (ir * 2 + 1)) + 1;
      burstInterval *= 0.88f;
      bulletShape = BulletShape.BulletShapeType.DESTRUCTIVE;
      bulletDestructive = true;
      float sr = rk - (burstNum - 1) / 2 - (nway - 1) / 0.66f - ir;
      if (sr < 0)
        sr = 0;
      speed = sqrt(sr * 0.7f);
      assert(speed <>= 0);
      speed *= 0.33f;
      shield = 12;
      break;
    case TurretType.SMALL:
      size = 0.33f;
      float br = (rk * 0.33f) * (1 + rand.nextSignedFloat(0.2f));
      float ir = (rk * 0.2f) * (1 + rand.nextSignedFloat(0.2f));
      burstNum = cast(int) br + 1;
      nway = 1;
      interval = cast(int) (120.0f / (ir * 2 + 1)) + 1;
      float sr = rk - burstNum + 1 - ir;
      if (sr < 0)
        sr = 0;
      speed = sqrt(sr);
      assert(speed <>= 0);
      speed *= 0.24f;
      break;
    case TurretType.MOVING:
      size = 0.36f;
      float br = (rk * 0.3f) * (1 + rand.nextSignedFloat(0.2f));
      float nr = (rk * 0.1f) * rand.nextFloat(1);
      float ir = (rk * 0.33f) * (1 + rand.nextSignedFloat(0.2f));
      burstNum = cast(int) br + 1;
      nway = cast(int) (nr * 0.66f + 1);
      interval = cast(int) (120.0f / (ir * 2 + 1)) + 1;
      float sr = rk - burstNum + 1 - (nway - 1) / 0.66f - ir;
      if (sr < 0)
        sr = 0;
      speed = sqrt(sr * 0.7f);
      assert(speed <>= 0);
      speed *= 0.2f;
      break;
    }
    if (speed < 0.1f)
      speed = 0.1f;
    else
      speed = sqrt(speed * 10) / 10;
    assert(speed <>= 0);
    if (burstNum > 2) {
      if (rand.nextInt(4) == 0) {
        speed *= 0.8f;
        burstInterval *= 0.7f;
        speedAccel = (speed * (0.4f + rand.nextFloat(0.3f))) / burstNum;
        if (rand.nextInt(2) == 0)
          speedAccel *= -1;
        speed -= speedAccel * burstNum / 2;
      }
      if (rand.nextInt(5) == 0) {
        if (nway > 1)
          nwayChange = true;
      }
    }
    nwayAngle = (0.1f + rand.nextFloat(0.33f)) / (1 + nway * 0.1f);
  }

  public void setBossSpec() {
    minRange = 0;
    maxRange *= 1.5f;
    shield *= 2.1f;
  }

  public float size() {
    return _size;
  }

  public float size(float v) {
    _size = v;
    shape.size = damagedShape.size = destroyedShape.size = _size;
    return _size;
  }
}

/**
 * Grouped turrets.
 */
public class TurretGroup {
 private:
  static const int MAX_NUM = 16;
  Ship ship;
  SparkPool sparks;
  SmokePool smokes;
  FragmentPool fragments;
  TurretGroupSpec spec;
  Vector centerPos;
  Turret[MAX_NUM] turret;
  int cnt;

  invariant {
    assert(centerPos.x < 15 && centerPos.x > -15);
    assert(centerPos.y < 60 && centerPos.y > -40);
  }

  public this(Field field, BulletPool bullets, Ship ship,
              SparkPool sparks, SmokePool smokes, FragmentPool fragments,
              Enemy parent) {
    this.ship = ship;
    centerPos = new Vector;
    foreach (inout Turret t; turret)
      t = new Turret(field, bullets, ship, sparks, smokes, fragments, parent);
  }

  public void set(TurretGroupSpec spec) {
    this.spec = spec;
    for (int i = 0; i < spec.num; i++)
      turret[i].start(spec.turretSpec);
    cnt = 0;
  }

  public bool move(Vector p, float deg) {
    bool alive = false;
    centerPos.x = p.x;
    centerPos.y = p.y;
    float d, md, y, my;
    switch (spec.alignType) {
    case TurretGroupSpec.AlignType.ROUND:
      d = spec.alignDeg;
      if (spec.num > 1) {
        md = spec.alignWidth / (spec.num - 1);
        d -= spec.alignWidth / 2;
      } else {
        md = 0;
      }
      break;
    case TurretGroupSpec.AlignType.STRAIGHT:
      y = 0;
      my = spec.offset.y / (spec.num + 1);
      break;
    }
    for (int i = 0; i < spec.num; i++) {
      float tbx, tby;
      switch (spec.alignType) {
      case TurretGroupSpec.AlignType.ROUND:
        tbx = sin(d) * spec.radius;
        tby = cos(d) * spec.radius;
        break;
      case TurretGroupSpec.AlignType.STRAIGHT:
        y += my;
        tbx = spec.offset.x;
        tby = y;
        d = atan2(tbx, tby);
        assert(d <>= 0);
        break;
      }
      tbx *= (1 - spec.distRatio);
      float bx = tbx * cos(-deg) - tby * sin(-deg);
      float by = tbx * sin(-deg) + tby * cos(-deg);
      alive |= turret[i].move(centerPos.x + bx, centerPos.y + by, d + deg);
      if (spec.alignType == TurretGroupSpec.AlignType.ROUND)
        d += md;
    }
    cnt++;
    return alive;
  }

  public void draw() {
    for (int i = 0; i < spec.num; i++)
      turret[i].draw();
  }

  public void remove() {
    for (int i = 0; i < spec.num; i++)
      turret[i].remove();
  }

  public bool checkCollision(float x, float y, Collidable c, Shot shot) {
    bool col = false;
    for (int i = 0; i < spec.num; i++)
      col |= turret[i].checkCollision(x, y, c, shot);
    return col;
  }
}

public class TurretGroupSpec {
 public:
  static enum AlignType {
    ROUND, STRAIGHT,
  };
  TurretSpec turretSpec;
  int num;
  int alignType;
  float alignDeg;
  float alignWidth;
  float radius;
  float distRatio;
  Vector offset;

  invariant {
    assert(num >= 1 && num < 20);
    assert(alignDeg <>= 0);
    assert(alignWidth <>= 0);
    assert(radius >= 0);
    assert(distRatio >= 0 && distRatio <= 1);
    assert(offset.x < 10 && offset.x > -10);
    assert(offset.y < 10 && offset.y > -10);
  }

  public this() {
    turretSpec = new TurretSpec;
    offset = new Vector;
    num = 1;
    alignDeg = alignWidth = 0;
    radius = 0;
    distRatio = 0;
  }

  public void init() {
    num = 1;
    alignType = AlignType.ROUND;
    alignDeg = alignWidth = radius = distRatio = 0;
    offset.x = offset.y = 0;
  }
}

/**
 * Turrets moving around a bridge.
 */
public class MovingTurretGroup {
 private:
  static const int MAX_NUM = 16;
  Ship ship;
  MovingTurretGroupSpec spec;
  float radius;
  float radiusAmpCnt;
  float deg;
  float rollAmpCnt;
  float swingAmpCnt;
  float swingAmpDeg;
  float swingFixDeg;
  float alignAmpCnt;
  float distDeg;
  float distAmpCnt;
  int cnt;
  Vector centerPos;
  Turret[MAX_NUM] turret;

  invariant {
    assert(radius > -10);
    assert(radiusAmpCnt <>= 0);
    assert(deg <>= 0);
    assert(rollAmpCnt <>= 0);
    assert(swingAmpCnt <>= 0);
    assert(swingAmpDeg <>= 0);
    assert(swingFixDeg <>= 0);
    assert(alignAmpCnt <>= 0);
    assert(distDeg <>= 0);
    assert(distAmpCnt <>= 0);
    assert(centerPos.x < 15 && centerPos.x > -15);
    assert(centerPos.y < 60 && centerPos.y > -40);
  }

  public this(Field field, BulletPool bullets, Ship ship,
              SparkPool sparks, SmokePool smokes, FragmentPool fragments,
              Enemy parent) {
    this.ship = ship;
    centerPos = new Vector;
    foreach (inout Turret t; turret)
      t = new Turret(field, bullets, ship, sparks, smokes, fragments, parent);
    radius = radiusAmpCnt = 0;
    deg = 0;
    rollAmpCnt = swingAmpCnt = swingAmpDeg = swingFixDeg = alignAmpCnt = 0;
    distDeg = distAmpCnt = 0;
  }

  public void set(MovingTurretGroupSpec spec) {
    this.spec = spec;
    radius = spec.radiusBase;
    radiusAmpCnt = 0;
    deg = 0;
    rollAmpCnt = swingAmpCnt = swingAmpDeg = alignAmpCnt = 0;
    distDeg = distAmpCnt = 0;
    swingFixDeg = PI;
    for (int i = 0; i < spec.num; i++)
      turret[i].start(spec.turretSpec);
    cnt = 0;
  }

  public void move(Vector p, float ed) {
    if (spec.moveType == MovingTurretGroupSpec.MoveType.SWING_FIX)
      swingFixDeg = ed;
    centerPos.x = p.x;
    centerPos.y = p.y;
    if (spec.radiusAmp > 0) {
      radiusAmpCnt += spec.radiusAmpVel;
      float av = sin(radiusAmpCnt);
      radius = spec.radiusBase + spec.radiusAmp * av;
    }
    if (spec.moveType == MovingTurretGroupSpec.MoveType.ROLL) {
      if (spec.rollAmp != 0) {
        rollAmpCnt += spec.rollAmpVel;
        float av = sin(rollAmpCnt);
        deg += spec.rollDegVel + spec.rollAmp * av;
      } else {
        deg += spec.rollDegVel;
      }
    } else {
      swingAmpCnt += spec.swingAmpVel;
      if (cos(swingAmpCnt) > 0) {
        swingAmpDeg += spec.swingDegVel;
      } else {
        swingAmpDeg -= spec.swingDegVel;
      }
      if (spec.moveType == MovingTurretGroupSpec.MoveType.SWING_AIM) {
        float od;
        Vector shipPos = ship.nearPos(centerPos);
        if (shipPos.dist(centerPos) < 0.1f)
          od = 0;
        else
          od = atan2(shipPos.x - centerPos.x, shipPos.y - centerPos.y);
        assert(od <>= 0);
        od += swingAmpDeg - deg;
        Math.normalizeDeg(od);
        deg += od * 0.1f;
      } else {
        float od = swingFixDeg + swingAmpDeg - deg;
        Math.normalizeDeg(od);
        deg += od * 0.1f;
      }
    }
    float d, ad, md;
    calcAlignDeg(d, ad, md);
    for (int i = 0; i < spec.num; i++) {
      d += md;
      float bx = sin(d) * radius * spec.xReverse;
      float by = cos(d) * radius * (1 - spec.distRatio);
      float fs, fd;
      if (fabs(bx) + fabs(by) < 0.1f) {
        fs = radius;
        fd = d;
      } else {
        fs = sqrt(bx * bx + by * by);
        fd = atan2(bx, by);
        assert(fd <>= 0);
      }
      fs *= 0.06f;
      turret[i].move(centerPos.x, centerPos.y, d, fs, fd);
    }
    cnt++;
  }

  private void calcAlignDeg(out float d, out float ad, out float md) {
    alignAmpCnt += spec.alignAmpVel;
    ad = spec.alignDeg * (1 + sin(alignAmpCnt) * spec.alignAmp);
    if (spec.num > 1) {
      if (spec.moveType == MovingTurretGroupSpec.MoveType.ROLL)
        md = ad / spec.num;
      else
        md = ad / (spec.num - 1);
    } else {
      md = 0;
    }
    d = deg - md - ad / 2;
  }

  public void draw() {
    for (int i = 0; i < spec.num; i++)
      turret[i].draw();
  }

  public void remove() {
    for (int i = 0; i < spec.num; i++)
      turret[i].remove();
  }
}

public class MovingTurretGroupSpec {
 public:
  static enum MoveType {
    ROLL, SWING_FIX, SWING_AIM,
  };
  TurretSpec turretSpec;
  int num;
  float alignDeg;
  float alignAmp;
  float alignAmpVel;
  float radiusBase;
  float radiusAmp;
  float radiusAmpVel;
  int moveType;
  float rollDegVel;
  float rollAmp;
  float rollAmpVel;
  float swingDegVel;
  float swingAmpVel;
  float distRatio;
  float xReverse;

  invariant {
    assert(num >= 1);
    assert(alignDeg <>= 0);
    assert(alignAmp <>= 0);
    assert(alignAmpVel <>= 0);
    assert(radiusBase <>= 0);
    assert(radiusAmp <>= 0);
    assert(radiusAmpVel <>= 0);
    assert(rollDegVel <>= 0);
    assert(rollAmp <>= 0);
    assert(rollAmpVel <>= 0);
    assert(swingDegVel <>= 0);
    assert(swingAmpVel <>= 0);
    assert(distRatio <>= 0);
    assert(xReverse == 1 || xReverse == -1);

  }

  public this() {
    turretSpec = new TurretSpec;
    num = 1;
    initParam();
  }

  private void initParam() {
    num = 1;
    alignDeg = PI * 2;
    alignAmp = alignAmpVel = 0;
    radiusBase = 1;
    radiusAmp = radiusAmpVel = 0;
    moveType = MoveType.SWING_FIX;
    rollDegVel = rollAmp = rollAmpVel = 0;
    swingDegVel = swingAmpVel = 0;
    distRatio = 0;
    xReverse = 1;
  }

  public void init() {
    initParam();
  }

  public void setAlignAmp(float a, float v) {
    alignAmp = a;
    alignAmpVel = v;
  }

  public void setRadiusAmp(float a, float v) {
    radiusAmp = a;
    radiusAmpVel = v;
  }

  public void setRoll(float dv, float a, float v) {
    moveType = MoveType.ROLL;
    rollDegVel = dv;
    rollAmp = a;
    rollAmpVel = v;
  }

  public void setSwing(float dv, float a, bool aim = false) {
    if (aim)
      moveType = MoveType.SWING_AIM;
    else
      moveType = MoveType.SWING_FIX;
    swingDegVel = dv;
    swingAmpVel = a;
  }

  public void setXReverse(float xr) {
    xReverse = xr;
  }
}
