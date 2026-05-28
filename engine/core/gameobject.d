module engine.core.gameobject;

import raylib : Vector3, Quaternion;

import engine.core.transform;
import engine.core.component;

class GameObject {
  string       name;
  bool         active = true;
  Transform    transform;
  Component[]  components;
  GameObject   parent;
  GameObject[] children;

  private bool started = false;
  
  version(Editor) {
    import editor.inspector.drawer;
    FieldState    nameFS;
    FieldState[3] posFS;
    FieldState[3] rotFS;
    FieldState[3] scaleFS;

    bool expanded = true;
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

  void addChild(GameObject child, bool keepWorldPos = true) nothrow {
    Vector3    wp = child.transform.position;
    Quaternion wr = child.transform.rotation;
    Vector3    ws = child.transform.scale;

    if (child.parent !is null)
      child.parent.removeChild(child, false);

    children          ~= child;
    child.parent       = this;
    child.transform.parent = &transform;  // only pointer, no _children bookkeeping
    _propagateDirty(child);

    if (keepWorldPos) {
      child.transform.position = wp;
      child.transform.rotation = wr;
      child.transform.scale    = ws;
    }
  }

  void removeChild(GameObject child, bool keepWorldPos = true) nothrow {
    import std.algorithm : remove;

    Vector3    wp = child.transform.position;
    Quaternion wr = child.transform.rotation;
    Vector3    ws = child.transform.scale;

    children                = children.remove!(c => c is child);
    child.parent            = null;
    child.transform.parent  = null;
    _propagateDirty(child);

    if (keepWorldPos) {
      child.transform.position = wp;
      child.transform.rotation = wr;
      child.transform.scale    = ws;
    }
  }

  void setParent(GameObject newParent, bool keepWorldPos = true) nothrow {
    if (parent is newParent) return;
    if (newParent !is null)
      newParent.addChild(this, keepWorldPos);
    else if (parent !is null)
      parent.removeChild(this, keepWorldPos);
  }

  void detachChildren(bool keepWorldPos = true) nothrow {
    auto snap = children.dup;
    foreach (c; snap)
      removeChild(c, keepWorldPos);
  }

  // walk the GO tree to propagate world dirty downward
  private static void _propagateDirty(GameObject node) nothrow {
    node.transform.markWorldDirty();
    foreach (c; node.children)
      _propagateDirty(c);
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

    foreach (c; children)
      if (c.active) c.draw();
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
