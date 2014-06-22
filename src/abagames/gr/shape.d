/*
 * $Id: shape.d,v 1.1.1.1 2005/06/18 00:46:00 kenta Exp $
 *
 * Copyright 2005 Kenta Cho. Some rights reserved.
 */
module abagames.gr.shape;

private import std.math;
private import derelict.opengl3.gl;
private import gl3n.linalg;
private import abagames.util.rand;
private import abagames.util.sdl.shaderprogram;
private import abagames.util.sdl.shape;
private import abagames.gr.screen;
private import abagames.gr.shaders;
private import abagames.gr.particle;

/**
 * Shape of a ship/platform/turret/bridge.
 */
public class BaseShape: Drawable {
 public:
  static enum ShapeType {
    SHIP, SHIP_ROUNDTAIL, SHIP_SHADOW, PLATFORM, TURRET, BRIDGE,
    SHIP_DAMAGED, SHIP_DESTROYED,
    PLATFORM_DAMAGED, PLATFORM_DESTROYED,
    TURRET_DAMAGED, TURRET_DESTROYED,
  };
 private:
  static ShaderProgram loopProgram;
  static ShaderProgram squareLoopProgram;
  static ShaderProgram pillarProgram;
  static GLuint vaoLoop;
  static GLuint[2] vboLoop;
  static GLuint vaoSquareLoop;
  static GLuint vboSquareLoop;
  static GLuint vaoPillar;
  static GLuint vboPillar;
  static const int POINT_NUM = 16;
  static Rand rand;
  static vec2 wakePos;
  float size, distRatio, spinyRatio;
  int type;
  float r, g, b;
  static const int PILLAR_POINT_NUM = 8;
  vec2[] pillarPos;
  vec2[] _pointPos;
  float[] _pointDeg;
  vec3 nextColor;
  mat4 model;

  invariant() {
    assert(wakePos.x < 15 && wakePos.x > -15);
    assert(wakePos.y < 60 && wakePos.y > -40);
    assert(size > 0 && size < 20);
    assert(distRatio >= 0 && distRatio <= 1);
    assert(spinyRatio >= 0 && spinyRatio <= 1);
    assert(type >= 0);
    assert(r >= 0 && r <= 1);
    assert(g >= 0 && g <= 1);
    assert(b >= 0 && b <= 1);
    foreach (const(vec2) p; pillarPos) {
      assert(p.x < 20 && p.x > -20);
      assert(p.y < 20 && p.x > -20);
    }
    foreach (const(vec2) p; _pointPos) {
      assert(p.x < 20 && p.x > -20);
      assert(p.y < 20 && p.x > -20);
    }
    foreach (float d; _pointDeg)
      assert(!d.isNaN);
  }

  public static this() {
    rand = new Rand;
    wakePos = vec2(0);

    loopProgram = null;
    squareLoopProgram = null;
    pillarProgram = null;
  }

  public static void setRandSeed(long seed) {
    rand.setSeed(seed);
  }

