/*
 * $Id: enemy.d,v 1.2 2005/07/17 11:02:45 kenta Exp $
 *
 * Copyright 2005 Kenta Cho. Some rights reserved.
 */
module abagames.gr.enemy;

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
private import abagames.gr.stagemanager;
private import abagames.gr.screen;
private import abagames.gr.particle;
private import abagames.gr.shot;
private import abagames.gr.shape;
private import abagames.gr.soundmanager;
private import abagames.gr.gamemanager;
private import abagames.gr.turret;
private import abagames.gr.letter;
private import abagames.gr.reel;

/**
 * Enemy ships.
 */
public class Enemy: Actor {
 private:
  EnemySpec spec;
  EnemyState _state;

  public override void init(Object[] args) {
    _state = new EnemyState
      (cast(Field) args[0], cast(Screen) args[1],
       cast(BulletPool) args[2], cast(Ship) args[3],
       cast(SparkPool) args[4], cast(SmokePool) args[5],
       cast(FragmentPool) args[6], cast(SparkFragmentPool) args[7],
       cast(NumIndicatorPool) args[8], cast(ScoreReel) args[9]);
  }

  public void setEnemyPool(EnemyPool enemies) {
    _state.setEnemyAndPool(this, enemies);
  }

  public void setStageManager(StageManager stageManager) {
    _state.setStageManager(stageManager);
  }

  public void set(EnemySpec spec) {
    this.spec = spec;
    exists = true;
  }

  public override void move() {
    if (!spec.move(state))
      remove();
  }

  public void checkShotHit(Vector p, Collidable shape, Shot shot) {
    if (_state.destroyedCnt >= 0)
      return;
    if (spec.checkCollision(_state, p.x, p.y, shape, shot)) {
      if (shot)
        shot.removeHitToEnemy(spec.isSmallEnemy);
    }
  }

  public bool checkHitShip(float x, float y, bool largeOnly = false) {
    return spec.checkShipCollision(_state, x, y, largeOnly);
  }

  public void addDamage(int n) {
    _state.addDamage(n);
  }

  public void increaseMultiplier(float m) {
    _state.increaseMultiplier(m);
  }

  public void addScore(int s) {
    _state.addScore(s);
  }

  public void remove() {
    _state.removeTurrets();
    exists = false;
  }

  public override void draw() {
    spec.draw(_state);
  }

  public EnemyState state() {
    return _state;
  }

  public Vector pos() {
    return _state.pos;
  }

  public float size() {
    return spec.size;
  }

  public int index() {
    return _state.idx;
  }

  public bool isBoss() {
    return spec.isBoss;
  }
}

/**
 * Enemy status (position, direction, velocity, turrets, etc).
 */
public class EnemyState {
 public:
  static enum AppearanceType {
    TOP, SIDE, CENTER,
  };
  static const int TURRET_GROUP_MAX = 10;
  static const int MOVING_TURRET_GROUP_MAX = 4;
  static const float MULTIPLIER_DECREASE_RATIO = 0.005f;
  int appType;
  Vector pos;
  Vector ppos;
  int shield;
  float deg;
  float velDeg;
  float speed;
  float turnWay;
  float trgDeg;
  int turnCnt;
  int state;
  int cnt;
  Vector vel;
  TurretGroup[TURRET_GROUP_MAX] turretGroup;
  MovingTurretGroup[MOVING_TURRET_GROUP_MAX] movingTurretGroup;
  bool damaged;
  int damagedCnt;
  int destroyedCnt;
  int explodeCnt, explodeItv;
  int idx;
  float multiplier;
  EnemySpec spec;
 private:
  static Rand rand;
  static Vector edgePos, explodeVel, damagedPos;
  static int idxCount = 0;
  Field field;
  Screen screen;
  BulletPool bullets;
  Ship ship;
  SparkPool sparks;
  SmokePool smokes;
  FragmentPool fragments;
  SparkFragmentPool sparkFragments;
  NumIndicatorPool numIndicators;
  Enemy enemy;
  EnemyPool enemies;
  StageManager stageManager;
  ScoreReel scoreReel;

  invariant {
    assert(pos.x < 15 && pos.x > -15);
    assert(pos.y < 60 && pos.y > -30);
    assert(ppos.x < 15 && ppos.x > -15);
    assert(ppos.y < 60 && ppos.y > -30);
    assert(shield <>= 0);
    assert(deg <>= 0);
    assert(velDeg <>= 0);
    assert(speed < 10 && speed > -10);
    assert(turnWay == 1 || turnWay == -1);
    assert(trgDeg <= 1 && trgDeg >= -1);
    assert(turnCnt >= 0);
    assert(vel.x < 10 && vel.x > -10);
    assert(vel.y < 10 && vel.y > -10);
    assert(explodeItv > 0);
    assert(edgePos.x < 15 && edgePos.x > -15);
    assert(edgePos.y < 60 && edgePos.y > -30);
    assert(explodeVel.x < 10 && explodeVel.x > -10);
    assert(explodeVel.y < 10 && explodeVel.y > -10);
    assert(damagedPos.x < 15 && damagedPos.x > -15);
    assert(damagedPos.y < 60 && damagedPos.y > -30);
    assert(multiplier >= 1);
  }

  public static this() {
    rand = new Rand;
    edgePos = new Vector;
    explodeVel = new Vector;
    damagedPos = new Vector;
  }

  public static void setRandSeed(long seed) {
    rand.setSeed(seed);
  }

  public this(Field field, Screen screen, BulletPool bullets, Ship ship,
              SparkPool sparks, SmokePool smokes,
              FragmentPool fragments, SparkFragmentPool sparkFragments,
              NumIndicatorPool numIndicators, ScoreReel scoreReel) {
    idx = idxCount;
    idxCount++;
    this.field = field;
    this.screen = screen;
    this.bullets = bullets;
    this.ship = ship;
    this.sparks = sparks;
    this.smokes = smokes;
    this.fragments = fragments;
    this.sparkFragments = sparkFragments;
    this.numIndicators = numIndicators;
    this.scoreReel = scoreReel;
    pos = new Vector;
    ppos = new Vector;
    vel = new Vector;
    deg = velDeg = speed = 0;
    turnWay = 1;
    explodeItv = 1;
    multiplier = 1;
    trgDeg = 0;
    turnCnt = 0;
  }

  public void setEnemyAndPool(Enemy enemy, EnemyPool enemies) {
    this.enemy = enemy;
    this.enemies = enemies;
    foreach (inout TurretGroup tg; turretGroup)
      tg = new TurretGroup(field, bullets, ship, sparks, smokes, fragments, enemy);
    foreach (inout MovingTurretGroup tg; movingTurretGroup)
      tg = new MovingTurretGroup(field, bullets, ship, sparks, smokes, fragments, enemy);
  }

