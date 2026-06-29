module engine.materials.material;

import raylib;

import engine.shaders.shadermanager : ShaderHandle;
import engine.shaders.ashader       : ShaderUniform;

struct EngineUniformLocs {
  int matModel  = -1;
  int matNormal = -1;
  int viewPos   = -1;
  int time      = -1;
}

struct MaterialAsset {
  string            sourcePath;
  ShaderHandle      shaderHandle;
  Material          raylibMaterial;
  ShaderUniform[]   uniforms;     // @material only, with current values
  EngineUniformLocs engineLocs;
  int               refCount;
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
