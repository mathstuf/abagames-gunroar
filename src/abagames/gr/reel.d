/*
 * $Id: reel.d,v 1.1.1.1 2005/06/18 00:46:00 kenta Exp $
 *
 * Copyright 2005 Kenta Cho. Some rights reserved.
 */
module abagames.gr.reel;

private import std.math;
private import gl3n.linalg;
private import abagames.util.math;
private import abagames.util.actor;
private import abagames.util.rand;
private import abagames.util.support.gl;
private import abagames.gr.letter;
private import abagames.gr.screen;
private import abagames.gr.soundmanager;

/**
 * Rolling reel that displays the score.
 */
public class ScoreReel {
 public:
  static const int MAX_DIGIT = 16;
 private:
  int score, targetScore;
  int _actualScore;
  int digit;
  NumReel[MAX_DIGIT] numReel;

  invariant() {
    assert(digit > 0 && digit <= MAX_DIGIT);
  }

  public this() {
    foreach (ref NumReel nr; numReel)
      nr = new NumReel;
    digit = 1;
  }

  public void clear(int digit = 9) {
    score = targetScore = _actualScore = 0;
    this.digit = digit;
    for (int i = 0; i < digit; i++)
      numReel[i].clear();
  }

  public void move() {
    for (int i = 0; i < digit; i++)
      numReel[i].move();
  }

  public void draw(mat4 view, float x, float y, float s) {
    float lx = x, ly = y;
    for (int i = 0; i < digit; i++) {
      numReel[i].draw(view, lx, ly, s);
      lx -= s * 2;
    }
  }

  public void addReelScore(int as) {
    targetScore += as;
    int ts = targetScore;
    for (int i = 0; i < digit; i++) {
      numReel[i].targetDeg = cast(float) ts * 360 / 10;
      ts /= 10;
      if (ts < 0)
        break;
    }
  }

  public void accelerate() {
    for (int i = 0; i < digit; i++)
      numReel[i].accelerate();
  }

  public void addActualScore(int as) {
    _actualScore += as;
  }

  public int actualScore() {
    return _actualScore;
  }
}

public class NumReel {
 private:
  static const float VEL_MIN = 5;
  static Rand rand;
  float deg;
  float _targetDeg;
  float ofs;
  float velRatio;

  invariant() {
    assert(deg >= 0);
    assert(_targetDeg >= 0);
    assert(ofs >= 0);
  }

  public static this() {
    rand = new Rand;
  }

  public static void setRandSeed(long seed) {
    rand.setSeed(seed);
  }

  public this() {
    init();
  }

  private void init() {
    deg = _targetDeg = 0;
    ofs = 0;
    velRatio = 1;
  }

  public void clear() {
    init();
  }

  public void move() {
    float vd = _targetDeg - deg;
    vd *= 0.05f * velRatio;
    if (vd < VEL_MIN * velRatio)
      vd = VEL_MIN * velRatio;
    deg += vd;
    if (deg > _targetDeg)
      deg = _targetDeg;
  }

  public void draw(mat4 view, float x, float y, float s) {
    int n = cast(int) ((deg * 10 / 360 + 0.99f) + 1) % 10;
    float d = deg % 360;
    float od = d - n * 360 / 10;
    od -= 15;
    Math.normalizeDeg360(od);
    od *= 1.5f;
    for (int i = 0; i < 3; i++) {
      mat4 model = mat4.identity;
      model.scale(s, -s, s);
      model.translate(0, 0, s * 2.4f);
      model.rotate(-od / 180 * PI, vec3(1, 0, 0));
      if (ofs > 0.005f)
        model.translate(x + rand.nextSignedFloat(1) * ofs, y + rand.nextSignedFloat(1) * ofs, 0);
      else
        model.translate(x, y, 0);

      float a = 1 - fabs((od + 15) / (360 / 10 * 1.5f)) / 2;
      if (a < 0)
        a = 0;
      Letter.setColor(vec4(a, a, a, 1));
      Letter.drawLetter(view * model, n, Letter.LINE_COLOR);
      Letter.setColor(vec4(a / 2, a / 2, a / 2, 1));
      Letter.drawLetter(view * model, n, Letter.POLY_COLOR);
      n--;
      if (n < 0)
        n = 9;
      od += 360 / 10 * 1.5f;
      Math.normalizeDeg360(od);
    }
    ofs *= 0.95f;
  }

  public void targetDeg(float td) {
    if ((td - _targetDeg) > 1)
      ofs += 0.1f;
    _targetDeg = td;
  }

  public void accelerate() {
    velRatio = 4;
  }
}

/**
 * Flying indicator that shows the score and the multiplier.
 */
public class NumIndicator: Actor {
 private:
  static enum IndicatorType {
    SCORE, MULTIPLIER,
  };
  static enum FlyingToType {
    RIGHT, BOTTOM,
  };
  static Rand rand;
  static const float TARGET_Y_MIN = -7;
  static const float TARGET_Y_MAX = 7;
  static const float TARGET_Y_INTERVAL = 1;
  static float targetY;
  struct Target {
    vec2 pos;
    int flyingTo;
    float initialVelRatio;
    float size;
    int n;
    int cnt;
  };
  ScoreReel scoreReel;
  vec2 pos, vel;
  int n, type;
  float size;
  int cnt;
  float alpha;
  Target[4] target;
  int targetIdx;
  int targetNum;

