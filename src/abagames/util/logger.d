/*
 * $Id: logger.d,v 1.2 2005/07/03 07:05:23 kenta Exp $
 *
 * Copyright 2004 Kenta Cho. Some rights reserved.
 */
module abagames.util.logger;

private import std.conv;
private import std.cstream;
private import std.string;

/**
 * Logger(error/info).
 */
version(Win32_release) {

private import std.string;
private import std.c.windows.windows;

public class Logger {

  public static void info(string msg, bool nline = true) {
    // Win32 exe crashes if it writes something to stderr.
    /*if (nline)
      std.cstream.derr.writeLine(msg);
    else
      std.cstream.derr.writeString(msg);*/
  }

  public static void info(double n, bool nline = true) {
    /*if (nline)
      std.cstream.derr.writeLine(std.string.toString(n));
    else
      std.cstream.derr.writeString(std.string.toString(n) ~ " ");*/
  }

  private static void putMessage(string msg) {
    MessageBoxA(null, std.string.toStringz(msg), "Error", MB_OK | MB_ICONEXCLAMATION);
  }

  public static void error(string msg) {
    putMessage("Error: " ~ msg);
  }

  public static void error(Exception e) {
    putMessage("Error: " ~ e.toString());
  }

  public static void error(Error e) {
    putMessage("Error: " ~ e.toString());
  }
}

} else version(Android) {

extern (C) void __android_log_write(int, const(char)*, const(char)*);

void android_log(int level, string msg) {
  __android_log_write(level, "gunroar", std.string.toStringz(msg));
}

public class Logger {

  private static const int WARN_LEVEL = 4;
  private static const int ERROR_LEVEL = 5;

  public static void info(string msg, bool nline = true) {
    if (nline)
      android_log(WARN_LEVEL, msg ~ "\n");
    else
      android_log(WARN_LEVEL, msg);
  }

  public static void info(double n, bool nline = true) {
    if (nline)
      android_log(WARN_LEVEL, to!string(n) ~ "\n");
    else
      android_log(WARN_LEVEL, to!string(n) ~ " ");
  }

  public static void error(string msg) {
    android_log(ERROR_LEVEL, "Error: " ~ msg ~ "\n");
  }

  public static void error(Exception e) {
    android_log(ERROR_LEVEL, "Error: " ~ e.toString() ~ "\n");
  }

  public static void error(Error e) {
    android_log(ERROR_LEVEL, "Error: " ~ e.toString() ~ "\n");
    if (e.next)
      error(to!Exception(e.next));
  }
}

} else {

public class Logger {

  public static void info(string msg, bool nline = true) {
    if (nline)
      std.cstream.derr.writeLine(msg);
    else
      std.cstream.derr.writeString(msg);
  }

  public static void info(double n, bool nline = true) {
    if (nline)
      std.cstream.derr.writeLine(to!string(n));
    else
      std.cstream.derr.writeString(to!string(n) ~ " ");
  }

  public static void error(string msg) {
    std.cstream.derr.writeLine("Error: " ~ msg);
  }

  public static void error(Exception e) {
    std.cstream.derr.writeLine("Error: " ~ e.toString());
  }

  public static void error(Error e) {
    std.cstream.derr.writeLine("Error: " ~ e.toString());
    if (e.next)
      error(to!Exception(e.next));
  }
}

}