  public this(float size, float distRatio, float spinyRatio,
              int type, float r, float g, float b) {
    this.size = size;
    this.distRatio = distRatio;
    this.spinyRatio = spinyRatio;
    this.type = type;
    this.r = r;
    this.g = g;
    this.b = b;

    if (type != ShapeType.BRIDGE) {
      for (int i = 0; i < POINT_NUM; i++) {
        if (type != ShapeType.SHIP && type != ShapeType.SHIP_DESTROYED && type != ShapeType.SHIP_DAMAGED &&
            i > POINT_NUM * 2 / 5 && i <= POINT_NUM * 3 / 5)
          continue;
        if ((type == ShapeType.TURRET || type == ShapeType.TURRET_DAMAGED || type == ShapeType.TURRET_DESTROYED) &&
            (i <= POINT_NUM / 5 || i > POINT_NUM * 4 / 5))
          continue;

        float d = PI * 2 * i / POINT_NUM;
        float cx = sin(d) * (1 - distRatio);
        float cy = cos(d);
        float sx, sy;
        if (i == POINT_NUM / 4 || i == POINT_NUM / 4 * 3)
          sy = 0;
        else
          sy = 1 / (1 + fabs(tan(d)));
        assert(!sy.isNaN);
        sx = 1 - sy;
        if (i >= POINT_NUM / 2)
          sx *= -1;
        if (i >= POINT_NUM / 4 && i <= POINT_NUM / 4 * 3)
          sy *= -1;
        sx *= 1 - distRatio;
        float px = cx * (1 - spinyRatio) + sx * spinyRatio;
        float py = cy * (1 - spinyRatio) + sy * spinyRatio;
        px *= size;
        py *= size;

        if (i == POINT_NUM / 8 || i == POINT_NUM / 8 * 3 ||
            i == POINT_NUM / 8 * 5 || i == POINT_NUM / 8 * 7)
          pillarPos ~= vec2(px * 0.8f, py * 0.8f);
        _pointPos ~= vec2(px, py);
        _pointDeg ~= d;
      }
    }

    if (loopProgram !is null) {
      return;
    }

    loopProgram = new ShaderProgram;
    loopProgram.setVertexShader(
      "uniform mat4 projmat;\n"
      "uniform mat4 modelmat;\n"
      "uniform float distRatio;\n"
      "uniform float spinyRatio;\n"
      "uniform float size;\n"
      "uniform float s;\n"
      "uniform float z;\n"
      "\n"
      "attribute float deg;\n"
      "attribute vec2 spos;\n"
      "\n"
      "void main() {\n"
      "  vec2 rot = vec2(sin(deg), cos(deg));\n"
      "  vec2 fpos = (1. - spinyRatio) * rot + spos * spinyRatio;\n"
      "  vec2 ratio = vec2(1. - distRatio, 1);\n"
      "  vec4 pos4 = vec4(fpos * size * s * ratio, z, 1);\n"
      "  gl_Position = projmat * modelmat * pos4;\n"
      "}\n"
    );
    loopProgram.setFragmentShader(
      "uniform float brightness;\n"
      "uniform vec3 color;\n"
      "\n"
      "void main() {\n"
      "  gl_FragColor = vec4(color * vec3(brightness), 1);\n"
      "}\n"
    );
    GLint degLoc = 0;
    GLint sposLoc = 1;
    loopProgram.bindAttribLocation(degLoc, "deg");
    loopProgram.bindAttribLocation(sposLoc, "spos");
    loopProgram.link();
    loopProgram.use();

    glGenBuffers(2, vboLoop.ptr);
    glGenVertexArrays(1, &vaoLoop);

    float[POINT_NUM] DEG;
    size_t dn = 0;
    float[2 * POINT_NUM] SPOS;
    size_t vn = 0;

    for (int i = 0; i < POINT_NUM; i++) {
      float d = PI * 2 * i / POINT_NUM;
      float sx, sy;
      if (i == POINT_NUM / 4 || i == POINT_NUM / 4 * 3)
        sy = 0;
      else
        sy = 1 / (1 + fabs(tan(d)));
      assert(!sy.isNaN);
      sx = 1 - sy;
      if (i >= POINT_NUM / 2)
        sx *= -1;
      if (i >= POINT_NUM / 4 && i <= POINT_NUM / 4 * 3)
        sy *= -1;

      DEG[dn++] = d;
      SPOS[vn++] = sx;
      SPOS[vn++] = sy;
    }

    glBindVertexArray(vaoLoop);

    glBindBuffer(GL_ARRAY_BUFFER, vboLoop[0]);
    glBufferData(GL_ARRAY_BUFFER, DEG.length * float.sizeof, DEG.ptr, GL_STATIC_DRAW);

    glVertexAttribPointer(degLoc, 1, GL_FLOAT, GL_FALSE, 0, null);
    glEnableVertexAttribArray(degLoc);

    glBindBuffer(GL_ARRAY_BUFFER, vboLoop[1]);
    glBufferData(GL_ARRAY_BUFFER, SPOS.length * float.sizeof, SPOS.ptr, GL_STATIC_DRAW);

    glVertexAttribPointer(sposLoc, 2, GL_FLOAT, GL_FALSE, 0, null);
    glEnableVertexAttribArray(sposLoc);

    squareLoopProgram = new ShaderProgram;
    squareLoopProgram.setVertexShader(
      "uniform mat4 projmat;\n"
      "uniform mat4 modelmat;\n"
      "uniform float size;\n"
      "uniform float s;\n"
      "uniform float yRatio;\n"
      "uniform float z;\n"
      "\n"
      "attribute float deg;\n"
      "\n"
      "void main() {\n"
      "  vec2 pos = size * s * vec2(sin(deg), cos(deg));\n"
      "  if (pos.y > 0.) {\n"
      "    pos.y *= yRatio;\n"
      "  }\n"
      "  gl_Position = projmat * modelmat * vec4(pos, z, 1);\n"
      "}\n"
    );
    squareLoopProgram.setFragmentShader(
      "uniform float brightness;\n"
      "uniform vec3 color;\n"
      "\n"
      "void main() {\n"
      "  gl_FragColor = vec4(color * vec3(brightness), 1);\n"
      "}\n"
    );
    squareLoopProgram.bindAttribLocation(degLoc, "deg");
    squareLoopProgram.link();
    squareLoopProgram.use();

    glGenBuffers(1, &vboSquareLoop);
    glGenVertexArrays(1, &vaoSquareLoop);

    float[5] SQUARELOOP;

    for (int i = 0; i <= 4; i++) {
      SQUARELOOP[i] = PI * 2 * i / 4 + PI / 4;
    }

    glBindVertexArray(vaoSquareLoop);

    glBindBuffer(GL_ARRAY_BUFFER, vboSquareLoop);
    glBufferData(GL_ARRAY_BUFFER, SQUARELOOP.length * float.sizeof, SQUARELOOP.ptr, GL_STATIC_DRAW);

    glVertexAttribPointer(degLoc, 1, GL_FLOAT, GL_FALSE, 0, null);
    glEnableVertexAttribArray(degLoc);

    pillarProgram = new ShaderProgram;
    pillarProgram.setVertexShader(
      "uniform mat4 projmat;\n"
      "uniform mat4 modelmat;\n"
      "uniform vec2 p;\n"
      "uniform float s;\n"
      "uniform float z;\n"
      "\n"
      "attribute float deg;\n"
      "\n"
      "void main() {\n"
      "  vec2 pos = p + s * vec2(sin(deg), cos(deg));\n"
      "  gl_Position = projmat * modelmat * vec4(pos, z, 1);\n"
      "}\n"
    );
    pillarProgram.setFragmentShader(
      "uniform float brightness;\n"
      "uniform vec3 color;\n"
      "\n"
      "void main() {\n"
      "  gl_FragColor = vec4(color * vec3(brightness), 1);\n"
      "}\n"
    );
    pillarProgram.bindAttribLocation(degLoc, "deg");
    pillarProgram.link();
    pillarProgram.use();

    glGenBuffers(1, &vboPillar);
    glGenVertexArrays(1, &vaoPillar);

    float[PILLAR_POINT_NUM] PILLAR;

    for (int i = 0; i < PILLAR_POINT_NUM; i++) {
      PILLAR[i] = PI * 2 * i / PILLAR_POINT_NUM;
    }

    glBindVertexArray(vaoPillar);

    glBindBuffer(GL_ARRAY_BUFFER, vboPillar);
    glBufferData(GL_ARRAY_BUFFER, PILLAR.length * float.sizeof, PILLAR.ptr, GL_STATIC_DRAW);

    glVertexAttribPointer(degLoc, 1, GL_FLOAT, GL_FALSE, 0, null);
    glEnableVertexAttribArray(degLoc);

    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindVertexArray(0);
  }

