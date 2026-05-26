module engine.scene.scene;

import std.algorithm.mutation : remove;

import engine.core.gameobject;
import engine.rendering.camera;

class Scene {
  string       name;
  GameObject[] roots;
  
  this(string name) {
    this.name = name;
  }
  
  GameObject createObject(string goName = "GameObject") {
    auto go = new GameObject();
    go.name = goName;
    roots  ~= go;
    return go;
  }

  void destoryObject(GameObject go) {
    go.destroy();
    roots = remove!(x => x is go)(roots);
  }

  void start() {
    foreach (go; roots)
      go.start();
  }

  void update(float dt) {
    foreach (go; roots)
      if (go.active) go.update(dt);
  }

  void draw() {
    foreach (go; roots)
      if (go.active) go.draw();
    // draw all children too
  }

  void destroy() {
    foreach (go; roots)
      go.destroy();

    roots = [];
  }

  Camera getMainCamera() {
    foreach (root; roots) {
      Camera c = findMainCamera(root);
      if (c !is null)
        return c;
    }
    return null;
  }

  private Camera findMainCamera(GameObject go) {
    Camera c = go.getComponent!Camera();
    if (c !is null)
      return c;

    foreach (child; go.children) {
      return findMainCamera(child);
    }
    return null;
  }

  version(Editor) {
    void editorStart() {
      foreach (go; roots)
        go.editorStart();
    }

    void editorDestroy() {
      foreach (go; roots)
        go.editorDestroy();

      roots = [];
    }

    void editorDestroyObject(GameObject go) {
      go.editorDestroy();
      roots = remove!(x => x is go)(roots);
    }
  }
}
