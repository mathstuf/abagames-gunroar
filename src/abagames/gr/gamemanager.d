/*
 * $Id: gamemanager.d,v 1.5 2005/09/11 00:47:40 kenta Exp $
 *
 * Copyright 2005 Kenta Cho. Some rights reserved.
 */
module abagames.gr.gamemanager;

private import std.math;
private import opengl;
private import SDL;
private import abagames.util.vector;
private import abagames.util.rand;
private import abagames.util.sdl.gamemanager;
private import abagames.util.sdl.texture;
private import abagames.util.sdl.input;
private import abagames.util.sdl.pad;
private import abagames.util.sdl.twinstick;
private import abagames.util.sdl.mouse;
private import abagames.util.sdl.shape;
private import abagames.gr.prefmanager;
private import abagames.gr.screen;
private import abagames.gr.ship;
private import abagames.gr.field;
private import abagames.gr.bullet;
private import abagames.gr.enemy;
private import abagames.gr.turret;
private import abagames.gr.stagemanager;
private import abagames.gr.particle;
private import abagames.gr.shot;
private import abagames.gr.crystal;
private import abagames.gr.letter;
private import abagames.gr.title;
private import abagames.gr.soundmanager;
private import abagames.gr.replay;
private import abagames.gr.shape;
private import abagames.gr.reel;
private import abagames.gr.mouseandpad;

/**
 * Manage the game state and actor pools.
 */
public class GameManager: abagames.util.sdl.gamemanager.GameManager {
 public:
  static float shipTurnSpeed = 1;
  static bool shipReverseFire = false;
 private:
  Pad pad;
  TwinStick twinStick;
  Mouse mouse;
  RecordableMouseAndPad mouseAndPad;
  PrefManager prefManager;
  Screen screen;
  Field field;
  Ship ship;
  ShotPool shots;
  BulletPool bullets;
  EnemyPool enemies;
  SparkPool sparks;
  SmokePool smokes;
  FragmentPool fragments;
  SparkFragmentPool sparkFragments;
  WakePool wakes;
  CrystalPool crystals;
  NumIndicatorPool numIndicators;
  StageManager stageManager;
  TitleManager titleManager;
  ScoreReel scoreReel;
  GameState state;
  TitleState titleState;
  InGameState inGameState;
  bool escPressed;

  public override void init() {
    Letter.init();
    Shot.init();
    BulletShape.init();
    EnemyShape.init();
    Turret.init();
    TurretShape.init();
    Fragment.init();
    SparkFragment.init();
    Crystal.init();
    prefManager = cast(PrefManager) abstPrefManager;
    screen = cast(Screen) abstScreen;
    pad = cast(Pad) (cast(MultipleInputDevice) input).inputs[0];
    twinStick = cast(TwinStick) (cast(MultipleInputDevice) input).inputs[1];
    twinStick.openJoystick(pad.openJoystick());
    mouse = cast(Mouse) (cast(MultipleInputDevice) input).inputs[2];
    mouse.init(screen);
    mouseAndPad = new RecordableMouseAndPad(mouse, pad);
    field = new Field;
    Object[] pargs;
    sparks = new SparkPool(120, pargs);
    pargs ~= field;
    wakes = new WakePool(100, pargs);
    pargs ~= wakes;
    smokes = new SmokePool(200, pargs);
    Object[] fargs;
    fargs ~= field;
    fargs ~= smokes;
    fragments = new FragmentPool(60, fargs);
    sparkFragments = new SparkFragmentPool(40, fargs);
    ship = new Ship(pad, twinStick, mouse, mouseAndPad,
                    field, screen, sparks, smokes, fragments, wakes);
    Object[] cargs;
    cargs ~= ship;
    CrystalPool crystals = new CrystalPool(80, cargs);
    scoreReel = new ScoreReel;
    Object[] nargs;
    nargs ~= scoreReel;
    NumIndicatorPool numIndicators = new NumIndicatorPool(50, nargs);
    Object[] bargs;
    bargs ~= this;
    bargs ~= field;
    bargs ~= ship;
    bargs ~= smokes;
    bargs ~= wakes;
    bargs ~= crystals;
    bullets = new BulletPool(240, bargs);
    Object[] eargs;
    eargs ~= field;
    eargs ~= screen;
    eargs ~= bullets;
    eargs ~= ship;
    eargs ~= sparks;
    eargs ~= smokes;
    eargs ~= fragments;
    eargs ~= sparkFragments;
    eargs ~= numIndicators;
    eargs ~= scoreReel;
    enemies = new EnemyPool(40, eargs);
    Object[] sargs;
    sargs ~= field;
    sargs ~= enemies;
    sargs ~= sparks;
    sargs ~= smokes;
    sargs ~= bullets;
    shots = new ShotPool(50, sargs);
    ship.setShots(shots);
    ship.setEnemies(enemies);
    stageManager = new StageManager(field, enemies, ship, bullets,
                                    sparks, smokes, fragments, wakes);
    ship.setStageManager(stageManager);
    field.setStageManager(stageManager);
    field.setShip(ship);
    enemies.setStageManager(stageManager);
    SoundManager.loadSounds();
    titleManager = new TitleManager(prefManager, pad, mouse, field, this);
    inGameState = new InGameState(this, screen, pad, twinStick, mouse, mouseAndPad,
                                  field, ship, shots, bullets, enemies,
                                  sparks, smokes, fragments, sparkFragments, wakes,
                                  crystals, numIndicators, stageManager, scoreReel,
                                  prefManager);
    titleState = new TitleState(this, screen, pad, twinStick, mouse, mouseAndPad,
                                field, ship, shots, bullets, enemies,
                                sparks, smokes, fragments, sparkFragments, wakes,
                                crystals, numIndicators, stageManager, scoreReel,
                                titleManager, inGameState);
    ship.setGameState(inGameState);
  }

