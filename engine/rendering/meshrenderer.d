module engine.renderer.meshrenderer;

import raylib;
import std.stdio;
import engine.core.component;

class MeshRenderer : Component {
  mixin Named!"MeshRenderer";
  
  Mesh mesh;
  Colors color;
  
  string testString = "hi";
  float testFloat = 67.6767f;
  int testInt = 420;
  bool testBool = false;
  
  private Model model;
  
  override void onStart() {
    model = LoadModelFromMesh(mesh);
  }
  
  override void onDraw() {
    DrawModel(model, owner.transform.position, 1.0f, color); 
  }

  override void onDestroy() {
    UnloadModel(model);
  }

  version(Editor) {
    import editor.inspector.drawer;

    private FieldState[string] fieldStates;
    
    override void drawInspector(ulong offsetX, ulong offsetY) {
      auto self = this;
      drawFields(self, fieldStates, offsetX, offsetY);
    }
  }
}
