module engine.oscillator;

import std.math;

import raylib;

import engine.core.component;
import engine.core.transform;

class Oscillator : Component {
  mixin Named!"Oscillator";
  
  Axis axis = Axis.Y;
  float frequency = 1;
  float amplitude = 1;
  
  private float t = 0;
  
  override void onUpdate(float dt) {
    t += dt;
    switch (axis) {
      case Axis.X: owner.transform.position.x = sin(frequency * t) * amplitude; break;
      case Axis.Y: owner.transform.position.y = sin(frequency * t) * amplitude; break;
      case Axis.Z: owner.transform.position.z = sin(frequency * t) * amplitude; break; 
      default: break;
    }
  }

  version(Editor) {
    import editor.inspector.drawer;

    private FieldState[string] fieldStates;
    
    override ulong drawInspector(ulong offsetX, ulong offsetY, ulong panelW) {
      auto self = this;
      return drawFields(self, fieldStates, offsetX, offsetY, panelW);
    }
  }
}
