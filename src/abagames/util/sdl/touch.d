/*
 * $Id: touch.d,v 1.5 2006/03/18 02:42:09 kenta Exp $
 *
 * Copyright 2005 Kenta Cho. Some rights reserved.
 */
module abagames.util.sdl.touch;

private import std.stream;
private import derelict.sdl2.sdl;
private import abagames.util.vector;
private import abagames.util.sdl.input;
private import abagames.util.sdl.recordableinput;

/**
 * Touch input.
 */
public class Touch: Input {
 private:
  TouchState state;

  public this() {
    state = new TouchState;
  }

  public void handleEvent(SDL_Event *event) {
    // Track fingers. We want the only use two of them.
    if (event.type == SDL_FINGERDOWN) {
      for (int i = 0; i < TouchState.MAXFINGERS; ++i) {
        if (!state.fingers[i].active) {
          state.fingers[i].active = true;
          state.fingers[i].id = event.tfinger.fingerId;
          state.fingers[i].position.x = event.tfinger.x;
          state.fingers[i].position.y = event.tfinger.y;
        }
      }
    } else if (event.type == SDL_FINGERUP) {
      for (int i = 0; i < TouchState.MAXFINGERS; ++i) {
        if (state.fingers[i].id == event.tfinger.fingerId) {
          state.fingers[i].active = false;
        }
      }
    } else if (event.type == SDL_FINGERMOTION) {
      for (int i = 0; i < TouchState.MAXFINGERS; ++i) {
        if (state.fingers[i].id == event.tfinger.fingerId) {
          state.fingers[i].position.x = event.tfinger.x;
          state.fingers[i].position.y = event.tfinger.y;
        }
      }
    }
  }

  public TouchState getState() {
    return state;
  }

  public TouchState getNullState() {
    state.clear();
    return state;
  }
}

public class FingerState {
 public:
  Vector position;
  int active;
  long id;
 private:

  invariant() {
    assert(position.x >= 0 && position.x <= 1);
    assert(position.y >= 0 && position.y <= 1);
  }

  public void clear() {
    position.x = position.y = 0;
    active = false;
  }

  public void read(File fd) {
    fd.read(active);
    if (active) {
      fd.read(position.x);
      fd.read(position.y);
      fd.read(id);
    }
  }

  public void write(File fd) {
    fd.write(active);
    if (active) {
      fd.write(position.x);
      fd.write(position.y);
      fd.write(id);
    }
  }

  public bool equals(FingerState s) {
    return (position.x == s.position.x && position.y == s.position.y &&
            active == s.active);
  }
}

public interface TouchRegion {
  public bool contains(Vector position);
  public Vector center();
}

public class InvertedTouchRegion {
 private:
  TouchRegion ignore;

  public this(TouchRegion ignore) {
    this.ignore = ignore;
  }

  public bool contains(Vector position) {
    return !ignore.contains(position);
  }

  public Vector center() {
    return ignore.center();
  }
}

public class CircularTouchRegion: TouchRegion {
 private:
  Vector center_;
  float radius;

  public this(Vector center_, float radius) {
    this.center_ = new Vector(center_);
    this.radius = radius;
  }

  public bool contains(Vector position) {
    return center_.dist(position) <= radius;
  }

  public Vector center() {
    return center_;
  }
}

public class EntireScreenRegion: TouchRegion {
  public bool contains(Vector position) {
    return true;
  }

  public Vector center() {
    return new Vector(0.5, 0.5);
  }
}

public class TouchState {
 public:
  static const int MAXFINGERS = 10;
  FingerState fingers[MAXFINGERS];
 private:

  public static TouchState newInstance() {
    return new TouchState;
  }

  public static TouchState newInstance(TouchState s) {
    return new TouchState(s);
  }

  public this() {
    fingers = new FingerState[MAXFINGERS];
  }

  public this(TouchState s) {
    this();
    set(s);
  }

  public void set(TouchState s) {
    fingers = s.fingers;
  }

  public void clear() {
    foreach (ref FingerState f; fingers) {
      f.clear();
    }
  }

  public void read(File fd) {
    foreach (ref FingerState f; fingers) {
      f.read(fd);
    }
  }

  public void write(File fd) {
    foreach (ref FingerState f; fingers) {
      f.write(fd);
    }
  }

  public bool equals(TouchState s) {
    for (int i = 0; i < MAXFINGERS; i++) {
      if (!fingers[i].equals(fingers[i])) {
        return false;
      }
    }
    return true;
  }

  // Utility methods
  public Vector getPrimaryTouch(TouchRegion region) {
    foreach (FingerState f; fingers) {
      if (f.active && region.contains(f.position)) {
        return f.position;
      }
    }
    return new Vector;
  }

  public Vector getSecondaryTouch(TouchRegion region, TouchRegion[] ignores, uint ignoreCount) {
    foreach (FingerState f; fingers) {
      if (f.active && region.contains(f.position)) {
        if (ignoreCount) {
          foreach (TouchRegion ignore; ignores) {
            if (ignore.contains(f.position)) {
              --ignoreCount;
              continue;
            }
          }
        }

        return f.position;
      }
    }
    return new Vector;
  }
}

public class RecordableTouch: Touch {
  mixin RecordableInput!(TouchState);
 private:

  alias Touch.getState getState;
  public TouchState getState(bool doRecord) {
    TouchState s = super.getState();
    if (doRecord)
      record(s);
    return s;
  }
}
