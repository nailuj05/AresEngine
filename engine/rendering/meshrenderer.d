module engine.renderer.meshrenderer;

import raylib;

import engine.core.component;

class MeshRenderer : Component {
  mixin Named!"MeshRenderer";
  
  // TODO: make this proper
  string meshPath;
  @DontSerialize Mesh mesh;
  Color color = Color(255, 0, 0);
  
  string testString = "hi";
  float testFloat = 67.6767f;
  int testInt = 420;
  bool testBool = false;
  
  private Model model;
  
  override void onStart() {
    model = LoadModelFromMesh(mesh);
  }
  
  override void onDraw() {
    model.transform = owner.transform.worldMatrix();
  
    DrawModel(model, Vector3.zero, 1.0f, color); 
  }

  override void onDestroy() {
    UnloadModel(model);
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
