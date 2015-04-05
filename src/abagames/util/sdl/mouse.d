/*
 * $Id: mouse.d,v 1.1 2005/09/11 00:47:41 kenta Exp $
 *
 * Copyright 2005 Kenta Cho. Some rights reserved.
 */
module abagames.util.sdl.mouse;

private import std.string;
private import std.stream;
private import gl3n.linalg;
private import derelict.sdl2.sdl;
private import abagames.util.sdl.input;
private import abagames.util.sdl.recordableinput;
private import abagames.util.sdl.screen;

/**
 * Mouse input.
 */
public class Mouse: Input {
 public:
  //float accel = 1;
 private:
  SizableScreen screen;
  MouseState state;

  public this() {
    state = new MouseState;
  }

  public void init(SizableScreen screen) {
    this.screen = screen;
    /*if (screen.windowMode) {
      SDL_GetMouseState(&state.pos.x, &state.pos.y);
    } else {
      state.pos.x = screen.width / 2;
      state.pos.y = screen.height / 2;
    }*/
  }

  public void handleEvent(SDL_Event *event) {
  }

  public MouseState getState() {
    int mx, my;
    int btn = SDL_GetMouseState(&mx, &my);
    state.pos.x = mx;
    state.pos.y = my;
    /*int mvx, mvy;
    int btn = SDL_GetRelativeMouseState(&mvx, &mvy);
    state.pos.x += mvx * accel;
    state.pos.y += mvy * accel;
    state.pos.x = bound(state.pos.x, 0, screen.width - 1);
    state.pos.y = bound(state.pos.y, 0, screen.height - 1);*/
    state.button = 0;
    if (btn & SDL_BUTTON(1))
      state.button |= MouseState.Button.LEFT;
    if (btn & SDL_BUTTON(3))
      state.button |= MouseState.Button.RIGHT;
    adjustPos(state);
    return state;
  }

  protected void adjustPos(MouseState ms) {}

  public MouseState getNullState() {
    state.clear();
    return state;
  }
}

public class MouseState {
 public:
  static enum Button {
    LEFT = 1, RIGHT = 2,
  };
  vec2 pos;
  int button;
 private:

  public static MouseState newInstance() {
    return new MouseState;
  }

  public static MouseState newInstance(MouseState s) {
    return new MouseState(s);
  }

  public this() {
  }

  public this(MouseState s) {
    this();
    set(s);
  }

  public void set(MouseState s) {
    pos = s.pos;
    button = s.button;
  }

  public void clear() {
    button = 0;
  }

  public void read(File fd) {
    fd.read(pos.x);
    fd.read(pos.y);
    fd.read(button);
  }

  public void write(File fd) {
    fd.write(pos.x);
    fd.write(pos.y);
    fd.write(button);
  }

  public bool equals(MouseState s) {
    if (pos == s.pos && button == s.button)
      return true;
    else
      return false;
  }
}

public class RecordableMouse: Mouse {
  mixin RecordableInput!(MouseState);
 private:

  alias Mouse.getState getState;
  public MouseState getState(bool doRecord) {
    MouseState s = super.getState();
    if (doRecord)
      record(s);
    return s;
  }
}
