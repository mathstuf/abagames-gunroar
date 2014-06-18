/*
 * $Id: crystal.d,v 1.2 2005/07/17 11:02:45 kenta Exp $
 *
 * Copyright 2005 Kenta Cho. Some rights reserved.
 */
module abagames.gr.crystal;

private import std.math;
private import derelict.opengl3.gl;
private import gl3n.linalg;
private import abagames.util.actor;
private import abagames.util.math;
private import abagames.gr.ship;
private import abagames.gr.screen;
private import abagames.gr.shape;

/**
 * Bonus crystals.
 */
public class Crystal: Actor {
 private:
  static const int COUNT = 60;
  static const int PULLIN_COUNT = cast(int) (COUNT * 0.8f);
  static CrystalShape _shape;
  Ship ship;
  vec2 pos;
  vec2 vel;
  int cnt;

  invariant() {
    assert(pos.x < 15 && pos.x > -15);
    assert(pos.y < 30 && pos.y > -30);
    assert(vel.x < 10 && vel.x > -10);
    assert(vel.y < 10 && vel.y > -10);
  }

  public static void init() {
    _shape = new CrystalShape;
  }

  public static void close() {
    _shape.close();
  }

  public this() {
    pos = vec2(0);
    vel = vec2(0);
  }

  public override void init(Object[] args) {
    ship = cast(Ship) args[0];
  }

  public void set(vec2 p) {
    pos.x = p.x;
    pos.y = p.y;
    cnt = COUNT;
    vel.x = 0;
    vel.y = 0.1f;
    exists = true;
  }

  public override void move() {
    cnt--;
    float dist = pos.fastdist(ship.midstPos);
    if (dist < 0.1f)
      dist = 0.1f;
    if (cnt < PULLIN_COUNT) {
      vel.x += (ship.midstPos.x - pos.x) / dist * 0.07f;
      vel.y += (ship.midstPos.y - pos.y) / dist * 0.07f;
      if (cnt < 0 || dist < 2) {
        exists = false;
        return;
      }
    }
    vel *= 0.95f;
    pos += vel;
  }

  public override void draw(mat4 view) {
    float r = 0.25f;
    float d = cnt * 0.1f;
    if (cnt > PULLIN_COUNT)
      r *= (cast(float) (COUNT - cnt)) / (COUNT - PULLIN_COUNT);
    for (int i = 0; i < 4; i++) {
      mat4 model = mat4.identity;
      model.translate(pos.x + sin(d) * r, pos.y + cos(d) * r, 0);
      _shape.setModelMatrix(model);

      glPushMatrix();
      glTranslatef(pos.x + sin(d) * r, pos.y + cos(d) * r, 0);
      _shape.draw(view);
      glPopMatrix();
      d += PI / 2;
    }
  }
}

public class CrystalPool: ActorPool!(Crystal) {
  public this(int n, Object[] args) {
    super(n, args);
  }
}
