module engine.core.component;

import engine.core.gameobject;

mixin template Named(string s)
{
  enum string typeName = s; // for serialization
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
    abstract ulong drawInspector(ulong offsetX, ulong offsetY, ulong panelW);
  }
}