  invariant() {
    assert(targetY <= TARGET_Y_MAX && targetY >= TARGET_Y_MIN);
    assert(pos.x < 15 && pos.x > -15);
    assert(pos.y < 20 && pos.y > -20);
    assert(vel.x < 10 && vel.x > -10);
    assert(vel.y < 10 && vel.y > -10);
    assert(alpha >= 0 && alpha <= 1);
    foreach (const(Target) t; target) {
      assert(t.pos.x < 15 && t.pos.x > -15);
      assert(t.pos.y < 20 && t.pos.y > -20);
      assert(t.initialVelRatio >= 0);
      assert(t.size >= 0);
    }
    assert(targetIdx >= -1 && targetIdx <= 4);
    assert(targetNum >= 0 && targetNum <= 4);
  }

  public static this() {
    rand = new Rand;
    targetY = TARGET_Y_MIN;
  }

  public static void setRandSeed(long seed) {
    rand.setSeed(seed);
  }

  public static void initTargetY() {
    targetY = TARGET_Y_MIN;
  }

  public static float getTargetY() {
    float ty = targetY;
    targetY += TARGET_Y_INTERVAL;
    if (targetY > TARGET_Y_MAX)
      targetY = TARGET_Y_MIN;
    return ty;
  }

  public static void decTargetY() {
    targetY -= TARGET_Y_INTERVAL;
    if (targetY < TARGET_Y_MIN)
      targetY = TARGET_Y_MAX;
  }

  public this() {
    pos = vec2(0);
    vel = vec2(0);
    foreach (ref Target t; target) {
      t.pos = vec2(0);
      t.initialVelRatio = 0;
      t.size = 0;
    }
    targetIdx = targetNum = 0;
    alpha = 1;
  }

  public override void init(Object[] args) {
    scoreReel = cast(ScoreReel) args[0];
  }

  public override void close() {
  }

  public void set(int n, IndicatorType type, float size, vec2 p) {
    set(n, type, size, p.x, p.y);
  }

  public void set(int n, IndicatorType type, float size, float x, float y) {
    if (exists && this.type == IndicatorType.SCORE) {
      if (this.target[targetIdx].flyingTo == FlyingToType.RIGHT)
        decTargetY();
      scoreReel.addReelScore(target[targetNum - 1].n);
    }
    this.n = n;
    this.type = type;
    this.size = size;
    pos = vec2(x, y);
    targetIdx = -1;
    targetNum = 0;
    alpha = 0.1f;
    exists = true;
  }

  public void addTarget(float x, float y, FlyingToType flyingTo, float initialVelRatio,
                        float size, int n, int cnt) {
    target[targetNum].pos = vec2(x, y);
    target[targetNum].flyingTo = flyingTo;
    target[targetNum].initialVelRatio = initialVelRatio;
    target[targetNum].size = size;
    target[targetNum].n = n;
    target[targetNum].cnt = cnt;
    targetNum++;
  }

  public void gotoNextTarget() {
    targetIdx++;
    if (targetIdx > 0)
      SoundManager.playSe("score_up.wav");
    if (targetIdx >= targetNum) {
      if (target[targetIdx - 1].flyingTo == FlyingToType.BOTTOM)
        scoreReel.addReelScore(target[targetIdx - 1].n);
      exists = false;
      return;
    }
    switch (target[targetIdx].flyingTo) {
    case FlyingToType.RIGHT:
      vel.x = -0.3f + rand.nextSignedFloat(0.05f);
      vel.y = rand.nextSignedFloat(0.1f);
      break;
    case FlyingToType.BOTTOM:
      vel.x = rand.nextSignedFloat(0.1f);
      vel.y = 0.3f + rand.nextSignedFloat(0.05f);
      decTargetY();
      break;
    default:
      assert(0);
    }
    vel *= target[targetIdx].initialVelRatio;
    cnt = target[targetIdx].cnt;
  }

  public override void move() {
    if (targetIdx < 0)
      return;
    vec2 tp = target[targetIdx].pos;
    switch (target[targetIdx].flyingTo) {
    case FlyingToType.RIGHT:
      vel.x += (tp.x - pos.x) * 0.0036f;
      pos.y += (tp.y - pos.y) * 0.1f;
      if (fabs(pos.y - tp.y) < 0.5f)
        pos.y += (tp.y - pos.y) * 0.33f;
      alpha += (1 - alpha) * 0.03f;
      break;
    case FlyingToType.BOTTOM:
      pos.x += (tp.x - pos.x) * 0.1f;
      vel.y += (tp.y - pos.y) * 0.0036f;
      alpha *= 0.97f;
      break;
    default:
      assert(0);
    }
    vel *= 0.98f;
    size += (target[targetIdx].size - size) * 0.025f;
    pos += vel;
    int vn = cast(int) ((target[targetIdx].n - n) * 0.2f);
    if (vn < 10 && vn > -10)
      n = target[targetIdx].n;
    else
      n += vn;
    switch (target[targetIdx].flyingTo) {
    case FlyingToType.RIGHT:
      if (pos.x > tp.x) {
        pos.x = tp.x;
        vel.x *= -0.05f;
      }
      break;
    case FlyingToType.BOTTOM:
      if (pos.y < tp.y) {
        pos.y = tp.y;
        vel.y *= -0.05f;
      }
      break;
    default:
      assert(0);
    }
    cnt--;
    if (cnt < 0)
      gotoNextTarget();
  }

  public override void draw(mat4 view) {
    Letter.setColor(vec4(alpha, alpha, alpha, 1));
    switch (type) {
    case IndicatorType.SCORE:
      Letter.drawNumSign(view, n, pos.x, pos.y, size, Letter.LINE_COLOR);
      break;
    case IndicatorType.MULTIPLIER:
      Letter.drawNumSign(view, n, pos.x, pos.y, size, Letter.LINE_COLOR, 33 /* x */, Letter.POLY_COLOR);
      break;
    default:
      assert(0);
    }
  }
}

public class NumIndicatorPool: ActorPool!(NumIndicator) {
  public this(int n, Object[] args) {
    super(n, args);
  }
}
