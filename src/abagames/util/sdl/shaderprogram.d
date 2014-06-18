/*
 * $Id: shaderprogram.d,v 1.1.1.1 2005/06/18 00:46:00 kenta Exp $
 *
 * Copyright 2005 Kenta Cho. Some rights reserved.
 */
module abagames.util.sdl.shaderprogram;

private import std.string;
//private import derelict.gles.gles2;
private import derelict.opengl3.gl;
private import gl3n.linalg;
private import abagames.util.sdl.sdlexception;
private import std.conv;

/**
 * Manage a shader program.
 */
public class ShaderProgram {
 private:
  bool haveShader;
  GLuint vertexShader;
  GLuint fragmentShader;
  GLuint program;
  GLint[string] uniformLocations;

  public this() {
    vertexShader = 0;
    fragmentShader = 0;
    program = glCreateProgram();
    haveShader = false;
  }

  public void setVertexShader(string source) {
    if (vertexShader)
      return;
    vertexShader = glCreateShader(GL_VERTEX_SHADER);
    compileShader(vertexShader, source);
  }

  public void setFragmentShader(string source) {
    if (fragmentShader)
      return;
    fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
    compileShader(fragmentShader, source);
  }

  private void compileShader(ref GLuint shader, string source) {
    const(char)*[] sources = [ std.string.toStringz(source) ];
    glShaderSource(shader, 1, sources.ptr, null);
    glCompileShader(shader);

    GLint status;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &status);
    if (!status) {
      GLint infoLen = 0;
      glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &infoLen);

      char[] infoLog;
      if(infoLen > 1) {
        infoLog.length = infoLen;
        glGetShaderInfoLog(shader, infoLen, null, infoLog.ptr);
      }

      glDeleteShader(shader);
      shader = 0;
      throw new SDLException("Error compiling shader: " ~ to!string(infoLog));
    }

    haveShader = true;
    glAttachShader(program, shader);
  }

  public void link() {
    if (!haveShader)
      throw new SDLException("No shader specified");
    if (!vertexShader)
      vertexShader = -1;
    if (!fragmentShader)
      fragmentShader = -1;
    glLinkProgram(program);

    GLint status;
    glGetProgramiv(program, GL_LINK_STATUS, &status);
    if (!status) {
      GLint infoLen = 0;
      glGetProgramiv(program, GL_INFO_LOG_LENGTH, &infoLen);

      char[] infoLog;
      if(infoLen > 1) {
        infoLog.length = infoLen;
        glGetProgramInfoLog(program, infoLen, null, infoLog.ptr);
      }

      glDeleteProgram(program);
      program = -1;
      throw new SDLException("Error linking program: " ~ to!string(infoLog));
    }
  }

  public void use() {
    glUseProgram(program);
  }

  public void bindAttribLocation(GLuint index, string name) {
    glBindAttribLocation(program, index, std.string.toStringz(name));
  }

  public GLint uniformLocation(string name) {
    if (name in uniformLocations) {
      return uniformLocations[name];
    }
    GLint loc = glGetUniformLocation(program, std.string.toStringz(name));
    uniformLocations[name] = loc;
    return loc;
  }

  public void setUniform(string name, int x) {
    GLint loc = uniformLocation(name);
    glUniform1i(loc, x);
  }

  public void setUniform(string name, float x) {
    GLint loc = uniformLocation(name);
    glUniform1f(loc, x);
  }

  public void setUniform(string name, vec2 v) {
    setUniform(name, v.x, v.y);
  }

  public void setUniform(string name, float x, float y) {
    GLint loc = uniformLocation(name);
    glUniform2f(loc, x, y);
  }

  public void setUniform(string name, vec3 v) {
    setUniform(name, v.x, v.y, v.z);
  }

  public void setUniform(string name, float x, float y, float z) {
    GLint loc = uniformLocation(name);
    glUniform3f(loc, x, y, z);
  }

  public void setUniform(string name, vec4 v) {
    setUniform(name, v.x, v.y, v.z, v.w);
  }

  public void setUniform(string name, float x, float y, float z, float w) {
    GLint loc = uniformLocation(name);
    glUniform4f(loc, x, y, z, w);
  }

  public void setUniform(string name, mat4 mat) {
    GLint loc = uniformLocation(name);
    glUniformMatrix4fv(loc, 1, GL_TRUE, mat.value_ptr);
  }

  public void close() {
    if (program > 0)
      glDeleteProgram(program);
    if (vertexShader > 0)
      glDeleteShader(vertexShader);
    if (fragmentShader > 0)
      glDeleteShader(fragmentShader);
  }
}
