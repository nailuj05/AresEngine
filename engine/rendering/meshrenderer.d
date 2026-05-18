module engine.renderer.meshrenderer;

import raylib;
import std.stdio;
import engine.core.component;

class MeshRenderer : Component {
  public Mesh mesh;
  public Colors color;

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
}
