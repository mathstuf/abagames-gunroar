/*
 * $Id: boot.d,v 1.6 2006/03/18 02:42:09 kenta Exp $
 *
 * Copyright 2005 Kenta Cho. Some rights reserved.
 */
module abagames.gr.boot;

version (Android) {
  private import std.conv;
}
private import core.stdc.stdlib;
private import std.string;
private import std.stream;
private import std.math;
private import std.c.stdlib;
private import abagames.util.logger;
private import abagames.util.tokenizer;
private import abagames.util.sdl.mainloop;
private import abagames.util.sdl.input;
private import abagames.util.sdl.pad;
private import abagames.util.sdl.twinstick;
private import abagames.util.sdl.touch;
private import abagames.util.sdl.accelerometer;
private import abagames.util.sdl.recordableinput;
private import abagames.util.sdl.sound;
private import abagames.gr.screen;
private import abagames.gr.gamemanager;
private import abagames.gr.prefmanager;
private import abagames.gr.ship;
private import abagames.gr.mouse;

/**
 * Boot the game.
 */
private:
Screen screen;
MultipleInputDevice input;
RecordablePad pad;
RecordableTwinStick twinStick;
RecordableTouch touch;
RecordableAccelerometer accelerometer;
RecordableMouse mouse;
GameManager gameManager;
PrefManager prefManager;
MainLoop mainLoop;

version (Win32_release) {
  // Boot as the Windows executable.
  private import std.c.windows.windows;
  private import std.string;

  extern (C) void gc_init();
  extern (C) void gc_term();
  extern (C) void _minit();
  extern (C) void _moduleCtor();

  extern (Windows)
  public int WinMain(HINSTANCE hInstance,
                     HINSTANCE hPrevInstance,
                     LPSTR lpCmdLine,
                     int nCmdShow) {
    int result;
    gc_init();
    _minit();
    try {
      _moduleCtor();
      char exe[4096];
      GetModuleFileNameA(null, exe, 4096);
      char[][1] prog;
      prog[0] = to!string(exe);
      result = boot(prog ~ std.string.split(to!string(lpCmdLine)));
    } catch (Throwable o) {
      Logger.error("Exception: " ~ o.toString());
      result = EXIT_FAILURE;
    }
    gc_term();
    return result;
  }
} else version (Android) {
  extern (C) {
    public int SDL_main(int argc, char** argv) {
      string[] args;
      for (int i = 0; i < argc; ++i) {
        args ~= to!string(argv[i]);
      }
      return boot(args);
    }
  }
} else {
  // Boot as the general executable.
  public int main(string[] args) {
    return boot(args);
  }
}

public int boot(string[] args) {
  screen = new Screen;
  input = new MultipleInputDevice;
  pad = new RecordablePad;
  twinStick = new RecordableTwinStick;
  touch = new RecordableTouch;
  mouse = new RecordableMouse(screen);
  accelerometer = new RecordableAccelerometer;
  input.inputs ~= pad;
  input.inputs ~= twinStick;
  input.inputs ~= mouse;
  input.inputs ~= touch;
  input.inputs ~= accelerometer;
  gameManager = new GameManager;
  prefManager = new PrefManager;
  mainLoop = new MainLoop(screen, input, gameManager, prefManager);
  try {
    parseArgs(args);
  } catch (Exception e) {
    Logger.info(e.toString());
    return EXIT_FAILURE;
  }
  try {
    mainLoop.loop();
  } catch (Throwable o) {
    Logger.info(o.toString());
    try {
      gameManager.saveErrorReplay();
    } catch (Throwable o1) {
      Logger.info(o.toString());
    }
    throw o;
  }
  return EXIT_SUCCESS;
}

private void parseArgs(string[] commandArgs) {
  string[] args = readOptionsIniFile();
  for (int i = 1; i < commandArgs.length; i++)
    args ~= commandArgs[i];
  string progName = commandArgs[0];
  for (int i = 0; i < args.length; i++) {
    switch (args[i]) {
    case "-brightness":
      if (i >= args.length - 1) {
        usage(progName);
        throw new Exception("Invalid options");
      }
      i++;
      float b = cast(float) atoi(args[i].ptr) / 100;
      if (b < 0 || b > 1) {
        usage(args[0]);
        throw new Exception("Invalid options");
      }
      Screen.brightness = b;
      break;
    case "-luminosity":
    case "-luminous":
      if (i >= args.length - 1) {
        usage(progName);
        throw new Exception("Invalid options");
      }
      i++;
      float l = cast(float) atoi(args[i].ptr) / 100;
      if (l < 0 || l > 1) {
        usage(progName);
        throw new Exception("Invalid options");
      }
      screen.luminosity = l;
      break;
    case "-window":
      screen.windowMode = true;
      break;
    case "-res":
      if (i >= args.length - 2) {
        usage(progName);
        throw new Exception("Invalid options");
      }
      i++;
      int w = atoi(args[i].ptr);
      i++;
      int h = atoi(args[i].ptr);
      screen.width = w;
      screen.height = h;
      break;
    case "-nosound":
      SoundManager.noSound = true;
      break;
    case "-exchange":
      pad.buttonReversed = true;
      break;
    case "-nowait":
      mainLoop.nowait = true;
      break;
    case "-accframe":
      mainLoop.accframe = 1;
      break;
    case "-turnspeed":
      if (i >= args.length - 1) {
        usage(progName);
        throw new Exception("Invalid options");
      }
      i++;
      float s = cast(float) atoi(args[i].ptr) / 100;
      if (s < 0 || s > 5) {
        usage(progName);
        throw new Exception("Invalid options");
      }
      GameManager.shipTurnSpeed = s;
      break;
    case "-firerear":
      GameManager.shipReverseFire = true;
      break;
    case "-rotatestick2":
    case "-rotaterightstick":
      if (i >= args.length - 1) {
        usage(progName);
        throw new Exception("Invalid options");
      }
      i++;
      twinStick.rotate = cast(float) atoi(args[i].ptr) * PI / 180.0f;
      break;
    case "-reversestick2":
    case "-reverserightstick":
      twinStick.reverse = -1;
      break;
    case "-enableaxis5":
      twinStick.enableAxis5 = true;
      break;
    /*case "-mouseaccel":
      if (i >= args.length - 1) {
        usage(progName);
        throw new Exception("Invalid options");
      }
      i++;
      float s = cast(float) std.string.atoi(args[i]) / 100;
      if (s < 0 || s > 5) {
        usage(progName);
        throw new Exception("Invalid options");
      }
      mouse.accel = s;
      break;*/
    default:
      usage(progName);
      throw new Exception("Invalid options");
    }
  }
}

private const string OPTIONS_INI_FILE = "options.ini";

private string[] readOptionsIniFile() {
  try {
    return Tokenizer.readFile(OPTIONS_INI_FILE, " ");
  } catch (Throwable e) {
    return null;
  }
}

private void usage(string progName) {
  Logger.error
    ("Usage: " ~ progName ~ " [-window] [-res x y] [-brightness [0-100]] [-luminosity [0-100]] [-nosound] [-exchange] [-turnspeed [0-500]] [-firerear] [-rotatestick2 deg] [-reversestick2] [-enableaxis5] [-nowait]");
}
