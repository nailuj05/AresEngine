module engine.materials.material;
import raylib;

struct MaterialAsset {
  string   sourcePath;
  Material raylibMaterial; // maps[MATERIAL_MAP_DIFFUSE..] hold all data
  int      refCount;
}

struct MaterialHandle {
  uint id;
  bool opCast(T : bool)() const { return id != 0; }
}

version(Editor) {
  struct MaterialEntry {
    string displayName;
    string path;
  }
 }