  public override void close() {
    ship.close();
    BulletShape.close();
    EnemyShape.close();
    TurretShape.close();
    Fragment.close();
    SparkFragment.close();
    Crystal.close();
    titleState.close();
    Letter.close();
  }

  public override void start() {
    loadLastReplay();
    startTitle();
  }

  public void startTitle(bool fromGameover = false) {
    if (fromGameover)
      saveLastReplay();
    titleState.replayData = inGameState.replayData;
    state = titleState;
    startState();
  }

  public void startInGame(int gameMode) {
    state = inGameState;
    inGameState.gameMode = gameMode;
    startState();
  }

  private void startState() {
    state.start();
  }

  public void saveErrorReplay() {
    if (state == inGameState)
      inGameState.saveReplay("error.rpl");
  }

  private void saveLastReplay() {
    try {
      inGameState.saveReplay("last.rpl");
    } catch (Object o) {}
  }

  private void loadLastReplay() {
    try {
      inGameState.loadReplay("last.rpl");
    } catch (Object o) {
      inGameState.resetReplay();
    }
  }

  private void loadErrorReplay() {
    try {
      inGameState.loadReplay("error.rpl");
    } catch (Object o) {
      inGameState.resetReplay();
    }
  }

  public void initInterval() {
    mainLoop.initInterval();
  }

  public void addSlowdownRatio(float sr) {
    mainLoop.addSlowdownRatio(sr);
  }

  public override void move() {
    if (pad.keys[SDLK_ESCAPE] == SDL_PRESSED) {
      if (!escPressed) {
        escPressed = true;
        if (state == inGameState) {
          startTitle();
        } else {
          mainLoop.breakLoop();
        }
        return;
      }
    } else {
      escPressed = false;
    }
    state.move();
  }

  public override void draw() {
    SDL_Event e = mainLoop.event;
    if (e.type == SDL_VIDEORESIZE) {
      SDL_ResizeEvent re = e.resize;
      if (re.w > 150 && re.h > 100)
        screen.resized(re.w, re.h);
   }
   if (screen.startRenderToLuminousScreen()) {
      glPushMatrix();
      screen.setEyepos();
      state.drawLuminous();
      glPopMatrix();
      screen.endRenderToLuminousScreen();
    }
    screen.clear();
    glPushMatrix();
    screen.setEyepos();
    state.draw();
    glPopMatrix();
    screen.drawLuminous();
    glPushMatrix();
    screen.setEyepos();
    field.drawSideWalls();
    state.drawFront();
    glPopMatrix();
    screen.viewOrthoFixed();
    state.drawOrtho();
    screen.viewPerspective();
  }
}

/**
 * Manage the game state.
 * (e.g. title, in game, gameover, pause, ...)
 */
public class GameState {
 protected:
  GameManager gameManager;
  Screen screen;
  Pad pad;
  TwinStick twinStick;
  Mouse mouse;
  RecordableMouseAndPad mouseAndPad;
  Field field;
  Ship ship;
  ShotPool shots;
  BulletPool bullets;
  EnemyPool enemies;
  SparkPool sparks;
  SmokePool smokes;
  FragmentPool fragments;
  SparkFragmentPool sparkFragments;
  WakePool wakes;
  CrystalPool crystals;
  NumIndicatorPool numIndicators;
  StageManager stageManager;
  ScoreReel scoreReel;
  ReplayData _replayData;

