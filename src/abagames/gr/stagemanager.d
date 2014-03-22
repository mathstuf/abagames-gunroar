/*
 * $Id: stagemanager.d,v 1.2 2005/07/03 07:05:22 kenta Exp $
 *
 * Copyright 2005 Kenta Cho. Some rights reserved.
 */
module abagames.gr.stagemanager;

private import std.string;
private import std.math;
private import abagames.util.vector;
private import abagames.util.rand;
private import abagames.util.sdl.shape;
private import abagames.gr.enemy;
private import abagames.gr.bullet;
private import abagames.gr.ship;
private import abagames.gr.field;
private import abagames.gr.letter;
private import abagames.gr.particle;
private import abagames.gr.soundmanager;

/**
 * Manage an enemys' appearance, a rank(difficulty) and a field.
 */
public class StageManager {
 private:
  static const float RANK_INC_BASE = 0.0018f;
  static const int BLOCK_DENSITY_MIN = 0;
  static const int BLOCK_DENSITY_MAX = 3;
  Field field;
  EnemyPool enemies;
  Ship ship;
  BulletPool bullets;
  SparkPool sparks;
  SmokePool smokes;
  FragmentPool fragments;
  WakePool wakes;
  Rand rand;
  float rank, baseRank, addRank, rankVel, rankInc;
  EnemyAppearance[] enemyApp;
  int _blockDensity;
  int batteryNum;
  PlatformEnemySpec platformEnemySpec;
  bool _bossMode;
  int bossAppCnt;
  int bossAppTime, bossAppTimeBase;
  int bgmStartCnt;

  invariant {
    assert(rank >= 1);
    assert(baseRank >= 1);
    assert(addRank >= 0);
    assert(rankVel <>= 0);
    assert(rankInc <>= 0);
    assert(_blockDensity >= BLOCK_DENSITY_MIN && _blockDensity <= BLOCK_DENSITY_MAX);
    assert(batteryNum >= 0 && batteryNum < 50);
  }

  public this(Field field, EnemyPool enemies, Ship ship, BulletPool bullets,
              SparkPool sparks, SmokePool smokes, FragmentPool fragments, WakePool wakes) {
    this.field = field;
    this.enemies = enemies;
    this.ship = ship;
    this.bullets = bullets;
    this.sparks = sparks;
    this.smokes = smokes;
    this.fragments = fragments;
    this.wakes = wakes;
    rand = new Rand;
    enemyApp = new EnemyAppearance[3];
    foreach (inout EnemyAppearance ea; enemyApp)
      ea = new EnemyAppearance;
    PlatformEnemySpec platformEnemySpec =
      new PlatformEnemySpec(field, ship, sparks, smokes, fragments, wakes);
    rank = baseRank = 1;
    addRank = rankVel = rankInc = 0;
    _blockDensity = 2;
  }

  public void setRandSeed(long seed) {
    rand.setSeed(seed);
  }

  public void start(float rankIncRatio) {
    rank = baseRank = 1;
    addRank = rankVel = 0;
    rankInc = RANK_INC_BASE * rankIncRatio;
    _blockDensity = rand.nextInt(BLOCK_DENSITY_MAX - BLOCK_DENSITY_MIN + 1) + BLOCK_DENSITY_MIN;
    _bossMode = false;
    bossAppTimeBase = 60 * 1000;
    resetBossMode();
    gotoNextBlockArea();
    bgmStartCnt = -1;
  }

  public void startBossMode() {
    _bossMode = true;
    bossAppCnt = 2;
    SoundManager.fadeBgm();
    bgmStartCnt = 120;
    rankVel = 0;
  }

  public void resetBossMode() {
    if (_bossMode) {
      _bossMode = false;
      SoundManager.fadeBgm();
      bgmStartCnt = 120;
      bossAppTimeBase += 30 * 1000;
    }
    bossAppTime = bossAppTimeBase;
  }