  public void close() {
    if (loopProgram !is null) {
      glDeleteVertexArrays(1, &vaoLoop);
      glDeleteBuffers(2, vboLoop.ptr);
      loopProgram.close();
      loopProgram = null;

      glDeleteVertexArrays(1, &vaoSquareLoop);
      glDeleteBuffers(1, &vboSquareLoop);
      squareLoopProgram.close();
      squareLoopProgram = null;

      glDeleteVertexArrays(1, &vaoPillar);
      glDeleteBuffers(1, &vboPillar);
      pillarProgram.close();
      pillarProgram = null;
    }
  }

  public override void setModelMatrix(mat4 model) {
    loopProgram.use();
    loopProgram.setUniform("modelmat", model);

    squareLoopProgram.use();
    squareLoopProgram.setUniform("modelmat", model);

    pillarProgram.use();
    pillarProgram.setUniform("modelmat", model);

    glUseProgram(0);
  }

  public override void draw(mat4 view) {
    float height = size * 0.5f;
    float z = 0;
    float sz = 1;
    vec3 baseColor = vec3(r, g, b);
    if (type == ShapeType.BRIDGE)
      z += height;
    if (type != ShapeType.SHIP_DESTROYED)
      nextColor = baseColor;
    else {
      // TODO: What color to set here?
    }

    loopProgram.use();

    loopProgram.setUniform("projmat", view);
    loopProgram.setUniform("brightness", Screen.brightness);
    loopProgram.setUniform("distRatio", distRatio);
    loopProgram.setUniform("spinyRatio", spinyRatio);
    loopProgram.setUniform("size", size);

    squareLoopProgram.use();

    squareLoopProgram.setUniform("projmat", view);
    squareLoopProgram.setUniform("brightness", Screen.brightness);
    squareLoopProgram.setUniform("size", size);

    pillarProgram.use();

    pillarProgram.setUniform("projmat", view);
    pillarProgram.setUniform("brightness", Screen.brightness);

    if (type != ShapeType.BRIDGE)
      createLoop(GL_LINE_LOOP, sz, z, false);
    else
      createSquareLoop(GL_LINE_LOOP, sz, z, false);
    if (type != ShapeType.SHIP_SHADOW && type != ShapeType.SHIP_DESTROYED &&
        type != ShapeType.PLATFORM_DESTROYED && type != ShapeType.TURRET_DESTROYED) {
      nextColor = 0.4f * baseColor;
      createLoop(GL_TRIANGLE_FAN, sz, z, true);
    }
    switch (type) {
    case ShapeType.SHIP:
    case ShapeType.SHIP_ROUNDTAIL:
    case ShapeType.SHIP_SHADOW:
    case ShapeType.SHIP_DAMAGED:
    case ShapeType.SHIP_DESTROYED:
      if (type != ShapeType.SHIP_DESTROYED)
        nextColor = 0.4f * baseColor;
      for (int i = 0; i < 3; i++) {
        z -= height / 4;
        sz -= 0.2f;
        createLoop(GL_LINE_LOOP, sz, z);
      }
      break;
    case ShapeType.PLATFORM:
    case ShapeType.PLATFORM_DAMAGED:
    case ShapeType.PLATFORM_DESTROYED:
      nextColor = 0.4f * baseColor;
      for (int i = 0; i < 3; i++) {
        z -= height / 3;
        foreach (vec2 pp; pillarPos) {
          createPillar(GL_LINE_LOOP, pp, size * 0.2f, z);
        }
      }
      break;
    case ShapeType.BRIDGE:
    case ShapeType.TURRET:
    case ShapeType.TURRET_DAMAGED:
      nextColor = 0.6f * baseColor;
      z += height;
      sz -= 0.33f;
      if (type == ShapeType.BRIDGE)
        createSquareLoop(GL_LINE_LOOP, sz, z);
      else
        createSquareLoop(GL_LINE_LOOP, sz, z / 2, false, 3);
      nextColor = 0.25f * baseColor;
      if (type == ShapeType.BRIDGE)
        createSquareLoop(GL_TRIANGLE_FAN, sz, z, true);
      else
        createSquareLoop(GL_TRIANGLE_FAN, sz, z / 2, true, 3);
      break;
    case ShapeType.TURRET_DESTROYED:
      break;
    default:
      assert(0);
    }

    glUseProgram(0);
  }

