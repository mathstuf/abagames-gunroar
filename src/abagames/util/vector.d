/*
 * $Id: vector.d,v 1.1.1.1 2005/06/18 00:46:00 kenta Exp $
 *
 * Copyright 2004 Kenta Cho. Some rights reserved.
 */
module abagames.util.vector;

private import std.math;
private import std.string;

/**
 * Vector.
 */
public class Vector {
 public:
  float x, y;
 private:

  public this() {
    x = y = 0;
  }

  public this(float x, float y) {
    this.x = x;
    this.y = y;
  }

  public float opMul(Vector v) {
    return x * v.x + y * v.y;
  }

  public Vector getElement(Vector v) {
    Vector rsl;
    float ll = v * v;
    if (ll != 0) {
      float mag = this * v;
      rsl.x = mag * v.x / ll;
      rsl.y = mag * v.y / ll;
    } else {
      rsl.x = rsl.y = 0; 
    }
    return rsl;
  }

  public void opAddAssign(Vector v) {
    x += v.x;
    y += v.y;
  }

  public void opSubAssign(Vector v) {
    x -= v.x;
    y -= v.y;
  }

  public void opMulAssign(float a) {	
    x *= a;
    y *= a;
  }

  public void opDivAssign(float a) {	
    x /= a;
    y /= a;
  }

  public float checkSide(Vector pos1, Vector pos2) {
    float xo = pos2.x - pos1.x;
    float yo = pos2.y - pos1.y;
    if (xo == 0) {
      if (yo == 0)
	return 0;
      if (yo > 0)
	return x - pos1.x;
      else
	return pos1.x - x;
    } else if (yo == 0) {
      if (xo > 0)
	return pos1.y - y;
      else
	return y - pos1.y;
    } else {
      if (xo * yo > 0)
	return (x - pos1.x) / xo - (y - pos1.y) / yo;
      else
	return -(x - pos1.x) / xo + (y - pos1.y) / yo;
    }
  }

  public float checkSide(Vector pos1, Vector pos2, Vector ofs) {
    float xo = pos2.x - pos1.x;
    float yo = pos2.y - pos1.y;
    float mx = x + ofs.x;
    float my = y + ofs.y;
    if (xo == 0) {
      if (yo == 0)
	return 0;
      if (yo > 0)
	return mx - pos1.x;
      else
	return pos1.x - mx;
    } else if (yo == 0) {
      if (xo > 0)
	return pos1.y - my;
      else
	return my - pos1.y;
    } else {
      if (xo * yo > 0)
	return (mx - pos1.x) / xo - (my - pos1.y) / yo;
      else
	return -(mx - pos1.x) / xo + (my - pos1.y) / yo;
    }
  }

  public bool checkCross(Vector p, Vector p1, Vector p2, float width) {
    float a1x, a1y, a2x, a2y;
    if (x < p.x) {
      a1x = x - width; a2x = p.x + width;
    } else {
      a1x = p.x - width; a2x = x + width;
    }
    if (y < p.y) {
      a1y = y - width; a2y = p.y + width;
    } else {
      a1y = p.y - width; a2y = y + width;
    }
    float b1x, b1y, b2x, b2y;
    if (p2.y < p1.y) {
      b1y = p2.y - width; b2y = p1.y + width;
    } else {
      b1y = p1.y - width; b2y = p2.y + width;
    }
    if (a2y >= b1y && b2y >= a1y) {
      if (p2.x < p1.x) {
        b1x = p2.x - width; b2x = p1.x + width;
      } else {
        b1x = p1.x - width; b2x = p2.x + width;
      }
      if (a2x >= b1x && b2x >= a1x) {
        float a = y - p.y;
        float b = p.x - x;
        float c = p.x * y - p.y * x;
        float d = p2.y - p1.y;
        float e = p1.x - p2.x;
        float f = p1.x * p2.y - p1.y * p2.x;
        float dnm = b * d - a * e;
        if (dnm != 0) {
          float x = (b*f - c*e) / dnm;
          float y = (c*d - a*f) / dnm;
          if (a1x <= x && x <= a2x && a1y <= y && y <= a2y &&
              b1x <= x && x <= b2x && b1y <= y && y <= b2y)
            return true;
        }
      }
    }
    return false;
  }

  public bool checkHitDist(Vector p, Vector pp, float dist) {
    float bmvx, bmvy, inaa;
    bmvx = pp.x;
    bmvy = pp.y;
    bmvx -= p.x;
    bmvy -= p.y;
    inaa = bmvx * bmvx + bmvy * bmvy;
    if (inaa > 0.00001) {
      float sofsx, sofsy, inab, hd;
      sofsx = x;
      sofsy = y;
      sofsx -= p.x;
      sofsy -= p.y;
      inab = bmvx * sofsx + bmvy * sofsy;
      if (inab >= 0 && inab <= inaa) {
	hd = sofsx * sofsx + sofsy * sofsy - inab * inab / inaa;
	if (hd >= 0 && hd <= dist)
	  return true;
      }
    }
    return false;
  }

  public float vctSize() {
    return sqrt(x * x + y * y);
  }

  public float dist(Vector v) {
    return dist(v.x, v.y);
  }

  public float dist(float px = 0, float py = 0) {
    float ax = fabs(x - px);
    float ay = fabs(y - py);
    if (ax > ay)
      return ax + ay / 2;
    else
      return ay + ax / 2;
  }

  public bool contains(Vector p, float r = 1) {
    return contains(p.x, p.y, r);
  }

  public bool contains(float px, float py, float r = 1) {
  if (px >= -x * r && px <= x * r && py >= -y * r && py <= y * r)
      return true;
    else
      return false;
  }

  public char[] toString() {
    return "(" ~ std.string.toString(x) ~ ", " ~ std.string.toString(y) ~ ")";
  }
}

public class Vector3 {
 public:
  float x, y, z;

  public this() {
    x = y = z = 0;
  }

  public this(float x, float y, float z) {
    this.x = x;
    this.y = y;
    this.z = z;
  }

  public void rollX(float d) {
    float ty = y * cos(d) - z * sin(d);
    z = y * sin(d) + z * cos(d);
    y = ty;
  }

  public void rollY(float d) {
    float tx = x * cos(d) - z * sin(d);
    z = x * sin(d) + z * cos(d);
    x = tx;
  }

  public void rollZ(float d) {
    float tx = x * cos(d) - y * sin(d);
    y = x * sin(d) + y * cos(d);
    x = tx;
  }

  public void blend(Vector3 v1, Vector3 v2, float ratio) {
    x = v1.x * ratio + v2.x * (1 - ratio);
    y = v1.y * ratio + v2.y * (1 - ratio);
    z = v1.z * ratio + v2.z * (1 - ratio);
  }

  public void opAddAssign(Vector3 v) {
    x += v.x;
    y += v.y;
    z += v.z;
  }

  public void opSubAssign(Vector3 v) {
    x -= v.x;
    y -= v.y;
    z -= v.z;
  }

  public void opMulAssign(float a) {	
    x *= a;
    y *= a;
    z *= a;
  }

  public void opDivAssign(float a) {	
    x /= a;
    y /= a;
    z /= a;
  }
}
