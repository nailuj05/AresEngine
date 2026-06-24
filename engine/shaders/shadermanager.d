module engine.shaders.shadermanager;

import std.string;
import std.file;
import std.path;
import std.algorithm : startsWith;

import raylib;

import engine.shaders.ashader;

private immutable string DefaultShaderSource = import("default.ashader");;
  
struct ShaderAsset {
  string          sourcePath;
  Shader          raylibShader;
  ShaderUniform[] uniforms;
  MatrixUniform[] matrices;
  int             refCount;
}

struct ShaderHandle {
  uint id;
  bool opCast(T : bool)() const { return id != 0; }
}

class ShaderManager {
private:
  static immutable string DefaultShaderKey = "builtin://default";
  string            _projectRoot;
  string            _cacheDir;
  ShaderAsset[uint] _assets;
  uint[string]      _pathIndex;
  uint              _nextId = 1;
  static ShaderManager _instance;

public:
  static @property ShaderManager instance() {
    assert(_instance, "ShaderManager not initialized");
    return _instance;
  }

  static void init(string projectRoot) {
    assert(!_instance, "ShaderManager already initialized");
    _instance              = new ShaderManager();
    _instance._projectRoot = projectRoot;
    _instance._cacheDir    = buildPath(projectRoot, ".ares", "shaders");
    mkdirRecurse(_instance._cacheDir);
    _instance.registerDefault();
  }

  ShaderHandle acquire(string path) {
    if (auto id = path in _pathIndex) {
      if (!_assets[*id].sourcePath.startsWith("builtin://"))
        _assets[*id].refCount++;
      return ShaderHandle(*id);
    }
    return compileFile(path);
  }

  ShaderHandle defaultShader() {
    auto id = DefaultShaderKey in _pathIndex;
    assert(id, "Default shader not registered");
    return ShaderHandle(*id);
  }

  void release(ShaderHandle h) {
    auto asset = h.id in _assets;
    if (!asset) return;
    if (asset.sourcePath.startsWith("builtin://")) return;  // pinned, never touched
    if (--asset.refCount == 0) unload(h.id);
  }

  inout(ShaderAsset)* get(ShaderHandle h) inout {
    return h.id in _assets;
  }

  void shutdown() {
    foreach (id, ref asset; _assets) {
      int expected = asset.sourcePath.startsWith("builtin://") ? 1 : 0;
      if (asset.refCount > expected)
        assert(false, format!"Shader (%s) refCount not zero (%s) (component leak)"(asset.sourcePath, asset.refCount));

      unload(id);
    }
    _assets    = null;
    _pathIndex = null;
    _instance  = null;
  }

private:
  void registerDefault() {
    auto parsed = parseAShader(DefaultShaderSource);
    // dump builtin to cache for inspection
    import std.path : buildPath;
    import std.file : write;
    write(buildPath(_cacheDir, "builtin_default.vert"), parsed.vertSource);
    write(buildPath(_cacheDir, "builtin_default.frag"), parsed.fragSource);
    register(DefaultShaderKey, parsed);
  }

  ShaderHandle compileFile(string path) {
    import std.digest.sha : sha256Of;
    import std.digest      : toHexString;
    string absPath = isAbsolute(path) ? path : buildPath(_projectRoot, path);
    string src     = readText(absPath);
    string hash    = toHexString(sha256Of(cast(const(ubyte)[])src)).idup[0 .. 16];
    auto   parsed  = parseAShader(src);
    // write to cache for inspection; skip if unchanged
    string vertOut = buildPath(_cacheDir, hash ~ ".vert");
    string fragOut = buildPath(_cacheDir, hash ~ ".frag");
    if (!exists(vertOut)) write(vertOut, parsed.vertSource);
    if (!exists(fragOut)) write(fragOut, parsed.fragSource);
    return register(path, parsed);
  }

  ShaderHandle register(string key, ParsedShader parsed) {
    Shader sh = LoadShaderFromMemory(parsed.vertSource.toStringz, parsed.fragSource.toStringz);
    assert(sh.id != 0, "Shader compilation failed, got default fallback");

    foreach (ref u; parsed.uniforms)
      u.loc = GetShaderLocation(sh, u.name.toStringz);
    foreach (ref m; parsed.matrices)
      m.loc = GetShaderLocation(sh, m.name.toStringz);

    ShaderAsset asset;
    asset.sourcePath   = key;
    asset.raylibShader = sh;
    asset.uniforms     = parsed.uniforms;
    asset.matrices     = parsed.matrices;
    asset.refCount     = 1;

    uint id         = _nextId++;
    _assets[id]     = asset;
    _pathIndex[key] = id;
    return ShaderHandle(id);
  }

  void unload(uint id) {
    auto asset = id in _assets;
    UnloadShader(asset.raylibShader);
    _pathIndex.remove(asset.sourcePath);
    _assets.remove(id);
  }
}