  public void setStageManager(StageManager stageManager) {
    this.stageManager = stageManager;
  }

  public void setSpec(EnemySpec spec) {
    this.spec = spec;
    shield = spec.shield;
    for (int i = 0; i < spec.turretGroupNum; i++)
      turretGroup[i].set(spec.turretGroupSpec[i]);
    for (int i = 0; i < spec.movingTurretGroupNum; i++)
      movingTurretGroup[i].set(spec.movingTurretGroupSpec[i]);
    cnt = 0;
    damaged = false;
    damagedCnt = 0;
    destroyedCnt = -1;
    explodeCnt = 0;
    explodeItv = 1;
    multiplier = 1;
  }

  public bool setAppearancePos(Field field, Ship ship, Rand rand,
                               int appType = AppearanceType.TOP) {
    this.appType = appType;
    for (int i = 0 ; i < 8 ; i++) {
      switch (appType) {
      case AppearanceType.TOP:
        pos.x = rand.nextSignedFloat(field.size.x);
        pos.y = field.outerSize.y * 0.99f + spec.size;
        if (pos.x < 0)
          velDeg = deg = PI - rand.nextFloat(0.5f);
        else
          velDeg = deg = PI + rand.nextFloat(0.5f);
        break;
      case AppearanceType.SIDE:
        if (rand.nextInt(2) == 0) {
          pos.x = -field.outerSize.x * 0.99f;
          velDeg = deg = PI / 2 + rand.nextFloat(0.66f);
        } else {
          pos.x = field.outerSize.x * 0.99f;
          velDeg = deg = -PI / 2 - rand.nextFloat(0.66f);
        }
        pos.y = field.size.y + rand.nextFloat(field.size.y) + spec.size;
        break;
      case AppearanceType.CENTER:
        pos.x = 0;
        pos.y = field.outerSize.y * 0.99f + spec.size;
        velDeg = deg = 0;
        break;
      }
      ppos.x = pos.x;
      ppos.y = pos.y;
      vel.x = vel.y = 0;
      speed = 0;
      if (appType == AppearanceType.CENTER || checkFrontClear(true))
        return true;
    }
    return false;
  }

  public bool checkFrontClear(bool checkCurrentPos = false) {
    int si = 1;
    if (checkCurrentPos)
      si = 0;
    for (int i = si; i < 5; i++) {
      float cx = pos.x + sin(deg) * i * spec.size;
      float cy = pos.y + cos(deg) * i * spec.size;
      if (field.getBlock(cx, cy) >= 0)
        return false;
      if (enemies.checkHitShip(cx, cy, enemy, true))
        return false;
    }
    return true;
  }

  public bool move() {
    ppos.x = pos.x;
    ppos.y = pos.y;
    multiplier -= MULTIPLIER_DECREASE_RATIO;
    if (multiplier < 1)
      multiplier = 1;
    if (destroyedCnt >= 0) {
      destroyedCnt++;
      explodeCnt--;
      if (explodeCnt < 0) {
        explodeItv += 2;
        explodeItv = cast(int) (cast(float) explodeItv * (1.2f + rand.nextFloat(1)));
        explodeCnt = explodeItv;
        destroyedEdge(cast(int) (sqrt(spec.size) * 27.0f / (explodeItv * 0.1f + 1)));
      }
    }
    damaged = false;
    if (damagedCnt > 0)
      damagedCnt--;
    bool alive = false;
    for (int i = 0; i < spec.turretGroupNum; i++)
      alive |= turretGroup[i].move(pos, deg);
    for (int i = 0; i < spec.movingTurretGroupNum; i++)
      movingTurretGroup[i].move(pos, deg);
    if (destroyedCnt < 0 && !alive)
      return destroyed();
    return true;
  }

  public bool checkCollision(float x, float y, Collidable c, Shot shot) {
    float ox = fabs(pos.x - x), oy = fabs(pos.y - y);
    if (ox + oy > spec.size * 2)
      return false;
    for (int i = 0; i < spec.turretGroupNum; i++)
      if (turretGroup[i].checkCollision(x, y, c, shot))
        return true;
    if (spec.bridgeShape.checkCollision(ox, oy, c)) {
      addDamage(shot.damage, shot);
      return true;
    }
    return false;
  }

  public void increaseMultiplier(float m) {
    multiplier += m;
  }

  public void addScore(int s) {
    setScoreIndicator(s, 1);
  }

  public void addDamage(int n, Shot shot = null) {
    shield -= n;
    if (shield <= 0) {
      destroyed(shot);
    } else {
      damaged = true;
      damagedCnt = 7;
    }
  }

  public bool destroyed(Shot shot = null) {
    float vz;
    if (shot) {
      explodeVel.x = Shot.SPEED * sin(shot.deg) / 2;
      explodeVel.y = Shot.SPEED * cos(shot.deg) / 2;
      vz = 0;
    } else {
      explodeVel.x = explodeVel.y = 0;
      vz = 0.05f;
    }
    float ss = spec.size * 1.5f;
    if (ss > 2)
      ss = 2;
    float sn;
    if (spec.size < 1)
      sn = spec.size;
    else
      sn = sqrt(spec.size);
    assert(sn <>= 0);
    if (sn > 3)
      sn = 3;
    for (int i = 0; i < sn * 8; i++) {
      Smoke s = smokes.getInstanceForced();
      s.set(pos, rand.nextSignedFloat(0.1f) + explodeVel.x, rand.nextSignedFloat(0.1f) + explodeVel.y,
            rand.nextFloat(vz),
            Smoke.SmokeType.EXPLOSION, 32 + rand.nextInt(30), ss);
    }
    for (int i = 0; i < sn * 36; i++) {
      Spark sp = sparks.getInstanceForced();
      sp.set(pos, rand.nextSignedFloat(0.8f) + explodeVel.x, rand.nextSignedFloat(0.8f) + explodeVel.y,
             0.5f + rand.nextFloat(0.5f), 0.5f + rand.nextFloat(0.5f), 0, 30 + rand.nextInt(30));
    }
    for (int i = 0; i < sn * 12; i++) {
      Fragment f = fragments.getInstanceForced();
      f.set(pos, rand.nextSignedFloat(0.33f) + explodeVel.x, rand.nextSignedFloat(0.33f) + explodeVel.y,
            0.05f + rand.nextFloat(0.1f),
            0.2f + rand.nextFloat(0.33f));
    }
    removeTurrets();
    int sc = spec.score;
    bool r;
    if (spec.type == EnemySpec.EnemyType.SMALL) {
      SoundManager.playSe("small_destroyed.wav");
      r = false;
    } else {
      SoundManager.playSe("destroyed.wav");
      int bn = bullets.removeIndexedBullets(idx);
      destroyedCnt = 0;
      explodeCnt = 1;
      explodeItv = 3;
      sc += bn * 10;
      r = true;
      if (spec.isBoss)
        screen.setScreenShake(45, 0.04f);
    }
    setScoreIndicator(sc, multiplier);
    return r;
  }