  private void createLoop(GLenum drawType, float s, float z, bool backToFirst = false) {
    static GLuint[POINT_NUM + 1] VTXELEM;
    GLsizei vn = 0;

    for (int i = 0; i < POINT_NUM; i++) {
      if (type != ShapeType.SHIP && type != ShapeType.SHIP_DESTROYED && type != ShapeType.SHIP_DAMAGED &&
          i > POINT_NUM * 2 / 5 && i <= POINT_NUM * 3 / 5)
        continue;
      if ((type == ShapeType.TURRET || type == ShapeType.TURRET_DAMAGED || type == ShapeType.TURRET_DESTROYED) &&
          (i <= POINT_NUM / 5 || i > POINT_NUM * 4 / 5))
        continue;

      VTXELEM[vn++] = i;
    }
    if (backToFirst) {
      VTXELEM[vn++] = VTXELEM[0];
    }

    loopProgram.use();

    loopProgram.setUniform("color", nextColor);
    loopProgram.setUniform("s", s);
    loopProgram.setUniform("z", z);

    glBindVertexArray(vaoLoop);
    glDrawElements(drawType, vn, GL_UNSIGNED_INT, VTXELEM.ptr);

    glBindVertexArray(0);
  }

  private void createSquareLoop(GLenum drawType, float s, float z, bool backToFirst = false, float yRatio = 1) {
    int pn;
    if (backToFirst)
      pn = 5;
    else
      pn = 4;

    squareLoopProgram.use();

    squareLoopProgram.setUniform("color", nextColor);
    squareLoopProgram.setUniform("yRatio", yRatio);
    squareLoopProgram.setUniform("s", s);
    squareLoopProgram.setUniform("z", z);

    glBindVertexArray(vaoSquareLoop);
    glDrawArrays(drawType, 0, pn);

    glBindVertexArray(0);
  }

