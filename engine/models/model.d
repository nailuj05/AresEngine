module engine.models.model;

import raylib;

struct MeshGroup {
  Mesh mesh;
  int  materialIndex;
}

struct ModelAsset {
  string       sourcePath;
  MeshGroup[]  meshGroups;
  Material[]   materials;
  int          refCount;

  // expand with animation data later
}

struct ModelHandle {
  uint id;
  bool opCast(T : bool)() const { return id != 0; }
}

version(Editor) {
  struct ModelEntry {
    string displayName;
    string path;
    int meshCount;
  }
}
