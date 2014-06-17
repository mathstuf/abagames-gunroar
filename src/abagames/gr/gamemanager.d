/*
 * $Id: gamemanager.d,v 1.5 2005/09/11 00:47:40 kenta Exp $
 *
 * Copyright 2005 Kenta Cho. Some rights reserved.
 */
module abagames.gr.gamemanager;

private import std.math;
private import derelict.opengl3.gl;
private import derelict.sdl2.sdl;
private import gl3n.linalg;
private import abagames.util.rand;
private import abagames.util.sdl.gamemanager;
private import abagames.util.sdl.texture;
private import abagames.util.sdl.input;
private import abagames.util.sdl.pad;
private import abagames.util.sdl.touch;
private import abagames.util.sdl.accelerometer;
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
private import abagames.gr.accelerometerandtouch;
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
  Touch touch;
  Accelerometer accelerometer;
  Mouse mouse;
  RecordableAccelerometerAndTouch accelerometerAndTouch;
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
  mat4 windowmat;
  bool escPressed;
  bool backgrounded;

  public override void init(mat4 windowmat) {
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
    touch = cast(Touch) (cast(MultipleInputDevice) input).inputs[3];
    accelerometer = cast(Accelerometer) (cast(MultipleInputDevice) input).inputs[4];
    mouse.init(screen);
    accelerometerAndTouch = new RecordableAccelerometerAndTouch(accelerometer, touch);
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
    ship = new Ship(pad, twinStick, touch, mouse, accelerometer, accelerometerAndTouch, mouseAndPad,
                    field, screen, sparks, smokes, fragments, wakes);
    Object[] cargs;
    cargs ~= ship;
    crystals = new CrystalPool(80, cargs);
    scoreReel = new ScoreReel;
    Object[] nargs;
    nargs ~= scoreReel;
    numIndicators = new NumIndicatorPool(50, nargs);
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
    titleManager = new TitleManager(prefManager, pad, mouse, touch, field, this);
    inGameState = new InGameState(this, screen, pad, twinStick, touch, mouse, accelerometer, accelerometerAndTouch, mouseAndPad,
                                  field, ship, shots, bullets, enemies,
                                  sparks, smokes, fragments, sparkFragments, wakes,
                                  crystals, numIndicators, stageManager, scoreReel,
                                  prefManager);
    titleState = new TitleState(this, screen, pad, twinStick, touch, mouse, accelerometer, accelerometerAndTouch, mouseAndPad,
                                field, ship, shots, bullets, enemies,
                                sparks, smokes, fragments, sparkFragments, wakes,
                                crystals, numIndicators, stageManager, scoreReel,
                                titleManager, inGameState);
    ship.setGameState(inGameState);

    this.windowmat = windowmat;
    escPressed = false;
    backgrounded = false;
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
    } catch (Throwable o) {}
  }

  private void loadLastReplay() {
    try {
      inGameState.loadReplay("last.rpl");
    } catch (Throwable o) {
      inGameState.resetReplay();
    }
  }

  private void loadErrorReplay() {
    try {
      inGameState.loadReplay("error.rpl");
    } catch (Throwable o) {
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
    if (pad.keys[SDL_SCANCODE_ESCAPE] == SDL_PRESSED) {
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
    // Do nothing in the background.
    if (backgrounded) {
      return;
    }
    SDL_Event e = mainLoop.event;
    if (handleAppEvents(e)) {
      return;
    }
    if (e.type == SDL_WINDOWEVENT_RESIZED) {
      SDL_WindowEvent we = e.window;
      Sint32 w = we.data1;
      Sint32 h = we.data2;
      if (w > 150 && h > 100)
        windowmat = screen.resized(w, h);
    }
    mat4 view = windowmat * screen.projectiveView();
    if (screen.startRenderToLuminousScreen()) {
      glPushMatrix();
      screen.setEyepos();
      state.drawLuminous(view);
      glPopMatrix();
      screen.endRenderToLuminousScreen();
    }
    screen.clear();
    glPushMatrix();
    screen.setEyepos();
    state.draw(view);
    glPopMatrix();
    screen.drawLuminous(mat4.identity);
    glPushMatrix();
    screen.setEyepos();
    field.drawSideWalls(view);
    state.drawFront(view);
    glPopMatrix();
    screen.viewOrthoFixed();
    mat4 orthoView = screen.fixedOrthoView();
    state.drawOrtho(orthoView);
    screen.viewPerspective();
  }

  private bool handleAppEvents(ref SDL_Event e) {
    switch (e.type) {
    case SDL_APP_TERMINATING:
      mainLoop.breakLoop();
      return true;
    case SDL_APP_WILLENTERBACKGROUND:
    case SDL_APP_DIDENTERBACKGROUND:
      // Pause the game.
      if (inGameState.pauseCnt <= 0 && !inGameState.isGameOver) {
        inGameState.pauseCnt = 1;
      }
      // We're in the background.
      backgrounded = true;
      return true;
    case SDL_APP_DIDENTERFOREGROUND:
      backgrounded = false;
      return true;
    // Nothing to be done; we'll just start looping.
    case SDL_APP_WILLENTERFOREGROUND:
      return true;
    // Not much we're going to do here.
    case SDL_APP_LOWMEMORY:
      return false;
    default:
      break;
    }

    return false;
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
  Touch touch;
  Mouse mouse;
  Accelerometer accelerometer;
  RecordableAccelerometerAndTouch accelerometerAndTouch;
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
              Pad pad, TwinStick twinStick, Touch touch, Mouse mouse, Accelerometer accelerometer,
              RecordableAccelerometerAndTouch accelerometerAndTouch, RecordableMouseAndPad mouseAndPad,
              Field field, Ship ship, ShotPool shots, BulletPool bullets, EnemyPool enemies,
              SparkPool sparks, SmokePool smokes,
              FragmentPool fragments, SparkFragmentPool sparkFragments, WakePool wakes,
              CrystalPool crystals, NumIndicatorPool numIndicators,
              StageManager stageManager, ScoreReel scoreReel) {
    this.gameManager = gameManager;
    this.screen = screen;
    this.pad = pad;
    this.twinStick = twinStick;
    this.touch = touch;
    this.mouse = mouse;
    this.accelerometer = accelerometer;
    this.accelerometerAndTouch = accelerometerAndTouch;
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
  public abstract void draw(mat4 view);
  public abstract void drawLuminous(mat4 view);
  public abstract void drawFront(mat4 view);
  public abstract void drawOrtho(mat4 view);

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
    NORMAL, TWIN_STICK, TOUCH, TILT, DOUBLE_PLAY, DOUBLE_PLAY_TOUCH, MOUSE,
  };
  static immutable int GAME_MODE_NUM = 7;
  static string[] gameModeText = ["NORMAL", "TWIN STICK", "TOUCH", "TILT", "DOUBLE PLAY", "DOUBLE PLAY TOUCH", "MOUSE"];
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

  // For touch-input modes.
  float _touchRadius;
  // For the TOUCH mode.
  TouchRegion _movementRegion;
  TouchRegion _fireRegion;

  invariant() {
    assert(left >= -1 && left < 10);
    assert(gameOverCnt >= 0);
    assert(pauseCnt >= 0);
    assert(scoreReelSize >= SCORE_REEL_SIZE_SMALL && scoreReelSize <= SCORE_REEL_SIZE_DEFAULT);
  }

  public this(GameManager gameManager, Screen screen,
              Pad pad, TwinStick twinStick, Touch touch, Mouse mouse, Accelerometer accelerometer,
              RecordableAccelerometerAndTouch accelerometerAndTouch, RecordableMouseAndPad mouseAndPad,
              Field field, Ship ship, ShotPool shots, BulletPool bullets, EnemyPool enemies,
              SparkPool sparks, SmokePool smokes,
              FragmentPool fragments, SparkFragmentPool sparkFragments, WakePool wakes,
              CrystalPool crystals, NumIndicatorPool numIndicators,
              StageManager stageManager, ScoreReel scoreReel,
              PrefManager prefManager) {
    super(gameManager, screen, pad, twinStick, touch, mouse, accelerometer, accelerometerAndTouch, mouseAndPad,
          field, ship, shots, bullets, enemies,
          sparks, smokes, fragments, sparkFragments, wakes, crystals, numIndicators,
          stageManager, scoreReel);
    this.prefManager = prefManager;
    rand = new Rand;
    _replayData = null;
    left = 0;
    gameOverCnt = pauseCnt = 0;
    scoreReelSize = SCORE_REEL_SIZE_DEFAULT;

    _touchRadius = Touch.touchRadius();
    // TODO: Are these sensible values?
    float touchPos = 1.5 * _touchRadius;
    _movementRegion = new CircularTouchRegion(vec2(touchPos, 1.0 - touchPos), _touchRadius);
    _fireRegion = new CircularTouchRegion(vec2(1.0 - touchPos, 1.0 - touchPos), _touchRadius);
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
    case GameMode.DOUBLE_PLAY_TOUCH:
    case GameMode.TOUCH:
      RecordableTouch rt = cast(RecordableTouch) touch;
      rt.startRecord();
      _replayData.touchInputRecord = rt.inputRecord;
      break;
    case GameMode.TILT:
      accelerometerAndTouch.startRecord();
      _replayData.accelerometerAndTouchInputRecord = accelerometerAndTouch.inputRecord;
      break;
    case GameMode.MOUSE:
      mouseAndPad.startRecord();
      _replayData.mouseAndPadInputRecord = mouseAndPad.inputRecord;
      break;
    default:
      assert(0);
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
    if (pad.keys[SDL_SCANCODE_P] == SDL_PRESSED) {
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

  public override void draw(mat4 view) {
    field.draw(view);
    glBegin(GL_TRIANGLES);
    wakes.draw(view);
    sparks.draw(view);
    glEnd();
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glBegin(GL_QUADS);
    smokes.draw(view);
    glEnd();
    fragments.draw(view);
    sparkFragments.draw(view);
    crystals.draw(view);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE);
    enemies.draw(view);
    shots.draw(view);
    ship.draw(view);
    bullets.draw(view);
  }

  public override void drawFront(mat4 view) {
    ship.drawFront(view);
    scoreReel.draw(view, 11.5f + (SCORE_REEL_SIZE_DEFAULT - scoreReelSize) * 3,
                   -8.2f - (SCORE_REEL_SIZE_DEFAULT - scoreReelSize) * 3,
                   scoreReelSize);
    float x = -12;
    for (int i = 0; i < left; i++) {
      glPushMatrix();
      glTranslatef(x, -9, 0);
      glScalef(0.7f, 0.7f, 0.7f);
      ship.drawShape(view);
      glPopMatrix();
      x += 0.7f;
    }
    numIndicators.draw(view);
  }

  public void drawGameParams(mat4 view) {
    stageManager.draw(view);
  }

  public override void drawOrtho(mat4 view) {
    drawGameParams(view);
    if (isGameOver)
      Letter.drawString(view, "GAME OVER", 190, 180, 15);
    else if (pauseCnt > 0 && (pauseCnt % 64) < 32)
      Letter.drawString(view, "PAUSE", 265, 210, 12);
    else if (_gameMode == GameMode.TOUCH) {
      // TODO: Draw the touch regions.
    }
  }

  public override void drawLuminous(mat4 view) {
    glBegin(GL_TRIANGLES);
    sparks.drawLuminous(view);
    glEnd();
    sparkFragments.drawLuminous(view);
    glBegin(GL_QUADS);
    smokes.drawLuminous(view);
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

  public void saveReplay(string fileName) {
    _replayData.save(fileName);
  }

  public void loadReplay(string fileName) {
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

  public float touchRadius() {
    return _touchRadius;
  }

  public TouchRegion movementRegion() {
    return _movementRegion;
  }

  public TouchRegion fireRegion() {
    return _fireRegion;
  }
}

public class TitleState: GameState {
 private:
  TitleManager titleManager;
  InGameState inGameState;
  int gameOverCnt;

  invariant() {
    assert(gameOverCnt >= 0);
  }

  public this(GameManager gameManager, Screen screen,
              Pad pad, TwinStick twinStick, Touch touch, Mouse mouse, Accelerometer accelerometer,
              RecordableAccelerometerAndTouch accelerometerAndTouch, RecordableMouseAndPad mouseAndPad,
              Field field, Ship ship, ShotPool shots, BulletPool bullets, EnemyPool enemies,
              SparkPool sparks, SmokePool smokes,
              FragmentPool fragments, SparkFragmentPool sparkFragments, WakePool wakes,
              CrystalPool crystals, NumIndicatorPool numIndicators,
              StageManager stageManager, ScoreReel scoreReel,
              TitleManager titleManager, InGameState inGameState) {
    super(gameManager, screen, pad, twinStick, touch, mouse, accelerometer, accelerometerAndTouch, mouseAndPad,
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
    case InGameState.GameMode.DOUBLE_PLAY_TOUCH:
    case InGameState.GameMode.TOUCH:
      RecordableTouch rts = cast(RecordableTouch) touch;
      rts.startReplay(_replayData.touchInputRecord);
      break;
    case InGameState.GameMode.TILT:
      accelerometerAndTouch.startReplay(_replayData.accelerometerAndTouchInputRecord);
      break;
    case InGameState.GameMode.MOUSE:
      mouseAndPad.startReplay(_replayData.mouseAndPadInputRecord);
      break;
    default:
      assert(0);
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

  public override void draw(mat4 view) {
    if (_replayData) {
      inGameState.draw(view);
    } else {
      field.draw(view);
    }
  }

  public override void drawFront(mat4 view) {
    if (_replayData)
      inGameState.drawFront(view);
  }

  public override void drawOrtho(mat4 view) {
    if (_replayData)
      inGameState.drawGameParams(view);
    titleManager.draw(view);
  }

  public override void drawLuminous(mat4 view) {
    inGameState.drawLuminous(view);
  }
}
