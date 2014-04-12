module abagames.util.android.storage;

version (ABAGames_Android) {

private import std.stream;

public class StorageManager {
  private:
    static string path;

    public static setPath(string p) {
      path = p;
    }

    public static File newFile() {
      return new AndroidFile(path);
    }
}

private class AndroidFile: File {
  private:
    string root;

    package this(string root) {
      this.root = root;
    }

    public override void open(string filename, FileMode mode = FileMode.In) {
      super.open(root ~ "/" ~ filename, mode);
    }

    public override void create(string filename) {
      super.create(root ~ "/" ~ filename);
    }

    public override void create(string filename, FileMode mode) {
      super.create(root ~ "/" ~ filename, mode);
    }
}

}
