/*
 * $Id: screen.d,v 1.1.1.1 2005/06/18 00:46:00 kenta Exp $
 *
 * Copyright 2005 Kenta Cho. Some rights reserved.
 */
module abagames.util.sdl.screen;

/**
 * SDL screen handler interface.
 */
public interface Screen {
  public void initSDL();
  public void closeSDL();
  public void flip();
  public void clear();
}

public interface SizableScreen {
  public bool windowMode();
  public int width();
  public int height();
}
