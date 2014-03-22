/*
 * $Id: math.d,v 1.1.1.1 2005/06/18 00:46:00 kenta Exp $
 *
 * Copyright 2005 Kenta Cho. Some rights reserved.
 */
module abagames.util.math;

private import std.math;

/**
 * Math utility methods.
 */
public class Math {
 private:

  public static void normalizeDeg(inout float d) {
    if (d < -PI)
      d = PI * 2 - (-d % (PI * 2));
    d = (d + PI) % (PI * 2) - PI;
  }

  public static void normalizeDeg360(inout float d) {
    if (d < -180)
      d = 360 - (-d % 360);
    d = (d + 180) % 360 - 180;
  }
}