  public void move() {
    bgmStartCnt--;
    if (bgmStartCnt == 0) {
      if (_bossMode)
        SoundManager.playBgm("gr0.ogg");
      else
        SoundManager.nextBgm();
    }
    if (_bossMode) {
      addRank *= 0.999f;
      if (!enemies.hasBoss && bossAppCnt <= 0)
        resetBossMode();
    } else {
      float rv = field.lastScrollY / ship.scrollSpeedBase - 2;
      bossAppTime -= 17;
      if (bossAppTime <= 0) {
        bossAppTime = 0;
        startBossMode();
      }
      if (rv > 0) {
        rankVel += rv * rv * 0.0004f * baseRank;
      } else {
        rankVel += rv * baseRank;
        if (rankVel < 0)
          rankVel = 0;
      }
      addRank += rankInc * (rankVel + 1);
      addRank *= 0.999f;
      baseRank += rankInc + addRank * 0.0001f;
    }
    rank = baseRank + addRank;
    foreach (EnemyAppearance ea; enemyApp)
      ea.move(enemies, field);
  }

  public void shipDestroyed() {
    rankVel = 0;
    if (!_bossMode)
      addRank = 0;
    else
      addRank /= 2;
  }

  public void gotoNextBlockArea() {
    if (_bossMode) {
      bossAppCnt--;
      if (bossAppCnt == 0) {
        ShipEnemySpec ses = new ShipEnemySpec(field, ship, sparks, smokes, fragments, wakes);
        ses.setParam(rank, ShipEnemySpec.ShipClass.BOSS, rand);
        Enemy en = enemies.getInstance();
        if (en) {
          if ((cast(HasAppearType) ses).setFirstState(en.state, EnemyState.AppearanceType.CENTER))
            en.set(ses);
        } else {
          resetBossMode();
        }
      }
      foreach (EnemyAppearance ea; enemyApp)
        ea.unset();
      return;
    }
    bool noSmallShip;
    if (_blockDensity < BLOCK_DENSITY_MAX && rand.nextInt(2) == 0)
      noSmallShip = true;
    else
      noSmallShip = false;
    _blockDensity += rand.nextSignedInt(1);
    if (_blockDensity < BLOCK_DENSITY_MIN)
      _blockDensity = BLOCK_DENSITY_MIN;
    else if (_blockDensity > BLOCK_DENSITY_MAX)
      _blockDensity = BLOCK_DENSITY_MAX;
    batteryNum = cast(int) ((_blockDensity + rand.nextSignedFloat(1)) * 0.75f);
    float tr = rank;
    int largeShipNum = cast(int) ((2 - _blockDensity + rand.nextSignedFloat(1)) * 0.5f);
    if (noSmallShip)
      largeShipNum *= 1.5f;
    else
      largeShipNum *= 0.5f;
    int appType = rand.nextInt(2);
    if (largeShipNum > 0) {
      float lr = tr * (0.25f + rand.nextFloat(0.15f));
      if (noSmallShip)
        lr *= 1.5f;
      tr -= lr;
      ShipEnemySpec ses = new ShipEnemySpec(field, ship, sparks, smokes, fragments, wakes);
      ses.setParam(lr / largeShipNum, ShipEnemySpec.ShipClass.LARGE, rand);
      enemyApp[0].set(ses, largeShipNum, appType, rand);
    } else {
      enemyApp[0].unset();
    }
    if (batteryNum > 0) {
      platformEnemySpec = new PlatformEnemySpec(field, ship, sparks, smokes, fragments, wakes);
      float pr = tr * (0.3f + rand.nextFloat(0.1f));
      platformEnemySpec.setParam(pr / batteryNum, rand);
    }
    appType = (appType + 1) % 2;
    int middleShipNum = cast(int) ((4 - _blockDensity + rand.nextSignedFloat(1)) * 0.66f);
    if (noSmallShip)
      middleShipNum *= 2;
    if (middleShipNum > 0) {
      float mr;
      if (noSmallShip)
        mr = tr;
      else
        mr = tr * (0.33f + rand.nextFloat(0.33f));
      tr -= mr;
      ShipEnemySpec ses = new ShipEnemySpec(field, ship, sparks, smokes, fragments, wakes);
      ses.setParam(mr / middleShipNum, ShipEnemySpec.ShipClass.MIDDLE, rand);
      enemyApp[1].set(ses, middleShipNum, appType, rand);
    } else {
      enemyApp[1].unset();
    }
    if (!noSmallShip) {
      appType = EnemyState.AppearanceType.TOP;
      int smallShipNum =
        cast(int) (sqrt(3 + tr) * (1 + rand.nextSignedFloat(0.5f)) * 2) + 1;
      if (smallShipNum > 256)
        smallShipNum = 256;
      SmallShipEnemySpec sses = new SmallShipEnemySpec(field, ship, sparks, smokes, fragments, wakes);
      sses.setParam(tr / smallShipNum, rand);
      enemyApp[2].set(sses, smallShipNum, appType, rand);
    } else {
      enemyApp[2].unset();
    }
  }

