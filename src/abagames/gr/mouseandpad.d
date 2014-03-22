/*
 * $Id: mouseandpad.d,v 1.1 2005/09/11 00:47:40 kenta Exp $
 *
 * Copyright 2005 Kenta Cho. Some rights reserved.
 */
module abagames.gr.mouseandpad;

private import std.string;
private import std.stream;
private import SDL;
private import abagames.util.sdl.input;
private import abagames.util.sdl.recordableinput;
private import abagames.util.sdl.mouse;
private import abagames.util.sdl.pad;

/**
 * Record mouse and pad input.
 */
public class MouseAndPadState {
 public:
  MouseState mouseState;
  PadState padState;
 private:

  public static MouseAndPadState newInstance() {
    return new MouseAndPadState;
  }

  public static MouseAndPadState newInstance(MouseAndPadState s) {
    return new MouseAndPadState(s);
  }

  public this() {
    mouseState = new MouseState;
    padState = new PadState;
  }

  public this(MouseAndPadState s) {
    this();
    set(s);
  }

  public void set(MouseAndPadState s) {
    mouseState.set(s.mouseState);
    padState.set(s.padState);
  }

  public void clear() {
    mouseState.clear();
    padState.clear();
  }

  public void read(File fd) {
    mouseState.read(fd);
    padState.read(fd);
  }

  public void write(File fd) {
    mouseState.write(fd);
    padState.write(fd);
  }

  public bool equals(MouseAndPadState s) {
    if (mouseState.equals(s.mouseState) && padState.equals(s.padState))
      return true;
    else
      return false;
  }
}

public class RecordableMouseAndPad {
  mixin RecordableInput!(MouseAndPadState);
 private:
  MouseAndPadState state;
  Mouse mouse;
  Pad pad;

  public this(Mouse mouse, Pad pad) {
    this.mouse = mouse;
    this.pad = pad;
    state = new MouseAndPadState;
  }

  public MouseAndPadState getState(bool doRecord = true) {
    RecordableMouse rm = cast(RecordableMouse) mouse;
    if (rm)
      state.mouseState = rm.getState(false);
    else
      state.mouseState = mouse.getState();
    RecordablePad rp = cast(RecordablePad) pad;
    if (rp)
      state.padState = rp.getState(false);
    else
      state.padState = pad.getState();
    if (doRecord)
      record(state);
    return state;
  }
}