  private void setScoreIndicator(int sc, float mp) {
    float ty = NumIndicator.getTargetY();
    if (mp > 1) {
      NumIndicator ni = numIndicators.getInstanceForced();
      ni.set(sc, NumIndicator.IndicatorType.SCORE, 0.5f, pos);
      ni.addTarget(8, ty, NumIndicator.FlyingToType.RIGHT, 1, 0.5f, sc, 40);
      ni.addTarget(11, ty, NumIndicator.FlyingToType.RIGHT, 0.5f, 0.75f,
                   cast(int) (sc * mp), 30);
      ni.addTarget(13, ty, NumIndicator.FlyingToType.RIGHT, 0.25f, 1,
                   cast(int) (sc * mp * stageManager.rankMultiplier), 20);
      ni.addTarget(12, -8, NumIndicator.FlyingToType.BOTTOM, 0.5f, 0.1f,
                   cast(int) (sc * mp * stageManager.rankMultiplier), 40);
      ni.gotoNextTarget();
      ni = numIndicators.getInstanceForced();
      int mn = cast(int) (mp * 1000);
      ni.set(mn, NumIndicator.IndicatorType.MULTIPLIER, 0.7f, pos);
      ni.addTarget(10.5f, ty, NumIndicator.FlyingToType.RIGHT, 0.5f, 0.2f, mn, 70);
      ni.gotoNextTarget();
      ni = numIndicators.getInstanceForced();
      int rn = cast(int) (stageManager.rankMultiplier * 1000);
      ni.set(rn, NumIndicator.IndicatorType.MULTIPLIER, 0.4f, 11, 8);
      ni.addTarget(13, ty, NumIndicator.FlyingToType.RIGHT, 0.5f, 0.2f, rn, 40);
      ni.gotoNextTarget();
      scoreReel.addActualScore(cast(int) (sc * mp * stageManager.rankMultiplier));
    } else {
      NumIndicator ni = numIndicators.getInstanceForced();
      ni.set(sc, NumIndicator.IndicatorType.SCORE, 0.3f, pos);
      ni.addTarget(11, ty, NumIndicator.FlyingToType.RIGHT, 1.5f, 0.2f, sc, 40);
      ni.addTarget(13, ty, NumIndicator.FlyingToType.RIGHT, 0.25f, 0.25f,
                   cast(int) (sc * stageManager.rankMultiplier), 20);
      ni.addTarget(12, -8, NumIndicator.FlyingToType.BOTTOM, 0.5f, 0.1f,
                   cast(int) (sc * stageManager.rankMultiplier), 40);
      ni.gotoNextTarget();
      ni = numIndicators.getInstanceForced();
      int rn = cast(int) (stageManager.rankMultiplier * 1000);
      ni.set(rn, NumIndicator.IndicatorType.MULTIPLIER, 0.4f, 11, 8);
      ni.addTarget(13, ty, NumIndicator.FlyingToType.RIGHT, 0.5f, 0.2f, rn, 40);
      ni.gotoNextTarget();
      scoreReel.addActualScore(cast(int) (sc * stageManager.rankMultiplier));
    }
  }

  public void destroyedEdge(int n) {
    SoundManager.playSe("explode.wav");
    int sn = n;
    if (sn > 48)
      sn = 48;
    Vector[] spp = (cast(BaseShape) spec.shape.shape).pointPos;
    float[] spd = (cast(BaseShape)spec.shape.shape).pointDeg;
    int si = rand.nextInt(spp.length);
    edgePos.x = spp[si].x * spec.size + pos.x;
    edgePos.y = spp[si].y * spec.size + pos.y;
    float ss = spec.size * 0.5f;
    if (ss > 1)
      ss = 1;
    for (int i = 0; i < sn; i++) {
      Smoke s = smokes.getInstanceForced();
      float sr = rand.nextFloat(0.5f);
      float sd = spd[si] + rand.nextSignedFloat(0.2f);
      assert(sd <>= 0);
      s.set(edgePos, sin(sd) * sr, cos(sd) * sr, -0.004f,
            Smoke.SmokeType.EXPLOSION, 75 + rand.nextInt(25), ss);
      for (int j = 0; j < 2; j++) {
        Spark sp = sparks.getInstanceForced();
        sp.set(edgePos, sin(sd) * sr * 2, cos(sd) * sr * 2,
               0.5f + rand.nextFloat(0.5f), 0.5f + rand.nextFloat(0.5f), 0, 30 + rand.nextInt(30));
      }
      if (i % 2 == 0) {
        SparkFragment sf = sparkFragments.getInstanceForced();
        sf.set(edgePos, sin(sd) * sr * 0.5f, cos(sd) * sr * 0.5f, 0.06f + rand.nextFloat(0.07f),
               (0.2f + rand.nextFloat(0.1f)));
      }
    }
  }

  public void removeTurrets() {
    for (int i = 0; i < spec.turretGroupNum; i++)
      turretGroup[i].remove();
    for (int i = 0; i < spec.movingTurretGroupNum; i++)
      movingTurretGroup[i].remove();
  }

  public void draw() {
    glPushMatrix();
    if (destroyedCnt < 0 && damagedCnt > 0) {
      damagedPos.x = pos.x + rand.nextSignedFloat(damagedCnt * 0.01f);
      damagedPos.y = pos.y + rand.nextSignedFloat(damagedCnt * 0.01f);
      Screen.glTranslate(damagedPos);
    } else {
      Screen.glTranslate(pos);
    }
    glRotatef(-deg * 180 / PI, 0, 0, 1);
    if (destroyedCnt >= 0)
      spec.destroyedShape.draw();
    else if (!damaged)
      spec.shape.draw();
    else
      spec.damagedShape.draw();
    if (destroyedCnt < 0)
      spec.bridgeShape.draw();
    glPopMatrix();
    if (destroyedCnt >= 0)
      return;
    for (int i = 0; i < spec.turretGroupNum; i++)
      turretGroup[i].draw();
    if (multiplier > 1) {
      float ox, oy;
      if (multiplier < 10)
        ox = 2.1f;
      else
        ox = 1.4f;
      oy = 1.25f;
      if(spec.isBoss) {
        ox += 4;
        oy -= 1.25f;
      }
      Letter.drawNumSign(cast(int) (multiplier * 1000),
                         pos.x + ox, pos.y + oy, 0.33f, 1, 33, 3);
    }
  }
}

/**
 * Base class for a specification of an enemy.
 */
