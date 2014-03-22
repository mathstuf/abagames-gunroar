/*
 * $Id: sdlexception.d,v 1.1.1.1 2005/06/18 00:46:00 kenta Exp $
 *
 * Copyright 2004 Kenta Cho. Some rights reserved.
 */
module abagames.util.sdl.sdlexception;

/**
 * SDL initialize failed.
 */
public class SDLInitFailedException: Exception {
  public this(char[] msg) {
    super(msg);
  }
}

/**
 * SDL general exception.
 */
public class SDLException: Exception {
  public this(char[] msg) {
    super(msg);
  }
}
