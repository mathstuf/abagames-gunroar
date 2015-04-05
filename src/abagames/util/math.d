/*
 * $Id: math.d,v 1.1.1.1 2005/06/18 00:46:00 kenta Exp $
 *
 * Copyright 2005 Kenta Cho. Some rights reserved.
 */
module abagames.util.math;

private import std.math;
private import gl3n.linalg;
private import abagames.util.rand;

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
  vec2 a = v1.absdiff(v2);
  if (a.x > a.y)
    return a.x + a.y / 2;
  else
    return a.y + a.x / 2;
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

vec2 absdiff(vec2 a, vec2 b) {
  return vec2(fabs(a.x - b.x), fabs(a.y - b.y));
}

vec2 sincos(float deg) {
  return vec2(sin(deg), cos(deg));
}

vec2 cosnsin(float deg) {
  return vec2(cos(deg), -sin(deg));
}

vec2 randvec(Rand rand, float f) {
  return vec2(rand.nextSignedFloat(f), rand.nextSignedFloat(f));
}

vec3 randvec3(Rand rand, float f) {
  return vec3(rand.nextSignedFloat(f), rand.nextSignedFloat(f), rand.nextSignedFloat(f));
}

vec2 randvecp(Rand rand, float f) {
  return vec2(rand.nextFloat(f), rand.nextFloat(f));
}

float angle(vec2 v) {
  return atan2(v.x, v.y);
}

vec2i toint(vec2 v) {
  return vec2i(cast(int) v.x, cast(int) v.y);
}

T bound(T)(const(T) v, const(T) min, const(T) max = T.max) {
  if (v < min)
    return min;
  if (v > max)
    return max;
  return v;
}

bool inbound(T)(const(T) v, const(T) min, const(T) max) {
  if (v < min)
    return false;
  if (v > max)
    return false;
  return true;
}

T boundr(T)(const(T) v, const(T) size) {
  if (v < 0)
    return v + size;
  if (v >= size)
    return v - size;
  return v;
}
