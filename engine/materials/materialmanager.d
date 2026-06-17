module engine.materials.materialmanager;

import std.string;
import std.algorithm : startsWith;
import std.json;
import std.file  : readText, write;

import raylib;

import engine.materials.material;

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
    _instance = new MaterialManager();
    _instance._projectRoot = projectRoot;
    _instance.registerDefault();
  }

  void shutdown() {
    if (!_instance) return;
    foreach (id, ref asset; _assets) {
      int expectedRef = asset.sourcePath.startsWith("builtin://") ? 1 : 0;
      if (asset.refCount > expectedRef)
        assert(false, "Material (" ~ asset.sourcePath ~ ") refCount not zero (component leak)");
      UnloadMaterial(asset.raylibMaterial);
    }
    _assets    = null;
    _pathIndex = null;
    _instance  = null;
  }

  MaterialHandle acquire(string path) {
    if (auto id = path in _pathIndex) {
      _assets[*id].refCount++;
      return MaterialHandle(*id);
    }
    return importFile(path);
  }

  MaterialHandle defaultMaterial() {
    auto id = DefaultMaterialKey in _pathIndex;
    assert(id, "Default material not registered");
    _assets[*id].refCount++;
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

  // Saves a material asset to disk as JSON.
  void save(MaterialHandle h, string path) {
    import std.path : buildPath, isAbsolute;
    auto asset   = h.id in _assets;
    string absPath = isAbsolute(path) ? path : buildPath(_projectRoot, path);
    JSONValue j  = JSONValue(["diffuse": serializeColor(asset.raylibMaterial.maps[MATERIAL_MAP_DIFFUSE].color)]);
    write(absPath, j.toPrettyString());
  }

private:
  void registerDefault() {
    Material mat  = LoadMaterialDefault();
    mat.maps[MATERIAL_MAP_DIFFUSE].color = Colors.WHITE;

    MaterialAsset asset;
    asset.sourcePath      = DefaultMaterialKey;
    asset.raylibMaterial  = mat;
    asset.refCount        = 1; // manager-owned, never released

    uint id = _nextId++;
    _assets[id]                   = asset;
    _pathIndex[DefaultMaterialKey] = id;
  }

  MaterialHandle importFile(string path) {
    import std.path : buildPath, isAbsolute;
    string absPath = isAbsolute(path) ? path : buildPath(_projectRoot, path);

    JSONValue j = parseJSON(readText(absPath));

    Material mat = LoadMaterialDefault();
    mat.maps[MATERIAL_MAP_DIFFUSE].color = toColor(j["diffuse"]);

    MaterialAsset asset;
    asset.sourcePath     = path;
    asset.raylibMaterial = mat;
    asset.refCount       = 1;

    uint id          = _nextId++;
    _assets[id]      = asset;
    _pathIndex[path] = id;
    return MaterialHandle(id);
  }

  void unload(uint id) {
    auto asset = id in _assets;
    UnloadMaterial(asset.raylibMaterial);
    _pathIndex.remove(asset.sourcePath);
    _assets.remove(id);
  }

  // Color helpers -- move to a shared util if loader.d exposes them
  static JSONValue serializeColor(Color c) {
    return JSONValue(["r": JSONValue(c.r), "g": JSONValue(c.g),
                      "b": JSONValue(c.b), "a": JSONValue(c.a)]);
  }

  static Color toColor(JSONValue j) {
    return Color(cast(ubyte)j["r"].integer, cast(ubyte)j["g"].integer,
                 cast(ubyte)j["b"].integer, cast(ubyte)j["a"].integer);
  }

  version(Editor) {
    public void loadAllAssets() {
      import std.file : dirEntries, SpanMode;
      import std.path : extension, relativePath;
      foreach (entry; dirEntries(_projectRoot, SpanMode.depth)) {
        if (!entry.isFile) continue;
        foreach (ext; MaterialExtensions) {
          if (entry.name.extension == ext) {
            acquire(relativePath(entry.name, _projectRoot));
            break;
          }
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
      foreach (id, ref asset; _assets)
        UnloadMaterial(asset.raylibMaterial);
      _assets.clear();
      _pathIndex.clear();
    }
  }
}
