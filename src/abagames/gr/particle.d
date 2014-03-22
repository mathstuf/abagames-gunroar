/*
 * $Id: particle.d,v 1.1.1.1 2005/06/18 00:46:00 kenta Exp $
 *
 * Copyright 2005 Kenta Cho. Some rights reserved.
 */
module abagames.gr.particle;

private import std.math;
private import opengl;
private import abagames.util.actor;
private import abagames.util.vector;
private import abagames.util.rand;
private import abagames.util.sdl.luminous;
private import abagames.util.sdl.displaylist;
private import abagames.gr.field;
private import abagames.gr.screen;

/**
 * Sparks.
 */
public class Spark: LuminousActor {
 private:
  static Rand rand;
  Vector pos, ppos;
  Vector vel;
  float r, g, b;
  int cnt;

  invariant {
    assert(pos.x < 40 && pos.x > -40);
    assert(pos.y < 60 && pos.y > -60);
    assert(ppos.x < 40 && ppos.x > -40);
    assert(ppos.y < 60 && ppos.y > -60);
    assert(vel.x < 10 && vel.x > -10);
    assert(vel.y < 10 && vel.y > -10);
    assert(r >= 0 && r <= 1);
    assert(g >= 0 && g <= 1);
    assert(b >= 0 && b <= 1);
    assert(cnt >= 0);
  }

  public static this() {
    rand = new Rand;
  }

  public static void setRandSeed(long seed) {
    rand.setSeed(seed);
  }

  public this() {
    pos = new Vector;
    ppos = new Vector;
    vel = new Vector;
    r = g = b = 0;
    cnt = 0;
  }

  public override void init(Object[] args) {
  }

  public void set(Vector p, float vx, float vy, float r, float g, float b, int c) {
    ppos.x = pos.x = p.x;
    ppos.y = pos.y = p.y;
    vel.x = vx;
    vel.y = vy;
    this.r = r;
    this.g = g;
    this.b = b;
    cnt = c;
    exists = true;
  }

  public override void move() {
    cnt--;
    if (cnt <= 0 || vel.dist() < 0.005f) {
      exists = false;
      return;
    }
    ppos.x = pos.x;
    ppos.y = pos.y;
    pos += vel;
    vel *= 0.96f;
  }

  public override void draw() {
    float ox = vel.x;
    float oy = vel.y;
    Screen.setColor(r, g, b, 1);
    ox *= 2;
    oy *= 2;
    glVertex3f(pos.x - ox, pos.y - oy, 0);
    ox *= 0.5f;
    oy *= 0.5f;
    Screen.setColor(r * 0.5f, g * 0.5f, b * 0.5f, 0);
    glVertex3f(pos.x - oy, pos.y + ox, 0);
    glVertex3f(pos.x + oy, pos.y - ox, 0);
  }

  public override void drawLuminous() {
    float ox = vel.x;
    float oy = vel.y;
    Screen.setColor(r, g, b, 1);
    ox *= 2;
    oy *= 2;
    glVertex3f(pos.x - ox, pos.y - oy, 0);
    ox *= 0.5f;
    oy *= 0.5f;
    Screen.setColor(r * 0.5f, g * 0.5f, b * 0.5f, 0);
    glVertex3f(pos.x - oy, pos.y + ox, 0);
    glVertex3f(pos.x + oy, pos.y - ox, 0);
  }
}

public class SparkPool: LuminousActorPool!(Spark) {
  public this(int n, Object[] args) {
    super(n, args);
  }
}

/**
 * Smokes.
 */
public class Smoke: LuminousActor {
 public:
  static enum SmokeType {
    FIRE, EXPLOSION, SAND, SPARK, WAKE, SMOKE, LANCE_SPARK,
  };
 private:
  static Rand rand;
  static Vector3 windVel;
  static Vector wakePos;
  Field field;
  WakePool wakes;
  Vector3 pos;
  Vector3 vel;
  int type;
  int cnt, startCnt;
  float size;
  float r, g, b, a;

