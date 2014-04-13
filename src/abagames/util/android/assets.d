module abagames.util.android.assets;

version (Android) {

private import derelict.android.android;
private import std.conv;
private import std.string;
private import core.sys.posix.sys.types;

public class AssetManager {
  private:
    static AAssetManager* manager;

    static this() {
      manager = null;
    }

    public static setManager(AAssetManager* mgr) {
      assert(manager is null);
      manager = mgr;
    }

    public static Asset open(string path) {
      assert(manager !is null);
      AAsset* asset = AAssetManager_open(manager, std.string.toStringz(path), AASSET_MODE_BUFFER);
      return new Asset(asset);
    }

    public static AssetDir openDir(string path) {
      assert(manager !is null);
      AAssetDir* dir = AAssetManager_openDir(manager, std.string.toStringz(path));
      return new AssetDir(dir);
    }
}

public class Asset {
  private:
    AAsset* asset;

    package this(AAsset* asset) {
      this.asset = asset;
    }

    public ~this() {
      AAsset_close(asset);
    }

    public int length() {
      return to!int(AAsset_getLength(asset));
    }

    public const(void)* buffer() {
      return AAsset_getBuffer(asset);
    }
}

public class AssetDir {
  private:
    AAssetDir* dir;

    package this(AAssetDir* dir) {
      this.dir = dir;
    }

    public ~this() {
      AAssetDir_close(dir);
    }

    public int opApply(int delegate(ref string) dg) {
      int result = 0;

      const(char)* cFileName;
      while ((cFileName = AAssetDir_getNextFileName(dir)) !is null) {
        string fileName = to!string(cFileName);
        result = dg(fileName);
        if (result) {
          break;
        }
      }

      return result;
    }
}

}