public class EnemySpec {
 public:
  static enum EnemyType {
    SMALL, LARGE, PLATFORM,
  };
 protected:
  static Rand rand;
  Field field;
  Ship ship;
  SparkPool sparks;
  SmokePool smokes;
  FragmentPool fragments;
  WakePool wakes;
  int shield;
  float _size;
  float distRatio;
  TurretGroupSpec[EnemyState.TURRET_GROUP_MAX] turretGroupSpec;
  int turretGroupNum;
  MovingTurretGroupSpec[EnemyState.MOVING_TURRET_GROUP_MAX] movingTurretGroupSpec;
  int movingTurretGroupNum;
  EnemyShape shape, damagedShape, destroyedShape, bridgeShape;
  int type;

  invariant {
    assert(shield > 0 && shield < 1000);
    assert(_size > 0 && _size < 20);
    assert(distRatio >= 0 && distRatio <= 1);
    assert(turretGroupNum >= 0 && turretGroupNum <= EnemyState.TURRET_GROUP_MAX);
    assert(movingTurretGroupNum >= 0 && movingTurretGroupNum <= EnemyState.MOVING_TURRET_GROUP_MAX);
    assert(type >= 0);
  }

  public static this() {
    rand = new Rand;
  }

  public static void setRandSeed(long seed) {
    rand.setSeed(seed);
  }

  public this(Field field, Ship ship,
              SparkPool sparks, SmokePool smokes, FragmentPool fragments, WakePool wakes) {
    this.field = field;
    this.ship = ship;
    this.sparks = sparks;
    this.smokes = smokes;
    this.fragments = fragments;
    this.wakes = wakes;
    foreach (inout TurretGroupSpec tgs; turretGroupSpec)
      tgs = new TurretGroupSpec;
    foreach (inout MovingTurretGroupSpec tgs; movingTurretGroupSpec)
      tgs = new MovingTurretGroupSpec;
    distRatio = 0;
    shield = 1;
    _size = 1;
  }

  public void set(int type) {
    this.type = type;
    _size = 1;
    distRatio = 0;
    turretGroupNum = movingTurretGroupNum = 0;
  }

  public TurretGroupSpec getTurretGroupSpec() {
    turretGroupNum++;
    turretGroupSpec[turretGroupNum - 1].init();
    return turretGroupSpec[turretGroupNum - 1];
  }

  public MovingTurretGroupSpec getMovingTurretGroupSpec() {
    movingTurretGroupNum++;
    movingTurretGroupSpec[movingTurretGroupNum - 1].init();
    return movingTurretGroupSpec[movingTurretGroupNum - 1];
  }

  protected void addMovingTurret(float rank, bool bossMode = false) {
    int mtn = cast(int) (rank * 0.2f);
    if (mtn > EnemyState.MOVING_TURRET_GROUP_MAX)
      mtn = EnemyState.MOVING_TURRET_GROUP_MAX;
    if (mtn >= 2)
      mtn = 1 + rand.nextInt(mtn - 1);
    else
      mtn = 1;
    float br = rank / mtn;
    int type;
    if (!bossMode) {
      switch (rand.nextInt(4)) {
      case 0:
      case 1:
        type = MovingTurretGroupSpec.MoveType.ROLL;
        break;
      case 2:
        type = MovingTurretGroupSpec.MoveType.SWING_FIX;
        break;
      case 3:
        type = MovingTurretGroupSpec.MoveType.SWING_AIM;
        break;
      }
    } else {
      type = MovingTurretGroupSpec.MoveType.ROLL;
    }
    float rad = 0.9f + rand.nextFloat(0.4f) - mtn * 0.1f;
    float radInc = 0.5f + rand.nextFloat(0.25f);
    float ad = PI * 2;
    float a, av, dv, s, sv;
    switch (type) {
    case MovingTurretGroupSpec.MoveType.ROLL:
      a = 0.01f + rand.nextFloat(0.04f);
      av = 0.01f + rand.nextFloat(0.03f);
      dv = 0.01f + rand.nextFloat(0.04f);
      break;
    case MovingTurretGroupSpec.MoveType.SWING_FIX:
      ad = PI / 10 + rand.nextFloat(PI / 15);
      s = 0.01f + rand.nextFloat(0.02f);
      sv = 0.01f + rand.nextFloat(0.03f);
      break;
    case MovingTurretGroupSpec.MoveType.SWING_AIM:
      ad = PI / 10 + rand.nextFloat(PI / 15);
      if (rand.nextInt(5) == 0)
        s = 0.01f + rand.nextFloat(0.01f);
      else
        s = 0;
      sv = 0.01f + rand.nextFloat(0.02f);
      break;
    }
    for (int i = 0; i < mtn; i++) {
      MovingTurretGroupSpec tgs = getMovingTurretGroupSpec();
      tgs.moveType = type;
      tgs.radiusBase = rad;
      float sr;
      switch (type) {
      case MovingTurretGroupSpec.MoveType.ROLL:
        tgs.alignDeg = ad;
        tgs.num = 4 + rand.nextInt(6);
        if (rand.nextInt(2) == 0) {
          if (rand.nextInt(2) == 0)
            tgs.setRoll(dv, 0, 0);
          else
            tgs.setRoll(-dv, 0, 0);
        } else {
          if (rand.nextInt(2) == 0)
            tgs.setRoll(0, a, av);
          else
            tgs.setRoll(0, -a, av);
        }
        if (rand.nextInt(3) == 0)
          tgs.setRadiusAmp(1 + rand.nextFloat(1), 0.01f + rand.nextFloat(0.03f));
        if (rand.nextInt(2) == 0)
          tgs.distRatio = 0.8f + rand.nextSignedFloat(0.3f);
        sr = br / tgs.num;
        break;
      case MovingTurretGroupSpec.MoveType.SWING_FIX:
        tgs.num = 3 + rand.nextInt(5);
        tgs.alignDeg = ad * (tgs.num * 0.1f + 0.3f);
        if (rand.nextInt(2) == 0)
          tgs.setSwing(s, sv);
        else
          tgs.setSwing(-s, sv);
        if (rand.nextInt(6) == 0)
          tgs.setRadiusAmp(1 + rand.nextFloat(1), 0.01f + rand.nextFloat(0.03f));
        if (rand.nextInt(4) == 0)
          tgs.setAlignAmp(0.25f + rand.nextFloat(0.25f), 0.01f + rand.nextFloat(0.02f));
        sr = br / tgs.num;
        sr *= 0.6f;
        break;
      case MovingTurretGroupSpec.MoveType.SWING_AIM:
        tgs.num = 3 + rand.nextInt(4);
        tgs.alignDeg = ad * (tgs.num * 0.1f + 0.3f);
        if (rand.nextInt(2) == 0)
          tgs.setSwing(s, sv, true);
        else
          tgs.setSwing(-s, sv, true);
        if (rand.nextInt(4) == 0)
          tgs.setRadiusAmp(1 + rand.nextFloat(1), 0.01f + rand.nextFloat(0.03f));
        if (rand.nextInt(5) == 0)
          tgs.setAlignAmp(0.25f + rand.nextFloat(0.25f), 0.01f + rand.nextFloat(0.02f));
        sr = br / tgs.num;
        sr *= 0.4f;
        break;
      }
      if (rand.nextInt(4) == 0)
        tgs.setXReverse(-1);
      tgs.turretSpec.setParam(sr, TurretSpec.TurretType.MOVING, rand);
      if (bossMode)
        tgs.turretSpec.setBossSpec();
      rad += radInc;
      ad *= 1 + rand.nextSignedFloat(0.2f);
    }
  }