  invariant {
    assert(windVel.x < 1 && windVel.x > -1);
    assert(windVel.y < 1 && windVel.y > -1);
    assert(wakePos.x < 15 && wakePos.x > -15);
    assert(wakePos.y < 20 && wakePos.y > -20);
    assert(pos.x < 15 && pos.x > -15);
    assert(pos.y < 20 && pos.y > -20);
    assert(pos.z < 20 && pos.z > -10);
    assert(vel.x < 10 && vel.x > -10);
    assert(vel.y < 10 && vel.y > -10);
    assert(vel.z < 10 && vel.z > -10);
    assert(type >= 0);
    assert(cnt >= 0);
    assert(startCnt > 0);
    assert(size >= 0 && size < 10);
    assert(r >= 0 && r <= 1);
    assert(g >= 0 && g <= 1);
    assert(b >= 0 && b <= 1);
    assert(a >= 0 && a <= 1);
  }

  public static this() {
    rand = new Rand;
    wakePos = new Vector;
    windVel = new Vector3(0.04f, 0.04f, 0.02f);
  }

  public static void setRandSeed(long seed) {
    rand.setSeed(seed);
  }

  public this() {
    pos = new Vector3;
    vel = new Vector3;
    type = 0;
    cnt = 0;
    startCnt = 1;
    size = 1;
    r = g = b = a = 0;
  }

  public override void init(Object[] args) {
    field = cast(Field) args[0];
    wakes = cast(WakePool) args[1];
  }

  public void set(Vector p, float mx, float my, float mz, int t, int c = 60, float sz = 2) {
    set(p.x, p.y, mx, my, mz, t, c, sz);
  }

  public void set(Vector3 p, float mx, float my, float mz, int t, int c = 60, float sz = 2) {
    set(p.x, p.y, mx, my, mz, t, c, sz);
    pos.z = p.z;
  }

  public void set(float x, float y, float mx, float my, float mz, int t, int c = 60, float sz = 2) {
    if (!field.checkInOuterField(x, y))
      return;
    pos.x = x;
    pos.y = y;
    pos.z = 0;
    vel.x = mx;
    vel.y = my;
    vel.z = mz;
    type = t;
    startCnt = cnt = c;
    size = sz;
    switch (type) {
    case SmokeType.FIRE:
      r = rand.nextFloat(0.1f) + 0.9f;
      g = rand.nextFloat(0.2f) + 0.2f;
      b = 0;
      a = 1;
      break;
    case SmokeType.EXPLOSION:
      r = rand.nextFloat(0.3f) + 0.7f;
      g = rand.nextFloat(0.3f) + 0.3f;
      b = 0;
      a = 1;
      break;
    case SmokeType.SAND:
      r = 0.8f;
      g = 0.8f;
      b = 0.6f;
      a = 0.6f;
      break;
    case SmokeType.SPARK:
      r = rand.nextFloat(0.3f) + 0.7f;
      g = rand.nextFloat(0.5f) + 0.5f;
      b = 0;
      a = 1;
      break;
    case SmokeType.WAKE:
      r = 0.6f;
      g = 0.6f;
      b = 0.8f;
      a = 0.6f;
      break;
    case SmokeType.SMOKE:
      r = rand.nextFloat(0.1f) + 0.1f;
      g = rand.nextFloat(0.1f) + 0.1f;
      b = 0.1f;
      a = 0.5f;
      break;
    case SmokeType.LANCE_SPARK:
      r = 0.4f;
      g = rand.nextFloat(0.2f) + 0.7f;
      b = rand.nextFloat(0.2f) + 0.7f;
      a = 1;
      break;
    }
    exists = true;
  }

