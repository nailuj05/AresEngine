module engine.models.modelmanager;

import std.string;
import std.algorithm : startsWith;

import raylib;

import engine.models.model;
import engine.materials.materialmanager : MAX_MATERIAL_MAPS;

class ModelManager {
private:
  static immutable string[] ModelExtensions = [".obj", ".glb", ".gltf"];

  string _projectRoot;
  ModelAsset[uint] _assets;
  uint[string]     _pathIndex;
  uint             _nextId = 1;
  static ModelManager _instance;

public:
  // Stable keys for use in MeshRenderer.meshPath
  static immutable string PrimitiveCube     = "primitive://cube";
  static immutable string PrimitiveSphere   = "primitive://sphere";
  static immutable string PrimitivePlane    = "primitive://plane";
  static immutable string PrimitiveCylinder = "primitive://cylinder";

  static @property ModelManager instance() {
    assert(_instance, "ModelManager not initialized");
    return _instance;
  }


  static void init(string projectRoot) {
    assert(!_instance, "ModelManager already initialized");
    _instance = new ModelManager();
    _instance._projectRoot = projectRoot;
    _instance.loadPrimitives();
  }

  void shutdown() {
    if (!_instance) return;
    foreach (id, ref asset; _assets) {
      // primitives carry one manager-owned ref, components should have released theirs
      int expectedRef = asset.sourcePath.startsWith("primitive://") ? 1 : 0;
      if (asset.refCount > expectedRef) {
        version(Editor) {} else { assert(false, format!"Model (%s) Ref Count not zero (component leaks)"(asset.sourcePath)); }
      }
      unload(id);
    }
    _assets    = null;
    _pathIndex = null;
    _instance  = null;
  }

  ModelHandle acquire(string path) {
    import std.stdio;
    if (auto id = path in _pathIndex) {
      if (!_assets[*id].sourcePath.startsWith("primitive://"))
        _assets[*id].refCount++;
      return ModelHandle(*id);
    }
    return importFile(path);
  }

  void release(ModelHandle h) {
    auto asset = h.id in _assets;
    import std.stdio;
    if (!asset) return;
    if (asset.sourcePath.startsWith("primitive://")) return;
    if (--asset.refCount == 0) unload(h.id);
  }

  inout(ModelAsset)* get(ModelHandle h) inout {
    return h.id in _assets;
  }

private:
  void loadPrimitives() {
    registerPrimitive(PrimitiveCube,     GenMeshCube(1.0f, 1.0f, 1.0f));
    registerPrimitive(PrimitiveSphere,   GenMeshSphere(0.5f, 24, 24));
    registerPrimitive(PrimitivePlane,    GenMeshPlane(1.0f, 1.0f, 1, 1));
    registerPrimitive(PrimitiveCylinder, GenMeshCylinder(0.5f, 1.0f, 16));
  }

  void registerPrimitive(string key, Mesh mesh) {
    ModelAsset asset;
    asset.sourcePath    = key;
    asset.refCount      = 1; // manager-owned ref, never released
    asset.meshGroups    = [MeshGroup(mesh, 0)];
    uint id             = _nextId++;
    _assets[id]         = asset;
    _pathIndex[key]     = id;
  }

  ModelHandle importFile(string path) {
    import std.path : buildPath, isAbsolute;
    string absPath = isAbsolute(path) ? path : buildPath(_projectRoot, path);
    Model tmp = LoadModel(absPath.toStringz);
    
    scope(exit) {
      MemFree(tmp.meshes);
      MemFree(tmp.materials);
      MemFree(tmp.meshMaterial);
    }

    ModelAsset asset;
    asset.sourcePath        = path;
    asset.refCount          = 1;
    
    asset.meshGroups.length = tmp.meshCount;
    foreach (i; 0 .. tmp.meshCount)
      asset.meshGroups[i] = MeshGroup(tmp.meshes[i], tmp.meshMaterial[i]);

    uint id          = _nextId++;
    _assets[id]      = asset;
    _pathIndex[path] = id;
    return ModelHandle(id);
  }

  void unload(uint id) {
    auto asset = id in _assets;
    foreach (ref g; asset.meshGroups) UnloadMesh(g.mesh);
    _pathIndex.remove(asset.sourcePath);
    _assets.remove(id);
  }

  version(Editor) {
    private string _assetsRoot;

    public void loadAllAssets() {
      import std.file : dirEntries, SpanMode;
      import std.path : extension, relativePath;
      foreach (entry; dirEntries(_projectRoot, SpanMode.depth)) {
        if (!entry.isFile) continue;
        foreach (ext; ModelExtensions) {
          if (entry.name.extension == ext) {
            acquire(relativePath(entry.name, _projectRoot));
            break;
          }
        }
      }
    }

    public ModelEntry[] availableModels() {
      import std.path : baseName, stripExtension;
      ModelEntry[] result;
      result.reserve(_assets.length);
      foreach (ref asset; _assets)
        result ~= ModelEntry(asset.sourcePath.startsWith("primitive://")
                             ? asset.sourcePath["primitive://".length .. $]
                             : asset.sourcePath.baseName.stripExtension,
                             asset.sourcePath,
                             cast(int) asset.meshGroups.length);
      return result;
    }
  }
}
