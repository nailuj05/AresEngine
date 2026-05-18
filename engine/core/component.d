module engine.core.component;

import engine.scene.gameobject;

abstract class Component {
  GameObject owner;
  bool enabled = true;

  void onStart()          {}
  void onUpdate(float dt) {}
  void onDraw()           {}
  void onDestroy()        {}
}