  public bool checkCollision(EnemyState es, float x, float y, Collidable c, Shot shot) {
    return es.checkCollision(x, y, c, shot);
  }

  public bool checkShipCollision(EnemyState es, float x, float y, bool largeOnly = false) {
    if (es.destroyedCnt >= 0 || (largeOnly && type != EnemyType.LARGE))
      return false;
    return shape.checkShipCollision(x - es.pos.x, y - es.pos.y, es.deg);
  }

  public bool move(EnemyState es) {
    return es.move();
  }

  public void draw(EnemyState es) {
    es.draw();
  }

  public float size() {
    return _size;
  }

  public float size(float v) {
    _size = v;
    if (shape)
      shape.size = _size;
    if (damagedShape)
      damagedShape.size = _size;
    if (destroyedShape)
      destroyedShape.size = _size;
    if (bridgeShape) {
      float s = 0.9f;
      bridgeShape.size = s * (1 - distRatio);
    }
    return _size;
  }

  public bool isSmallEnemy() {
    if (type == EnemyType.SMALL)
      return true;
    else
      return false;
  }

  public abstract int score();
  public abstract bool isBoss();
}

public interface HasAppearType {
  public bool setFirstState(EnemyState es, int appType);
}

/**
 * Specification for a small class ship.
 */
public class SmallShipEnemySpec: EnemySpec, HasAppearType {
 public:
  static enum MoveType {
    STOPANDGO, CHASE,
  };
  static enum MoveState {
    STAYING, MOVING,
  };
 private:
  int type;
  float accel, maxSpeed, staySpeed;
  int moveDuration, stayDuration;
  float speed, turnDeg;

  invariant {
    assert(type >= 0);
    assert(accel >= 0 && accel <= 1);
    assert(maxSpeed < 10 && maxSpeed > -10);
    assert(staySpeed < 10 && staySpeed > -10);
    assert(moveDuration > 0 && moveDuration < 500);
    assert(stayDuration > 0 && stayDuration < 500);
    assert(speed < 10 && speed > -10);
    assert(turnDeg < 1 && turnDeg > -1);
  }

  public this(Field field, Ship ship,
              SparkPool sparks, SmokePool smokes, FragmentPool fragments, WakePool wakes) {
    super(field, ship, sparks, smokes, fragments, wakes);
    type = 0;
    accel = maxSpeed = staySpeed = 0;
    moveDuration = stayDuration = 1;
    speed = turnDeg = 0;
  }

  public void setParam(float rank, Rand rand) {
    set(EnemyType.SMALL);
    shape = new EnemyShape(EnemyShape.EnemyShapeType.SMALL);
    damagedShape = new EnemyShape(EnemyShape.EnemyShapeType.SMALL_DAMAGED);
    bridgeShape = new EnemyShape(EnemyShape.EnemyShapeType.SMALL_BRIDGE);
    type = rand.nextInt(2);
    float sr = rand.nextFloat(rank * 0.8f);
    if (sr > 25)
      sr = 25;
    switch (type) {
    case MoveType.STOPANDGO:
      distRatio = 0.5f;
      size = 0.47f + rand.nextFloat(0.1f);
      accel = 0.5f - 0.5f / (2.0f + rand.nextFloat(rank));
      maxSpeed = 0.05f * (1.0f + sr);
      staySpeed = 0.03f;
      moveDuration = 32 + rand.nextSignedInt(12);
      stayDuration = 32 + rand.nextSignedInt(12);
      break;
    case MoveType.CHASE:
      distRatio = 0.5f;
      size = 0.5f + rand.nextFloat(0.1f);
      speed = 0.036f * (1.0f + sr);
      turnDeg = 0.02f + rand.nextSignedFloat(0.04f);
      break;
    }
    shield = 1;
    TurretGroupSpec tgs = getTurretGroupSpec();
    tgs.turretSpec.setParam(rank - sr * 0.5f, TurretSpec.TurretType.SMALL, rand);
  }

  public bool setFirstState(EnemyState es, int appType) {
    es.setSpec(this);
    if (!es.setAppearancePos(field, ship, rand, appType))
      return false;
    switch (type) {
    case MoveType.STOPANDGO:
      es.speed = 0;
      es.state = MoveState.MOVING;
      es.cnt = moveDuration;
      break;
    case MoveType.CHASE:
      es.speed = speed;
      break;
    }
    return true;
  }

  public bool move(EnemyState es) {
    if (!super.move(es))
      return false;
    switch (type) {
    case MoveType.STOPANDGO:
      es.pos.x += sin(es.velDeg) * es.speed;
      es.pos.y += cos(es.velDeg) * es.speed;
      es.pos.y -= field.lastScrollY;
      if  (es.pos.y <= -field.outerSize.y)
        return false;
      if (field.getBlock(es.pos) >= 0 || !field.checkInOuterHeightField(es.pos)) {
        es.velDeg += PI;
        es.pos.x += sin(es.velDeg) * es.speed * 2;
        es.pos.y += cos(es.velDeg) * es.speed * 2;
      }
      switch (es.state) {
      case MoveState.MOVING:
        es.speed += (maxSpeed - es.speed) * accel;
        es.cnt--;
        if (es.cnt <= 0) {
          es.velDeg = rand.nextFloat(PI * 2);
          es.cnt = stayDuration;
          es.state = MoveState.STAYING;
        }
        break;
      case MoveState.STAYING:
        es.speed += (staySpeed - es.speed) * accel;
        es.cnt--;
        if (es.cnt <= 0) {
          es.cnt = moveDuration;
          es.state = MoveState.MOVING;
        }
        break;
      }
      break;
    case MoveType.CHASE:
      es.pos.x += sin(es.velDeg) * speed;
      es.pos.y += cos(es.velDeg) * speed;
      es.pos.y -= field.lastScrollY;
      if  (es.pos.y <= -field.outerSize.y)
        return false;
      if (field.getBlock(es.pos) >= 0 || !field.checkInOuterHeightField(es.pos)) {
        es.velDeg += PI;
        es.pos.x += sin(es.velDeg) * es.speed * 2;
        es.pos.y += cos(es.velDeg) * es.speed * 2;
      }
      float ad;
      Vector shipPos = ship.nearPos(es.pos);
      if (shipPos.dist(es.pos) < 0.1f)
        ad = 0;
      else
        ad = atan2(shipPos.x - es.pos.x, shipPos.y - es.pos.y);
      assert(ad <>= 0);
      float od = ad - es.velDeg;
      Math.normalizeDeg(od);
      if (od <= turnDeg && od >= -turnDeg)
        es.velDeg = ad;
      else if (od < 0)
        es.velDeg -= turnDeg;
      else
        es.velDeg += turnDeg;
      Math.normalizeDeg(es.velDeg);
      es.cnt++;
    }
    float od = es.velDeg - es.deg;
    Math.normalizeDeg(od);
    es.deg += od * 0.05f;
    Math.normalizeDeg(es.deg);
    if (es.cnt % 6 == 0 && es.speed >= 0.03f)
      shape.addWake(wakes, es.pos, es.deg, es.speed);
    return true;
  }

