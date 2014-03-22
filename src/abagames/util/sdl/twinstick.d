/*
 * $Id: twinstick.d,v 1.5 2006/03/18 02:42:09 kenta Exp $
 *
 * Copyright 2005 Kenta Cho. Some rights reserved.
 */
module abagames.util.sdl.twinstick;

private import std.string;
private import std.stream;
private import std.math;
private import SDL;
private import abagames.util.vector;
private import abagames.util.sdl.input;
private import abagames.util.sdl.recordableinput;

/**
 * Twinstick input.
 */
public class TwinStick: Input {
 public:
  float rotate = 0;
  float reverse = 1;
  Uint8 *keys;
  bool enableAxis5 = false;
 private:
  SDL_Joystick *stick = null;
  const int JOYSTICK_AXIS_MAX = 32768;
  TwinStickState state;

  public this() {
    state = new TwinStickState;
  }

  public SDL_Joystick* openJoystick(SDL_Joystick *st = null) {
    if (st == null) {
      if (SDL_InitSubSystem(SDL_INIT_JOYSTICK) < 0)
        return null;
      stick = SDL_JoystickOpen(0);
    } else {
      stick = st;
    }
    return stick;
  }

  public void handleEvent(SDL_Event *event) {
    keys = SDL_GetKeyState(null);
  }

  public TwinStickState getState() {
    if (stick) {
      state.left.x = adjustAxis(SDL_JoystickGetAxis(stick, 0));
      state.left.y = -adjustAxis(SDL_JoystickGetAxis(stick, 1));
      int rx = 0;
      if (enableAxis5)
        rx = SDL_JoystickGetAxis(stick, 4);
      else
        rx = SDL_JoystickGetAxis(stick, 2);
      int ry = SDL_JoystickGetAxis(stick, 3);
      if (rx == 0 && ry == 0) {
        state.right.x = state.right.y = 0;
      } else {
        ry = -ry;
        float rd = atan2(rx, ry) * reverse + rotate;
        assert(rd <>= 0);
        float rl = sqrt(cast(float) rx * rx + cast(float) ry * ry);
        assert(rl <>= 0);
        state.right.x = adjustAxis(cast(int) (sin(rd) * rl));
        state.right.y = adjustAxis(cast(int) (cos(rd) * rl));
      }
    } else {
      state.left.x = state.left.y = state.right.x = state.right.y = 0;
    }
    if (keys[SDLK_d] == SDL_PRESSED)
      state.left.x = 1;
    if (keys[SDLK_l] == SDL_PRESSED)
      state.right.x = 1;
    if (keys[SDLK_a] == SDL_PRESSED)
      state.left.x = -1;
    if (keys[SDLK_j] == SDL_PRESSED)
      state.right.x = -1;
    if (keys[SDLK_s] == SDL_PRESSED)
      state.left.y = -1;
    if (keys[SDLK_k] == SDL_PRESSED)
      state.right.y = -1;
    if (keys[SDLK_w] == SDL_PRESSED)
      state.left.y = 1;
    if (keys[SDLK_i] == SDL_PRESSED)
      state.right.y = 1;
    return state;
  }

  public float adjustAxis(int v) {
    float a = 0;
    if (v > JOYSTICK_AXIS_MAX / 3) {
      a = cast(float) (v - JOYSTICK_AXIS_MAX / 3) /
        (JOYSTICK_AXIS_MAX - JOYSTICK_AXIS_MAX / 3);
      if (a > 1)
        a = 1;
    } else if (v < -(JOYSTICK_AXIS_MAX / 3)) {
      a = cast(float) (v + JOYSTICK_AXIS_MAX / 3) /
        (JOYSTICK_AXIS_MAX - JOYSTICK_AXIS_MAX / 3);
      if (a < -1)
        a = -1;
    }
    return a;
  }

  public TwinStickState getNullState() {
    state.clear();
    return state;
  }
}

public class TwinStickState {
 public:
  Vector left, right;
 private:

  invariant {
    assert(left.x >= -1 && left.x <= 1);
    assert(left.y >= -1 && left.y <= 1);
    assert(right.x >= -1 && right.x <= 1);
    assert(right.y >= -1 && right.y <= 1);
  }

  public static TwinStickState newInstance() {
    return new TwinStickState;
  }

  public static TwinStickState newInstance(TwinStickState s) {
    return new TwinStickState(s);
  }

  public this() {
    left = new Vector;
    right = new Vector;
  }

  public this(TwinStickState s) {
    this();
    set(s);
  }

  public void set(TwinStickState s) {
    left.x = s.left.x;
    left.y = s.left.y;
    right.x = s.right.x;
    right.y = s.right.y;
  }

  public void clear() {
    left.x = left.y = right.x = right.y = 0;
  }

  public void read(File fd) {
    fd.read(left.x);
    fd.read(left.y);
    fd.read(right.x);
    fd.read(right.y);
  }

  public void write(File fd) {
    fd.write(left.x);
    fd.write(left.y);
    fd.write(right.x);
    fd.write(right.y);
  }

  public bool equals(TwinStickState s) {
    return (left.x == s.left.x && left.y == s.left.y &&
            right.x == s.right.x && right.y == s.right.y);
  }
}

public class RecordableTwinStick: TwinStick {
  mixin RecordableInput!(TwinStickState);
 private:

  public TwinStickState getState(bool doRecord = true) {
    TwinStickState s = super.getState();
    if (doRecord)
      record(s);
    return s;
  }
}
