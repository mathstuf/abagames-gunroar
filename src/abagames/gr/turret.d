/*
 * $Id: turret.d,v 1.3 2005/07/17 11:02:46 kenta Exp $
 *
 * Copyright 2005 Kenta Cho. Some rights reserved.
 */
module abagames.gr.turret;

private import std.math;
private import gl3n.linalg;
private import abagames.util.actor;
private import abagames.util.rand;
private import abagames.util.math;
private import abagames.util.support.gl;
private import abagames.util.sdl.shaderprogram;
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
  static ShaderProgram program;
  static GLuint vao;
  static GLuint vbo;
  static Rand rand;
  static vec2 damagedPos;
  Field field;
  BulletPool bullets;
  Ship ship;
  SparkPool sparks;
  SmokePool smokes;
  FragmentPool fragments;
  TurretSpec spec;
  vec2 pos;
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
  vec3 storedColor;

  invariant() {
    assert(pos.x < 15 && pos.x > -15);
    assert(pos.y < 60 && pos.y > -40);
    assert(!deg.isNaN);
    assert(!baseDeg.isNaN);
    assert(bulletSpeed > 0);
  }

  public static void init() {
    rand = new Rand;
    damagedPos = vec2(0);

    program = new ShaderProgram;
    program.setVertexShader(
      "uniform mat4 projmat;\n"
      "uniform float minAlphaFactor;\n"
      "uniform float maxAlphaFactor;\n"
      "uniform float minRange;\n"
      "uniform float maxRange;\n"
      "uniform float deg;\n"
      "uniform float ndeg;\n"
      "uniform vec2 pos;\n"
      "\n"
      "attribute float minmax;\n"
      "attribute float angleChoice;\n"
      "\n"
      "varying float f_alphaFactor;\n"
      "\n"
      "void main() {\n"
      "  float factor = (minmax > 0.) ? maxRange : minRange;\n"
      "  float rdeg = (angleChoice > 0.) ? ndeg : deg;\n"
      "  vec2 rot = factor * vec2(sin(rdeg), cos(rdeg));\n"
      "  gl_Position = projmat * vec4(pos + rot, 0, 1);\n"
      "  float alphaFactor = (minmax > 0.) ? maxAlphaFactor : minAlphaFactor;\n"
      "  f_alphaFactor = alphaFactor;\n"
      "}\n"
    );
    program.setFragmentShader(
      "uniform float brightness;\n"
      "uniform float alpha;\n"
      "uniform vec3 color;\n"
      "\n"
      "varying float f_alphaFactor;\n"
      "\n"
      "void main() {\n"
      "  gl_FragColor = vec4(color * vec3(brightness), alpha * f_alphaFactor);\n"
      "}\n"
    );
    GLint minmaxLoc = 0;
    GLint angleChoiceLoc = 1;
    program.bindAttribLocation(minmaxLoc, "minmax");
    program.bindAttribLocation(angleChoiceLoc, "angleChoice");
    program.link();
    program.use();

    program.setUniform("color", 0.9f, 0.1f, 0.1f);

    static const float[] BUF = [
      /*
      minmax, angleChoice */
      0,      0,
      1,      0,
      1,      1,
      0,      1
    ];
    enum MINMAX = 0;
    enum ANGLECHOICE = 1;
    enum BUFSZ = 2;

    glGenVertexArrays(1, &vao);
    glGenBuffers(1, &vbo);

    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, BUF.length * float.sizeof, BUF.ptr, GL_STATIC_DRAW);

    glBindVertexArray(vao);

    vertexAttribPointer(minmaxLoc, 1, BUFSZ, MINMAX);
    glEnableVertexAttribArray(minmaxLoc);

    vertexAttribPointer(angleChoiceLoc, 1, BUFSZ, ANGLECHOICE);
    glEnableVertexAttribArray(angleChoiceLoc);
  }

  public static close() {
    glDeleteVertexArrays(1, &vao);
    glDeleteBuffers(1, &vbo);
    program.close();
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
    pos = vec2(0);
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
    pos = vec2(x, y);
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
    vec2 shipPos = ship.nearPos(pos);
    vec2 shipVel = ship.nearVel(pos);
    vec2 a = shipPos - pos;
    if (spec.lookAheadRatio != 0) {
      float rd = pos.fastdist(shipPos) / spec.speed * 1.2f;
      a += shipVel * spec.lookAheadRatio * rd;
    }
    float ad;
    if (fabs(a.x) + fabs(a.y) < 0.1f)
      ad = 0;
    else
      ad = atan2(a.x, a.y);
    assert(!ad.isNaN);
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
                         pos.fastdist(shipPos) < spec.maxRange * 1.1f &&
                         pos.fastdist(shipPos) > spec.minRange)) {
        cnt = -(spec.burstNum - 1) * spec.burstInterval;
        bulletSpeed = spec.speed;
        burstCnt = 0;
      }
    }
    if (cnt <= 0 && -cnt % spec.burstInterval == 0 &&
        ((spec.invisible && field.checkInField(pos)) ||
         (spec.invisible && parent.isBoss && field.checkInOuterField(pos)) ||
         (!spec.invisible && field.checkInFieldExceptTop(pos))) &&
        pos.fastdist(shipPos) > spec.minRange) {
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

  public void setDefaultColor(vec3 color) {
    storedColor = color;
  }

  public void draw(mat4 view) {
    if (spec.invisible)
      return;

    mat4 model = mat4.identity;
    model.rotate(baseDeg + deg, vec3(0, 0, 1));
    if (destroyedCnt < 0 && damagedCnt > 0) {
      damagedPos.x = pos.x + rand.nextSignedFloat(damagedCnt * 0.015f);
      damagedPos.y = pos.y + rand.nextSignedFloat(damagedCnt * 0.015f);
      model.translate(damagedPos.x, damagedPos.y, 0);
    } else {
      model.translate(pos.x, pos.y, 0);
    }
    if (destroyedCnt >= 0) {
      spec.destroyedShape.setDefaultColor(storedColor);
      spec.destroyedShape.draw(view, model);
    } else if (!damaged) {
      spec.shape.setDefaultColor(storedColor);
      spec.shape.draw(view, model);
    } else {
      spec.damagedShape.setDefaultColor(storedColor);
      spec.damagedShape.draw(view, model);
    }

    if (destroyedCnt >= 0)
      return;
    if (appCnt > 120)
      return;
    float a = 1 - cast(float) appCnt / 120;
    if (startCnt < 12)
      a = cast(float) startCnt / 12;
    float td = baseDeg + deg;

    program.use();

    program.setUniform("projmat", view);
    program.setUniform("brightness", Screen.brightness);
    program.setUniform("minRange", spec.minRange);
    program.setUniform("maxRange", spec.maxRange);
    program.setUniform("pos", pos);
    program.setUniform("alpha", a);

    if (spec.nway <= 1) {
      program.setUniform("deg", td);
      program.setUniform("minAlphaFactor", 1f);
      program.setUniform("maxAlphaFactor", 0.5f);

      program.useVao(vao);
      glDrawArrays(GL_LINE_STRIP, 0, 2);
    } else {
      td -= spec.nwayAngle * (spec.nway - 1) / 2;

      program.setUniform("deg", td);
      program.setUniform("minAlphaFactor", 0.75f);
      program.setUniform("maxAlphaFactor", 0.25f);

      program.useVao(vao);
      glDrawArrays(GL_LINE_STRIP, 0, 2);

      program.setUniform("minAlphaFactor", 0.3f);
      program.setUniform("maxAlphaFactor", 0.05f);

      for (int i = 0; i < spec.nway - 1; i++) {
        float ntd = td + spec.nwayAngle;

        program.setUniform("deg", td);
        program.setUniform("ndeg", ntd);

        glDrawArrays(GL_TRIANGLE_FAN, 0, 4);

        td = ntd;
      }

      program.setUniform("deg", td);
      program.setUniform("minAlphaFactor", 0.75f);
      program.setUniform("maxAlphaFactor", 0.25f);

      glDrawArrays(GL_LINE_STRIP, 0, 2);
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
    default:
      assert(0);
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

  invariant() {
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
      assert(!speed.isNaN);
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
      assert(!speed.isNaN);
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
      burstInterval = cast(int)(burstInterval * 0.88f);
      bulletShape = BulletShape.BulletShapeType.DESTRUCTIVE;
      bulletDestructive = true;
      float sr = rk - (burstNum - 1) / 2 - (nway - 1) / 0.66f - ir;
      if (sr < 0)
        sr = 0;
      speed = sqrt(sr * 0.7f);
      assert(!speed.isNaN);
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
      assert(!speed.isNaN);
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
      assert(!speed.isNaN);
      speed *= 0.2f;
      break;
    default:
      assert(0);
    }
    if (speed < 0.1f)
      speed = 0.1f;
    else
      speed = sqrt(speed * 10) / 10;
    assert(!speed.isNaN);
    if (burstNum > 2) {
      if (rand.nextInt(4) == 0) {
        speed *= 0.8f;
        burstInterval = cast(int)(burstInterval * 0.7f);
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
    shield = cast(int)(shield * 2.1f);
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
  vec2 centerPos;
  Turret[MAX_NUM] turret;
  int cnt;

  invariant() {
    assert(centerPos.x < 15 && centerPos.x > -15);
    assert(centerPos.y < 60 && centerPos.y > -40);
  }

  public this(Field field, BulletPool bullets, Ship ship,
              SparkPool sparks, SmokePool smokes, FragmentPool fragments,
              Enemy parent) {
    this.ship = ship;
    centerPos = vec2(0);
    foreach (ref Turret t; turret)
      t = new Turret(field, bullets, ship, sparks, smokes, fragments, parent);
  }

  public void set(TurretGroupSpec spec) {
    this.spec = spec;
    for (int i = 0; i < spec.num; i++)
      turret[i].start(spec.turretSpec);
    cnt = 0;
  }

  public bool move(vec2 p, float deg) {
    bool alive = false;
    centerPos = p;
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
    default:
      assert(0);
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
        assert(!d.isNaN);
        break;
      default:
        assert(0);
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

  public void setDefaultColor(vec3 color) {
    for (int i = 0; i < spec.num; i++)
      turret[i].setDefaultColor(color);
  }

  public void draw(mat4 view) {
    for (int i = 0; i < spec.num; i++)
      turret[i].draw(view);
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
  vec2 offset;

  invariant() {
    assert(num >= 1 && num < 20);
    assert(!alignDeg.isNaN);
    assert(!alignWidth.isNaN);
    assert(radius >= 0);
    assert(distRatio >= 0 && distRatio <= 1);
    assert(offset.x < 10 && offset.x > -10);
    assert(offset.y < 10 && offset.y > -10);
  }

  public this() {
    turretSpec = new TurretSpec;
    offset = vec2(0);
    num = 1;
    alignDeg = alignWidth = 0;
    radius = 0;
    distRatio = 0;
  }

  public void init() {
    num = 1;
    alignType = AlignType.ROUND;
    alignDeg = alignWidth = radius = distRatio = 0;
    offset = vec2(0);
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
  vec2 centerPos;
  Turret[MAX_NUM] turret;

  invariant() {
    assert(radius > -10);
    assert(!radiusAmpCnt.isNaN);
    assert(!deg.isNaN);
    assert(!rollAmpCnt.isNaN);
    assert(!swingAmpCnt.isNaN);
    assert(!swingAmpDeg.isNaN);
    assert(!swingFixDeg.isNaN);
    assert(!alignAmpCnt.isNaN);
    assert(!distDeg.isNaN);
    assert(!distAmpCnt.isNaN);
    assert(centerPos.x < 15 && centerPos.x > -15);
    assert(centerPos.y < 60 && centerPos.y > -40);
  }

  public this(Field field, BulletPool bullets, Ship ship,
              SparkPool sparks, SmokePool smokes, FragmentPool fragments,
              Enemy parent) {
    this.ship = ship;
    centerPos = vec2(0);
    foreach (ref Turret t; turret)
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

  public void move(vec2 p, float ed) {
    if (spec.moveType == MovingTurretGroupSpec.MoveType.SWING_FIX)
      swingFixDeg = ed;
    centerPos = p;
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
        vec2 shipPos = ship.nearPos(centerPos);
        if (shipPos.fastdist(centerPos) < 0.1f)
          od = 0;
        else
          od = atan2(shipPos.x - centerPos.x, shipPos.y - centerPos.y);
        assert(!od.isNaN);
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
        assert(!fd.isNaN);
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

  public void draw(mat4 view) {
    for (int i = 0; i < spec.num; i++)
      turret[i].draw(view);
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

  invariant() {
    assert(num >= 1);
    assert(!alignDeg.isNaN);
    assert(!alignAmp.isNaN);
    assert(!alignAmpVel.isNaN);
    assert(!radiusBase.isNaN);
    assert(!radiusAmp.isNaN);
    assert(!radiusAmpVel.isNaN);
    assert(!rollDegVel.isNaN);
    assert(!rollAmp.isNaN);
    assert(!rollAmpVel.isNaN);
    assert(!swingDegVel.isNaN);
    assert(!swingAmpVel.isNaN);
    assert(!distRatio.isNaN);
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
