/*
 * $Id: shaders.d,v 1.2 2005/07/03 07:05:22 kenta Exp $
 *
 * Copyright 2005 Kenta Cho. Some rights reserved.
 */
module abagames.gr.shaders;

//private import derelict.gles.gles2;
private import derelict.opengl3.gl;
private import abagames.util.sdl.shaderprogram;

public template makevec4(int size, string name) {
  static if (size == 1) {
    const char[] makevec4 = "\"vec4(" ~ name ~ ", 0, 0, 1)\"";
  } else static if (size == 2) {
    const char[] makevec4 = "\"vec4(" ~ name ~ ", 0, 1)\"";
  } else static if (size == 3) {
    const char[] makevec4 = "\"vec4(" ~ name ~ ", 1)\"";
  } else static if (size == 4) {
    const char[] makevec4 = "\"" ~ name ~ "\"";
  } else {
    static assert(0);
  }
}

public template UniformColorShader(int pos, int color) {
  protected static ShaderProgram program;
  protected static GLint posLoc;
  protected static GLuint vao;
  protected static GLuint vbo;
 private:

  protected override ShaderProgram initShader() {
    if (program !is null) {
      return program;
    }

    program = new ShaderProgram;
    program.setVertexShader(
      "uniform mat4 modelmat;\n"
      "uniform mat4 projmat;\n"
      "\n"
      "attribute vec" ~ to!string(pos) ~ " pos;\n"
      "\n"
      "void main() {\n"
      "  vec4 pos4 = " ~ mixin(makevec4!(pos, "pos")) ~ ";\n"
      "  gl_Position = projmat * modelmat * pos4;\n"
      "}\n"
    );
    program.setFragmentShader(
      "uniform float brightness;\n"
      "uniform vec" ~ to!string(color) ~ " color;\n"
      "\n"
      "void main() {\n"
      "  vec4 color4 = " ~ mixin(makevec4!(color, "color")) ~ ";\n"
      "  vec4 brightness4 = vec4(vec3(brightness), 1);\n"
      "  gl_FragColor = color4 * brightness4;\n"
      "}\n"
    );
    posLoc = 0;
    program.bindAttribLocation(posLoc, "pos");
    program.link();
    program.use();

    glGenBuffers(1, &vbo);
    glGenVertexArrays(1, &vao);

    fillStaticShaderData();

    return program;
  }

  public override void close() {
    if (program !is null) {
      glDeleteVertexArrays(1, &vao);
      glDeleteBuffers(1, &vbo);
      super.close();
      program = null;
    }
  }
}

public template AttributeColorShader(int pos, int color) {
  protected static ShaderProgram program;
  protected static GLint posLoc;
  protected static GLint colorLoc;
  protected static GLuint vao;
  protected static GLuint[2] vbo;
 private:

  protected override ShaderProgram initShader() {
    if (program !is null) {
      return program;
    }

    program = new ShaderProgram;
    program.setVertexShader(
      "uniform mat4 modelmat;\n"
      "uniform mat4 projmat;\n"
      "\n"
      "attribute vec" ~ to!string(pos) ~ " pos;\n"
      "attribute vec" ~ to!string(color) ~ " color;\n"
      "\n"
      "varying vec" ~ to!string(color) ~ " f_color;\n"
      "\n"
      "void main() {\n"
      "  vec4 pos4 = " ~ mixin(makevec4!(pos, "pos")) ~ ";\n"
      "  gl_Position = projmat * modelmat * pos4;\n"
      "  f_color = color;\n"
      "}\n"
    );
    program.setFragmentShader(
      "uniform float brightness;\n"
      "\n"
      "varying vec" ~ to!string(color) ~ " f_color;\n"
      "\n"
      "void main() {\n"
      "  vec4 f_color4 = " ~ mixin(makevec4!(color, "f_color")) ~ ";\n"
      "  vec4 brightness4 = vec4(vec3(brightness), 1);\n"
      "  gl_FragColor = f_color4 * brightness4;\n"
      "}\n"
    );
    posLoc = 0;
    colorLoc = 1;
    program.bindAttribLocation(posLoc, "pos");
    program.bindAttribLocation(colorLoc, "color");
    program.link();
    program.use();

    glGenBuffers(2, vbo.ptr);
    glGenVertexArrays(1, &vao);

    fillStaticShaderData();

    return program;
  }

  public override void close() {
    if (program !is null) {
      glDeleteVertexArrays(1, &vao);
      glDeleteBuffers(2, vbo.ptr);
      super.close();
      program = null;
    }
  }
}
