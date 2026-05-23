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
    float value = sin(frequency * t) * amplitude;
    Vector3 pos = owner.transform.position;
    final switch (axis) {
        case Axis.X: pos.x = value; break;
        case Axis.Y: pos.y = value; break;
        case Axis.Z: pos.z = value; break;
    }
    owner.transform.position = pos;
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
