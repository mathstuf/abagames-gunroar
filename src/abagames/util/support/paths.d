/*
 * $Id: paths.d,v 1.1.1.1 2005/06/18 00:46:00 kenta Exp $
 *
 * Copyright 2004 Kenta Cho. Some rights reserved.
 */
module abagames.util.support.paths;

version (Android) {
    private import std.conv;
    private import derelict.sdl2.sdl;
}

public string dataStoragePath() {
    version (Android) {
        return to!string(SDL_AndroidGetExternalStoragePath());
    } else {
        return ".";
    }
}

public string assetStoragePath() {
    version (Android) {
        return to!string(SDL_AndroidGetInternalStoragePath());
    } else {
        return ".";
    }
}