  public int score() {
    return 50;
  }

  public bool isBoss() {
    return false;
  }
}

/**
 * Specification for a large/middle class ship.
 */
public class ShipEnemySpec: EnemySpec, HasAppearType {
 public:
  static enum ShipClass {
    MIDDLE, LARGE, BOSS,
  };
 private:
  static const int SINK_INTERVAL = 120;
  float speed, degVel;
  int shipClass;

  invariant {
    assert(speed < 10 && speed > -10);
    assert(degVel < 1 && degVel > -1);
  }

  public this(Field field, Ship ship,
              SparkPool sparks, SmokePool smokes, FragmentPool fragments, WakePool wakes) {
    super(field, ship, sparks, smokes, fragments, wakes);
    speed = degVel = 0;
  }

  public void setParam(float rank, int cls, Rand rand) {
    shipClass = cls;
    set(EnemyType.LARGE);
    shape = new EnemyShape(EnemyShape.EnemyShapeType.MIDDLE);
    damagedShape = new EnemyShape(EnemyShape.EnemyShapeType.MIDDLE_DAMAGED);
    destroyedShape = new EnemyShape(EnemyShape.EnemyShapeType.MIDDLE_DESTROYED);
    bridgeShape = new EnemyShape(EnemyShape.EnemyShapeType.MIDDLE_BRIDGE);
    distRatio = 0.7f;
    int mainTurretNum = 0, subTurretNum = 0;
    float movingTurretRatio = 0;
    float rk = rank;
    switch (cls) {
    case ShipClass.MIDDLE:
      float sz = 1.5f + rank / 15 + rand.nextFloat(rank / 15);
      float ms = 2 + rand.nextFloat(0.5f);
      if (sz > ms)
        sz = ms;
      size = sz;
      speed = 0.015f + rand.nextSignedFloat(0.005f);
      degVel = 0.005f + rand.nextSignedFloat(0.003f);
      switch (rand.nextInt(3)) {
      case 0:
        mainTurretNum = cast(int) (size * (1 + rand.nextSignedFloat(0.25f)) + 1);
        break;
      case 1:
        subTurretNum = cast(int) (size * 1.6f * (1 + rand.nextSignedFloat(0.5f)) + 2);
        break;
      case 2:
        mainTurretNum = cast(int) (size * (0.5f + rand.nextSignedFloat(0.12f)) + 1);
        movingTurretRatio = 0.5f + rand.nextFloat(0.25f);
        rk = rank * (1 - movingTurretRatio);
        movingTurretRatio *= 2;
        break;
      }
      break;
    case ShipClass.LARGE:
      float sz = 2.5f + rank / 24 + rand.nextFloat(rank / 24);
      float ms = 3 + rand.nextFloat(1);
      if (sz > ms)
        sz = ms;
      size = sz;
      speed = 0.01f + rand.nextSignedFloat(0.005f);
      degVel = 0.003f + rand.nextSignedFloat(0.002f);
      mainTurretNum = cast(int) (size * (0.7f + rand.nextSignedFloat(0.2f)) + 1);
      subTurretNum = cast(int) (size * 1.6f * (0.7f + rand.nextSignedFloat(0.33f)) + 2);
      movingTurretRatio = 0.25f + rand.nextFloat(0.5f);
      rk = rank * (1 - movingTurretRatio);
      movingTurretRatio *= 3;
      break;
    case ShipClass.BOSS:
      float sz = 5 + rank / 30 + rand.nextFloat(rank / 30);
      float ms = 9 + rand.nextFloat(3);
      if (sz > ms)
        sz = ms;
      size = sz;
      speed = ship.scrollSpeedBase + 0.0025f + rand.nextSignedFloat(0.001f);
      degVel = 0.003f + rand.nextSignedFloat(0.002f);
      mainTurretNum = cast(int) (size * 0.8f * (1.5f + rand.nextSignedFloat(0.4f)) + 2);
      subTurretNum = cast(int) (size * 0.8f * (2.4f + rand.nextSignedFloat(0.6f)) + 2);
      movingTurretRatio = 0.2f + rand.nextFloat(0.3f);
      rk = rank * (1 - movingTurretRatio);
      movingTurretRatio *= 2.5f;
      break;
    }
    shield = cast(int) (size * 10);
    if (cls == ShipClass.BOSS)
      shield *= 2.4f;
    if (mainTurretNum + subTurretNum <= 0) {
      TurretGroupSpec tgs = getTurretGroupSpec();
      tgs.turretSpec.setParam(0, TurretSpec.TurretType.DUMMY, rand);
    } else {
      float subTurretRank = rk / (mainTurretNum * 3 + subTurretNum);
      float mainTurretRank = subTurretRank * 2.5f;
      if (cls != ShipClass.BOSS) {
        int frontMainTurretNum = cast(int) (mainTurretNum / 2 + 0.99f);
        int rearMainTurretNum = mainTurretNum - frontMainTurretNum;
        if (frontMainTurretNum > 0) {
          TurretGroupSpec tgs = getTurretGroupSpec();
          tgs.turretSpec.setParam(mainTurretRank, TurretSpec.TurretType.MAIN, rand);
          tgs.num = frontMainTurretNum;
          tgs.alignType = TurretGroupSpec.AlignType.STRAIGHT;
          tgs.offset.y = -size * (0.9f + rand.nextSignedFloat(0.05f));
        }
        if (rearMainTurretNum > 0) {
          TurretGroupSpec tgs = getTurretGroupSpec();
          tgs.turretSpec.setParam(mainTurretRank, TurretSpec.TurretType.MAIN, rand);
          tgs.num = rearMainTurretNum;
          tgs.alignType = TurretGroupSpec.AlignType.STRAIGHT;
          tgs.offset.y = size * (0.9f + rand.nextSignedFloat(0.05f));
        }
        TurretSpec pts;
        if (subTurretNum > 0) {
          int frontSubTurretNum = (subTurretNum + 2) / 4;
          int rearSubTurretNum = (subTurretNum - frontSubTurretNum * 2) / 2;
          int tn = frontSubTurretNum;
          float ad = -PI / 4;
          for (int i = 0; i < 4; i++) {
            if (i == 2)
              tn = rearSubTurretNum;
            if (tn <= 0)
              continue;
            TurretGroupSpec tgs = getTurretGroupSpec();
            if (i == 0 || i == 2) {
              if (rand.nextInt(2) == 0)
                tgs.turretSpec.setParam(subTurretRank, TurretSpec.TurretType.SUB, rand);
              else
                tgs.turretSpec.setParam(subTurretRank, TurretSpec.TurretType.SUB_DESTRUCTIVE, rand);
              pts = tgs.turretSpec;
            } else {
              tgs.turretSpec.setParam(pts);
            }
            tgs.num = tn;
            tgs.alignType = TurretGroupSpec.AlignType.ROUND;
            tgs.alignDeg = ad;
            ad += PI / 2;
            tgs.alignWidth = PI / 6 + rand.nextFloat(PI / 8);
            tgs.radius = size * 0.75f;
            tgs.distRatio = distRatio;
          }
        }
      } else {
        mainTurretRank *= 2.5f;
        subTurretRank *= 2;
        TurretSpec pts;
        if (mainTurretNum > 0) {
          int frontMainTurretNum = (mainTurretNum + 2) / 4;
          int rearMainTurretNum = (mainTurretNum - frontMainTurretNum * 2) / 2;
          int tn = frontMainTurretNum;
          float ad = -PI / 4;
          for (int i = 0; i < 4; i++) {
            if (i == 2)
              tn = rearMainTurretNum;
            if (tn <= 0)
              continue;
            TurretGroupSpec tgs = getTurretGroupSpec();
            if (i == 0 || i == 2) {
              tgs.turretSpec.setParam(mainTurretRank, TurretSpec.TurretType.MAIN, rand);
              pts = tgs.turretSpec;
              pts.setBossSpec();
            } else {
              tgs.turretSpec.setParam(pts);
            }
            tgs.num = tn;
            tgs.alignType = TurretGroupSpec.AlignType.ROUND;
            tgs.alignDeg = ad;
            ad += PI / 2;
            tgs.alignWidth = PI / 6 + rand.nextFloat(PI / 8);
            tgs.radius = size * 0.45f;
            tgs.distRatio = distRatio;
          }
        }
        if (subTurretNum > 0) {
          int[3] tn;
          tn[0] = (subTurretNum + 2) / 6;
          tn[1] = (subTurretNum - tn[0] * 2) / 4;
          tn[2] = (subTurretNum - tn[0] * 2 - tn[1] * 2) / 2;
          static const float[] ad = [PI / 4, -PI / 4, PI / 2, -PI / 2, PI / 4 * 3, -PI / 4 * 3];
          for (int i = 0; i < 6; i++) {
            int idx = i / 2;
            if (tn[idx] <= 0)
              continue;
            TurretGroupSpec tgs = getTurretGroupSpec();
            if (i == 0 || i == 2 || i == 4) {
              if (rand.nextInt(2) == 0)
                tgs.turretSpec.setParam(subTurretRank, TurretSpec.TurretType.SUB, rand);
              else
                tgs.turretSpec.setParam(subTurretRank, TurretSpec.TurretType.SUB_DESTRUCTIVE, rand);
              pts = tgs.turretSpec;
              pts.setBossSpec();
            } else {
              tgs.turretSpec.setParam(pts);
            }
            tgs.num = tn[idx];
            tgs.alignType = TurretGroupSpec.AlignType.ROUND;
            tgs.alignDeg = ad[i];
            tgs.alignWidth = PI / 7 + rand.nextFloat(PI / 9);
            tgs.radius = size * 0.75f;
            tgs.distRatio = distRatio;
          }
        }
      }
    }
    if (movingTurretRatio > 0) {
      if (cls == ShipClass.BOSS)
        addMovingTurret(rank * movingTurretRatio, true);
      else
        addMovingTurret(rank * movingTurretRatio);
    }
  }

