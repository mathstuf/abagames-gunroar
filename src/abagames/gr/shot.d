/*
 * $Id: shot.d,v 1.2 2005/07/03 07:05:22 kenta Exp $
 *
 * Copyright 2005 Kenta Cho. Some rights reserved.
 */
module abagames.gr.shot;

private import std.math;
private import std.string;
private import gl3n.linalg;
private import abagames.util.actor;
private import abagames.util.rand;
private import abagames.util.support.gl;
private import abagames.util.sdl.shaderprogram;
private import abagames.util.sdl.shape;
private import abagames.gr.field;
private import abagames.gr.screen;
private import abagames.gr.shaders;
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
  static ShaderProgram program;
  static GLuint vao;
  static GLuint vbo;
  static ShotShape shape;
  static LanceShape lanceShape;
  static Rand rand;
  Field field;
  EnemyPool enemies;
  SparkPool sparks;
  SmokePool smokes;
  BulletPool bullets;
  vec2 pos;
  int cnt;
  int hitCnt;
  float _deg;
  int _damage;
  bool lance;

  invariant() {
    assert(pos.x < 15 && pos.x > -15);
    assert(pos.y < 20 && pos.y > -20);
    assert(cnt >= 0);
    assert(hitCnt >= 0);
    assert(!_deg.isNaN);
    assert(_damage >= 1);
  }

  public static void init() {
    shape = new ShotShape;
    lanceShape = new LanceShape;
    rand = new Rand;

    program = new ShaderProgram;
    program.setVertexShader(
      "uniform mat4 projmat;\n"
      "uniform mat4 modelmat;\n"
      "uniform float size;\n"
      "\n"
      "attribute vec3 pos;\n"
      "\n"
      "void main() {\n"
      "  vec3 sizev = vec3(size, 1, size);\n"
      "  vec4 pos4 = vec4(pos * sizev, 1);\n"
      "  gl_Position = projmat * pos4;\n"
      "}\n"
    );
    program.setFragmentShader(
      "uniform float brightness;\n"
      "uniform vec4 color;\n"
      "\n"
      "void main() {\n"
      "  vec4 brightness4 = vec4(vec3(brightness), 1);\n"
      "  gl_FragColor = color * brightness4;\n"
      "}\n"
    );
    GLint posLoc = 0;
    program.bindAttribLocation(posLoc, "pos");
    program.link();
    program.use();

    glGenVertexArrays(1, &vao);
    glGenBuffers(1, &vbo);

    static const float[] BUF = [
      /*
      pos */
      -1,  LANCE_SPEED, 0.5f, 0,
       1,  LANCE_SPEED, 0.5f, 0,
       1, -LANCE_SPEED, 0.5f, 0,
      -1, -LANCE_SPEED, 0.5f, 0
    ];
    enum POS = 0;
    enum BUFSZ = 4;

    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, BUF.length * float.sizeof, BUF.ptr, GL_STATIC_DRAW);

    glBindVertexArray(vao);

    vertexAttribPointer(posLoc, 3, BUFSZ, POS);
    glEnableVertexAttribArray(posLoc);
  }

  public static void setRandSeed(long seed) {
    rand.setSeed(seed);
  }

  public override void close() {
    shape.close();

    if (program !is null) {
      glDeleteVertexArrays(1, &vao);
      glDeleteBuffers(1, &vbo);
      program.close();
      program = null;
    }
  }

  public this() {
    pos = vec2(0);
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

  public void set(vec2 p, float d, bool lance = false, int dmg = -1) {
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

  public override void draw(mat4 view) {
    if (lance) {
      float x = pos.x, y = pos.y;
      float size = 0.25f, a = 0.6f;
      int hc = hitCnt;

      program.use();

      program.setUniform("brightness", Screen.brightness);

      for (int i = 0; i < cnt / 4 + 1; i++) {
        size *= 0.9f;
        a *= 0.8f;
        if (hc > 0) {
          hc--;
          continue;
        }
        float d = i * 13 + cnt * 3;

        mat4 model = mat4.identity;
        model.rotate(-d / 180 * PI, vec3(0, 1, 0));
        model.rotate(_deg, vec3(0, 0, 1));
        model.translate(x, y, 0);
        program.setUniform("modelmat", model);

        program.setUniform("size", size);

        for (int j = 0; j < 6; j++) {
          program.setUniform("color", 0.4f, 0.8f, 0.8f, a);
          glDrawArrays(GL_LINE_LOOP, 0, 4);

          program.setUniform("color", 0.2f, 0.5f, 0.5f, a / 2);
          glDrawArrays(GL_TRIANGLE_FAN, 0, 4);

          d += 60;
        }
        x -= sin(deg) * LANCE_SPEED * 2;
        y -= cos(deg) * LANCE_SPEED * 2;
      }
    } else {
      mat4 model = mat4.identity;
      model.rotate(-cnt * 31 / 180 * PI, vec3(0, 1, 0));
      model.rotate(_deg, vec3(0, 0, 1));
      model.translate(pos.x, pos.y, 0);

      shape.draw(view, model);
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
  mixin UniformColorShader!(3, 3);

  protected void fillStaticShaderData() {
    program.setUniform("color", 0.1f, 0.33f, 0.1f);

    static const float[] BUF = [
      /*
      pos,                     padding */
       0,       0.3f,  0.1f,   0,
       0.066f,  0.3f, -0.033f, 0,
       0.1f,   -0.3f, -0.05f,  0,
       0,      -0.3f,  0.15f,  0,

       0.066f,  0.3f, -0.033f, 0,
      -0.066f,  0.3f, -0.033f, 0,
      -0.1f,   -0.3f, -0.05f,  0,
       0.1f,   -0.3f, -0.05f,  0,

      -0.066f,  0.3f, -0.033f, 0,
       0,       0.3f,  0.1f,   0,
       0,      -0.3f,  0.15f,  0,
      -0.1f,   -0.3f, -0.05f,  0
    ];
    enum POS = 0;
    enum BUFSZ = 4;

    glBindBuffer(GL_ARRAY_BUFFER, vbo[0]);
    glBufferData(GL_ARRAY_BUFFER, BUF.length * float.sizeof, BUF.ptr, GL_STATIC_DRAW);

    glBindVertexArray(vao[0]);

    vertexAttribPointer(posLoc, 3, BUFSZ, POS);
    glEnableVertexAttribArray(posLoc);
  }

  protected override void drawShape() {
    program.setUniform("brightness", Screen.brightness);

    program.useVao(vao[0]);
    glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
    glDrawArrays(GL_TRIANGLE_FAN, 4, 4);
    glDrawArrays(GL_TRIANGLE_FAN, 8, 4);
  }

  protected override void setCollision() {
    _collision = vec2(0.33f, 0.33f);
  }
}

public class LanceShape: Collidable {
  mixin CollidableImpl;
 private:
  vec2 _collision;

  public this() {
    _collision = vec2(0.66f, 0.66f);
  }

  public vec2 collision() {
    return _collision;
  }
}
