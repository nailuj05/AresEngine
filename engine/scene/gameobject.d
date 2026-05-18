module engine.scene.gameobject;

import engine.core.transform;
import engine.core.component;

class GameObject {
  string      name;
  bool        active = true;
  Transform   transform;
  Component[] components;

  private bool started = false;
  
  T addComponent(T : Component)() {
    auto c  = new T();
    c.owner = this;
    components ~= c;

    if (!started) c.onStart();
      
    return c;
  }

  T getComponent(T : Component)() {
    foreach (c; components)
      if (auto t = cast(T) c) return t;
    return null;
  }

  void start() {
    foreach (c; components)
      if (c.enabled) c.onStart();

    started = true;
  }

  void update(float dt) {
    foreach (c; components)
      if (c.enabled) c.onUpdate(dt);
  }

  void draw() {
    // draw ctx?
    foreach (c; components)
      if (c.enabled) c.onDraw();
  }

  void destory() {
    foreach (c; components)
      c.onDestroy();
  }
}
