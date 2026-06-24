module engine.materials.materialmanager;

import std.string;
import std.algorithm : startsWith;
import std.json;
import std.file  : readText, write;

import raylib;

import engine.materials.material;
import engine.shaders.shadermanager;
import engine.shaders.ashader;

enum MAX_MATERIAL_MAPS = 12;

class MaterialManager {
private:
  static immutable string[] MaterialExtensions = [".mat"];
  static immutable string   DefaultMaterialKey = "builtin://default";

  string              _projectRoot;
  MaterialAsset[uint] _assets;
  uint[string]        _pathIndex;
  uint                _nextId = 1;
  static MaterialManager _instance;

public:
  static @property MaterialManager instance() {
    assert(_instance, "MaterialManager not initialized");
    return _instance;
  }

  static void init(string projectRoot) {
    assert(!_instance, "MaterialManager already initialized");
    _instance              = new MaterialManager();
    _instance._projectRoot = projectRoot;
    _instance.registerDefault();
  }

  void shutdown() {
    if (!_instance) return;
    foreach (id, ref asset; _assets) {
      int expected = asset.sourcePath.startsWith("builtin://") ? 1 : 0;
      if (asset.refCount > expected)
        assert(false, format!"Material (%s) refCount not zero (%s) (component leak)"(asset.sourcePath, asset.refCount));

      unload(id);
    }
    _assets    = null;
    _pathIndex = null;
    _instance  = null;
  }

  MaterialHandle acquire(string path) {
    if (auto id = path in _pathIndex) {
      if (!_assets[*id].sourcePath.startsWith("builtin://"))
        _assets[*id].refCount++;
      return MaterialHandle(*id);
    }
    return importFile(path);
  }

  MaterialHandle defaultMaterial() {
    auto id = DefaultMaterialKey in _pathIndex;
    assert(id, "Default material not registered");
    return MaterialHandle(*id);
  }

  void release(MaterialHandle h) {
    auto asset = h.id in _assets;
    if (!asset) return;
    if (asset.sourcePath.startsWith("builtin://")) return;
    if (--asset.refCount == 0) unload(h.id);
  }

  inout(MaterialAsset)* get(MaterialHandle h) inout {
    return h.id in _assets;
  }

  void save(MaterialHandle h, string path) {
    import std.path : buildPath, isAbsolute;
    auto asset   = h.id in _assets;
    assert(asset);
    auto shAsset = ShaderManager.instance.get(asset.shaderHandle);

    JSONValue[] uniformsJ;
    foreach (ref u; asset.uniforms)
      uniformsJ ~= JSONValue(["name":  JSONValue(u.name),
                              "value": JSONValue([u.data[0], u.data[1], u.data[2], u.data[3]]),
                              ]);

    JSONValue j = JSONValue(["shader":   JSONValue(shAsset ? shAsset.sourcePath : ""),
                             "uniforms": JSONValue(uniformsJ),
                             ]);
    string absPath = isAbsolute(path) ? path : buildPath(_projectRoot, path);
    write(absPath, j.toPrettyString());
  }

private:
  void registerDefault() {
    ShaderHandle sh = ShaderManager.instance.defaultShader();
    auto handle     = buildAsset(DefaultMaterialKey, sh, null);
    // white default color
    auto id    = DefaultMaterialKey in _pathIndex;
    auto asset = &_assets[*id];
    foreach (ref u; asset.uniforms)
      if (u.name == "color") { u.data = [1.0f, 1.0f, 1.0f, 1.0f]; break; }
  }

  MaterialHandle importFile(string path) {
    import std.path : buildPath, isAbsolute;
    string absPath = isAbsolute(path) ? path : buildPath(_projectRoot, path);
    JSONValue j    = parseJSON(readText(absPath));

    string shaderPath = "shader" in j ? j["shader"].str : "";
    ShaderHandle sh   = shaderPath.length > 0
      ? ShaderManager.instance.acquire(shaderPath)
      : ShaderManager.instance.defaultShader();

    float[4][string] savedValues;
    if (auto uArr = "uniforms" in j)
      foreach (ref uJ; uArr.array) {
        auto arr = uJ["value"].array;
        savedValues[uJ["name"].str] = [cast(float)arr[0].floating, cast(float)arr[1].floating,
                                       cast(float)arr[2].floating, cast(float)arr[3].floating,
                                       ];
      }

    return buildAsset(path, sh, &savedValues);
  }

