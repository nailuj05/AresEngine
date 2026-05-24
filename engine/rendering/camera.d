module engine.rendering.camera;

import raylib;

import engine.core.component;

class Camera : Component {
  mixin Named!"Camera";

  CameraProjection projection = CameraProjection.CAMERA_PERSPECTIVE;
  float fieldOfView = 80.0f;
  float nearPlane   = 0.1f;
  float farPlane    = 1000.0f; 
  
  @DontSerialize Camera3D rcamera; 
  private Vector3 forward;

  override void onStart() {
    rcamera.up         = Vector3(0, 1, 0);
    rcamera.projection = projection;
    rlSetClipPlanes(nearPlane, farPlane);
  }

  override void onUpdate(float dt) {
    rcamera.position   = owner.transform.position;
    rcamera.fovy       = fieldOfView;
    rcamera.up         = Vector3(0, 1, 0);
    rcamera.projection = projection;
    rcamera.target     = owner.transform.position + owner.transform.forward;
  }

  override void onDraw() {
    version(Editor) {
      Color colorSolid = Color(50, 50, 50);
      Color colorWire  = Color(10, 10, 10);

      Vector3 pos   = owner.transform.position;
      Vector3 fwd   = owner.transform.forward;

      int lenseSegs = projection == CameraProjection.CAMERA_PERSPECTIVE ? 12 : 4;
      
      DrawCylinderEx(pos, pos + fwd, 0.0f, 0.5f, lenseSegs, colorSolid);
      DrawCylinderEx(pos - fwd * 0.4f, pos + fwd * 0.4f, 0.45f, 0.45f, 4, colorSolid);
      DrawCylinderWiresEx(pos, pos + fwd, 0.0f, 0.5f, lenseSegs, colorWire);
      DrawCylinderWiresEx(pos - fwd * 0.4f, pos + fwd * 0.4f, 0.45f, 0.45f, 4, colorWire);
    }
  }

  override void onDestroy() {
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
