/*
 * $Id: touch.d,v 1.5 2006/03/18 02:42:09 kenta Exp $
 *
 * Copyright 2005 Kenta Cho. Some rights reserved.
 */
module abagames.util.sdl.touch;

private import std.stream;
private import derelict.sdl2.sdl;
private import gl3n.linalg;
private import abagames.util.sdl.input;
private import abagames.util.sdl.recordableinput;
private import abagames.util.math;

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

          state.fingers[i].update();
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

          state.fingers[i].update();
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

  public static float touchRadius() {
    int w, h;
    SDL_Window* window = SDL_GL_GetCurrentWindow();
    SDL_GetWindowSize(window, &w, &h);
    // TODO: Get the physical size of the window. Touch regions should
    // be...reasonable in size.
    return 0.05;
  }
}

public class FingerState {
 public:
  vec2 position;
  TouchVector normPosition;
  int active;
  long id;
 private:

  invariant() {
    assert(position.x >= 0 && position.x <= 1);
    assert(position.y >= 0 && position.y <= 1);
  }

  public this() {
    position = vec2(0);
    active = false;
  }

  public void clear() {
    position = vec2(0);
    active = false;
  }

  public void read(File fd) {
    fd.read(active);
    if (active) {
      fd.read(position.x);
      fd.read(position.y);
      fd.read(id);

      update();
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
    return (position == s.position && active == s.active);
  }

  public void update() {
    normPosition = new TouchVector(position);
  }
}

public interface TouchRegion {
  public bool contains(TouchVector position);
  public vec2 center();
}

public class InvertedTouchRegion {
 private:
  TouchRegion ignore;

  public this(TouchRegion ignore) {
    this.ignore = ignore;
  }

  public bool contains(TouchVector position) {
    return !ignore.contains(position);
  }

  public vec2 center() {
    return ignore.center();
  }
}

public class CircularTouchRegion: TouchRegion {
 private:
  TouchVector center_;
  float radius;

  public this(vec2 center_, float radius) {
    this.center_ = new TouchVector(center_);
    this.radius = radius;
  }

  public bool contains(TouchVector position) {
    return center_.vec.fastdist(position.vec) <= radius;
  }

  public vec2 center() {
    return center_.vec;
  }
}

public class EntireScreenRegion: TouchRegion {
  public bool contains(TouchVector position) {
    return true;
  }

  public vec2 center() {
    return vec2(0.5, 0.5);
  }
}

// A normalized vector which scales the 'y' axis so that it uses the same units
// (in physical space) as the 'x' axis. This is required since SDL uses a 0..1
// scale for each axis and testing whether a region is used should be based on
// what the user actually sees.
public class TouchVector {
 public:
   vec2 vec;
 private:
  static float aspect = 0.0;

  static void init() {
    // Set the aspect ratio.
    // TODO: Get DPI involved here as well.
    int w, h;
    SDL_Window* window = SDL_GL_GetCurrentWindow();
    SDL_GetWindowSize(window, &w, &h);
    aspect = cast(float) w / cast(float) h;
  }

  public this(float x, float y) {
    init();
    vec = vec2(x, y * aspect);
  }

  public this(vec2 input) {
    init();
    vec = vec2(input.x, input.y * aspect);
  }

  public vec2 touchNormalized() {
    return vec2(vec.x, vec.y / aspect);
  }
}

public class TouchState {
 public:
  static const int MAXFINGERS = 10;
  FingerState[MAXFINGERS] fingers;
 private:

  public static TouchState newInstance() {
    return new TouchState;
  }

  public static TouchState newInstance(TouchState s) {
    return new TouchState(s);
  }

  public this() {
    fingers = new FingerState[MAXFINGERS];
    foreach (ref FingerState f; fingers) {
      f = new FingerState();
    }
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
  public vec2 getPrimaryTouch(TouchRegion region) {
    foreach (FingerState f; fingers) {
      if (f.active && region.contains(f.normPosition)) {
        return f.position;
      }
    }
    return vec2(0);
  }

  public vec2 getSecondaryTouch(TouchRegion region, TouchRegion[] ignores, uint ignoreCount) {
    foreach (FingerState f; fingers) {
      if (f.active && region.contains(f.normPosition)) {
        if (ignoreCount) {
          foreach (TouchRegion ignore; ignores) {
            if (ignore.contains(f.normPosition)) {
              --ignoreCount;
              continue;
            }
          }
        }

        return f.position;
      }
    }
    return vec2(0);
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
