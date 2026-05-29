module engine.core.gameobject;

import raylib : Vector3, Quaternion;

import engine.core.transform;
import engine.core.component;

class GameObject {
  string       name;
  bool         active = true;
  Transform    transform;
  Component[]  components;

  private bool started = false;
  
  version(Editor) {
    import editor.inspector.drawer;
    FieldState    nameFS;
    FieldState[3] posFS;
    FieldState[3] rotFS;
    FieldState[3] scaleFS;

    bool expanded = true;
  }

  this() {
    transform = new Transform(this);
  }
    
  T addComponent(T : Component)() {
    auto c  = new T();
    c.owner = this;
    components ~= c;

    version(Editor) {
      if (!started) c.onEditorStart();
    } else {
      if (!started) c.onStart();
    }
      
    return c;
  }

  T getComponent(T : Component)() {
    foreach (c; components)
      if (auto t = cast(T) c) return t;
    return null;
  }

  void removeComponent(T : Component)(T c) {
    import std.algorithm : countUntil, remove;
    auto idx = components.countUntil!"a is b"(c);
    if (idx < 0) return;
    version(Editor) 
      c.onEditorDestroy();
    else
      c.onDestory();
    components = components.remove(idx);
  }

  void start() {
    foreach (c; components)
      if (c.enabled) c.onStart();

    foreach (c; transform.children)
      if (c.gameObject.active) c.gameObject.start();
    
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

    foreach (c; transform.children)
      if (c.gameObject.active) c.gameObject.draw();
  }

  void destroy() {
    foreach (c; components)
      c.onDestroy();

    foreach (c; transform.children)
      c.gameObject.destroy();
  }

  version(Editor) {
    void editorStart() {
      foreach (c; components)
        if (c.enabled) c.onEditorStart();
      
      foreach (c; transform.children)
        if (c.gameObject.active) c.gameObject.editorStart();

      started = true;
    }

    void editorDestroy() {
      foreach (c; components)
        c.onEditorDestroy();
      
      foreach (c; transform.children)
        c.gameObject.editorDestroy();
    }
  }
}