  public void addBatteries(PlatformPos[] platformPos, int platformPosNum) {
    int ppn = platformPosNum;
    int bn = batteryNum;
    for (int i = 0; i < 100; i++) {
      if (ppn <= 0 || bn <= 0)
        break;
      int ppi = rand.nextInt(platformPosNum);
      for (int j = 0; j < platformPosNum; j++) {
        if (!platformPos[ppi].used)
          break;
        ppi++;
        if (ppi >= platformPosNum)
          ppi = 0;
      }
      if (platformPos[ppi].used)
        break;
      Enemy en = enemies.getInstance();
      if (!en)
        break;
      platformPos[ppi].used = true;
      ppn--;
      Vector p = field.convertToScreenPos
        (cast(int) platformPos[ppi].pos.x, cast(int) platformPos[ppi].pos.y);
      if (!platformEnemySpec.setFirstState(en.state, p.x, p.y, platformPos[ppi].deg))
        continue;
      for (int i = 0; i < platformPosNum; i++) {
        if (fabs(platformPos[ppi].pos.x - platformPos[i].pos.x) <= 1 &&
            fabs(platformPos[ppi].pos.y - platformPos[i].pos.y) <= 1 &&
            !platformPos[i].used) {
          platformPos[i].used = true;
          ppn--;
        }
      }
      en.set(platformEnemySpec);
      bn--;
    }
  }

  public int blockDensity() {
    return _blockDensity;
  }

  public void draw() {
    Letter.drawNum(cast(int) (rank * 1000), 620, 10, 10, 0, 0, 33, 3);
    Letter.drawTime(bossAppTime, 120, 20, 7);
  }

  public float rankMultiplier() {
    return rank;
  }

  public bool bossMode() {
    return _bossMode;
  }
}

public class EnemyAppearance {
 private:
  EnemySpec spec;
  float nextAppDist, nextAppDistInterval;
  int appType;

  invariant {
    assert(nextAppDist <>= 0);
    assert(nextAppDistInterval > 0);
    assert(appType >= 0);
  }

  public this() {
    nextAppDist = 0;
    nextAppDistInterval = 1;
  }

  public void set(EnemySpec s, int num, int appType, Rand rand) {
    spec = s;
    nextAppDistInterval = (cast(float) Field.NEXT_BLOCK_AREA_SIZE) / num;
    nextAppDist = rand.nextFloat(nextAppDistInterval);
    this.appType = appType;
  }

  public void unset() {
    spec = null;
  }

  public void move(EnemyPool enemies, Field field) {
    if (!spec)
      return;
    nextAppDist -= field.lastScrollY;
    if (nextAppDist <= 0) {
      nextAppDist += nextAppDistInterval;
      appear(enemies);
    }
  }

  private void appear(EnemyPool enemies) {
    Enemy en = enemies.getInstance();
    if (en) {
      if ((cast(HasAppearType) spec).setFirstState(en.state, appType))
        en.set(spec);
    }
  }
}
