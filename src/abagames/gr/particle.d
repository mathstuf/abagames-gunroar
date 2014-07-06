/*
 * $Id: particle.d,v 1.1.1.1 2005/06/18 00:46:00 kenta Exp $
 *
 * Copyright 2005 Kenta Cho. Some rights reserved.
 */
module abagames.gr.particle;

private import std.math;
private import gl3n.linalg;
private import abagames.util.actor;
private import abagames.util.math;
private import abagames.util.rand;
private import abagames.util.gl.gl;
private import abagames.util.sdl.luminous;
private import abagames.util.sdl.shaderprogram;
private import abagames.gr.field;
private import abagames.gr.screen;

/**
 * Sparks.
 */
public class Spark: LuminousActor {
 private:
  static Rand rand;
  static ShaderProgram program;
  static GLuint vao;
  static GLuint[3] vbo;
  vec2 pos;
  vec2 vel;
  float r, g, b;
  int cnt;

  invariant() {
    assert(pos.x < 40 && pos.x > -40);
    assert(pos.y < 60 && pos.y > -60);
    assert(vel.x < 10 && vel.x > -10);
    assert(vel.y < 10 && vel.y > -10);
    assert(r >= 0 && r <= 1);
    assert(g >= 0 && g <= 1);
    assert(b >= 0 && b <= 1);
    assert(cnt >= 0);
  }

  public static this() {
    rand = new Rand;
    program = null;
  }

  public static void setRandSeed(long seed) {
    rand.setSeed(seed);
  }

  public this() {
    pos = vec2(0);
    vel = vec2(0);
    r = g = b = 0;
    cnt = 0;
  }

  public override void init(Object[] args) {
    if (program !is null) {
      return;
    }

    program = new ShaderProgram;
    program.setVertexShader(
      "uniform mat4 projmat;\n"
      "uniform vec2 pos;\n"
      "uniform vec2 vel;\n"
      "\n"
      "attribute vec2 velFactor;\n"
      "attribute float velFlip;\n"
      "attribute vec4 colorFactor;\n"
      "\n"
      "varying vec4 f_colorFactor;\n"
      "\n"
      "void main() {\n"
      "  vec2 rvel = (velFlip > 0.) ? vel.yx : vel.xy;\n"
      "  gl_Position = projmat * vec4(pos + velFactor * rvel, 0, 1);\n"
      "  f_colorFactor = colorFactor;\n"
      "}\n"
    );
    program.setFragmentShader(
      "uniform vec3 color;\n"
      "uniform float brightness;\n"
      "\n"
      "varying vec4 f_colorFactor;\n"
      "\n"
      "void main() {\n"
      "  gl_FragColor = vec4(color * brightness, 1) * f_colorFactor;\n"
      "}\n"
    );
    GLint velFactorLoc = 0;
    GLint velFlipLoc = 1;
    GLint colorFactorLoc = 2;
    program.bindAttribLocation(velFactorLoc, "velFactor");
    program.bindAttribLocation(velFlipLoc, "velFlip");
    program.bindAttribLocation(colorFactorLoc, "colorFactor");
    program.link();
    program.use();

    glGenBuffers(3, vbo.ptr);
    glGenVertexArrays(1, &vao);

    static const float[] VELFACTOR = [
      -2, -2,
      -1,  1,
       1, -1
    ];
    static const float[] VELFLIP = [
      0,
      1,
      1
    ];
    static const float[] COLORFACTOR = [
      1,    1,    1,    1,
      0.5f, 0.5f, 0.5f, 0,
      0.5f, 0.5f, 0.5f, 0
    ];

    glBindVertexArray(vao);

    glBindBuffer(GL_ARRAY_BUFFER, vbo[0]);
    glBufferData(GL_ARRAY_BUFFER, VELFACTOR.length * float.sizeof, VELFACTOR.ptr, GL_STATIC_DRAW);

    glVertexAttribPointer(velFactorLoc, 2, GL_FLOAT, GL_FALSE, 0, null);
    glEnableVertexAttribArray(velFactorLoc);

    glBindBuffer(GL_ARRAY_BUFFER, vbo[1]);
    glBufferData(GL_ARRAY_BUFFER, VELFLIP.length * float.sizeof, VELFLIP.ptr, GL_STATIC_DRAW);

    glVertexAttribPointer(velFlipLoc, 1, GL_FLOAT, GL_FALSE, 0, null);
    glEnableVertexAttribArray(velFlipLoc);

    glBindBuffer(GL_ARRAY_BUFFER, vbo[2]);
    glBufferData(GL_ARRAY_BUFFER, COLORFACTOR.length * float.sizeof, COLORFACTOR.ptr, GL_STATIC_DRAW);

    glVertexAttribPointer(colorFactorLoc, 4, GL_FLOAT, GL_FALSE, 0, null);
    glEnableVertexAttribArray(colorFactorLoc);

    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindVertexArray(0);
  }

