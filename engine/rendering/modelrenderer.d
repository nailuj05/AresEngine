module engine.rendering.modelrenderer;

import raylib;

import engine.asset;
import engine.models.model;
import engine.models.modelmanager;
import engine.core.component;

class ModelRenderer : Component {
  mixin Named!"ModelRenderer";

  @Asset(AssetKind.Model) string modelPath;

  // per-material-slot overrides; shorter than asset.materials = no override for that slot
  Material[] materialOverrides;

  private ModelHandle _handle;

  @property ModelHandle handle() { return _handle; }

  override void onStart() {
    _handle = ModelManager.instance.acquire(modelPath);
  }

  override void onDraw() {
    if (!_handle) return;
    auto asset = ModelManager.instance.get(_handle);
    foreach (i, ref g; asset.meshGroups) {
      Material mat = resolveMaterial(asset, g.materialIndex);
      DrawMesh(g.mesh, mat, owner.transform.worldMatrix());
    }
  }

  override void onDestroy() {
    ModelManager.instance.release(_handle);
    _handle = ModelHandle.init;
  }

  private Material resolveMaterial(ModelAsset* asset, int slot) {
    if (slot < materialOverrides.length)
      return materialOverrides[slot];
    return asset.materials[slot];
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
      if (drawFields(self, fieldStates, offsetX, offsetY, panelW, &endY)) {
        // reload on change
        import std.stdio;
        writeln("changed");
        reload();
      }
      return endY;
    }
  }
}