  MaterialHandle buildAsset(string key, ShaderHandle sh, float[4][string]* savedValues) {
    auto shAsset = ShaderManager.instance.get(sh);
    assert(shAsset);

    ShaderUniform[] matUniforms;
    EngineUniformLocs engineLocs;

    Material mat;
    mat.shader = shAsset.raylibShader;
    mat.maps   = cast(MaterialMap*) MemAlloc((MaterialMapIndex.MATERIAL_MAP_CUBEMAP + 1) * MaterialMap.sizeof);
    // default albedo white so colDiffuse * color != black
    mat.maps[MaterialMapIndex.MATERIAL_MAP_ALBEDO].color = Colors.WHITE;

    foreach (ref u; shAsset.uniforms) {
      switch (u.name) {
      case "colDiffuse": mat.shader.locs[ShaderLocationIndex.SHADER_LOC_COLOR_DIFFUSE] = u.loc; break;
      case "viewPos":
        mat.shader.locs[ShaderLocationIndex.SHADER_LOC_VECTOR_VIEW] = u.loc;
        engineLocs.viewPos = u.loc;
        break;
      default: break;
      }
      if (u.owner == UniformOwner.Material) {
        ShaderUniform copy = u;
        if (savedValues)
          if (auto v = u.name in *savedValues)
            copy.data = *v;
        matUniforms ~= copy;
      }
    }

    foreach (ref m; shAsset.matrices) {
      switch (m.name) {
      case "mvp":       mat.shader.locs[ShaderLocationIndex.SHADER_LOC_MATRIX_MVP]    = m.loc; break;
      case "matModel":
        mat.shader.locs[ShaderLocationIndex.SHADER_LOC_MATRIX_MODEL]  = m.loc;
        engineLocs.matModel = m.loc;
        break;
      case "matNormal":
        mat.shader.locs[ShaderLocationIndex.SHADER_LOC_MATRIX_NORMAL] = m.loc;
        engineLocs.matNormal = m.loc;
        break;
      default: break;
      }
    }

    // rest unchanged
    MaterialAsset asset;
    asset.sourcePath     = key;
    asset.shaderHandle   = sh;
    asset.raylibMaterial = mat;
    asset.uniforms       = matUniforms;
    asset.engineLocs     = engineLocs;
    asset.refCount       = 1;

    uint id         = _nextId++;
    _assets[id]     = asset;
    _pathIndex[key] = id;
    return MaterialHandle(id);
  }

  void unload(uint id) {
    auto asset = id in _assets;
    // Same manual free as above
    foreach (ref map; asset.raylibMaterial.maps[0 .. MAX_MATERIAL_MAPS])
      if (map.texture.id != 0) UnloadTexture(map.texture);
    MemFree(asset.raylibMaterial.maps);
    ShaderManager.instance.release(asset.shaderHandle);
    _pathIndex.remove(asset.sourcePath);
    _assets.remove(id);
  }

  version(Editor) {
    public void loadAllAssets() {
      import std.file : dirEntries, SpanMode;
      import std.path : extension, relativePath;
      foreach (entry; dirEntries(_projectRoot, SpanMode.depth)) {
        if (!entry.isFile) continue;
        foreach (ext; MaterialExtensions)
          if (entry.name.extension == ext) {
            acquire(relativePath(entry.name, _projectRoot));
            break;
          }
      }
    }

    public MaterialEntry[] availableMaterials() {
      import std.path : baseName, stripExtension;
      MaterialEntry[] result;
      result.reserve(_assets.length);
      foreach (ref asset; _assets)
        result ~= MaterialEntry(
                                asset.sourcePath.startsWith("builtin://")
                                ? asset.sourcePath["builtin://".length .. $]
                                : asset.sourcePath.baseName.stripExtension,
                                asset.sourcePath);
      return result;
    }

    public void unloadAll() {
      foreach (id, ref asset; _assets) {
        // Same manual free as above
        foreach (ref map; asset.raylibMaterial.maps[0 .. MAX_MATERIAL_MAPS])
          if (map.texture.id != 0) UnloadTexture(map.texture);
        MemFree(asset.raylibMaterial.maps);
        ShaderManager.instance.release(asset.shaderHandle);
      }
      _assets.clear();
      _pathIndex.clear();
    }
  }
}