  public this(GameManager gameManager, Screen screen,
              Pad pad, TwinStick twinStick, Mouse mouse, RecordableMouseAndPad mouseAndPad,
              Field field, Ship ship, ShotPool shots, BulletPool bullets, EnemyPool enemies,
              SparkPool sparks, SmokePool smokes,
              FragmentPool fragments, SparkFragmentPool sparkFragments, WakePool wakes,
              CrystalPool crystals, NumIndicatorPool numIndicators,
              StageManager stageManager, ScoreReel scoreReel) {
    this.gameManager = gameManager;
    this.screen = screen;
    this.pad = pad;
    this.twinStick = twinStick;
    this.mouse = mouse;
    this.mouseAndPad = mouseAndPad;
    this.field = field;
    this.ship = ship;
    this.shots = shots;
    this.bullets = bullets;
    this.enemies = enemies;
    this.sparks = sparks;
    this.smokes = smokes;
    this.fragments = fragments;
    this.sparkFragments = sparkFragments;
    this.wakes = wakes;
    this.crystals = crystals;
    this.numIndicators = numIndicators;
    this.stageManager = stageManager;
    this.scoreReel = scoreReel;
  }

  public abstract void start();
  public abstract void move();
  public abstract void draw();
  public abstract void drawLuminous();
  public abstract void drawFront();
  public abstract void drawOrtho();

  protected void clearAll() {
    shots.clear();
    bullets.clear();
    enemies.clear();
    sparks.clear();
    smokes.clear();
    fragments.clear();
    sparkFragments.clear();
    wakes.clear();
    crystals.clear();
    numIndicators.clear();
  }

  public ReplayData replayData(ReplayData v) {
    return _replayData = v;
  }

  public ReplayData replayData() {
    return _replayData;
  }
}

public class InGameState: GameState {
 public:
  static enum GameMode {
    NORMAL, TWIN_STICK, DOUBLE_PLAY, MOUSE,
  };
  static int GAME_MODE_NUM = 4;
  static char[][] gameModeText = ["NORMAL", "TWIN STICK", "DOUBLE PLAY", "MOUSE"];
  bool isGameOver;
 private:
  static const float SCORE_REEL_SIZE_DEFAULT = 0.5f;
  static const float SCORE_REEL_SIZE_SMALL = 0.01f;
  Rand rand;
  PrefManager prefManager;
  int left;
  int time;
  int gameOverCnt;
  bool btnPressed;
  int pauseCnt;
  bool pausePressed;
  float scoreReelSize;
  int _gameMode;

  invariant {
    assert(left >= -1 && left < 10);
    assert(gameOverCnt >= 0);
    assert(pauseCnt >= 0);
    assert(scoreReelSize >= SCORE_REEL_SIZE_SMALL && scoreReelSize <= SCORE_REEL_SIZE_DEFAULT);
  }

  public this(GameManager gameManager, Screen screen,
              Pad pad, TwinStick twinStick, Mouse mouse, RecordableMouseAndPad mouseAndPad,
              Field field, Ship ship, ShotPool shots, BulletPool bullets, EnemyPool enemies,
              SparkPool sparks, SmokePool smokes,
              FragmentPool fragments, SparkFragmentPool sparkFragments, WakePool wakes,
              CrystalPool crystals, NumIndicatorPool numIndicators,
              StageManager stageManager, ScoreReel scoreReel,
              PrefManager prefManager) {
    super(gameManager, screen, pad, twinStick, mouse, mouseAndPad,
          field, ship, shots, bullets, enemies,
          sparks, smokes, fragments, sparkFragments, wakes, crystals, numIndicators,
          stageManager, scoreReel);
    this.prefManager = prefManager;
    rand = new Rand;
    _replayData = null;
    left = 0;
    gameOverCnt = pauseCnt = 0;
    scoreReelSize = SCORE_REEL_SIZE_DEFAULT;
  }

  public override void start() {
    ship.unsetReplayMode();
    _replayData = new ReplayData;
    prefManager.prefData.recordGameMode(_gameMode);
    switch (_gameMode) {
    case GameMode.NORMAL:
      RecordablePad rp = cast(RecordablePad) pad;
      rp.startRecord();
      _replayData.padInputRecord = rp.inputRecord;
      break;
    case GameMode.TWIN_STICK:
    case GameMode.DOUBLE_PLAY:
      RecordableTwinStick rts = cast(RecordableTwinStick) twinStick;
      rts.startRecord();
      _replayData.twinStickInputRecord = rts.inputRecord;
      break;
    case GameMode.MOUSE:
      mouseAndPad.startRecord();
      _replayData.mouseAndPadInputRecord = mouseAndPad.inputRecord;
      break;
    }
    _replayData.seed = rand.nextInt32();
    _replayData.shipTurnSpeed = GameManager.shipTurnSpeed;
    _replayData.shipReverseFire = GameManager.shipReverseFire;
    _replayData.gameMode = _gameMode;
    SoundManager.enableBgm();
    SoundManager.enableSe();
    startInGame();
  }

