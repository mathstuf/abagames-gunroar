/*
 * $Id: mouse.d,v 1.1 2005/09/11 00:47:41 kenta Exp $
 *
 * Copyright 2005 Kenta Cho. Some rights reserved.
 */
module abagames.util.sdl.mouse;

private import std.string;
private import std.stream;
private import SDL;
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
      SDL_GetMouseState(&state.x, &state.y);
    } else {
      state.x = screen.width / 2;
      state.y = screen.height / 2;
    }*/
  }

  public void handleEvent(SDL_Event *event) {
  }

  public MouseState getState() {
    int mx, my;
    int btn = SDL_GetMouseState(&mx, &my);
    state.x = mx;
    state.y = my;
    /*int mvx, mvy;
    int btn = SDL_GetRelativeMouseState(&mvx, &mvy);
    state.x += mvx * accel;
    state.y += mvy * accel;
    if (state.x < 0)
      state.x = 0;
    else if (state.x >= screen.width)
      state.x = screen.width - 1;
    if (state.y < 0)
      state.y = 0;
    else if (state.y >= screen.height)
      state.x = screen.height - 1;*/
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
  float x, y;
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
    x = s.x;
    y = s.y;
    button = s.button;
  }

  public void clear() {
    button = 0;
  }

  public void read(File fd) {
    fd.read(x);
    fd.read(y);
    fd.read(button);
  }

  public void write(File fd) {
    fd.write(x);
    fd.write(y);
    fd.write(button);
  }

  public bool equals(MouseState s) {
    if (x == s.x && y == s.y && button == s.button)
      return true;
    else
      return false;
  }
}

public class RecordableMouse: Mouse {
  mixin RecordableInput!(MouseState);
 private:

  public MouseState getState(bool doRecord = true) {
    MouseState s = super.getState();
    if (doRecord)
      record(s);
    return s;
  }
}
