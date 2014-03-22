/*
 * $Id: tokenizer.d,v 1.1.1.1 2005/06/18 00:46:00 kenta Exp $
 *
 * Copyright 2004 Kenta Cho. Some rights reserved.
 */
module abagames.util.tokenizer;

private import std.conv;
private import std.stream;
private import std.string;

/**
 * Tokenizer.
 */
public class Tokenizer {
 private:

  public static char[][] readFile(char[] fileName, string separator) {
    char[][] result;
    scope File fd = new File;
    fd.open(to!string(fileName));
    for (;;) {
      char[] line = fd.readLine();
      if (!line)
        break;
      char[][] spl = std.string.split(line, separator);
      foreach (char[] s; spl) {
        char[] r = strip(s);
        if (r.length > 0)
          result ~= r;
      }
    }
    fd.close();
    return result;
  }
}

/**
 * CSV format tokenizer.
 */
public class CSVTokenizer {
 private:

  public static char[][] readFile(char[] fileName) {
    return Tokenizer.readFile(fileName, ",");
  }
}