  public override void move() {
    cnt--;
    if (cnt <= 0 || !field.checkInOuterField(pos.x, pos.y)) {
      exists = false;
      return;
    }
    if (type != SmokeType.WAKE) {
      vel.x += (windVel.x - vel.x) * 0.01f;
      vel.y += (windVel.y - vel.y) * 0.01f;
      vel.z += (windVel.z - vel.z) * 0.01f;
    }
    pos += vel;
    pos.y -= field.lastScrollY;
    switch (type) {
    case SmokeType.FIRE:
    case SmokeType.EXPLOSION:
    case SmokeType.SMOKE:
      if (cnt < startCnt / 2) {
        r *= 0.95f;
        g *= 0.95f;
        b *= 0.95f;
      } else {
        a *= 0.97f;
      }
      size *= 1.01f;
      break;
    case SmokeType.SAND:
      r *= 0.98f;
      g *= 0.98f;
      b *= 0.98f;
      a *= 0.98f;
      break;
    case SmokeType.SPARK:
      r *= 0.92f;
      g *= 0.92f;
      a *= 0.95f;
      vel *= 0.9f;
      break;
    case SmokeType.WAKE:
      a *= 0.98f;
      size *= 1.005f;
      break;
    case SmokeType.LANCE_SPARK:
      a *= 0.95f;
      size *= 0.97f;
      break;
    }
    if (size > 5)
      size = 5;
    if (type == SmokeType.EXPLOSION && pos.z < 0.01f) {
      int bl = field.getBlock(pos.x, pos.y);
      if (bl >= 1)
        vel *= 0.8f;
      if (cnt % 3 == 0 && bl < -1) {
        float sp = sqrt(vel.x * vel.x + vel.y * vel.y);
        if (sp > 0.3f) {
          float d = atan2(vel.x, vel.y);
          assert(d <>= 0);
          wakePos.x = pos.x + sin(d + PI / 2) * size * 0.25f;
          wakePos.y = pos.y + cos(d + PI / 2) * size * 0.25f;
          Wake w = wakes.getInstanceForced();
          assert(wakePos.x <>= 0);
          assert(wakePos.y <>= 0);
          w.set(wakePos, d + PI - 0.2f + rand.nextSignedFloat(0.1f), sp * 0.33f,
                20 + rand.nextInt(12), size * (7.0f + rand.nextFloat(3)));
          wakePos.x = pos.x + sin(d - PI / 2) * size * 0.25f;
          wakePos.y = pos.y + cos(d - PI / 2) * size * 0.25f;
          w = wakes.getInstanceForced();
          assert(wakePos.x <>= 0);
          assert(wakePos.y <>= 0);
          w.set(wakePos, d + PI + 0.2f + rand.nextSignedFloat(0.1f), sp * 0.33f,
                20 + rand.nextInt(12), size * (7.0f + rand.nextFloat(3)));
        }
      }
    }
  }

  public override void draw() {
    float quadSize = size / 2;
    Screen.setColor(r, g, b, a);
    glVertex3f(pos.x - quadSize, pos.y - quadSize, pos.z);
    glVertex3f(pos.x + quadSize, pos.y - quadSize, pos.z);
    glVertex3f(pos.x + quadSize, pos.y + quadSize, pos.z);
    glVertex3f(pos.x - quadSize, pos.y + quadSize, pos.z);
  }

  public override void drawLuminous() {
    if (r + g > 0.8f && b < 0.5f) {
      float quadSize = size / 2;
      Screen.setColor(r, g, b, a);
      glVertex3f(pos.x - quadSize, pos.y - quadSize, pos.z);
      glVertex3f(pos.x + quadSize, pos.y - quadSize, pos.z);
      glVertex3f(pos.x + quadSize, pos.y + quadSize, pos.z);
      glVertex3f(pos.x - quadSize, pos.y + quadSize, pos.z);
    }
  }
}

public class SmokePool: LuminousActorPool!(Smoke) {
  public this(int n, Object[] args) {
    super(n, args);
  }
}

/**
 * Fragments of destroyed enemies.
 */
public class Fragment: Actor {
 private:
  static DisplayList displayList;
  static Rand rand;
  Field field;
  SmokePool smokes;
  Vector3 pos;
  Vector3 vel;
  float size;
  float d2, md2;

  invariant {
    assert(pos.x < 15 && pos.x > -15);
    assert(pos.y < 20 && pos.y > -20);
    assert(pos.z < 20 && pos.z > -10);
    assert(vel.x < 10 && vel.x > -10);
    assert(vel.y < 10 && vel.y > -10);
    assert(vel.z < 10 && vel.z > -10);
    assert(size >= 0 && size < 10);
    assert(d2 <>= 0);
    assert(md2 <>= 0);
  }

  public static void init() {
    rand = new Rand;
    displayList = new DisplayList(1);
    displayList.beginNewList();
    Screen.setColor(0.7f, 0.5f, 0.5f, 0.5f);
    glBegin(GL_TRIANGLE_FAN);
    glVertex2f(-0.5f, -0.25f);
    glVertex2f(0.5f, -0.25f);
    glVertex2f(0.5f, 0.25f);
    glVertex2f(-0.5f, 0.25f);
    glEnd();
    Screen.setColor(0.7f, 0.5f, 0.5f, 0.9f);
    glBegin(GL_LINE_LOOP);
    glVertex2f(-0.5f, -0.25f);
    glVertex2f(0.5f, -0.25f);
    glVertex2f(0.5f, 0.25f);
    glVertex2f(-0.5f, 0.25f);
    glEnd();
    displayList.endNewList();
  }

