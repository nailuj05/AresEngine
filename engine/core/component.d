module engine.core.component;

import engine.core.gameobject;

mixin template Named(string s)
{
  override @property string name() const
  {
    return s;
  }
}

abstract class Component {
  GameObject owner;
  bool enabled = true;
  @property string name() const;

  void onStart()          {}
  void onUpdate(float dt) {}
  void onDraw()           {}
  void onDestroy()        {}

  version(Editor) {
    abstract void drawInspector(ulong offsetX, ulong offsetY) {}
  }
}
