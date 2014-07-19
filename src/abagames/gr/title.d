/*
 * $Id: title.d,v 1.4 2005/09/11 00:47:40 kenta Exp $
 *
 * Copyright 2005 Kenta Cho. Some rights reserved.
 */
module abagames.gr.title;

private import std.math;
private import derelict.sdl2.sdl;
private import gl3n.linalg;
private import abagames.util.support.gl;
private import abagames.util.sdl.shaderprogram;
private import abagames.util.sdl.texture;
private import abagames.util.sdl.pad;
private import abagames.util.sdl.mouse;
private import abagames.util.sdl.touch;
private import abagames.gr.screen;
private import abagames.gr.prefmanager;
private import abagames.gr.field;
private import abagames.gr.letter;
private import abagames.gr.gamemanager;
private import abagames.gr.replay;
private import abagames.gr.soundmanager;

/**
 * Title screen.
 */
public class TitleManager {
 private:
  static const float SCROLL_SPEED_BASE = 0.025f;
  PrefManager prefManager;
  RecordablePad pad;
  RecordableMouse mouse;
  RecordableTouch touch;
  Field field;
  GameManager gameManager;
  ShaderProgram logoLineProgram;
  ShaderProgram logoFillProgram;
  ShaderProgram titleProgram;
  GLuint[3] vao;
  GLuint[5] vbo;
  Texture logo;
  int cnt;
  ReplayData _replayData;
  int btnPressedCnt;
  int gameMode;

  public this(PrefManager prefManager, Pad pad, Mouse mouse, Touch touch,
              Field field, GameManager gameManager) {
    this.prefManager = prefManager;
    this.pad = cast(RecordablePad) pad;
    this.mouse = cast(RecordableMouse) mouse;
    this.touch = cast(RecordableTouch) touch;
    this.field = field;
    this.gameManager = gameManager;
    init();
  }