  public override void close() {
    if (program !is null) {
      glDeleteVertexArrays(1, &vao);
      glDeleteBuffers(3, vbo.ptr);
      program.close();
      program = null;
    }
  }

  public void set(vec2 p, float vx, float vy, float r, float g, float b, int c) {
    pos.x = p.x;
    pos.y = p.y;
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
    if (cnt <= 0 || vel.fastdist() < 0.005f) {
      exists = false;
      return;
    }
    pos += vel;
    vel *= 0.96f;
  }

  public override void draw(mat4 view) {
    drawCommon(view);
  }

  public override void drawLuminous(mat4 view) {
    drawCommon(view);
  }

  private void drawCommon(mat4 view) {
    program.use();

    program.setUniform("projmat", view);
    program.setUniform("brightness", Screen.brightness);
    program.setUniform("color", r, g, b);
    program.setUniform("pos", pos);
    program.setUniform("vel", vel);

    glBindVertexArray(vao);
    glDrawArrays(GL_TRIANGLES, 0, 3);

    glBindVertexArray(0);
    glUseProgram(0);
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
  static vec3 windVel;
  static vec2 wakePos;
  static ShaderProgram program;
  static GLuint vao;
  static GLuint vbo;
  Field field;
  WakePool wakes;
  vec3 pos;
  vec3 vel;
  int type;
  int cnt, startCnt;
  float size;
  float r, g, b, a;

  invariant() {
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
    wakePos = vec2(0);
    windVel = vec3(0.04f, 0.04f, 0.02f);
    program = null;
  }

  public static void setRandSeed(long seed) {
    rand.setSeed(seed);
  }

  public this() {
    pos = vec3(0);
    vel = vec3(0);
    type = 0;
    cnt = 0;
    startCnt = 1;
    size = 1;
    r = g = b = a = 0;
  }

  public override void init(Object[] args) {
    field = cast(Field) args[0];
    wakes = cast(WakePool) args[1];

    if (program !is null) {
      return;
    }

    program = new ShaderProgram;
    program.setVertexShader(
      "uniform mat4 projmat;\n"
      "uniform vec3 pos;\n"
      "uniform float size;\n"
      "\n"
      "attribute vec2 diff;\n"
      "\n"
      "void main() {\n"
      "  gl_Position = projmat * vec4(pos + vec3(size * diff, 0), 1);\n"
      "}\n"
    );
    program.setFragmentShader(
      "uniform float brightness;\n"
      "uniform vec4 color;\n"
      "\n"
      "void main() {\n"
      "  gl_FragColor = color * vec4(vec3(brightness), 1);\n"
      "}\n"
    );
    GLint diffLoc = 0;
    program.bindAttribLocation(diffLoc, "diff");
    program.link();
    program.use();

    glGenBuffers(1, &vbo);
    glGenVertexArrays(1, &vao);

    glBindVertexArray(vao);

    const float[] DIFF = [
      -0.5f, -0.5f,
       0.5f, -0.5f,
       0.5f,  0.5f,
      -0.5f,  0.5f,
    ];

    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, DIFF.length * float.sizeof, DIFF.ptr, GL_STATIC_DRAW);

    glVertexAttribPointer(diffLoc, 2, GL_FLOAT, GL_FALSE, 0, null);
    glEnableVertexAttribArray(diffLoc);

    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindVertexArray(0);
  }

  public override void close() {
    if (program !is null) {
      glDeleteVertexArrays(1, &vao);
      glDeleteBuffers(1, &vbo);
      program.close();
      program = null;
    }
  }

  public void set(vec2 p, float mx, float my, float mz, int t, int c = 60, float sz = 2) {
    set(p.x, p.y, mx, my, mz, t, c, sz);
  }