  public void startInGame() {
    clearAll();
    long seed = _replayData.seed;
    field.setRandSeed(seed);
    EnemyState.setRandSeed(seed);
    EnemySpec.setRandSeed(seed);
    Turret.setRandSeed(seed);
    Spark.setRandSeed(seed);
    Smoke.setRandSeed(seed);
    Fragment.setRandSeed(seed);
    SparkFragment.setRandSeed(seed);
    Screen.setRandSeed(seed);
    BaseShape.setRandSeed(seed);
    ship.setRandSeed(seed);
    Shot.setRandSeed(seed);
    stageManager.setRandSeed(seed);
    NumReel.setRandSeed(seed);
    NumIndicator.setRandSeed(seed);
    SoundManager.setRandSeed(seed);
    stageManager.start(1);
    field.start();
    ship.start(_gameMode);
    initGameState();
    screen.setScreenShake(0, 0);
    gameOverCnt = 0;
    pauseCnt = 0;
    scoreReelSize = SCORE_REEL_SIZE_DEFAULT;
    isGameOver = false;
    SoundManager.playBgm();
  }

  private void initGameState() {
    time = 0;
    left = 2;
    scoreReel.clear(9);
    NumIndicator.initTargetY();
  }

  public override void move() {
    if (pad.keys[SDLK_p] == SDL_PRESSED) {
      if (!pausePressed) {
        if (pauseCnt <= 0 && !isGameOver)
          pauseCnt = 1;
        else
          pauseCnt = 0;
      }
      pausePressed = true;
    } else {
      pausePressed = false;
    }
    if (pauseCnt > 0) {
      pauseCnt++;
      return;
    }
    moveInGame();
    if (isGameOver) {
      gameOverCnt++;
      PadState input = (cast(RecordablePad) pad).getState(false);
      MouseState mouseInput = (cast(RecordableMouse) mouse).getState(false);
      if ((input.button & PadState.Button.A) ||
          (gameMode == InGameState.GameMode.MOUSE &&
           (mouseInput.button & MouseState.Button.LEFT))) {
        if (gameOverCnt > 60 && !btnPressed)
          gameManager.startTitle(true);
        btnPressed = true;
      } else {
        btnPressed = false;
      }
      if (gameOverCnt == 120) {
        SoundManager.fadeBgm();
        SoundManager.disableBgm();
      }
      if (gameOverCnt > 1200)
        gameManager.startTitle(true);
    }
  }

  public void moveInGame() {
    field.move();
    ship.move();
    stageManager.move();
    enemies.move();
    shots.move();
    bullets.move();
    crystals.move();
    numIndicators.move();
    sparks.move();
    smokes.move();
    fragments.move();
    sparkFragments.move();
    wakes.move();
    screen.move();
    scoreReelSize += (SCORE_REEL_SIZE_DEFAULT - scoreReelSize) * 0.05f;
    scoreReel.move();
    if (!isGameOver)
      time += 17;
    SoundManager.playMarkedSe();
  }

  public override void draw() {
    field.draw();
    glBegin(GL_TRIANGLES);
    wakes.draw();
    sparks.draw();
    glEnd();
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glBegin(GL_QUADS);
    smokes.draw();
    glEnd();
    fragments.draw();
    sparkFragments.draw();
    crystals.draw();
    glBlendFunc(GL_SRC_ALPHA, GL_ONE);
    enemies.draw();
    shots.draw();
    ship.draw();
    bullets.draw();
  }

  public void drawFront() {
    ship.drawFront();
    scoreReel.draw(11.5f + (SCORE_REEL_SIZE_DEFAULT - scoreReelSize) * 3,
                   -8.2f - (SCORE_REEL_SIZE_DEFAULT - scoreReelSize) * 3,
                   scoreReelSize);
    float x = -12;
    for (int i = 0; i < left; i++) {
      glPushMatrix();
      glTranslatef(x, -9, 0);
      glScalef(0.7f, 0.7f, 0.7f);
      ship.drawShape();
      glPopMatrix();
      x += 0.7f;
    }
    numIndicators.draw();
  }

  public void drawGameParams() {
    stageManager.draw();
  }

