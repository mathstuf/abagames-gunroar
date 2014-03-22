/*
 * $Id: texture.d,v 1.2 2005/07/03 07:05:23 kenta Exp $
 *
 * Copyright 2005 Kenta Cho. Some rights reserved.
 */
module abagames.util.sdl.texture;

private import std.string;
private import derelict.opengl3.gl;
private import derelict.sdl2.sdl;
private import abagames.util.sdl.sdlexception;

/**
 * Manage OpenGL textures.
 */
public class Texture {
 public:
  static string imagesDir = "images/";
  static SDL_Surface*[string] surface;
 private:
  GLuint num, maskNum;
  int textureNum, maskTextureNum;
  Uint32[128 * 128] pixels;
  Uint32[128 * 128] maskPixels;

  public static SDL_Surface* loadBmp(string name) {
    if (name in surface) {
      return surface[name];
    } else {
      string fileName = imagesDir ~ name;
      SDL_Surface *s = SDL_LoadBMP(std.string.toStringz(fileName));
      if (!s)
        throw new SDLInitFailedException("Unable to load: " ~ fileName);
      SDL_PixelFormat format;
      format.palette = null;
      format.BitsPerPixel = 32;
      format.BytesPerPixel = 4;
      format.Rmask = 0x000000ff;
      format.Gmask = 0x0000ff00;
      format.Bmask = 0x00ff0000;
      format.Amask = 0xff000000;
      format.Rshift = 0;
      format.Gshift = 8;
      format.Bshift = 16;
      format.Ashift = 24;
      format.Rloss = 0;
      format.Gloss = 0;
      format.Bloss = 0;
      format.Aloss = 0;
      //format.alpha = 0;
      SDL_Surface *cs = SDL_ConvertSurface(s, &format, SDL_SWSURFACE);
      surface[name] = cs;
      return cs;
    }
  }

  public this(string name) {
    SDL_Surface *s = loadBmp(name);
    glGenTextures(1, &num);
    glBindTexture(GL_TEXTURE_2D, num);
    glTexStorage2D(GL_TEXTURE_2D, 4, GL_RGBA8, s.w, s.h);
    glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, s.w, s.h, GL_BGRA, GL_UNSIGNED_BYTE, s.pixels);
    glGenerateMipmap(GL_TEXTURE_2D);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  }

  public this(string name, int sx, int sy, int xn, int yn, int panelWidth, int panelHeight,
              Uint32 maskColor = 0xffffffffu) {
    SDL_Surface *s = loadBmp(name);
    Uint32* surfacePixels = cast(Uint32*) s.pixels;
    this(surfacePixels, s.w, sx, sy, xn, yn, panelWidth, panelHeight, maskColor);
  }

  public this(Uint32* surfacePixels, int surfaceWidth,
              int sx, int sy, int xn, int yn, int panelWidth, int panelHeight,
              Uint32 maskColor = 0xffffffffu) {
    textureNum = xn * yn;
    glGenTextures(textureNum, &num);
    if (maskColor != 0xffffffffu) {
      maskTextureNum = textureNum;
      glGenTextures(maskTextureNum, &maskNum);
    }
    int ti = 0;
    for (int oy = 0; oy < yn; oy++) {
      for (int ox = 0; ox < xn; ox++) {
        int pi = 0;
        for (int y = 0; y < panelHeight; y++) {
          for (int x = 0; x < panelWidth; x++) {
            Uint32 p = surfacePixels[ox * panelWidth + x + sx + (oy * panelHeight + y + sy) * surfaceWidth];
            Uint32 m;
            if (p == maskColor) {
              p = 0xff000000u;
              m = 0x00ffffffu;
            } else {
              m = 0x00000000u;
            }
            pixels[pi] = p;
            if (maskColor != 0xffffffffu)
              maskPixels[pi] = m;
            pi++;
          }
        }
        glBindTexture(GL_TEXTURE_2D, num + ti);
        glTexStorage2D(GL_TEXTURE_2D, 4, GL_RGBA8, panelWidth, panelHeight);
        glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, panelWidth, panelHeight, GL_BGRA, GL_UNSIGNED_BYTE, pixels.ptr);
        glGenerateMipmap(GL_TEXTURE_2D);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
        glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR_MIPMAP_NEAREST);
        glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR);
        if (maskColor != 0xffffffffu) {
          glBindTexture(GL_TEXTURE_2D, maskNum + ti);
          glTexStorage2D(GL_TEXTURE_2D, 4, GL_RGBA8, panelWidth, panelHeight);
          glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, panelWidth, panelHeight, GL_BGRA, GL_UNSIGNED_BYTE, maskPixels.ptr);
          glGenerateMipmap(GL_TEXTURE_2D);
          glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
          glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
          glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR_MIPMAP_NEAREST);
          glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR);
        }
        ti++;
      }
    }
  }

  public void close() {
    glDeleteTextures(textureNum, &num);
    if (maskTextureNum > 0)
      glDeleteTextures(maskTextureNum, &maskNum);
  }

  public void bind(int idx = 0) {
    glBindTexture(GL_TEXTURE_2D, num + idx);
  }

  public void bindMask(int idx = 0) {
    glBindTexture(GL_TEXTURE_2D, maskNum + idx);
  }
}