  public bool setFirstState(EnemyState es, int appType) {
    es.setSpec(this);
    if (!es.setAppearancePos(field, ship, rand, appType))
      return false;
    es.speed = speed;
    if (es.pos.x < 0)
      es.turnWay = -1;
    else
      es.turnWay = 1;
    if (isBoss) {
      es.trgDeg = rand.nextFloat(0.1f) + 0.1f;
      if (rand.nextInt(2) == 0)
        es.trgDeg *= -1;
      es.turnCnt = 250 + rand.nextInt(150);
    }
    return true;
  }

  public bool move(EnemyState es) {
    if (es.destroyedCnt >= SINK_INTERVAL)
      return false;
    if (!super.move(es))
      return false;
    es.pos.x += sin(es.deg) * es.speed;
    es.pos.y += cos(es.deg) * es.speed;
    es.pos.y -= field.lastScrollY;
    if  (es.pos.x <= -field.outerSize.x - size || es.pos.x >= field.outerSize.x + size ||
         es.pos.y <= -field.outerSize.y - size)
      return false;
    if (es.pos.y > field.outerSize.y * 2.2f + size)
      es.pos.y = field.outerSize.y * 2.2f + size;
    if (isBoss) {
      es.turnCnt--;
      if (es.turnCnt <= 0) {
        es.turnCnt = 250 + rand.nextInt(150);
        es.trgDeg = rand.nextFloat(0.1f) + 0.2f;
        if (es.pos.x > 0)
          es.trgDeg *= -1;
      }
      es.deg += (es.trgDeg - es.deg) * 0.0025f;
      if (ship.higherPos.y > es.pos.y)
        es.speed += (speed * 2 - es.speed) * 0.005f;
      else
        es.speed += (speed - es.speed) * 0.01f;
    } else {
      if (!es.checkFrontClear()) {
        es.deg += degVel * es.turnWay;
        es.speed *= 0.98f;
      } else {
        if (es.destroyedCnt < 0)
          es.speed += (speed - es.speed) * 0.01f;
        else
          es.speed *= 0.98f;
      }
    }
    es.cnt++;
    if (es.cnt % 6 == 0 && es.speed >= 0.01f && es.destroyedCnt < SINK_INTERVAL / 2)
      shape.addWake(wakes, es.pos, es.deg, es.speed);
    return true;
  }

