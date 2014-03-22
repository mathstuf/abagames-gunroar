/*
 * $Id: mainloop.d,v 1.1.1.1 2005/06/18 00:46:00 kenta Exp $
 *
 * Copyright 2005 Kenta Cho. Some rights reserved.
 */
module abagames.util.sdl.mainloop;

private import SDL;
private import abagames.util.logger;
private import abagames.util.rand;
private import abagames.util.prefmanager;
private import abagames.util.sdl.gamemanager;
private import abagames.util.sdl.screen;
private import abagames.util.sdl.input;
private import abagames.util.sdl.sound;
private import abagames.util.sdl.sdlexception;

/**
 * SDL main loop.
 */
public class MainLoop {
 public:
  const int INTERVAL_BASE = 16;
  bool nowait = false;
  bool accframe = false;
  int maxSkipFrame = 5;
  SDL_Event event;
 private:
  Screen screen;
  Input input;
  GameManager gameManager;
  PrefManager prefManager;
  float slowdownRatio;
  float interval = INTERVAL_BASE;
  float _slowdownStartRatio = 1;
  float _slowdownMaxRatio = 1.75f;

  public this(Screen screen, Input input,
	      GameManager gameManager, PrefManager prefManager) {
    this.screen = screen;
    this.input = input;
    gameManager.setMainLoop(this);
    gameManager.setUIs(screen, input);
    gameManager.setPrefManager(prefManager);
    this.gameManager = gameManager;
    this.prefManager = prefManager;
  }

  // Initialize and load preference.
  private void initFirst() {
    prefManager.load();
    try {
      SoundManager.init();
    } catch (SDLInitFailedException e) {
      Logger.error(e);
    }
    gameManager.init();
    initInterval();
  }

  // Quit and save preference.
  private void quitLast() {
    gameManager.close();
    SoundManager.close();
    prefManager.save();
    screen.closeSDL();
    SDL_Quit();
  }

  private bool done;

  public void breakLoop() {
    done = true;
  }

  public void loop() {
    done = false;
    long prvTickCount = 0;
    int i;
    long nowTick;
    int frame;
    screen.initSDL();
    initFirst();
    gameManager.start();
    while (!done) {
      if (SDL_PollEvent(&event) == 0)
        event.type = SDL_USEREVENT;
      input.handleEvent(&event);
      if (event.type == SDL_QUIT)
        breakLoop();
      nowTick = SDL_GetTicks();
      int itv = cast(int) interval;
      frame = cast(int) (nowTick - prvTickCount) / itv;
      if (frame <= 0) {
        frame = 1;
        SDL_Delay(prvTickCount + itv - nowTick);
        if (accframe) {
          prvTickCount = SDL_GetTicks();
        } else {
          prvTickCount += interval;
        }
      } else if (frame > maxSkipFrame) {
        frame = maxSkipFrame;
        prvTickCount = nowTick;
      } else {
        //prvTickCount += frame * interval;
        prvTickCount = nowTick;
      }
      slowdownRatio = 0;
      for (i = 0; i < frame; i++) {
        gameManager.move();
      }
      slowdownRatio /= frame;
      screen.clear();
      gameManager.draw();
      screen.flip();
      if (!nowait)
        calcInterval();
    }
    quitLast();
  }

  // Intentional slowdown.
  
  public void initInterval() {
    interval = INTERVAL_BASE;
  }

  public void addSlowdownRatio(float sr) {
    slowdownRatio += sr;
  }

  private void calcInterval() {
    if (slowdownRatio > _slowdownStartRatio) {
      float sr = slowdownRatio / _slowdownStartRatio;
      if (sr > _slowdownMaxRatio)
        sr = _slowdownMaxRatio;
      interval += (sr * INTERVAL_BASE - interval) * 0.1;
    } else {
      interval += (INTERVAL_BASE - interval) * 0.08;
    }
  }

  public float slowdownStartRatio(float v) {
    return _slowdownStartRatio = v;
  }

  public float slowdownMaxRatio(float v) {
    return _slowdownMaxRatio = v;
  }
}