  private void createPillar(GLenum drawType, vec2 p, float s, float z) {
    pillarProgram.use();

    pillarProgram.setUniform("color", nextColor);
    pillarProgram.setUniform("p", p);
    pillarProgram.setUniform("s", s);
    pillarProgram.setUniform("z", z);

    glBindVertexArray(vaoPillar);
    glDrawArrays(drawType, 0, PILLAR_POINT_NUM);

    glBindVertexArray(0);
  }

  public void addWake(WakePool wakes, vec2 pos, float deg, float spd, float sr = 1) {
    float sp = spd;
    if (sp > 0.1f)
      sp = 0.1f;
    float sz = size;
    if (sz > 10)
      sz = 10;
    wakePos.x = pos.x + sin(deg + PI / 2 + 0.7f) * size * 0.5f * sr;
    wakePos.y = pos.y + cos(deg + PI / 2 + 0.7f) * size * 0.5f * sr;
    Wake w = wakes.getInstanceForced();
    w.set(wakePos, deg + PI - 0.2f + rand.nextSignedFloat(0.1f), sp, 40, sz * 32 * sr);
    wakePos.x = pos.x + sin(deg - PI / 2 - 0.7f) * size * 0.5f * sr;
    wakePos.y = pos.y + cos(deg - PI / 2 - 0.7f) * size * 0.5f * sr;
    w = wakes.getInstanceForced();
    w.set(wakePos, deg + PI + 0.2f + rand.nextSignedFloat(0.1f), sp, 40, sz * 32 * sr);
  }

  public vec2[] pointPos() {
    return _pointPos;
  }

  public float[] pointDeg() {
    return _pointDeg;
  }

  public bool checkShipCollision(float x, float y, float deg, float sr = 1) {
    float cs = size * (1 - distRatio) * 1.1f * sr;
    if (dist(x, y, 0, 0) < cs)
      return true;
    float ofs = 0;
    for (;;) {
      ofs += cs;
      cs *= distRatio;
      if (cs < 0.2f)
        return false;
      if (dist(x, y, sin(deg) * ofs, cos(deg) * ofs) < cs ||
          dist(x, y, -sin(deg) * ofs, -cos(deg) * ofs) < cs)
        return true;
    }
    assert(0);
  }

  private float dist(float x, float y, float px, float py) {
    float ax = fabs(x - px);
    float ay = fabs(y - py);
    if (ax > ay)
      return ax + ay / 2;
    else
      return ay + ax / 2;
  }
}

public class CollidableBaseShape: BaseShape, Collidable {
  mixin CollidableImpl;
 private:
  vec2 _collision;

  public this(float size, float distRatio, float spinyRatio,
              int type,
              float r, float g, float b) {
    super(size, distRatio, spinyRatio, type, r, g, b);
    _collision = vec2(size / 2, size / 2);
  }

  public vec2 collision() {
    return _collision;
  }
}

public class TurretShape: ResizableDrawable {
 public:
  static enum TurretShapeType {
    NORMAL, DAMAGED, DESTROYED,
  };
 private:
  static BaseShape[] shapes;

  public static void init() {
    shapes ~= new CollidableBaseShape(1, 0, 0, BaseShape.ShapeType.TURRET, 1, 0.8f, 0.8f);
    shapes ~= new BaseShape(1, 0, 0, BaseShape.ShapeType.TURRET_DAMAGED, 0.9f, 0.9f, 1);
    shapes ~= new BaseShape(1, 0, 0, BaseShape.ShapeType.TURRET_DESTROYED, 0.8f, 0.33f, 0.66f);
  }

  public static void close() {
    foreach (BaseShape s; shapes)
      s.close();
  }

  public this(int t) {
    shape = shapes[t];
  }
}

public class EnemyShape: ResizableDrawable {
 public:
  static enum EnemyShapeType {
    SMALL, SMALL_DAMAGED, SMALL_BRIDGE,
    MIDDLE, MIDDLE_DAMAGED, MIDDLE_DESTROYED, MIDDLE_BRIDGE,
    PLATFORM, PLATFORM_DAMAGED, PLATFORM_DESTROYED, PLATFORM_BRIDGE,
  };
  static const float MIDDLE_COLOR_R = 1, MIDDLE_COLOR_G = 0.6f, MIDDLE_COLOR_B = 0.5f;
 private:
  static BaseShape[] shapes;

