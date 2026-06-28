module engine.scene.objectmanager;

import std.json;
import std.path : buildPath, isAbsolute, extension, baseName, stripExtension, relativePath;
import std.file : readText, write, exists, dirEntries, SpanMode;
import std.string : startsWith;

import engine.core.transform;
import engine.scene.scene : activeScene, Scene;
import engine.scene.loader : serializeTransform, deserializeTransform;

struct ObjectEntry {
  string displayName;
  string path;        // scene:// or prefabs/foo.prefab
}

class ObjectManager {
private:
  string            _projectRoot;
  JSONValue[string] _prefabCache;
  static ObjectManager _instance;

public:
  static immutable string[] PrefabExtensions = [".prefab"];

  static @property ObjectManager instance() {
    assert(_instance, "ObjectManager not initialized");
    return _instance;
  }

  static void init(string projectRoot) {
    assert(!_instance, "ObjectManager already initialized");
    _instance = new ObjectManager();
    _instance._projectRoot = projectRoot;
  }

  void shutdown() {
    _prefabCache = null;
    _instance    = null;
  }

  // --- Scene path resolution ---

  Transform findByPath(string path) {
    if (!path.startsWith("scene://")) return null;
    auto scene = activeScene();
    if (!scene) return null;

    import std.string : split;
    string[] parts = path["scene://".length .. $].split('/');
    if (!parts.length) return null;

    Transform cur = null;
    foreach (t; scene.roots)
      if (t.gameObject.name == parts[0]) { cur = t; break; }
    if (cur is null) return null;

    foreach (part; parts[1 .. $]) {
      Transform next = null;
      foreach (child; cur.children)
        if (child.gameObject.name == part) { next = child; break; }
      if (next is null) return null;
      cur = next;
    }
    return cur;
  }

  string pathOf(Transform t) {
    import std.array : join;
    string[] parts;
    Transform cur = t;
    while (cur !is null) {
      parts = cur.gameObject.name ~ parts;
      cur   = cur.parent;
    }
    auto scene = activeScene();
    if (!scene) return "";
    foreach (r; scene.roots)
      if (r.gameObject.name == parts[0])
        return "scene://" ~ join(parts, "/");
    return "";
  }

  // --- Prefab instantiation ---

  void savePrefab(Transform root, string path) {
    string abs = absPath(path);
    JSONValue j = serializeTransform(root);
    write(abs, j.toPrettyString());
    _prefabCache[path] = j;
  }

  Transform instantiate(string path) {
    if (path.startsWith("scene://")) {
      Transform src = findByPath(path);
      if (!src) return null;
      JSONValue j = serializeTransform(src);
      Transform t = deserializeTransform(j);
      activeScene().roots ~= t;
      return t;
    }

    JSONValue* cached = path in _prefabCache;
    JSONValue  j;
    if (cached) {
      j = *cached;
    } else {
      string abs = absPath(path);
      if (!exists(abs)) return null;
      j                  = parseJSON(readText(abs));
      _prefabCache[path] = j;
    }
    Transform t = deserializeTransform(j);
    activeScene().roots ~= t;
    t.gameObject.start();
    return t;
  }

  Transform instantiate(Transform source) {
    JSONValue j = serializeTransform(source);
    import std.stdio;
    writeln(j.toString);
    Transform t = deserializeTransform(j);
    activeScene().roots ~= t;
    t.gameObject.start();
    return t;
  }

  void invalidatePrefab(string path) { _prefabCache.remove(path); }

  // --- Picker entries ---

  // Returns scene objects and prefabs merged; meta column differentiates them.
  ObjectEntry[] availableObjects() {
    ObjectEntry[] result;
    auto scene = activeScene();
    if (scene)
      foreach (t; scene.roots)
        collectSceneEntries(t, "scene://", result);
    foreach (ref e; availablePrefabEntries())
      result ~= e;
    return result;
  }

  static string objectMeta(const ref ObjectEntry e) {
    return e.path.startsWith("scene://") ? "scene" : "prefab";
  }

private:
  string absPath(string path) {
    return isAbsolute(path) ? path : buildPath(_projectRoot, path);
  }

  static void collectSceneEntries(Transform t, string prefix, ref ObjectEntry[] out_) {
    string path = prefix ~ t.gameObject.name;
    out_ ~= ObjectEntry(t.gameObject.name, path);
    foreach (child; t.children)
      collectSceneEntries(child, path ~ "/", out_);
  }

  ObjectEntry[] availablePrefabEntries() {
    ObjectEntry[] result;
    foreach (entry; dirEntries(_projectRoot, SpanMode.depth)) {
      if (!entry.isFile) continue;
      foreach (ext; PrefabExtensions) {
        if (entry.name.extension == ext) {
          string rel = relativePath(entry.name, _projectRoot);
          result ~= ObjectEntry(rel.baseName.stripExtension, rel);
          break;
        }
      }
    }
    return result;
  }
}
