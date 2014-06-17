/*
 * $Id: twinstick.d,v 1.5 2006/03/18 02:42:09 kenta Exp $
 *
 * Copyright 2005 Kenta Cho. Some rights reserved.
 */
module abagames.util.sdl.accelerometer;

private import std.stream;
private import std.math;
private import derelict.sdl2.sdl;
private import gl3n.linalg;
private import abagames.util.sdl.input;
private import abagames.util.sdl.recordableinput;

/**
 * Accelerometer input.
 */
public class Accelerometer: Input {
 private:
  SDL_Joystick *stick = null;
  const int JOYSTICK_AXIS_MAX = 32768;
  AccelerometerState state;

  public this() {
    state = new AccelerometerState;
  }

  public SDL_Joystick* openJoystick(SDL_Joystick *st = null) {
    if (st == null) {
      if (SDL_InitSubSystem(SDL_INIT_JOYSTICK) < 0)
        return null;
      stick = SDL_JoystickOpen(0);
    } else if (st !is null) {
      stick = st;
    }
    return stick;
  }

  public void handleEvent(SDL_Event *event) {
  }

  public AccelerometerState getState() {
    state.tilt.x = adjustAxis(SDL_JoystickGetAxis(stick, 0));
    state.tilt.y = -adjustAxis(SDL_JoystickGetAxis(stick, 1));
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

  public AccelerometerState getNullState() {
    state.clear();
    return state;
  }
}

public class AccelerometerState {
 public:
  vec2 tilt;
 private:

  invariant() {
    assert(tilt.x >= -1 && tilt.x <= 1);
    assert(tilt.y >= -1 && tilt.y <= 1);
  }

  public static AccelerometerState newInstance() {
    return new AccelerometerState;
  }

  public static AccelerometerState newInstance(AccelerometerState s) {
    return new AccelerometerState(s);
  }

  public this() {
    tilt = vec2(0);
  }

  public this(AccelerometerState s) {
    this();
    set(s);
  }

  public void set(AccelerometerState s) {
    tilt.x = s.tilt.x;
    tilt.y = s.tilt.y;
  }

  public void clear() {
    tilt.x = tilt.y = 0;
  }

  public void read(File fd) {
    fd.read(tilt.x);
    fd.read(tilt.y);
  }

  public void write(File fd) {
    fd.write(tilt.x);
    fd.write(tilt.y);
  }

  public bool equals(AccelerometerState s) {
    return (tilt.x == s.tilt.x && tilt.y == s.tilt.y);
  }
}

public class RecordableAccelerometer: Accelerometer {
  mixin RecordableInput!(AccelerometerState);
 private:

  alias Accelerometer.getState getState;
  public AccelerometerState getState(bool doRecord) {
    AccelerometerState s = super.getState();
    if (doRecord)
      record(s);
    return s;
  }
}