  public void set(vec3 p, float mx, float my, float mz, int t, int c = 60, float sz = 2) {
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
    default:
      assert(0);
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
    default:
      assert(0);
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
          assert(!d.isNaN);
          wakePos.x = pos.x + sin(d + PI / 2) * size * 0.25f;
          wakePos.y = pos.y + cos(d + PI / 2) * size * 0.25f;
          Wake w = wakes.getInstanceForced();
          assert(!wakePos.x.isNaN);
          assert(!wakePos.y.isNaN);
          w.set(wakePos, d + PI - 0.2f + rand.nextSignedFloat(0.1f), sp * 0.33f,
                20 + rand.nextInt(12), size * (7.0f + rand.nextFloat(3)));
          wakePos.x = pos.x + sin(d - PI / 2) * size * 0.25f;
          wakePos.y = pos.y + cos(d - PI / 2) * size * 0.25f;
          w = wakes.getInstanceForced();
          assert(!wakePos.x.isNaN);
          assert(!wakePos.y.isNaN);
          w.set(wakePos, d + PI + 0.2f + rand.nextSignedFloat(0.1f), sp * 0.33f,
                20 + rand.nextInt(12), size * (7.0f + rand.nextFloat(3)));
        }
      }
    }
  }

  public override void draw(mat4 view) {
    drawCommon(view);
  }

  public override void drawLuminous(mat4 view) {
    if (r + g > 0.8f && b < 0.5f) {
      drawCommon(view);
    }
  }

  private void drawCommon(mat4 view) {
    program.use();

    program.setUniform("projmat", view);
    program.setUniform("brightness", Screen.brightness);
    program.setUniform("color", r, g, b, a);
    program.setUniform("size", size);
    program.setUniform("pos", pos);

    glBindVertexArray(vao);
    glDrawArrays(GL_TRIANGLE_FAN, 0, 4);

    glBindVertexArray(0);
    glUseProgram(0);
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
  static ShaderProgram program;
  static GLuint vao;
  static GLuint vbo;
  static Rand rand;
  Field field;
  SmokePool smokes;
  vec3 pos;
  vec3 vel;
  float size;
  float d2, md2;

  invariant() {
    assert(pos.x < 15 && pos.x > -15);
    assert(pos.y < 20 && pos.y > -20);
    assert(pos.z < 20 && pos.z > -10);
    assert(vel.x < 10 && vel.x > -10);
    assert(vel.y < 10 && vel.y > -10);
    assert(vel.z < 10 && vel.z > -10);
    assert(size >= 0 && size < 10);
    assert(!d2.isNaN);
    assert(!md2.isNaN);
  }

  public static void init() {
    rand = new Rand;

    program = new ShaderProgram;
    program.setVertexShader(
      "uniform mat4 projmat;\n"
      "uniform mat4 modelmat;\n"
      "\n"
      "attribute vec2 pos;\n"
      "\n"
      "void main() {\n"
      "  gl_Position = projmat * modelmat * vec4(pos, 0, 1);\n"
      "}\n"
    );
    program.setFragmentShader(
      "uniform vec3 color;\n"
      "uniform float brightness;\n"
      "uniform float alpha;\n"
      "\n"
      "void main() {\n"
      "  gl_FragColor = vec4(color * brightness, alpha);\n"
      "}\n"
    );
    GLint posLoc = 0;
    program.bindAttribLocation(posLoc, "pos");
    program.link();
    program.use();

    program.setUniform("color", 0.7f, 0.5f, 0.5f);

    glGenBuffers(1, &vbo);
    glGenVertexArrays(1, &vao);

    static const float[] VTX = [
      -0.5f, -0.25f,
       0.5f, -0.25f,
       0.5f,  0.25f,
      -0.5f,  0.25f
    ];

    glBindVertexArray(vao);

    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, VTX.length * float.sizeof, VTX.ptr, GL_STATIC_DRAW);

    glVertexAttribPointer(posLoc, 2, GL_FLOAT, GL_FALSE, 0, null);
    glEnableVertexAttribArray(posLoc);

    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindVertexArray(0);
  }

  public static void setRandSeed(long seed) {
    rand.setSeed(seed);
  }

  public override void close() {
    if (program !is null) {
      glDeleteVertexArrays(1, &vao);
      glDeleteBuffers(1, &vbo);
      program.close();
      program = null;
    }
  }

  public this() {
    pos = vec3(0);
    vel = vec3(0);
    size = 1;
    d2 = md2 = 0;
  }

  public override void init(Object[] args) {
    field = cast(Field) args[0];
    smokes = cast(SmokePool) args[1];
  }

  public void set(vec2 p, float mx, float my, float mz, float sz = 1) {
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

  public override void draw(mat4 view) {
    program.use();

    mat4 model = mat4.identity;
    model.scale(size, size, 1);
    model.rotate(-d2 / 180 * PI, vec3(1, 0, 0));
    model.translate(pos.x, pos.y, pos.z);

    program.setUniform("projmat", view);
    program.setUniform("modelmat", model);
    program.setUniform("brightness", Screen.brightness);

    glBindVertexArray(vao);

    program.setUniform("alpha", 0.5f);
    glDrawArrays(GL_TRIANGLE_FAN, 0, 4);

    program.setUniform("alpha", 0.9f);
    glDrawArrays(GL_LINE_LOOP, 0, 4);

    glBindVertexArray(0);
    glUseProgram(0);
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
  static ShaderProgram program;
  static GLuint vao;
  static GLuint vbo;
  static Rand rand;
  Field field;
  SmokePool smokes;
  vec3 pos;
  vec3 vel;
  float size;
  float d2, md2;
  int cnt;
  bool hasSmoke;

  invariant() {
    assert(pos.x < 15 && pos.x > -15);
    assert(pos.y < 20 && pos.y > -20);
    assert(pos.z < 20 && pos.z > -10);
    assert(vel.x < 10 && vel.x > -10);
    assert(vel.y < 10 && vel.y > -10);
    assert(vel.z < 10 && vel.z > -10);
    assert(size >= 0 && size < 10);
    assert(!d2.isNaN);
    assert(!md2.isNaN);
    assert(cnt >= 0);
  }

  public static void init() {
    rand = new Rand;

    program = new ShaderProgram;
    program.setVertexShader(
      "uniform mat4 projmat;\n"
      "uniform mat4 modelmat;\n"
      "\n"
      "attribute vec2 pos;\n"
      "\n"
      "void main() {\n"
      "  gl_Position = projmat * modelmat * vec4(pos, 0, 1);\n"
      "}\n"
    );
    program.setFragmentShader(
      "uniform vec4 color;\n"
      "uniform float brightness;\n"
      "\n"
      "void main() {\n"
      "  gl_FragColor = color * vec4(vec3(brightness), 1);\n"
      "}\n"
    );
    GLint posLoc = 0;
    program.bindAttribLocation(posLoc, "pos");
    program.link();
    program.use();

    glGenBuffers(1, &vbo);
    glGenVertexArrays(1, &vao);

    static const float[] VTX = [
      -0.25f, -0.25f,
       0.25f, -0.25f,
       0.25f,  0.25f,
      -0.25f,  0.25f
    ];

    glBindVertexArray(vao);

    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, VTX.length * float.sizeof, VTX.ptr, GL_STATIC_DRAW);

    glVertexAttribPointer(posLoc, 2, GL_FLOAT, GL_FALSE, 0, null);
    glEnableVertexAttribArray(posLoc);
  }

  public static void setRandSeed(long seed) {
    rand.setSeed(seed);
  }

  public override void close() {
    if (program !is null) {
      glDeleteVertexArrays(1, &vao);
      glDeleteBuffers(1, &vbo);
      program.close();
      program = null;
    }
  }

  public this() {
    pos = vec3(0);
    vel = vec3(0);
    size = 1;
    d2 = md2 = 0;
    cnt = 0;
  }

  public override void init(Object[] args) {
    field = cast(Field) args[0];
    smokes = cast(SmokePool) args[1];
  }

  public void set(vec2 p, float mx, float my, float mz, float sz = 1) {
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

  public override void draw(mat4 view) {
    drawCommon(view);
  }

  public override void drawLuminous(mat4 view) {
    drawCommon(view);
  }

  private void drawCommon(mat4 view) {
    program.use();

    mat4 model = mat4.identity;
    model.rotate(-d2 / 180 * PI, vec3(1, 0, 0));
    model.scale(size, size, 1);
    model.translate(pos.x, pos.y, pos.z);

    program.setUniform("projmat", view);
    program.setUniform("modelmat", model);
    program.setUniform("color", 1, rand.nextFloat(1), 0, 0.8f);
    program.setUniform("brightness", Screen.brightness);

    glBindVertexArray(vao);
    glDrawArrays(GL_TRIANGLE_FAN, 0, 4);

    glBindVertexArray(0);
    glUseProgram(0);
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
  static ShaderProgram program;
  static GLuint vao;
  static GLuint[3] vbo;
  Field field;
  vec2 pos;
  vec2 vel;
  float deg;
  float speed;
  float size;
  int cnt;
  bool revShape;

  invariant() {
    assert(pos.x < 15 && pos.x > -15);
    assert(pos.y < 20 && pos.y > -20);
    assert(vel.x < 10 && vel.x > -10);
    assert(vel.y < 10 && vel.y > -10);
    assert(size > 0 && size < 1000);
    assert(!deg.isNaN);
    assert(speed >= 0 && speed < 10);
    assert(cnt >= 0);
  }

  public static this() {
    program = null;
  }

  public this() {
    pos = vec2(0);
    vel = vec2(0);
    size = 1;
    deg = 0;
    speed = 0;
    cnt = 0;
  }

  public override void init(Object[] args) {
    field = cast(Field) args[0];

    if (program !is null) {
      return;
    }

    program = new ShaderProgram;
    program.setVertexShader(
      "uniform mat4 projmat;\n"
      "uniform vec2 pos;\n"
      "uniform vec2 vel;\n"
      "uniform float size;\n"
      "uniform int revShape;\n"
      "\n"
      "attribute vec2 velFactor;\n"
      "attribute float velFlip;\n"
      "attribute vec3 color;\n"
      "\n"
      "varying vec3 f_color;\n"
      "\n"
      "void main() {\n"
      "  vec2 rvel;\n"
      "  if (velFlip > 0.) {\n"
      "    rvel = vel.yx;\n"
      "  } else if (revShape != 0) {\n"
      "    rvel = -vel;\n"
      "  } else {\n"
      "    rvel = vel;\n"
      "  }\n"
      "  gl_Position = projmat * vec4(pos + (size * velFactor * rvel), 0, 1);\n"
      "  f_color = color;\n"
      "}\n"
    );
    program.setFragmentShader(
      "uniform float brightness;\n"
      "\n"
      "varying vec3 f_color;\n"
      "\n"
      "void main() {\n"
      "  gl_FragColor = vec4(f_color * brightness, 1);\n"
      "}\n"
    );
    GLint velFactorLoc = 0;
    GLint velFlipLoc = 1;
    GLint colorLoc = 2;
    program.bindAttribLocation(velFactorLoc, "velFactor");
    program.bindAttribLocation(velFlipLoc, "velFlip");
    program.bindAttribLocation(colorLoc, "color");
    program.link();
    program.use();

    glGenBuffers(3, vbo.ptr);
    glGenVertexArrays(1, &vao);

    static const float[] VELFACTOR = [
      -1,    -1,
      -0.2f,  0.2f,
       0.2f, -0.2f
    ];
    static const float[] VELFLIP = [
      0,
      1,
      1
    ];
    static const float[] COLOR = [
      0.33f, 0.33f, 1,    1,
      0.2f,  0.2f,  0.6f, 0.5f,
      0.2f,  0.2f,  0.6f, 0.5f
    ];

    glBindVertexArray(vao);

    glBindBuffer(GL_ARRAY_BUFFER, vbo[0]);
    glBufferData(GL_ARRAY_BUFFER, VELFACTOR.length * float.sizeof, VELFACTOR.ptr, GL_STATIC_DRAW);

    glVertexAttribPointer(velFactorLoc, 2, GL_FLOAT, GL_FALSE, 0, null);
    glEnableVertexAttribArray(velFactorLoc);

    glBindBuffer(GL_ARRAY_BUFFER, vbo[1]);
    glBufferData(GL_ARRAY_BUFFER, VELFLIP.length * float.sizeof, VELFLIP.ptr, GL_STATIC_DRAW);

    glVertexAttribPointer(velFlipLoc, 1, GL_FLOAT, GL_FALSE, 0, null);
    glEnableVertexAttribArray(velFlipLoc);

    glBindBuffer(GL_ARRAY_BUFFER, vbo[2]);
    glBufferData(GL_ARRAY_BUFFER, COLOR.length * float.sizeof, COLOR.ptr, GL_STATIC_DRAW);

    glVertexAttribPointer(colorLoc, 4, GL_FLOAT, GL_FALSE, 0, null);
    glEnableVertexAttribArray(colorLoc);

    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindVertexArray(0);
  }

  public override void close() {
    if (program !is null) {
      glDeleteVertexArrays(1, &vao);
      glDeleteBuffers(3, vbo.ptr);
      program.close();
      program = null;
    }
  }

  public void set(vec2 p, float deg, float speed, int c = 60, float sz = 1, bool rs = false) {
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
    if (cnt <= 0 || vel.fastdist() < 0.005f || !field.checkInOuterField(pos.x, pos.y)) {
      exists = false;
      return;
    }
    pos += vel;
    pos.y -= field.lastScrollY;
    vel *= 0.96f;
    size *= 1.02f;
  }

  public override void draw(mat4 view) {
    program.use();

    program.setUniform("projmat", view);
    program.setUniform("brightness", Screen.brightness);
    program.setUniform("pos", pos);
    program.setUniform("vel", vel);
    program.setUniform("size", size);
    program.setUniform("revShape", revShape);

    glBindVertexArray(vao);
    glDrawArrays(GL_TRIANGLES, 0, 3);

    glBindVertexArray(0);
    glUseProgram(0);
  }
}

public class WakePool: ActorPool!(Wake) {
  public this(int n, Object[] args) {
    super(n, args);
  }
}
