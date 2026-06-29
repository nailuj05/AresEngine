module engine.scene.scene;

import std.algorithm.mutation : remove;

import engine.core.transform;
import engine.core.gameobject;
import engine.rendering.camera;
import engine.rendering.drawcontext;
import engine.physics.world;

private Scene _activeScene;

Scene activeScene() { return _activeScene; }
void  setActiveScene(Scene s) { _activeScene = s; }

class Scene {
  string       name;
  Transform[] roots;
  PhysicsWorld physicsWorld;

  // Objects queued for destruction; flushed at the end of update().
  private GameObject[] _pendingDestroy;

  this(string name) {
    this.name = name;
  }
  
  GameObject createObject(string goName = "GameObject") {
    auto go = new GameObject();
    go.name = goName;
    roots  ~= go.transform;
    return go;
  }

  void destroyObject(GameObject go) {
    version(Editor) {
      go.editorDestroy();
    } else {
      go.destroy();
    }
    roots = remove!(x => x is go.transform)(roots);
  }

  // Queue an object for safe destruction at the end of the current frame.
  // Use this instead of destroyObject when destroying from inside update or a
  // physics callback, where mutating the scene/physics lists immediately would
  // corrupt in-progress iteration.
  void requestDestroy(GameObject go) {
    if (go is null) return;
    foreach (q; _pendingDestroy)
      if (q is go) return;            // already queued
    _pendingDestroy ~= go;
  }

  private void processDestroyQueue() {
    if (_pendingDestroy.length == 0) return;
    auto queued   = _pendingDestroy;  // take a snapshot
    _pendingDestroy = [];             // so destroys can queue more for next frame
    foreach (go; queued)
      destroyObject(go);
  }

  void start() {
    foreach (t; roots)
      t.gameObject.start();
  }

  void update(float dt) {
    physicsWorld.step(dt);
    foreach (t; roots)
      if (t.gameObject.active) t.gameObject.update(dt);
    processDestroyQueue();            // flush deferred destroys at a safe point
  }

  void draw(DrawContext ctx) {
    foreach (t; roots)
      if (t.gameObject.active) t.gameObject.draw(ctx);
  }

  void destroy() {
    foreach (t; roots)
      t.gameObject.destroy();

    roots = [];
  }

  Camera getMainCamera() {
    foreach (t; roots) {
      Camera c = findMainCamera(t.gameObject);
      if (c !is null)
        return c;
    }
    return null;
  }

  private Camera findMainCamera(GameObject go) {
    Camera c = go.getComponent!Camera();
    if (c !is null)
      return c;

    foreach (child; go.transform.children) {
      return findMainCamera(child.gameObject);
    }
    return null;
  }

  // --- Paths ---

  public static string[] collectScenePaths(Scene scene) {
    if (!scene) return [];
    string[] result;
    foreach (t; scene.roots)
      collectPathsRecursive(t, "scene://", result);
    return result;
  }
 
  private static void collectPathsRecursive(Transform t, string prefix, ref string[] out_) {
    string path = prefix ~ t.gameObject.name;
    out_ ~= path;
    foreach (child; t.children)
      collectPathsRecursive(child, path ~ "/", out_);
  }
  
  // Returns the Transform at the given scene:// path, or null.
  // Path format: "scene://name/childname/..."  (case-sensitive, by .name)
  Transform findByPath(string path) {
    import std.string : startsWith, split;
    static immutable string prefix = "scene://";
    if (!path.startsWith(prefix)) return null;
    string[] parts = path[prefix.length .. $].split('/');
    if (!parts.length) return null;

    // find root by name
    Transform cur = null;
    foreach (t; roots) {
      if (t.gameObject.name == parts[0]) { cur = t; break; }
    }
    if (cur is null) return null;

    foreach (part; parts[1 .. $]) {
      Transform next = null;
      foreach (child; cur.children) {
        if (child.gameObject.name == part) { next = child; break; }
      }
      if (next is null) return null;
      cur = next;
    }
    return cur;
  }

  // Returns the scene:// path for a Transform, or "" if not in this scene.
  string pathOf(Transform t) {
    import std.array : join;
    string[] parts;
    Transform cur = t;
    while (cur !is null) {
      parts = cur.gameObject.name ~ parts;
      cur   = cur.parent;
    }
    // verify the root is actually in this scene
    foreach (r; roots) {
      if (r.gameObject.name == parts[0]) return "scene://" ~ join(parts, "/");
    }
    return "";
  }

  // --- Editor ---
  version(Editor) {
    void editorStart() {
      foreach (t; roots)
        t.gameObject.editorStart();
    }

    void editorDestroy() {
      foreach (t; roots)
        t.gameObject.editorDestroy();

      roots = [];
    }

    void editorDestroyObject(GameObject go) {
      go.editorDestroy();
      roots = remove!(x => x is go)(roots);
    }
  }
}
