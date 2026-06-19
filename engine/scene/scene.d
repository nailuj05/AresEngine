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

  void start() {
    foreach (t; roots)
      t.gameObject.start();
  }

  void update(float dt) {
    physicsWorld.step(dt);
    foreach (t; roots)
      if (t.gameObject.active) t.gameObject.update(dt);
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