  private void init() {
    logo = new Texture("title.bmp");

    titleProgram = new ShaderProgram;
    titleProgram.setVertexShader(
      "uniform mat4 projmat;\n"
      "uniform mat4 modelmat;\n"
      "\n"
      "attribute vec2 pos;\n"
      "attribute vec2 tex;\n"
      "\n"
      "varying vec2 f_tc;\n"
      "\n"
      "void main() {\n"
      "  gl_Position = projmat * modelmat * vec4(pos, 0, 1);\n"
      "  f_tc = tex;\n"
      "}\n"
    );
    titleProgram.setFragmentShader(
      "uniform sampler2D sampler;\n"
      "uniform vec3 color;\n"
      "uniform float brightness;\n"
      "\n"
      "varying vec2 f_tc;\n"
      "\n"
      "void main() {\n"
      "  gl_FragColor = texture2D(sampler, f_tc) * vec4(color * vec3(brightness), 1);\n"
      "}\n"
    );
    GLint posLoc = 0;
    GLint texLoc = 1;
    titleProgram.bindAttribLocation(posLoc, "pos");
    titleProgram.bindAttribLocation(texLoc, "tex");
    titleProgram.link();
    titleProgram.use();

    titleProgram.setUniform("color", 1, 1, 1);
    titleProgram.setUniform("sampler", 0);

    glGenVertexArrays(3, vao.ptr);
    glGenBuffers(5, vbo.ptr);

    static const float[] TEX = [
      0, 0,
      1, 0,
      1, 1,
      0, 1
    ];
    static const float[] TITLEVTX = [
      0,   -63,
      255, -63,
      255,  0,
      0,    0
    ];

    glBindVertexArray(vao[0]);

    glBindBuffer(GL_ARRAY_BUFFER, vbo[0]);
    glBufferData(GL_ARRAY_BUFFER, TITLEVTX.length * float.sizeof, TITLEVTX.ptr, GL_STATIC_DRAW);

    glVertexAttribPointer(posLoc, 2, GL_FLOAT, GL_FALSE, 0, null);
    glEnableVertexAttribArray(posLoc);

    glBindBuffer(GL_ARRAY_BUFFER, vbo[1]);
    glBufferData(GL_ARRAY_BUFFER, TEX.length * float.sizeof, TEX.ptr, GL_STATIC_DRAW);

    glVertexAttribPointer(texLoc, 2, GL_FLOAT, GL_FALSE, 0, null);
    glEnableVertexAttribArray(texLoc);

    logoLineProgram = new ShaderProgram;
    logoLineProgram.setVertexShader(
      "uniform mat4 projmat;\n"
      "uniform mat4 modelmat;\n"
      "\n"
      "attribute vec2 pos;\n"
      "\n"
      "void main() {\n"
      "  gl_Position = projmat * modelmat * vec4(pos, 0, 1);\n"
      "}\n"
    );
    logoLineProgram.setFragmentShader(
      "uniform vec3 color;\n"
      "uniform float brightness;\n"
      "\n"
      "void main() {\n"
      "  gl_FragColor = vec4(color * vec3(brightness), 1);\n"
      "}\n"
    );
    logoLineProgram.bindAttribLocation(posLoc, "pos");
    logoLineProgram.link();
    logoLineProgram.use();

    logoLineProgram.setUniform("color", 1, 1, 1);

    static const float[] LINEVTX = [
      -80,  -7,
      -20,  -7,
       10, -70,

       45,  -2,
      -15,  -2,
      -45,  61
    ];

    glBindVertexArray(vao[1]);

    glBindBuffer(GL_ARRAY_BUFFER, vbo[2]);
    glBufferData(GL_ARRAY_BUFFER, LINEVTX.length * float.sizeof, LINEVTX.ptr, GL_STATIC_DRAW);

    glVertexAttribPointer(posLoc, 2, GL_FLOAT, GL_FALSE, 0, null);
    glEnableVertexAttribArray(posLoc);

    logoFillProgram = new ShaderProgram;
    logoFillProgram.setVertexShader(
      "uniform mat4 projmat;\n"
      "uniform mat4 modelmat;\n"
      "\n"
      "attribute vec2 pos;\n"
      "attribute vec3 color;\n"
      "\n"
      "varying vec3 f_color;\n"
      "\n"
      "void main() {\n"
      "  gl_Position = projmat * modelmat * vec4(pos, 0, 1);\n"
      "  f_color = color;\n"
      "}\n"
    );
    logoFillProgram.setFragmentShader(
      "uniform float brightness;\n"
      "\n"
      "varying vec3 f_color;\n"
      "\n"
      "void main() {\n"
      "  vec4 brightness4 = vec4(vec3(brightness), 1);\n"
      "  gl_FragColor = vec4(f_color, 1) * brightness4;\n"
      "}\n"
    );
    GLint colorLoc = 1;
    logoFillProgram.bindAttribLocation(posLoc, "pos");
    logoFillProgram.bindAttribLocation(colorLoc, "color");
    logoFillProgram.link();
    logoFillProgram.use();

    static const float[] FILLVTX = [
      -19,  -6,
      -79,  -6,
       11, -69,

      -16,  -3,
       44,  -3,
      -46,  60
    ];

    static const float[] COLOR = [
      1, 1, 1,
      0, 0, 0,
      0, 0, 0,

      1, 1, 1,
      0, 0, 0,
      0, 0, 0
    ];

    glBindVertexArray(vao[2]);

    glBindBuffer(GL_ARRAY_BUFFER, vbo[3]);
    glBufferData(GL_ARRAY_BUFFER, FILLVTX.length * float.sizeof, FILLVTX.ptr, GL_STATIC_DRAW);

    glVertexAttribPointer(posLoc, 2, GL_FLOAT, GL_FALSE, 0, null);
    glEnableVertexAttribArray(posLoc);

    glBindBuffer(GL_ARRAY_BUFFER, vbo[4]);
    glBufferData(GL_ARRAY_BUFFER, COLOR.length * float.sizeof, COLOR.ptr, GL_STATIC_DRAW);

    glVertexAttribPointer(colorLoc, 3, GL_FLOAT, GL_FALSE, 0, null);
    glEnableVertexAttribArray(colorLoc);

    gameMode = prefManager.prefData.gameMode;
  }

  public void close() {
    logo.close();

    glDeleteVertexArrays(3, vao.ptr);
    glDeleteBuffers(5, vbo.ptr);
    titleProgram.close();
    logoLineProgram.close();
    logoFillProgram.close();
  }

  public void start() {
    cnt = 0;
    field.start();
    btnPressedCnt = 1;
  }

  public void move() {
    if (!_replayData) {
      field.move();
      field.scroll(SCROLL_SPEED_BASE, true);
    }
    PadState input = pad.getState(false);
    MouseState mouseInput = mouse.getState(false);
    // TODO: Use swipe motions to change the selection.
    if (btnPressedCnt <= 0) {
      if (((input.button & PadState.Button.A) ||
           (gameMode == InGameState.GameMode.MOUSE &&
            (mouseInput.button & MouseState.Button.LEFT))) &&
          gameMode >= 0)
        gameManager.startInGame(gameMode);
      int gmc = 0;
      if ((input.button & PadState.Button.B) || (input.dir & PadState.Dir.DOWN))
        gmc = 1;
      else if (input.dir & PadState.Dir.UP)
        gmc = -1;
      if (gmc != 0) {
        do {
          gameMode += gmc;
          if (gameMode >= InGameState.GAME_MODE_NUM)
            gameMode = -1;
          else if (gameMode < -1)
            gameMode = InGameState.GAME_MODE_NUM - 1;
        } while (!modeSupported(gameMode));
        if (gameMode == -1 && _replayData) {
          SoundManager.enableBgm();
          SoundManager.enableSe();
          SoundManager.playCurrentBgm();
        } else {
          SoundManager.fadeBgm();
          SoundManager.disableBgm();
          SoundManager.disableSe();
        }
      }
    }
    if ((input.button & (PadState.Button.A | PadState.Button.B)) ||
        (input.dir & (PadState.Dir.UP | PadState.Dir.DOWN)) ||
        (mouseInput.button & MouseState.Button.LEFT))
      btnPressedCnt = 6;
    else
      btnPressedCnt--;
    cnt++;
  }