  public static void init() {
    shapes ~= new BaseShape
      (1, 0.5f, 0.1f, BaseShape.ShapeType.SHIP, 0.9f, 0.7f, 0.5f);
    shapes ~= new BaseShape
      (1, 0.5f, 0.1f, BaseShape.ShapeType.SHIP_DAMAGED, 0.5f, 0.5f, 0.9f);
    shapes ~= new CollidableBaseShape
      (0.66f, 0, 0, BaseShape.ShapeType.BRIDGE, 1, 0.2f, 0.3f);
    shapes ~= new BaseShape
      (1, 0.7f, 0.33f, BaseShape.ShapeType.SHIP, MIDDLE_COLOR_R, MIDDLE_COLOR_G, MIDDLE_COLOR_B);
    shapes ~= new BaseShape
      (1, 0.7f, 0.33f, BaseShape.ShapeType.SHIP_DAMAGED, 0.5f, 0.5f, 0.9f);
    shapes ~= new BaseShape
      (1, 0.7f, 0.33f, BaseShape.ShapeType.SHIP_DESTROYED, 0, 0, 0);
    shapes ~= new CollidableBaseShape
      (0.66f, 0, 0, BaseShape.ShapeType.BRIDGE, 1, 0.2f, 0.3f);
    shapes ~= new BaseShape
      (1, 0, 0, BaseShape.ShapeType.PLATFORM, 1, 0.6f, 0.7f);
    shapes ~= new BaseShape
      (1, 0, 0, BaseShape.ShapeType.PLATFORM_DAMAGED, 0.5f, 0.5f, 0.9f);
    shapes ~= new BaseShape
      (1, 0, 0, BaseShape.ShapeType.PLATFORM_DESTROYED, 1, 0.6f, 0.7f);
    shapes ~= new CollidableBaseShape
      (0.5f, 0, 0, BaseShape.ShapeType.BRIDGE, 1, 0.2f, 0.3f);
  }

  public static void close() {
    foreach (BaseShape s; shapes)
      s.close();
  }

  public this(int t) {
    shape = shapes[t];
  }

  public void addWake(WakePool wakes, vec2 pos, float deg, float sp) {
    (cast(BaseShape) shape).addWake(wakes, pos, deg, sp, size);
  }

  public bool checkShipCollision(float x, float y, float deg) {
    return (cast(BaseShape) shape).checkShipCollision(x, y, deg, size);
  }
}

public class BulletShape: ResizableDrawable {
 public:
  static enum BulletShapeType {
    NORMAL, SMALL, MOVING_TURRET, DESTRUCTIVE,
  };
 private:
  static DrawableShape[] shapes;

  public static void init() {
    shapes ~= new NormalBulletShape;
    shapes ~= new SmallBulletShape;
    shapes ~= new MovingTurretBulletShape;
    shapes ~= new DestructiveBulletShape;
  }

  public static void close() {
    foreach (DrawableShape s; shapes)
      s.close();
  }

  public void set(int t) {
    shape = shapes[t];
  }
}

public class NormalBulletShape: DrawableShapeNew {
  mixin UniformColorShader!(3, 3);

  public void fillStaticShaderData() {
    static const float[] VTX = [
       0.2f, -0.25f, 0.2f,
       0,     0.33f, 0,
      -0.2f, -0.25f, -0.2f,

      -0.2f, -0.25f, 0.2f,
       0,     0.33f, 0,
       0.2f, -0.25f, -0.2f,

       0,     0.33f,  0,
       0.2f, -0.25f,  0.2f,
      -0.2f, -0.25f,  0.2f,
      -0.2f, -0.25f, -0.2f,
       0.2f, -0.25f, -0.2f,
       0.2f, -0.25f,  0.2f
    ];

    glBindVertexArray(vao[0]);

    glBindBuffer(GL_ARRAY_BUFFER, vbo[0]);
    glBufferData(GL_ARRAY_BUFFER, VTX.length * float.sizeof, VTX.ptr, GL_STATIC_DRAW);

    glVertexAttribPointer(posLoc, 3, GL_FLOAT, GL_FALSE, 0, null);
    glEnableVertexAttribArray(posLoc);

    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindVertexArray(0);
  }

  public override void drawShape() {
    program.setUniform("brightness", Screen.brightness);

    glBindVertexArray(vao[0]);

    glDisable(GL_BLEND);

    program.setUniform("color", 1, 1, 0.3f);
    glDrawArrays(GL_LINE_STRIP, 0, 3);
    glDrawArrays(GL_LINE_STRIP, 3, 3);

    glEnable(GL_BLEND);

    program.setUniform("color", 0.5f, 0.2f, 0.1f);
    glDrawArrays(GL_TRIANGLE_FAN, 6, 6);
  }
}

public class SmallBulletShape: DrawableShapeNew {
  mixin UniformColorShader!(3, 3);

