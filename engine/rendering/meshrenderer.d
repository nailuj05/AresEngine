module engine.rendering.meshrenderer;

import raylib;

import engine.core.component;

class MeshRenderer : Component {
  mixin Named!"MeshRenderer";
  
  // TODO: make this proper
  string meshPath;
  @DontSerialize Mesh mesh;
  Color color = Color(255, 0, 0);
  
  private Material mat;
  
  override void onStart() {
    mesh = GenMeshCube(1.0f, 1.0f, 1.0f);

    // TODO: Proper Materials, Shaders etc
    mat = LoadMaterialDefault();
    mat.maps[MATERIAL_MAP_DIFFUSE].color = color;
  }
  
  override void onDraw() {
    mat.maps[MATERIAL_MAP_DIFFUSE].color = color;
    DrawMesh(mesh, mat, owner.transform.worldMatrix()); 
  }

  override void onDestroy() {
    UnloadMaterial(mat);
    UnloadMesh(mesh);
  }
  
  version(Editor) {
    import editor.inspector.drawer;
  
    override void onEditorStart() {
      onStart();
    }

    override void onEditorDestroy() {
      onDestroy();
    }
    
    private FieldState[string] fieldStates;
    
    override float drawInspector(float offsetX, float offsetY, float panelW) {
      auto self = this;
      return drawFields(self, fieldStates, offsetX, offsetY, panelW);
    }
  }
}
