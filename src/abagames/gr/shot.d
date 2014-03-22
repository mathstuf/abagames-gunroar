/*
 * $Id: shot.d,v 1.2 2005/07/03 07:05:22 kenta Exp $
 *
 * Copyright 2005 Kenta Cho. Some rights reserved.
 */
module abagames.gr.shot;

private import std.math;
private import std.string;
private import opengl;
private import abagames.util.actor;
private import abagames.util.vector;
private import abagames.util.rand;
private import abagames.util.sdl.shape;
private import abagames.gr.field;
private import abagames.gr.screen;
private import abagames.gr.enemy;
private import abagames.gr.particle;
private import abagames.gr.bullet;
private import abagames.gr.soundmanager;

/**
 * Player's shot.
 */
public class Shot: Actor {
 public:
  static const float SPEED = 0.6f;
  static const float LANCE_SPEED = 0.5f;//0.4f;
 private:
  static ShotShape shape;
  static LanceShape lanceShape;
  static Rand rand;
  Field field;
  EnemyPool enemies;
  SparkPool sparks;
  SmokePool smokes;
  BulletPool bullets;
  Vector pos;
  int cnt;
  int hitCnt;
  float _deg;
  int _damage;
  bool lance;

  invariant {
    assert(pos.x < 15 && pos.x > -15);
    assert(pos.y < 20 && pos.y > -20);
    assert(cnt >= 0);
    assert(hitCnt >= 0);
    assert(_deg <>= 0);
    assert(_damage >= 1);
  }

  public static void init() {
    shape = new ShotShape;
    lanceShape = new LanceShape;
    rand = new Rand;
  }

  public static void setRandSeed(long seed) {
    rand.setSeed(seed);
  }

  public static void close() {
    shape.close();
  }

  public this() {
    pos = new Vector;
    cnt = hitCnt = 0;
    _deg = 0;
    _damage = 1;
    lance = false;
  }

  public override void init(Object[] args) {
    field = cast(Field) args[0];
    enemies = cast(EnemyPool) args[1];
    sparks = cast(SparkPool) args[2];
    smokes = cast(SmokePool) args[3];
    bullets = cast(BulletPool) args[4];
  }

  public void set(Vector p, float d, bool lance = false, int dmg = -1) {
    pos.x = p.x;
    pos.y = p.y;
    cnt = hitCnt = 0;
    _deg = d;
    this.lance = lance;
    if (lance)
      _damage = 10;
    else
      _damage = 1;
    if (dmg >= 0)
      _damage = dmg;
    exists = true;
  }

  public override void move() {
    cnt++;
    if (hitCnt > 0) {
      hitCnt++;
      if (hitCnt > 30)
        remove();
      return;
    }
    float sp;
    if (!lance) {
      sp = SPEED;
    } else {
      if (cnt < 10)
        sp = LANCE_SPEED * cnt / 10;
      else
        sp = LANCE_SPEED;
    }
    pos.x += sin(_deg) * sp;
    pos.y += cos(_deg) * sp;
    pos.y -= field.lastScrollY;
    if (field.getBlock(pos) >= Field.ON_BLOCK_THRESHOLD ||
        !field.checkInOuterField(pos) || pos.y > field.size.y)
      remove();
    if (lance) {
      enemies.checkShotHit(pos, lanceShape, this);
    } else {
      bullets.checkShotHit(pos, shape, this);
      enemies.checkShotHit(pos, shape, this);
    }
  }

  public void remove() {
    if (lance && hitCnt <= 0) {
      hitCnt = 1;
      return;
    }
    exists = false;
  }

  public void removeHitToBullet() {
    removeHit();
  }

  public void removeHitToEnemy(bool isSmallEnemy = false) {
    if (isSmallEnemy && lance)
      return;
    SoundManager.playSe("hit.wav");
    removeHit();
  }