  private bool modeSupported(int mode) {
    SDL_Joystick* stick = pad.openJoystick();
    int numAxes = 0;
    if (stick) {
      numAxes = SDL_JoystickNumAxes(stick);
    }
    switch (mode) {
    case -1:
      // Replay is always available.
      break;
    // Requires a keyboard or a joystick.
    case InGameState.GameMode.NORMAL:
      // TODO: Detect keyboard.
      if (!true && numAxes < 2) {
        return false;
      }
      break;
    // Fine with a keyboard or a joystick with 5 axes.
    case InGameState.GameMode.DOUBLE_PLAY:
    case InGameState.GameMode.TWIN_STICK:
      // TODO: Detect keyboard.
      // A joystick needs 5 axes (two thumbsticks; the 5th for -enableaxis5).
      if (!true && numAxes < 5) {
        return false;
      }
      break;
    // Requires a keyboard and mouse.
    case InGameState.GameMode.MOUSE:
      if (SDL_GetCursor() is null) {
        return false;
      }
      break;
    // Requires a joystick with 2 axes (not an accelerometer otherwise).
    case InGameState.GameMode.TILT:
      if (numAxes != 2) {
        return false;
      }
      // Also requires touch.
      goto case;
    // Requires a touch input.
    case InGameState.GameMode.TOUCH:
    case InGameState.GameMode.DOUBLE_PLAY_TOUCH:
      if (!SDL_GetNumTouchDevices()) {
        return false;
      }
      break;
    default:
      break;
    }

    return true;
  }

  public void draw(mat4 view) {
    if (gameMode < 0) {
      Letter.drawString(view, "REPLAY", 3, 400, 5);
      return;
    }
    float ts = 1;
    if (cnt > 120) {
      ts -= (cnt - 120) * 0.015f;
      if (ts < 0.5f)
        ts = 0.5f;
    }

    mat4 model = mat4.identity;
    model.scale(ts, ts, 0);
    model.translate(80 * ts, 240, 0);

    titleProgram.use();
    titleProgram.setUniform("brightness", Screen.brightness);
    titleProgram.setUniform("projmat", view);
    titleProgram.setUniform("modelmat", model);

    logoLineProgram.use();
    logoLineProgram.setUniform("brightness", Screen.brightness);
    logoLineProgram.setUniform("projmat", view);
    logoLineProgram.setUniform("modelmat", model);

    logoFillProgram.use();
    logoFillProgram.setUniform("brightness", Screen.brightness);
    logoFillProgram.setUniform("projmat", view);
    logoFillProgram.setUniform("modelmat", model);

    drawLogo();

    if (cnt > 150) {
      Letter.drawString(view, "HIGH", 3, 305, 4, Letter.Direction.TO_RIGHT, Letter.COLOR1);
      Letter.drawNum(view, prefManager.prefData.highScore(gameMode), 80, 320, 4, Letter.COLOR0, 9);
    }
    if (cnt > 200) {
      Letter.drawString(view, "LAST", 3, 345, 4, Letter.Direction.TO_RIGHT, Letter.COLOR1);
      int ls = 0;
      if (_replayData)
        ls = _replayData.score;
      Letter.drawNum(view, ls, 80, 360, 4, Letter.COLOR0, 9);
    }
    Letter.drawString(view, InGameState.gameModeText[gameMode], 3, 400, 5);
  }

  public ReplayData replayData(ReplayData v) {
    return _replayData = v;
  }

  private void drawLogo() {
    glEnable(GL_TEXTURE_2D);

    titleProgram.use();

    glActiveTexture(GL_TEXTURE0);
    logo.bind();

    titleProgram.useVao(vao[0]);
    glDrawArrays(GL_TRIANGLE_FAN, 0, 4);

    glDisable(GL_TEXTURE_2D);

    Screen.lineWidth(3);

    logoLineProgram.use();

    logoLineProgram.useVao(vao[1]);
    glDrawArrays(GL_LINE_STRIP, 0, 3);
    glDrawArrays(GL_LINE_STRIP, 3, 3);

    logoFillProgram.use();

    logoFillProgram.useVao(vao[2]);
    glDrawArrays(GL_TRIANGLE_FAN, 0, 3);
    glDrawArrays(GL_TRIANGLE_FAN, 3, 3);

    Screen.lineWidth(1);
  }
}
