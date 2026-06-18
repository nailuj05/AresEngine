module engine.rendering.modelrenderer;

import std.string : toStringz;

import raylib;
import raygui;

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
  
  private Mesh[]     _meshCache; // GPU handles, stable
  private Material[] _matCache;  // value copies, cheap
  
  override void onStart() {
    _modelHandle = ModelManager.instance.acquire(modelPath);
    auto asset   = ModelManager.instance.get(_modelHandle);
    _matHandles.length = asset.meshGroups.length;
    foreach (ref h; _matHandles)
      h = MaterialManager.instance.defaultMaterial();
    buildCache();
  }

  override void onDraw() {
    if (!_modelHandle) return;
    foreach (i, ref mesh; _meshCache)
      DrawMesh(mesh, _matCache[i], owner.transform.worldMatrix());
  }

  override void onDestroy() {
    import std.stdio;
    writeln("destroy");
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

  void reloadMaterials() {
    foreach (i, ref h; _matHandles)
      _matCache[i] = MaterialManager.instance.get(h).raylibMaterial;
  }
  
  private void buildCache() {
    auto modelAsset  = ModelManager.instance.get(_modelHandle);
    _meshCache.length = modelAsset.meshGroups.length;
    _matCache.length  = modelAsset.meshGroups.length;
    foreach (i, ref g; modelAsset.meshGroups)
      _meshCache[i] = g.mesh;
    reloadMaterials();
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

      Rectangle btn = Rectangle(offsetX + 8, endY, panelW - 16, 20);
      if (GuiButton(btn, "Load Materials from Model".toStringz())) {
        import std.stdio;
        writeln("reload");
      }

      endY += 28;
      
      return endY;
    }
  }
}