  public void fillStaticShaderData() {
    static const float[] VTX = [
       0.25f, -0.25f,  0.25f,
       0,      0.33f,  0,
      -0.25f, -0.25f, -0.25f,

      -0.25f, -0.25f,  0.25f,
       0,      0.33f,  0,
       0.25f, -0.25f, -0.25f,

       0,      0.33f,  0,
       0.25f, -0.25f,  0.25f,
      -0.25f, -0.25f,  0.25f,
      -0.25f, -0.25f, -0.25f,
       0.25f, -0.25f, -0.25f,
       0.25f, -0.25f,  0.25f
    ];

    glBindVertexArray(vao[0]);

    glBindBuffer(GL_ARRAY_BUFFER, vbo[0]);
    glBufferData(GL_ARRAY_BUFFER, VTX.length * float.sizeof, VTX.ptr, GL_STATIC_DRAW);

    glVertexAttribPointer(posLoc, 3, GL_FLOAT, GL_FALSE, 0, null);
    glEnableVertexAttribArray(posLoc);

    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindVertexArray(0);
  }

  public override void drawShape() {
    program.setUniform("brightness", Screen.brightness);

    glBindVertexArray(vao[0]);

    glDisable(GL_BLEND);

    program.setUniform("color", 0.6f, 0.9f, 0.3f);
    glDrawArrays(GL_LINE_STRIP, 0, 3);
    glDrawArrays(GL_LINE_STRIP, 3, 3);

    glEnable(GL_BLEND);

    program.setUniform("color", 0.2f, 0.4f, 0.1f);
    glDrawArrays(GL_TRIANGLE_FAN, 6, 6);
  }
}

public class MovingTurretBulletShape: DrawableShapeNew {
  mixin UniformColorShader!(3, 3);

  public void fillStaticShaderData() {
    static const float[] VTX = [
       0.25f, -0.25f,  0.25f,
       0,      0.33f,  0,
      -0.25f, -0.25f, -0.25f,

      -0.25f, -0.25f,  0.25f,
       0,      0.33f,  0,
       0.25f, -0.25f, -0.25f,

       0,      0.33f,  0,
       0.25f, -0.25f,  0.25f,
      -0.25f, -0.25f,  0.25f,
      -0.25f, -0.25f, -0.25f,
       0.25f, -0.25f, -0.25f,
       0.25f, -0.25f,  0.25f
    ];

    glBindVertexArray(vao[0]);

    glBindBuffer(GL_ARRAY_BUFFER, vbo[0]);
    glBufferData(GL_ARRAY_BUFFER, VTX.length * float.sizeof, VTX.ptr, GL_STATIC_DRAW);

    glVertexAttribPointer(posLoc, 3, GL_FLOAT, GL_FALSE, 0, null);
    glEnableVertexAttribArray(posLoc);

    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindVertexArray(0);
  }

  public override void drawShape() {
    program.setUniform("brightness", Screen.brightness);

    glBindVertexArray(vao[0]);

    glDisable(GL_BLEND);

    program.setUniform("color", 0.7f, 0.5f, 0.9f);
    glDrawArrays(GL_LINE_STRIP, 0, 3);
    glDrawArrays(GL_LINE_STRIP, 3, 3);

    glEnable(GL_BLEND);

    program.setUniform("color", 0.2f, 0.2f, 0.3f);
    glDrawArrays(GL_TRIANGLE_FAN, 6, 6);
  }
}

public class DestructiveBulletShape: DrawableShapeNew, Collidable {
  mixin UniformColorShader!(2, 3);
  mixin CollidableImpl;
 private:
  vec2 _collision;

  public void fillStaticShaderData() {
    static const float[] VTX = [
       0.2f,  0,
       0,     0.4f,
      -0.2f,  0,
       0,    -0.4f
    ];

    glBindVertexArray(vao[0]);

    glBindBuffer(GL_ARRAY_BUFFER, vbo[0]);
    glBufferData(GL_ARRAY_BUFFER, VTX.length * float.sizeof, VTX.ptr, GL_STATIC_DRAW);

    glVertexAttribPointer(posLoc, 2, GL_FLOAT, GL_FALSE, 0, null);
    glEnableVertexAttribArray(posLoc);

    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindVertexArray(0);

    _collision = vec2(0.4f, 0.4f);
  }

  public override void drawShape() {
    program.setUniform("brightness", Screen.brightness);

    glBindVertexArray(vao[0]);

    glDisable(GL_BLEND);

    program.setUniform("color", 0.9f, 0.9f, 0.6f);
    glDrawArrays(GL_LINE_STRIP, 0, 4);

    glEnable(GL_BLEND);

    program.setUniform("color", 0.7f, 0.5f, 0.4f);
    glDrawArrays(GL_TRIANGLE_FAN, 0, 4);

    _collision = vec2(0.4f, 0.4f);
  }