  public override void draw(EnemyState es) {
    if (es.destroyedCnt >= 0)
      Screen.setColor(
        EnemyShape.MIDDLE_COLOR_R * (1 - cast(float) es.destroyedCnt / SINK_INTERVAL) * 0.5f,
        EnemyShape.MIDDLE_COLOR_G * (1 - cast(float) es.destroyedCnt / SINK_INTERVAL) * 0.5f,
        EnemyShape.MIDDLE_COLOR_B * (1 - cast(float) es.destroyedCnt / SINK_INTERVAL) * 0.5f);
    super.draw(es);
  }

  public int score() {
    switch (shipClass) {
    case ShipClass.MIDDLE:
      return 100;
    case ShipClass.LARGE:
      return 300;
    case ShipClass.BOSS:
      return 1000;
    }
  }

  public bool isBoss() {
    if (shipClass == ShipClass.BOSS)
      return true;
    return false;
  }
}

/**
 * Specification for a sea-based platform.
 */
public class PlatformEnemySpec: EnemySpec {
 private:

  public this(Field field, Ship ship,
              SparkPool sparks, SmokePool smokes, FragmentPool fragments, WakePool wakes) {
    super(field, ship, sparks, smokes, fragments, wakes);
  }

  public void setParam(float rank, Rand rand) {
    set(EnemyType.PLATFORM);
    shape = new EnemyShape(EnemyShape.EnemyShapeType.PLATFORM);
    damagedShape = new EnemyShape(EnemyShape.EnemyShapeType.PLATFORM_DAMAGED);
    destroyedShape = new EnemyShape(EnemyShape.EnemyShapeType.PLATFORM_DESTROYED);
    bridgeShape = new EnemyShape(EnemyShape.EnemyShapeType.PLATFORM_BRIDGE);
    distRatio = 0;
    size = 1 + rank / 30 + rand.nextFloat(rank / 30);
    float ms = 1 + rand.nextFloat(0.25f);
    if (size > ms)
      size = ms;
    int mainTurretNum = 0, frontTurretNum = 0, sideTurretNum = 0;
    float rk = rank;
    float movingTurretRatio = 0;
    switch (rand.nextInt(3)) {
    case 0:
      frontTurretNum = cast(int) (size * (2 + rand.nextSignedFloat(0.5f)) + 1);
      movingTurretRatio = 0.33f + rand.nextFloat(0.46f);
      rk *= (1 - movingTurretRatio);
      movingTurretRatio *= 2.5f;
      break;
    case 1:
      frontTurretNum = cast(int) (size * (0.5f + rand.nextSignedFloat(0.2f)) + 1);
      sideTurretNum = cast(int) (size * (0.5f + rand.nextSignedFloat(0.2f)) + 1) * 2;
      break;
    case 2:
      mainTurretNum = cast(int) (size * (1 + rand.nextSignedFloat(0.33f)) + 1);
      break;
    }
    shield = cast(int) (size * 20);
    int subTurretNum = frontTurretNum + sideTurretNum;
    float subTurretRank = rk / (mainTurretNum * 3 + subTurretNum);
    float mainTurretRank = subTurretRank * 2.5f;
    if (mainTurretNum > 0) {
      TurretGroupSpec tgs = getTurretGroupSpec();
      tgs.turretSpec.setParam(mainTurretRank, TurretSpec.TurretType.MAIN, rand);
      tgs.num = mainTurretNum;
      tgs.alignType = TurretGroupSpec.AlignType.ROUND;
      tgs.alignDeg = 0;
      tgs.alignWidth = PI * 0.66f + rand.nextFloat(PI / 2);
      tgs.radius = size * 0.7f;
      tgs.distRatio = distRatio;
    }
    if (frontTurretNum > 0) {
      TurretGroupSpec tgs = getTurretGroupSpec();
      tgs.turretSpec.setParam(subTurretRank, TurretSpec.TurretType.SUB, rand);
      tgs.num = frontTurretNum;
      tgs.alignType = TurretGroupSpec.AlignType.ROUND;
      tgs.alignDeg = 0;
      tgs.alignWidth = PI / 5 + rand.nextFloat(PI / 6);
      tgs.radius = size * 0.8f;
      tgs.distRatio = distRatio;
    }
    sideTurretNum /= 2;
    if (sideTurretNum > 0) {
      TurretSpec pts;
      for (int i = 0; i < 2; i++) {
        TurretGroupSpec tgs = getTurretGroupSpec();
        if (i == 0) {
          tgs.turretSpec.setParam(subTurretRank, TurretSpec.TurretType.SUB, rand);
          pts = tgs.turretSpec;
        } else {
          tgs.turretSpec.setParam(pts);
        }
        tgs.num = sideTurretNum;
        tgs.alignType = TurretGroupSpec.AlignType.ROUND;
        tgs.alignDeg = PI / 2 - PI * i;
        tgs.alignWidth = PI / 5 + rand.nextFloat(PI / 6);
        tgs.radius = size * 0.75f;
        tgs.distRatio = distRatio;
      }
    }
    if (movingTurretRatio > 0) {
      addMovingTurret(rank * movingTurretRatio);
    }
  }

  public bool setFirstState(EnemyState es, float x, float y, float d) {
    es.setSpec(this);
    es.pos.x = x;
    es.pos.y = y;
    es.deg = d;
    es.speed = 0;
    if (!es.checkFrontClear(true))
      return false;
    return true;
  }

  public bool move(EnemyState es) {
    if (!super.move(es))
      return false;
    es.pos.y -= field.lastScrollY;
    if  (es.pos.y <= -field.outerSize.y)
      return false;
    return true;
  }

  public int score() {
    return 100;
  }

  public bool isBoss() {
    return false;
  }
}

public class EnemyPool: ActorPool!(Enemy) {
 private:

  public this(int n, Object[] args) {
    super(n, args);
    foreach (Enemy e; actor)
      e.setEnemyPool(this);
  }

  public void setStageManager(StageManager stageManager) {
    foreach (Enemy e; actor)
      e.setStageManager(stageManager);
  }

  public void checkShotHit(Vector pos, Collidable shape, Shot shot = null) {
    foreach (Enemy e; actor)
      if (e.exists)
        e.checkShotHit(pos, shape, shot);
  }

  public Enemy checkHitShip(float x, float y, Enemy deselection = null, bool largeOnly = false) {
    foreach (Enemy e; actor)
      if (e.exists && e != deselection)
        if (e.checkHitShip(x, y, largeOnly))
          return e;
    return null;
  }

  public bool hasBoss() {
    foreach (Enemy e; actor)
      if (e.exists && e.isBoss)
        return true;
    return false;
  }
}
