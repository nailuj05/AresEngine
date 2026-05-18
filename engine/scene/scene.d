module engine.scene.scene;

import std.algorithm.mutation : remove;
import engine.core.gameobject;

class Scene {
  string       name;
  GameObject[] roots;
  
  GameObject createObject(string goName = "GameObject") {
    auto go = new GameObject();
    go.name = goName;
    roots  ~= go;
    return go;
  }

  void destoryObject(GameObject go) {
    go.destory();
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
    // destory entire scene (unload)
  }
}