  private void removeHit() {
    remove();
    int sn;
    if (lance) {
      for (int i = 0; i < 10; i++) {
        Smoke s = smokes.getInstanceForced();
        float d = _deg + rand.nextSignedFloat(0.1f);
        float sp = rand.nextFloat(LANCE_SPEED);
        s.set(pos, sin(d) * sp, cos(d) * sp, 0,
              Smoke.SmokeType.LANCE_SPARK, 30 + rand.nextInt(30), 1);
        s = smokes.getInstanceForced();
        d = _deg + rand.nextSignedFloat(0.1f);
        sp = rand.nextFloat(LANCE_SPEED);
        s.set(pos, -sin(d) * sp, -cos(d) * sp, 0,
              Smoke.SmokeType.LANCE_SPARK, 30 + rand.nextInt(30), 1);
      }
    } else {
      Spark s = sparks.getInstanceForced();
      float d = _deg + rand.nextSignedFloat(0.5f);
      s.set(pos, sin(d) * SPEED, cos(d) * SPEED,
            0.6f + rand.nextSignedFloat(0.4f), 0.6f + rand.nextSignedFloat(0.4f), 0.1f, 20);
      s = sparks.getInstanceForced();
      d = _deg + rand.nextSignedFloat(0.5f);
      s.set(pos, -sin(d) * SPEED, -cos(d) * SPEED,
            0.6f + rand.nextSignedFloat(0.4f), 0.6f + rand.nextSignedFloat(0.4f), 0.1f, 20);
    }
  }

  public override void draw() {
    if (lance) {
      float x = pos.x, y = pos.y;
      float size = 0.25f, a = 0.6f;
      int hc = hitCnt;
      for (int i = 0; i < cnt / 4 + 1; i++) {
        size *= 0.9f;
        a *= 0.8f;
        if (hc > 0) {
          hc--;
          continue;
        }
        float d = i * 13 + cnt * 3;
        for (int j = 0; j < 6; j++) {
          glPushMatrix();
          glTranslatef(x, y, 0);
          glRotatef(-_deg * 180 / PI, 0, 0, 1);
          glRotatef(d, 0, 1, 0);
          Screen.setColor(0.4f, 0.8f, 0.8f, a);
          glBegin(GL_LINE_LOOP);
          glVertex3f(-size, LANCE_SPEED, size / 2);
          glVertex3f(size, LANCE_SPEED, size / 2);
          glVertex3f(size, -LANCE_SPEED, size / 2);
          glVertex3f(-size, -LANCE_SPEED, size / 2);
          glEnd();
          Screen.setColor(0.2f, 0.5f, 0.5f, a / 2);
          glBegin(GL_TRIANGLE_FAN);
          glVertex3f(-size, LANCE_SPEED, size / 2);
          glVertex3f(size, LANCE_SPEED, size / 2);
          glVertex3f(size, -LANCE_SPEED, size / 2);
          glVertex3f(-size, -LANCE_SPEED, size / 2);
          glEnd();
          glPopMatrix();
          d += 60;
        }
        x -= sin(deg) * LANCE_SPEED * 2;
        y -= cos(deg) * LANCE_SPEED * 2;
      }
    } else {
      glPushMatrix();
      Screen.glTranslate(pos);
      glRotatef(-_deg * 180 / PI, 0, 0, 1);
      glRotatef(cnt * 31, 0, 1, 0);
      shape.draw();
      glPopMatrix();
    }
  }

  public float deg() {
    return _deg;
  }

  public int damage() {
    return _damage;
  }

  public bool removed() {
    if (hitCnt > 0)
      return true;
    else
      return false;
  }
}

public class ShotPool: ActorPool!(Shot) {
  public this(int n, Object[] args) {
    super(n, args);
  }

  public bool existsLance() {
    foreach (Shot s; actor)
      if (s.exists)
        if (s.lance && !s.removed)
          return true;
    return false;
  }
}

public class ShotShape: CollidableDrawable {
  protected override void createDisplayList() {
    Screen.setColor(0.1f, 0.33f, 0.1f);
    glBegin(GL_QUADS);
    glVertex3f(0, 0.3f, 0.1f);
    glVertex3f(0.066f, 0.3f, -0.033f);
    glVertex3f(0.1f, -0.3f, -0.05f);
    glVertex3f(0, -0.3f, 0.15f);
    glVertex3f(0.066f, 0.3f, -0.033f);
    glVertex3f(-0.066f, 0.3f, -0.033f);
    glVertex3f(-0.1f, -0.3f, -0.05f);
    glVertex3f(0.1f, -0.3f, -0.05f);
    glVertex3f(-0.066f, 0.3f, -0.033f);
    glVertex3f(0, 0.3f, 0.1f);
    glVertex3f(0, -0.3f, 0.15f);
    glVertex3f(-0.1f, -0.3f, -0.05f);
    glEnd();
  }

  protected override void setCollision() {
    _collision = new Vector(0.33f, 0.33f);
  }
}

public class LanceShape: Collidable {
  mixin CollidableImpl;
 private:
  Vector _collision;

  public this() {
    _collision = new Vector(0.66f, 0.66f);
  }

  public Vector collision() {
    return _collision;
  }
}
