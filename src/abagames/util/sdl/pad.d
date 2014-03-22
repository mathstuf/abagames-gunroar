/*
 * $Id: pad.d,v 1.2 2005/07/03 07:05:23 kenta Exp $
 *
 * Copyright 2004 Kenta Cho. Some rights reserved.
 */
module abagames.util.sdl.pad;

private import std.string;
private import std.stream;
private import SDL;
private import abagames.util.sdl.input;
private import abagames.util.sdl.recordableinput;

/**
 * Joystick and keyboard input.
 */
public class Pad: Input {
 public:
  Uint8 *keys;
  bool buttonReversed = false;
 private:
  SDL_Joystick *stick = null;
  const int JOYSTICK_AXIS = 16384;
  PadState state;

  public this() {
    state = new PadState;
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

  public PadState getState() {
    int x = 0, y = 0;
    state.dir = 0;
    if (stick) {
      x = SDL_JoystickGetAxis(stick, 0);
      y = SDL_JoystickGetAxis(stick, 1);
    }
    if (keys[SDLK_RIGHT] == SDL_PRESSED || keys[SDLK_KP6] == SDL_PRESSED || 
        keys[SDLK_d] == SDL_PRESSED || keys[SDLK_l] == SDL_PRESSED ||
        x > JOYSTICK_AXIS)
      state.dir |= PadState.Dir.RIGHT;
    if (keys[SDLK_LEFT] == SDL_PRESSED || keys[SDLK_KP4] == SDL_PRESSED ||
        keys[SDLK_a] == SDL_PRESSED || keys[SDLK_j] == SDL_PRESSED ||
        x < -JOYSTICK_AXIS)
      state.dir |= PadState.Dir.LEFT;
    if (keys[SDLK_DOWN] == SDL_PRESSED || keys[SDLK_KP2] == SDL_PRESSED ||
        keys[SDLK_s] == SDL_PRESSED || keys[SDLK_k] == SDL_PRESSED ||
        y > JOYSTICK_AXIS)
      state.dir |= PadState.Dir.DOWN;
    if (keys[SDLK_UP] == SDL_PRESSED ||  keys[SDLK_KP8] == SDL_PRESSED ||
        keys[SDLK_w] == SDL_PRESSED || keys[SDLK_i] == SDL_PRESSED ||
        y < -JOYSTICK_AXIS)
      state.dir |= PadState.Dir.UP;
    state.button = 0;
    int btn1 = 0, btn2 = 0;
    float leftTrigger = 0, rightTrigger = 0;
    if (stick) {
      btn1 = SDL_JoystickGetButton(stick, 0) + SDL_JoystickGetButton(stick, 3) +
             SDL_JoystickGetButton(stick, 4) + SDL_JoystickGetButton(stick, 7) +
             SDL_JoystickGetButton(stick, 8) + SDL_JoystickGetButton(stick, 11);
      btn2 = SDL_JoystickGetButton(stick, 1) + SDL_JoystickGetButton(stick, 2) +
             SDL_JoystickGetButton(stick, 5) + SDL_JoystickGetButton(stick, 6) +
             SDL_JoystickGetButton(stick, 9) + SDL_JoystickGetButton(stick, 10);
    }
    if (keys[SDLK_z] == SDL_PRESSED || keys[SDLK_PERIOD] == SDL_PRESSED ||
        keys[SDLK_LCTRL] == SDL_PRESSED || keys[SDLK_RCTRL] == SDL_PRESSED || 
        btn1) {
      if (!buttonReversed)
        state.button |= PadState.Button.A;
      else
        state.button |= PadState.Button.B;
    }
    if (keys[SDLK_x] == SDL_PRESSED || keys[SDLK_SLASH] == SDL_PRESSED ||
        keys[SDLK_LALT] == SDL_PRESSED || keys[SDLK_RALT] == SDL_PRESSED ||
        keys[SDLK_LSHIFT] == SDL_PRESSED || keys[SDLK_RSHIFT] == SDL_PRESSED ||
        keys[SDLK_RETURN] == SDL_PRESSED ||
        btn2) {
      if (!buttonReversed)
        state.button |= PadState.Button.B;
      else
        state.button |= PadState.Button.A;
    }
    return state;
  }

  public PadState getNullState() {
    state.clear();
    return state;
  }

}

public class PadState {
 public:
  static enum Dir {
    UP = 1, DOWN = 2, LEFT = 4, RIGHT = 8,
  };
  static enum Button {
    A = 16, B = 32, ANY = 48,
  };
  int dir, button;
 private:

  public static PadState newInstance() {
    return new PadState;
  }

  public static PadState newInstance(PadState s) {
    return new PadState(s);
  }

  public this() {
  }

  public this(PadState s) {
    this();
    set(s);
  }

  public void set(PadState s) {
    dir = s.dir;
    button = s.button;
  }

  public void clear() {
    dir = button = 0;
  }

  public void read(File fd) {
    int s;
    fd.read(s);
    dir = s & (Dir.UP | Dir.DOWN | Dir.LEFT | Dir.RIGHT);
    button = s & Button.ANY;
  }

  public void write(File fd) {
    int s = dir | button;
    fd.write(s);
  }

  public bool equals(PadState s) {
    if (dir == s.dir && button == s.button)
      return true;
    else
      return false;
  }
}

public class RecordablePad: Pad {
  mixin RecordableInput!(PadState);
 private:

  public PadState getState(bool doRecord = true) {
    PadState s = super.getState();
    if (doRecord)
      record(s);
    return s;
  }
}