  public void drawOrtho() {
    drawGameParams();
    if (isGameOver)
      Letter.drawString("GAME OVER", 190, 180, 15);
    if (pauseCnt > 0 && (pauseCnt % 64) < 32)
      Letter.drawString("PAUSE", 265, 210, 12);
  }

  public override void drawLuminous() {
    glBegin(GL_TRIANGLES);
    sparks.drawLuminous();
    glEnd();
    sparkFragments.drawLuminous();
    glBegin(GL_QUADS);
    smokes.drawLuminous();
    glEnd();
  }

  public void shipDestroyed() {
    clearBullets();
    stageManager.shipDestroyed();
    gameManager.initInterval();
    left--;
    if (left < 0) {
      isGameOver = true;
      btnPressed = true;
      SoundManager.fadeBgm();
      scoreReel.accelerate();
      if (!ship.replayMode) {
        SoundManager.disableSe();
        prefManager.prefData.recordResult(scoreReel.actualScore, _gameMode);
        _replayData.score = scoreReel.actualScore;
      }
    }
  }

  public void clearBullets() {
    bullets.clear();
  }

  public void shrinkScoreReel() {
    scoreReelSize += (SCORE_REEL_SIZE_SMALL - scoreReelSize) * 0.08f;
  }

  public void saveReplay(char[] fileName) {
    _replayData.save(fileName);
  }

  public void loadReplay(char[] fileName) {
    _replayData = new ReplayData;
    _replayData.load(fileName);
  }

  public void resetReplay() {
    _replayData = null;
  }

  public int gameMode() {
    return _gameMode;
  }

  public int gameMode(int v) {
    return _gameMode = v;
  }
}

public class TitleState: GameState {
 private:
  TitleManager titleManager;
  InGameState inGameState;
  int gameOverCnt;

  invariant {
    assert(gameOverCnt >= 0);
  }

  public this(GameManager gameManager, Screen screen,
              Pad pad, TwinStick twinStick, Mouse mouse, RecordableMouseAndPad mouseAndPad,
              Field field, Ship ship, ShotPool shots, BulletPool bullets, EnemyPool enemies,
              SparkPool sparks, SmokePool smokes,
              FragmentPool fragments, SparkFragmentPool sparkFragments, WakePool wakes,
              CrystalPool crystals, NumIndicatorPool numIndicators,
              StageManager stageManager, ScoreReel scoreReel,
              TitleManager titleManager, InGameState inGameState) {
    super(gameManager, screen, pad, twinStick, mouse, mouseAndPad,
          field, ship, shots, bullets, enemies,
          sparks, smokes, fragments, sparkFragments, wakes, crystals, numIndicators,
          stageManager, scoreReel);
    this.titleManager = titleManager;
    this.inGameState = inGameState;
    gameOverCnt = 0;
  }

  public void close() {
    titleManager.close();
  }

  public override void start() {
    SoundManager.haltBgm();
    SoundManager.disableBgm();
    SoundManager.disableSe();
    titleManager.start();
    if (replayData)
      startReplay();
    else
      titleManager.replayData = null;
  }

  private void startReplay() {
    ship.setReplayMode(_replayData.shipTurnSpeed, _replayData.shipReverseFire);
    switch (_replayData.gameMode) {
    case InGameState.GameMode.NORMAL:
      RecordablePad rp = cast(RecordablePad) pad;
      rp.startReplay(_replayData.padInputRecord);
      break;
    case InGameState.GameMode.TWIN_STICK:
    case InGameState.GameMode.DOUBLE_PLAY:
      RecordableTwinStick rts = cast(RecordableTwinStick) twinStick;
      rts.startReplay(_replayData.twinStickInputRecord);
      break;
    case InGameState.GameMode.MOUSE:
      mouseAndPad.startReplay(_replayData.mouseAndPadInputRecord);
      break;
    }
    titleManager.replayData = _replayData;
    inGameState.gameMode = _replayData.gameMode;
    inGameState.startInGame();
  }

  public override void move() {
    if (_replayData) {
      if (inGameState.isGameOver) {
        gameOverCnt++;
        if (gameOverCnt > 120)
          startReplay();
      }
      inGameState.moveInGame();
    }
    titleManager.move();
  }

  public override void draw() {
    if (_replayData) {
      inGameState.draw();
    } else {
      field.draw();
    }
  }

  public void drawFront() {
    if (_replayData)
      inGameState.drawFront();
  }

  public override void drawOrtho() {
    if (_replayData)
      inGameState.drawGameParams();
    titleManager.draw();
  }

  public override void drawLuminous() {
    inGameState.drawLuminous();
  }
}