  public static void setRandSeed(long seed) {
    rand.setSeed(seed);
  }

  public static void close() {
    displayList.close();
  }

  public this() {
    pos = new Vector3;
    vel = new Vector3;
    size = 1;
    d2 = md2 = 0;
  }

  public override void init(Object[] args) {
    field = cast(Field) args[0];
    smokes = cast(SmokePool) args[1];
  }

  public void set(Vector p, float mx, float my, float mz, float sz = 1) {
    if (!field.checkInOuterField(p.x, p.y))
      return;
    pos.x = p.x;
    pos.y = p.y;
    pos.z = 0;
    vel.x = mx;
    vel.y = my;
    vel.z = mz;
    size = sz;
    if (size > 5)
      size = 5;
    d2 = rand.nextFloat(360);
    md2 = rand.nextSignedFloat(20);
    exists = true;
  }

  public override void move() {
    if (!field.checkInOuterField(pos.x, pos.y)) {
      exists = false;
      return;
    }
    vel.x *= 0.96f;
    vel.y *= 0.96f;
    vel.z += (-0.04f - vel.z) * 0.01f;
    pos += vel;
    if (pos.z < 0) {
      Smoke s = smokes.getInstanceForced();
      if (field.getBlock(pos.x, pos.y) < 0)
        s.set(pos.x, pos.y, 0, 0, 0, Smoke.SmokeType.WAKE, 60, size * 0.66f);
      else
        s.set(pos.x, pos.y, 0, 0, 0, Smoke.SmokeType.SAND, 60, size * 0.75f);
      exists = false;
      return;
    }
    pos.y -= field.lastScrollY;
    d2 += md2;
  }

  public override void draw() {
    glPushMatrix();
    Screen.glTranslate(pos);
    glRotatef(d2, 1, 0, 0);
    glScalef(size, size, 1);
    displayList.call(0);
    glPopMatrix();
  }
}

public class FragmentPool: ActorPool!(Fragment) {
  public this(int n, Object[] args) {
    super(n, args);
  }
}

/**
 * Luminous fragments.
 */
public class SparkFragment: LuminousActor {
 private:
  static DisplayList displayList;
  static Rand rand;
  Field field;
  SmokePool smokes;
  Vector3 pos;
  Vector3 vel;
  float size;
  float d2, md2;
  int cnt;
  bool hasSmoke;

  invariant {
    assert(pos.x < 15 && pos.x > -15);
    assert(pos.y < 20 && pos.y > -20);
    assert(pos.z < 20 && pos.z > -10);
    assert(vel.x < 10 && vel.x > -10);
    assert(vel.y < 10 && vel.y > -10);
    assert(vel.z < 10 && vel.z > -10);
    assert(size >= 0 && size < 10);
    assert(d2 <>= 0);
    assert(md2 <>= 0);
    assert(cnt >= 0);
  }

  public static void init() {
    rand = new Rand;
    displayList = new DisplayList(1);
    displayList.beginNewList();
    glBegin(GL_TRIANGLE_FAN);
    glVertex2f(-0.25f, -0.25f);
    glVertex2f(0.25f, -0.25f);
    glVertex2f(0.25f, 0.25f);
    glVertex2f(-0.25f, 0.25f);
    glEnd();
    displayList.endNewList();
  }

  public static void setRandSeed(long seed) {
    rand.setSeed(seed);
  }

  public static void close() {
    displayList.close();
  }

  public this() {
    pos = new Vector3;
    vel = new Vector3;
    size = 1;
    d2 = md2 = 0;
    cnt = 0;
  }

  public override void init(Object[] args) {
    field = cast(Field) args[0];
    smokes = cast(SmokePool) args[1];
  }

  public void set(Vector p, float mx, float my, float mz, float sz = 1) {
    if (!field.checkInOuterField(p.x, p.y))
      return;
    pos.x = p.x;
    pos.y = p.y;
    pos.z = 0;
    vel.x = mx;
    vel.y = my;
    vel.z = mz;
    size = sz;
    if (size > 5)
      size = 5;
    d2 = rand.nextFloat(360);
    md2 = rand.nextSignedFloat(15);
    if (rand.nextInt(4) == 0)
      hasSmoke = true;
    else
      hasSmoke = false;
    cnt = 0;
    exists = true;
  }

