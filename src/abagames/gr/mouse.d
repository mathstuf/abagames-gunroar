/*
 * $Id: mouse.d,v 1.1 2005/09/11 00:47:40 kenta Exp $
 *
 * Copyright 2005 Kenta Cho. Some rights reserved.
 */
module abagames.gr.mouse;

private import abagames.util.sdl.mouse;
private import abagames.util.sdl.screen;

/**
 * Mouse input.
 */
public class RecordableMouse: abagames.util.sdl.mouse.RecordableMouse {
 private:
  static const float MOUSE_SCREEN_MAPPING_RATIO_X = 26.0f;
  static const float MOUSE_SCREEN_MAPPING_RATIO_Y = 19.5f;
  SizableScreen screen;

  public this(SizableScreen screen) {
    super();
    this.screen = screen;
  }

  protected override void adjustPos(MouseState ms) {
    ms.x =  (ms.x - screen.width  / 2) * MOUSE_SCREEN_MAPPING_RATIO_X / screen.width;
    ms.y = -(ms.y - screen.height / 2) * MOUSE_SCREEN_MAPPING_RATIO_Y / screen.height;
  }
}
