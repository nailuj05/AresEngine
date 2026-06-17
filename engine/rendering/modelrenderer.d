module engine.rendering.modelrenderer;
import raylib;
import engine.asset;
import engine.models.model;
import engine.models.modelmanager;
import engine.materials.material;
import engine.materials.materialmanager;
import engine.core.component;

class ModelRenderer : Component {
  mixin Named!"ModelRenderer";

  @Asset(AssetKind.Model) string modelPath;

  private ModelHandle    _modelHandle;
  private MaterialHandle[] _matHandles; // one per mesh group, all default on start

  override void onStart() {
    _modelHandle = ModelManager.instance.acquire(modelPath);
    auto asset   = ModelManager.instance.get(_modelHandle);
    _matHandles.length = asset.meshGroups.length;
    foreach (ref h; _matHandles)
      h = MaterialManager.instance.defaultMaterial();
  }

  override void onDraw() {
    if (!_modelHandle) return;
    auto modelAsset = ModelManager.instance.get(_modelHandle);
    foreach (i, ref g; modelAsset.meshGroups) {
      auto matAsset = MaterialManager.instance.get(_matHandles[i]);
      Material mat  = matAsset.raylibMaterial;
      DrawMesh(g.mesh, mat, owner.transform.worldMatrix());
    }
  }

  override void onDestroy() {
    foreach (ref h; _matHandles)
      MaterialManager.instance.release(h);
    _matHandles = null;
    ModelManager.instance.release(_modelHandle);
    _modelHandle = ModelHandle.init;
  }

  void reload() {
    version(Editor) {
      onEditorDestroy();
      onEditorStart();
    } else {
      onDestroy();
      onStart();
    }
  }

  version(Editor) {
    import editor.inspector.drawer;
    override void onEditorStart()   { onStart(); }
    override void onEditorDestroy() { onDestroy(); }
    private FieldState[string] fieldStates;
    override float drawInspector(float offsetX, float offsetY, float panelW) {
      auto self = this;
      float endY = 0.0f;
      if (drawFields(self, fieldStates, offsetX, offsetY, panelW, &endY))
        reload();
      return endY;
    }
  }
}
