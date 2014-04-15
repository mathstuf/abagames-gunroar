/*
 * $Id: title.d,v 1.4 2005/09/11 00:47:40 kenta Exp $
 *
 * Copyright 2005 Kenta Cho. Some rights reserved.
 */
module abagames.gr.title;

version (Android) {
  private import abagames.util.android.assets;
}
private import std.math;
private import derelict.sdl2.sdl;
private import derelict.opengl3.gl;
private import abagames.util.vector;
private import abagames.util.sdl.displaylist;
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
  DisplayList displayList;
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
    version (Android) {
      scope Asset asset = AssetManager.open("images/title.bmp");
      logo = new Texture("title.bmp", asset.buffer(), asset.length());
    } else {
      logo = new Texture("title.bmp");
    }
    displayList = new DisplayList(1);
    displayList.beginNewList();
    glEnable(GL_TEXTURE_2D);
    logo.bind();
    Screen.setColor(1, 1, 1);
    glBegin(GL_TRIANGLE_FAN);
    glTexCoord2f(0, 0);
    glVertex2f(0, -63);
    glTexCoord2f(1, 0);
    glVertex2f(255, -63);
    glTexCoord2f(1, 1);
    glVertex2f(255, 0);
    glTexCoord2f(0, 1);
    glVertex2f(0, 0);
    glEnd();
    Screen.lineWidth(3);
    glDisable(GL_TEXTURE_2D);
    glBegin(GL_LINE_STRIP);
    glVertex2f(-80, -7);
    glVertex2f(-20, -7);
    glVertex2f(10, -70);
    glEnd();
    glBegin(GL_LINE_STRIP);
    glVertex2f(45, -2);
    glVertex2f(-15, -2);
    glVertex2f(-45, 61);
    glEnd();
    glBegin(GL_TRIANGLE_FAN);
    Screen.setColor(1, 1, 1);
    glVertex2f(-19, -6);
    Screen.setColor(0, 0, 0);
    glVertex2f(-79, -6);
    glVertex2f(11, -69);
    glEnd();
    glBegin(GL_TRIANGLE_FAN);
    Screen.setColor(1, 1, 1);
    glVertex2f(-16, -3);
    Screen.setColor(0, 0, 0);
    glVertex2f(44, -3);
    glVertex2f(-46, 60);
    glEnd();
    Screen.lineWidth(1);
    displayList.endNewList();
    gameMode = prefManager.prefData.gameMode;
  }

  public void close() {
    displayList.close();
    logo.close();
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

  public void draw() {
    if (gameMode < 0) {
      Letter.drawString("REPLAY", 3, 400, 5);
      return;
    }
    float ts = 1;
    if (cnt > 120) {
      ts -= (cnt - 120) * 0.015f;
      if (ts < 0.5f)
        ts = 0.5f;
    }
    glPushMatrix();
    glTranslatef(80 * ts, 240, 0);
    glScalef(ts, ts, 0);
    displayList.call();
    glPopMatrix();
    if (cnt > 150) {
      Letter.drawString("HIGH", 3, 305, 4, Letter.Direction.TO_RIGHT, 1);
      Letter.drawNum(prefManager.prefData.highScore(gameMode), 80, 320, 4, 0, 9);
    }
    if (cnt > 200) {
      Letter.drawString("LAST", 3, 345, 4, Letter.Direction.TO_RIGHT, 1);
      int ls = 0;
      if (_replayData)
        ls = _replayData.score;
      Letter.drawNum(ls, 80, 360, 4, 0, 9);
    }
    Letter.drawString(InGameState.gameModeText[gameMode], 3, 400, 5);
  }

  public ReplayData replayData(ReplayData v) {
    return _replayData = v;
  }
}
