module engine.core.gameobject;

import engine.core.transform;
import engine.core.component;

class GameObject {
  string       name;
  bool         active = true;
  Transform    transform;
  Component[]  components;
  GameObject[] children;

  private bool started = false;
  
  version(Editor) {
    import editor.inspector.drawer;
    FieldState    nameFS;
    FieldState[3] posFS;
    FieldState[3] rotFS;
    FieldState[3] scaleFS;
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

  void destroy() {
    foreach (c; components)
      c.onDestroy();

    foreach (go; children)
      go.destroy();
  }

  version(Editor) {
    void editorStart() {
      foreach (c; components)
        if (c.enabled) c.onEditorStart();
      
      started = true;
    }

    void editorDestroy() {
      foreach (c; components)
        c.onEditorDestroy();
      
      foreach (go; children)
        go.editorDestroy();
    }
  }
}
