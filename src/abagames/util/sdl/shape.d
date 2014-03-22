/*
 * $Id: shape.d,v 1.1.1.1 2005/06/18 00:46:00 kenta Exp $
 *
 * Copyright 2005 Kenta Cho. Some rights reserved.
 */
module abagames.util.sdl.shape;

private import opengl;
private import abagames.util.vector;
private import abagames.util.sdl.displaylist;

/**
 * Interface for drawing a shape.
 */
public interface Drawable {
  public void draw();
}

/**
 * Interface and implmentation for a shape that has a collision.
 */
public interface Collidable {
  public Vector collision();
  public bool checkCollision(float ax, float ay, Collidable shape = null);
}

private template CollidableImpl() {
  public bool checkCollision(float ax, float ay, Collidable shape = null) {
    float cx, cy;
    if (shape) {
      cx = collision.x + shape.collision.x;
      cy = collision.y + shape.collision.y;
    } else {
      cx = collision.x;
      cy = collision.y;
    }
    if (ax <= cx && ay <= cy)
      return true;
    else
      return false;
  }
}

/**
 * Drawable that has a single displaylist.
 */
public abstract class DrawableShape: Drawable {
  protected DisplayList displayList;
 private:

  public this() {
    displayList = new DisplayList(1);
    displayList.beginNewList();
    createDisplayList();
    displayList.endNewList();
  }

  protected abstract void createDisplayList();

  public void close() {
    displayList.close();
  }

  public void draw() {
    displayList.call(0);
  }
}

/**
 * DrawableShape that has a collision.
 */
public abstract class CollidableDrawable: DrawableShape, Collidable {
  mixin CollidableImpl;
  protected Vector _collision;
 private:

  public this() {
    super();
    setCollision();
  }

  protected abstract void setCollision();

  public Vector collision() {
    return _collision;
  }
}

/**
 * Drawable that can change a size.
 */
public class ResizableDrawable: Drawable, Collidable {
  mixin CollidableImpl;
 private:
  Drawable _shape;
  float _size;
  Vector _collision;

  public void draw() {
    glScalef(_size, _size, _size);
    _shape.draw();
  }

  public Drawable shape(Drawable v) {
    _collision = new Vector;
    return _shape = v;
  }

  public Drawable shape() {
    return _shape;
  }

  public float size(float v) {
    return _size = v;
  }

  public float size() {
    return _size;
  }

  public Vector collision() {
    Collidable cd = cast(Collidable) _shape;
    if (cd) {
      _collision.x = cd.collision.x * _size;
      _collision.y = cd.collision.y * _size;
      return _collision;
    } else {
      return null;
    }
  }
}
