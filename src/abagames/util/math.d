/*
 * $Id: math.d,v 1.1.1.1 2005/06/18 00:46:00 kenta Exp $
 *
 * Copyright 2005 Kenta Cho. Some rights reserved.
 */
module abagames.util.math;

private import std.math;
private import gl3n.linalg;

/**
 * Math utility methods.
 */
public class Math {
 private:

  public static void normalizeDeg(ref float d) {
    if (d < -PI)
      d = PI * 2 - (-d % (PI * 2));
    d = (d + PI) % (PI * 2) - PI;
  }

  public static void normalizeDeg360(ref float d) {
    if (d < -180)
      d = 360 - (-d % 360);
    d = (d + 180) % 360 - 180;
  }
}

real fastdist(vec2 v1, vec2 v2 = vec2(0)) {
  float ax = fabs(v1.x - v2.x);
  float ay = fabs(v1.y - v2.y);
  if (ax > ay)
    return ax + ay / 2;
  else
    return ay + ax / 2;
}

bool contains(vec2 v1, float x, float y, float r = 1) {
  if (x >= -v1.x * r && x <= v1.x * r && y >= -v1.y * r && y <= v1.y * r)
    return true;
  else
    return false;
}

bool contains(vec2 v1, vec2 v2, float r = 1) {
  return contains(v1, v2.x, v2.y, r);
}
