/*
 * $Id: accelerometerandtouch.d,v 1.1 2005/09/11 00:47:40 kenta Exp $
 *
 * Copyright 2005 Kenta Cho. Some rights reserved.
 */
module abagames.gr.accelerometerandtouch;

private import std.string;
private import std.stream;
private import derelict.sdl2.sdl;
private import abagames.util.sdl.input;
private import abagames.util.sdl.recordableinput;
private import abagames.util.sdl.accelerometer;
private import abagames.util.sdl.touch;

/**
 * Record accelerometer and touch input.
 */
public class AccelerometerAndTouchState {
 public:
  AccelerometerState accelerometerState;
  TouchState touchState;
 private:

  public static AccelerometerAndTouchState newInstance() {
    return new AccelerometerAndTouchState;
  }

  public static AccelerometerAndTouchState newInstance(AccelerometerAndTouchState s) {
    return new AccelerometerAndTouchState(s);
  }

  public this() {
    accelerometerState = new AccelerometerState;
    touchState = new TouchState;
  }

  public this(AccelerometerAndTouchState s) {
    this();
    set(s);
  }

  public void set(AccelerometerAndTouchState s) {
    accelerometerState.set(s.accelerometerState);
    touchState.set(s.touchState);
  }

  public void clear() {
    accelerometerState.clear();
    touchState.clear();
  }

  public void read(File fd) {
    accelerometerState.read(fd);
    touchState.read(fd);
  }

  public void write(File fd) {
    accelerometerState.write(fd);
    touchState.write(fd);
  }

  public bool equals(AccelerometerAndTouchState s) {
    if (accelerometerState.equals(s.accelerometerState) && touchState.equals(s.touchState))
      return true;
    else
      return false;
  }
}

public class RecordableAccelerometerAndTouch {
  mixin RecordableInput!(AccelerometerAndTouchState);
 private:
  AccelerometerAndTouchState state;
  Accelerometer accelerometer;
  Touch touch;

  public this(Accelerometer accelerometer, Touch touch) {
    this.accelerometer = accelerometer;
    this.touch = touch;
    state = new AccelerometerAndTouchState;
  }

  public AccelerometerAndTouchState getState(bool doRecord = true) {
    RecordableAccelerometer ra = cast(RecordableAccelerometer) accelerometer;
    if (ra)
      state.accelerometerState = ra.getState(false);
    else
      state.accelerometerState = accelerometer.getState();
    RecordableTouch rt = cast(RecordableTouch) touch;
    if (rt)
      state.touchState = rt.getState(false);
    else
      state.touchState = touch.getState();
    if (doRecord)
      record(state);
    return state;
  }
}