  public override void move() {
    if (!field.checkInOuterField(pos.x, pos.y)) {
      exists = false;
      return;
    }
    vel.x *= 0.99f;
    vel.y *= 0.99f;
    vel.z += (-0.08f - vel.z) * 0.01f;
    pos += vel;
    if (pos.z < 0) {
      Smoke s = smokes.getInstanceForced();
      if (field.getBlock(pos.x, pos.y) < 0)
        s.set(pos.x, pos.y, 0, 0, 0, Smoke.SmokeType.WAKE, 60, size * 0.66f);
      else
        s.set(pos.x, pos.y, 0, 0, 0, Smoke.SmokeType.SAND, 60, size * 0.75f);
      exists = false;
      return;
    }
    pos.y -= field.lastScrollY;
    d2 += md2;
    cnt++;
    if (hasSmoke && cnt % 5 == 0) {
      Smoke s = smokes.getInstance();
      if (s)
        s.set(pos, 0, 0, 0, Smoke.SmokeType.SMOKE, 90 + rand.nextInt(60), size * 0.5f);
    }
  }

  public override void draw() {
    glPushMatrix();
    Screen.setColor(1, rand.nextFloat(1), 0, 0.8f);
    Screen.glTranslate(pos);
    glRotatef(d2, 1, 0, 0);
    glScalef(size, size, 1);
    displayList.call(0);
    glPopMatrix();
  }

  public override void drawLuminous() {
    glPushMatrix();
    Screen.setColor(1, rand.nextFloat(1), 0, 0.8f);
    Screen.glTranslate(pos);
    glRotatef(d2, 1, 0, 0);
    glScalef(size, size, 1);
    displayList.call(0);
    glPopMatrix();
  }
}

public class SparkFragmentPool: LuminousActorPool!(SparkFragment) {
  public this(int n, Object[] args) {
    super(n, args);
  }
}

/**
 * Wakes of ships and smokes.
 */
public class Wake: Actor {
 private:
  Field field;
  Vector pos;
  Vector vel;
  float deg;
  float speed;
  float size;
  int cnt;
  bool revShape;

  invariant {
    assert(pos.x < 15 && pos.x > -15);
    assert(pos.y < 20 && pos.y > -20);
    assert(vel.x < 10 && vel.x > -10);
    assert(vel.y < 10 && vel.y > -10);
    assert(size > 0 && size < 1000);
    assert(deg <>= 0);
    assert(speed >= 0 && speed < 10);
    assert(cnt >= 0);
  }

  public this() {
    pos = new Vector;
    vel = new Vector;
    size = 1;
    deg = 0;
    speed = 0;
    cnt = 0;
  }

  public override void init(Object[] args) {
    field = cast(Field) args[0];
  }

  public void set(Vector p, float deg, float speed, int c = 60, float sz = 1, bool rs = false) {
    if (!field.checkInOuterField(p.x, p.y))
      return;
    pos.x = p.x;
    pos.y = p.y;
    this.deg = deg;
    this.speed = speed;
    vel.x = sin(deg) * speed;
    vel.y = cos(deg) * speed;
    cnt = c;
    size = sz;
    revShape = rs;
    exists = true;
  }

  public override void move() {
    cnt--;
    if (cnt <= 0 || vel.dist() < 0.005f || !field.checkInOuterField(pos.x, pos.y)) {
      exists = false;
      return;
    }
    pos += vel;
    pos.y -= field.lastScrollY;
    vel *= 0.96f;
    size *= 1.02f;
  }

  public override void draw() {
    float ox = vel.x;
    float oy = vel.y;
    Screen.setColor(0.33f, 0.33f, 1);
    ox *= size;
    oy *= size;
    if (revShape)
      glVertex3f(pos.x + ox, pos.y + oy, 0);
    else
      glVertex3f(pos.x - ox, pos.y - oy, 0);
    ox *= 0.2f;
    oy *= 0.2f;
    Screen.setColor(0.2f, 0.2f, 0.6f, 0.5f);
    glVertex3f(pos.x - oy, pos.y + ox, 0);
    glVertex3f(pos.x + oy, pos.y - ox, 0);
  }
}

public class WakePool: ActorPool!(Wake) {
  public this(int n, Object[] args) {
    super(n, args);
  }
}
