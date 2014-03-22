/*
 * $Id: prefmanager.d,v 1.4 2005/09/11 00:47:40 kenta Exp $
 *
 * Copyright 2005 Kenta Cho. Some rights reserved.
 */
module abagames.gr.prefmanager;

private import std.stream;
private import abagames.util.prefmanager;
private import abagames.gr.gamemanager;

/**
 * Save/Load the high score.
 */
public class PrefManager: abagames.util.prefmanager.PrefManager {
 private:
  static const int VERSION_NUM = 14;
  static const int VERSION_NUM_13 = 13;
  static const string PREF_FILE = "gr.prf";
  PrefData _prefData;

  public this() {
    _prefData = new PrefData;
  }

  public void load() {
    scope File fd = new File;
    try {
      int ver;
      fd.open(PREF_FILE);
      fd.read(ver);
      if (ver == VERSION_NUM_13)
        _prefData.loadVer13(fd);
      else if (ver != VERSION_NUM)
        throw new Error("Wrong version num");
      else
        _prefData.load(fd);
    } catch (Throwable e) {
      _prefData.init();
    } finally {
      if (fd.isOpen())
        fd.close();
    }
  }

  public void save() {
    scope File fd = new File;
    fd.create(PREF_FILE);
    fd.write(VERSION_NUM);
    _prefData.save(fd);
    fd.close();
  }

  public PrefData prefData() {
    return _prefData;
  }
}

public class PrefData {
 private:
  //int[InGameState.GAME_MODE_NUM] _highScore;
  int[4] _highScore;
  int _gameMode;

  public void init() {
    foreach (ref int hs; _highScore)
      hs = 0;
    _gameMode = 0;
  }

  public void load(File fd) {
    foreach (ref int hs; _highScore)
      fd.readf("%d", &hs);
    fd.readf("%d", &_gameMode);
  }

  public void loadVer13(File fd) {
    init();
    for (int i = 0; i < 3; i++)
      fd.readf("%d", &_highScore[i]);
    fd.readf("%d", &_gameMode);
  }

  public void save(File fd) {
    foreach (ref int hs; _highScore)
      fd.writef("%d", hs);
    fd.writef("%d", _gameMode);
  }

  public void recordGameMode(int gm) {
    _gameMode = gm;
  }

  public void recordResult(int score, int gm) {
    if (score > _highScore[gm])
      _highScore[gm] = score;
    _gameMode = gm;
  }

  public int highScore(int gm) {
    return _highScore[gm];
  }

  public int gameMode() {
    return _gameMode;
  }
}
