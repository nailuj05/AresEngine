module engine.materials.material;
import raylib;

enum UniformType { Float, Vec2, Vec3, Vec4, Int }

struct ShaderUniform {
  string      name;
  int         loc  = -1;  // cached via GetShaderLocation at load time
  UniformType type;
  float[4]    data;       // all scalar/vector types fit; cast at upload
}

struct MaterialAsset {
  string          sourcePath;
  Material        raylibMaterial;  // holds shader + map slots
  ShaderUniform[] uniforms;
  int             refCount;
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