  public vec2 collision() {
    return _collision;
  }
}

public class CrystalShape: DrawableShapeNew {
  mixin UniformColorShader!(2, 3);

  public void fillStaticShaderData() {
    program.setUniform("color", 0.6f, 1, 0.7f);

    static const float[] VTX = [
      -0.2f,  0.2f,
       0.2f,  0.2f,
       0.2f, -0.2f,
      -0.2f, -0.2f
    ];

    glBindVertexArray(vao[0]);

    glBindBuffer(GL_ARRAY_BUFFER, vbo[0]);
    glBufferData(GL_ARRAY_BUFFER, VTX.length * float.sizeof, VTX.ptr, GL_STATIC_DRAW);

    glVertexAttribPointer(posLoc, 2, GL_FLOAT, GL_FALSE, 0, null);
    glEnableVertexAttribArray(posLoc);

    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindVertexArray(0);
  }

  public override void drawShape() {
    program.setUniform("brightness", Screen.brightness);

    glBindVertexArray(vao[0]);
    glDrawArrays(GL_LINE_LOOP, 0, 4);
  }
}

public class ShieldShape: DrawableShapeNew {
  mixin AttributeColorShader!(2, 3, 3, 2);

  public void fillStaticShaderData() {
    static float[2 * 10] VTX;
    size_t vn = 0;

    VTX[vn++] = 0;
    VTX[vn++] = 0;

    float d = 0;
    for (int i = 0; i < 9; i++) {
      VTX[vn++] = sin(d);
      VTX[vn++] = cos(d);

      d += PI / 4;
    }

    static const float[] LINECOLOR = [
      0.5f, 0.5f, 0.7f,
      0.5f, 0.5f, 0.7f,
      0.5f, 0.5f, 0.7f,
      0.5f, 0.5f, 0.7f,
      0.5f, 0.5f, 0.7f,
      0.5f, 0.5f, 0.7f,
      0.5f, 0.5f, 0.7f,
      0.5f, 0.5f, 0.7f,
      0.5f, 0.5f, 0.7f
    ];

    static const float[] FILLCOLOR = [
      0,    0,    0,
      0.3f, 0.3f, 0.5f,
      0.3f, 0.3f, 0.5f,
      0.3f, 0.3f, 0.5f,
      0.3f, 0.3f, 0.5f,
      0.3f, 0.3f, 0.5f,
      0.3f, 0.3f, 0.5f,
      0.3f, 0.3f, 0.5f,
      0.3f, 0.3f, 0.5f,
      0.3f, 0.3f, 0.5f
    ];

    glBindBuffer(GL_ARRAY_BUFFER, vbo[0]);
    glBufferData(GL_ARRAY_BUFFER, VTX.length * float.sizeof, VTX.ptr, GL_STATIC_DRAW);

    glBindVertexArray(vao[0]);

    glVertexAttribPointer(posLoc, 2, GL_FLOAT, GL_FALSE, 0, null);
    glEnableVertexAttribArray(posLoc);

    glBindVertexArray(vao[1]);

    glVertexAttribPointer(posLoc, 2, GL_FLOAT, GL_FALSE, 0, null);
    glEnableVertexAttribArray(posLoc);

    glBindVertexArray(vao[0]);

    glBindBuffer(GL_ARRAY_BUFFER, vbo[1]);
    glBufferData(GL_ARRAY_BUFFER, LINECOLOR.length * float.sizeof, LINECOLOR.ptr, GL_STATIC_DRAW);

    glVertexAttribPointer(colorLoc, 3, GL_FLOAT, GL_FALSE, 0, null);
    glEnableVertexAttribArray(colorLoc);

    glBindVertexArray(vao[1]);

    glBindBuffer(GL_ARRAY_BUFFER, vbo[2]);
    glBufferData(GL_ARRAY_BUFFER, FILLCOLOR.length * float.sizeof, FILLCOLOR.ptr, GL_STATIC_DRAW);

    glVertexAttribPointer(colorLoc, 3, GL_FLOAT, GL_FALSE, 0, null);
    glEnableVertexAttribArray(colorLoc);
  }

  public override void drawShape() {
    program.setUniform("brightness", Screen.brightness);

    glBindVertexArray(vao[0]);
    glDrawArrays(GL_LINE_LOOP, 1, 8);

    glBindVertexArray(vao[1]);
    glDrawArrays(GL_TRIANGLE_FAN, 0, 10);
  }
}
