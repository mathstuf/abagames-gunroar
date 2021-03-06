/*
 * $Id: shape.d,v 1.1.1.1 2005/06/18 00:46:00 kenta Exp $
 *
 * Copyright 2005 Kenta Cho. Some rights reserved.
 */
module abagames.util.sdl.shape;

private import gl3n.linalg;
private import abagames.util.support.gl;
private import abagames.util.sdl.shaderprogram;

/**
 * Interface for drawing a shape.
 */
public interface Drawable {
  public void draw(mat4, mat4);
}

/**
 * Interface and implmentation for a shape that has a collision.
 */
public interface Collidable {
  public vec2 collision();
  public bool checkCollision(float ax, float ay, Collidable shape = null);
}

public template CollidableImpl() {
  public bool checkCollision(float ax, float ay, Collidable shape = null) {
    vec2 c;
    if (shape) {
      c = collision + shape.collision;
    } else {
      c = collision;
    }
    if (ax <= c.x && ay <= c.y)
      return true;
    else
      return false;
  }
}

/**
 * Drawable that has a single displaylist.
 */
public abstract class DrawableShape: Drawable {
  private ShaderProgram program;
 private:

  public this() {
    program = initShader();
  }

  protected abstract ShaderProgram initShader();
  protected abstract void drawShape();

  public void close() {
    program.close();
  }

  public void draw(mat4 view, mat4 model) {
    program.use();
    program.setUniform("projmat", view);
    program.setUniform("modelmat", model);
    drawShape();
  }
}

/**
 * DrawableShape that has a collision.
 */
public abstract class CollidableDrawable: DrawableShape, Collidable {
  mixin CollidableImpl;
  protected vec2 _collision;
 private:

  public this() {
    super();
    setCollision();
  }

  protected abstract void setCollision();

  public vec2 collision() {
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
  vec2 _collision;

  public void draw(mat4 view, mat4 model) {
    mat4 scalemat = mat4.identity;
    scalemat.scale(_size, _size, _size);
    _shape.draw(view, model * scalemat);
  }

  public Drawable shape(Drawable v) {
    _collision = vec2(0);
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

  public vec2 collision() {
    Collidable cd = cast(Collidable) _shape;
    if (cd) {
      _collision = cd.collision * _size;
      return _collision;
    } else {
      return vec2(0);
    }
  }
}
