/*
 * $Id: replay.d,v 1.4 2005/09/11 00:47:40 kenta Exp $
 *
 * Copyright 2005 Kenta Cho. Some rights reserved.
 */
module abagames.gr.replay;

version (ABAGames_Android) {
  private import abagames.util.android.storage;
}
private import std.conv;
private import std.stream;
private import abagames.util.sdl.recordableinput;
private import abagames.util.sdl.pad;
private import abagames.util.sdl.touch;
private import abagames.util.sdl.twinstick;
private import abagames.util.sdl.mouse;
private import abagames.gr.gamemanager;
private import abagames.gr.accelerometerandtouch;
private import abagames.gr.mouseandpad;

/**
 * Save/Load a replay data.
 */
public class ReplayData {
 public:
  static const char[] dir = "replay";
  static const int VERSION_NUM = 11;
  InputRecord!(PadState) padInputRecord;
  InputRecord!(TwinStickState) twinStickInputRecord;
  InputRecord!(AccelerometerAndTouchState) accelerometerAndTouchInputRecord;
  InputRecord!(MouseAndPadState) mouseAndPadInputRecord;
  InputRecord!(TouchState) touchInputRecord;
  long seed;
  int score = 0;
  float shipTurnSpeed;
  bool shipReverseFire;
  int gameMode;
 private:

  public void save(string fileName) {
    version (ABAGames_Android) {
      scope File fd = StorageManager.newFile();
    } else {
      scope File fd = new File;
    }
    fd.create(to!string(dir ~ "/" ~ fileName));
    fd.write(VERSION_NUM);
    fd.write(seed);
    fd.write(score);
    fd.write(shipTurnSpeed);
    if (shipReverseFire)
      fd.write(1);
    else
      fd.write(0);
    fd.write(gameMode);
    switch (gameMode) {
    case InGameState.GameMode.NORMAL:
      padInputRecord.save(fd);
      break;
    case InGameState.GameMode.TWIN_STICK:
    case InGameState.GameMode.DOUBLE_PLAY:
      twinStickInputRecord.save(fd);
      break;
    case InGameState.GameMode.DOUBLE_PLAY_TOUCH:
    case InGameState.GameMode.TOUCH:
      touchInputRecord.save(fd);
      break;
    case InGameState.GameMode.TILT:
      accelerometerAndTouchInputRecord.save(fd);
      break;
    case InGameState.GameMode.MOUSE:
      mouseAndPadInputRecord.save(fd);
      break;
    default:
      assert(0);
    }
    fd.close();
  }

  public void load(string fileName) {
    version (ABAGames_Android) {
      scope File fd = StorageManager.newFile();
    } else {
      scope File fd = new File;
    }
    fd.open(to!string(dir ~ "/" ~ fileName));
    int ver;
    fd.read(ver);
    if (ver != VERSION_NUM)
      throw new Error("Wrong version num");
    fd.read(seed);
    fd.read(score);
    fd.read(shipTurnSpeed);
    int srf;
    fd.read(srf);
    if (srf == 1)
      shipReverseFire = true;
    else
      shipReverseFire = false;
    fd.read(gameMode);
    switch (gameMode) {
    case InGameState.GameMode.NORMAL:
      padInputRecord = new InputRecord!(PadState);
      padInputRecord.load(fd);
      break;
    case InGameState.GameMode.TWIN_STICK:
    case InGameState.GameMode.DOUBLE_PLAY:
      twinStickInputRecord = new InputRecord!(TwinStickState);
      twinStickInputRecord.load(fd);
      break;
    case InGameState.GameMode.DOUBLE_PLAY_TOUCH:
    case InGameState.GameMode.TOUCH:
      touchInputRecord = new InputRecord!(TouchState);
      touchInputRecord.load(fd);
      break;
    case InGameState.GameMode.TILT:
      accelerometerAndTouchInputRecord = new InputRecord!(AccelerometerAndTouchState);
      accelerometerAndTouchInputRecord.load(fd);
      break;
    case InGameState.GameMode.MOUSE:
      mouseAndPadInputRecord = new InputRecord!(MouseAndPadState);
      mouseAndPadInputRecord.load(fd);
      break;
    default:
      assert(0);
    }
    fd.close();
  }
}
