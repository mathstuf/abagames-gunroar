/*
 * $Id: soundmanager.d,v 1.5 2005/09/11 00:47:40 kenta Exp $
 *
 * Copyright 2005 Kenta Cho. Some rights reserved.
 */
module abagames.gr.soundmanager;

version (Android) {
  private import std.conv;
}
private import std.path;
private import std.file;
private import derelict.sdl2.sdl;
private import abagames.util.rand;
private import abagames.util.logger;
private import abagames.util.sdl.sound;

/**
 * Manage BGMs and SEs.
 */
public class SoundManager: abagames.util.sdl.sound.SoundManager {
 private static:
  string[] seFileName =
    ["shot.wav", "lance.wav", "hit.wav",
     "turret_destroyed.wav", "destroyed.wav", "small_destroyed.wav", "explode.wav",
     "ship_destroyed.wav", "ship_shield_lost.wav", "score_up.wav"];
  int[] seChannel =
    [0, 1, 2, 3, 4, 5, 6, 7, 7, 6];
  Music[string] bgm;
  Chunk[string] se;
  bool[string] seMark;
  bool bgmDisabled = false;
  bool seDisabled = false;
  const int RANDOM_BGM_START_INDEX = 1;
  Rand rand;
  string[] bgmFileName;
  string currentBgm;
  size_t prevBgmIdx;
  size_t nextIdxMv;

  public static void setRandSeed(long seed) {
    rand.setSeed(seed);
  }

  public static void loadSounds() {
    loadMusics();
    loadChunks();
    rand = new Rand;
  }

  private static void loadMusics() {
    string dir = ".";
    version (Android) {
      dir = to!string(SDL_AndroidGetInternalStoragePath());
    }
    dir ~= "/" ~ Music.dir;
    foreach (string filePath; dirEntries(dir, "*.{ogg,wav}", SpanMode.shallow)) {
      string fileName = baseName(filePath);
      Music music = new Music();
      music.load(fileName);
      bgm[fileName] = music;
      bgmFileName ~= fileName;
      Logger.info("Load bgm: " ~ fileName);
    }
  }

  private static void loadChunks() {
    int i = 0;
    foreach (string fileName; seFileName) {
      Chunk chunk = new Chunk();
      chunk.load(fileName, seChannel[i]);
      se[fileName] = chunk;
      seMark[fileName] = false;
      Logger.info("Load SE: " ~ fileName);
      i++;
    }
  }

  public static void playBgm(string name) {
    currentBgm = name;
    if (bgmDisabled)
      return;
    Music.haltMusic();
    bgm[name].play();
  }

  public static void playBgm() {
    size_t bgmIdx = rand.nextInt(bgm.length - RANDOM_BGM_START_INDEX) + RANDOM_BGM_START_INDEX;
    nextIdxMv = rand.nextInt(2) * 2 - 1;
    prevBgmIdx = bgmIdx;
    playBgm(bgmFileName[bgmIdx]);
  }

  public static void nextBgm() {
    size_t bgmIdx = prevBgmIdx + nextIdxMv;
    if (bgmIdx < RANDOM_BGM_START_INDEX)
      bgmIdx = bgm.length - 1;
    else if (bgmIdx >= bgm.length)
        bgmIdx = RANDOM_BGM_START_INDEX;
    prevBgmIdx = bgmIdx;
    playBgm(bgmFileName[bgmIdx]);
  }

  public static void playCurrentBgm() {
    playBgm(currentBgm);
  }

  public static void fadeBgm() {
    Music.fadeMusic();
  }

  public static void haltBgm() {
    Music.haltMusic();
  }

  public static void playSe(string name) {
    if (seDisabled)
      return;
    seMark[name] = true;
  }

  public static void playMarkedSe() {
    string[] keys = seMark.keys;
    foreach (string key; keys) {
      if (seMark[key]) {
        se[key].play();
        seMark[key] = false;
      }
    }
  }

  public static void disableSe() {
    seDisabled = true;
  }

  public static void enableSe() {
    seDisabled = false;
  }

  public static void disableBgm() {
    bgmDisabled = true;
  }

  public static void enableBgm() {
    bgmDisabled = false;
  }
}
