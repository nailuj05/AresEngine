module engine.rendering.modelrenderer;

import raylib;

import engine.asset;
import engine.models.model;
import engine.models.modelmanager;
import engine.materials.material;
import engine.materials.materialmanager;
import engine.rendering.drawcontext;
import engine.shaders.ashader : ShaderUniform, toRaylibUniformType;
import engine.core.component;

private struct CachedDraw {
  Mesh            mesh;
  Material        mat;
  ShaderUniform[] matUniforms;
  EngineUniformLocs engineLocs;
}

class ModelRenderer : Component {
  mixin Named!"ModelRenderer";

  @Asset(AssetKind.Model) string modelPath;

  private ModelHandle      _modelHandle;
  private MaterialHandle[] _matHandles;
  private MaterialHandle[] _overrides;   // parallel to _matHandles; invalid == use default
  private CachedDraw[]     _drawCache;
  
  private string[] _overridePaths; // parallel to _matHandles

  // Override a single material slot. Releases any previous override in
  // that slot. Pass MaterialHandle.init to clear the override and revert
  // to the default material assigned at load time.
  void setMaterialOverride(int slot, string path) {
    if (slot < 0 || slot >= cast(int)_matHandles.length) return;
    _overridePaths[slot] = path;
    // release old override handle if any
    if (_overrides[slot]) {
      MaterialManager.instance.release(_overrides[slot]);
      _overrides[slot] = MaterialHandle.init;
    }
    if (path.length > 0)
      _overrides[slot] = MaterialManager.instance.acquire(path);
    refreshMaterials();
  }

  void clearMaterialOverride(int slot) {
    if (slot < 0 || slot >= cast(int)_matHandles.length) return;
    _overridePaths[slot] = "";
    if (_overrides[slot]) {
      MaterialManager.instance.release(_overrides[slot]);
      _overrides[slot] = MaterialHandle.init;
    }
    refreshMaterials();
  }

  override void onStart() {
    _modelHandle = ModelManager.instance.acquire(modelPath);
    auto asset   = ModelManager.instance.get(_modelHandle);
    _matHandles.length = asset.meshGroups.length;
    _overrides.length  = asset.meshGroups.length;  // all init == invalid
    foreach (ref h; _matHandles)
      h = MaterialManager.instance.defaultMaterial();

    foreach (i, p; _overridePaths)
      if (p.length > 0)
        _overrides[i] = MaterialManager.instance.acquire(p);
    refreshMaterials();
    
    buildCache();
  }

  override void onDraw(DrawContext ctx) {
    if (!_modelHandle) return;
    Matrix world  = owner.transform.worldMatrix();
    Matrix normal = MatrixTranspose(MatrixInvert(world));
    foreach (ref d; _drawCache) {
      if (d.engineLocs.matModel  != -1) SetShaderValueMatrix(d.mat.shader, d.engineLocs.matModel,  world);
      if (d.engineLocs.matNormal != -1) SetShaderValueMatrix(d.mat.shader, d.engineLocs.matNormal, normal);
      foreach (ref u; d.matUniforms)
        SetShaderValue(d.mat.shader, u.loc, u.data.ptr, toRaylibUniformType(u.type));
      DrawMesh(d.mesh, d.mat, world);
    }
  }

  override void onDestroy() {
    foreach (ref h; _overrides)
      if (h) MaterialManager.instance.release(h);
    _overrides = null;

    foreach (ref h; _matHandles)
      MaterialManager.instance.release(h);
    _matHandles = null;
    _drawCache  = null;

    ModelManager.instance.release(_modelHandle);
    _modelHandle = ModelHandle.init;
  }

  // Rebuild the draw cache material entries, preferring override over default.
  void refreshMaterials() {
    foreach (i, ref h; _matHandles) {
      MaterialHandle active = (_overrides[i]) ? _overrides[i] : h;
      auto ma = MaterialManager.instance.get(active);
      _drawCache[i].mat         = ma.raylibMaterial;
      _drawCache[i].matUniforms = ma.uniforms;
      _drawCache[i].engineLocs  = ma.engineLocs;
    }
  }

  void reload() {
    version(Editor) { onEditorDestroy(); onEditorStart(); }
    else             { onDestroy();       onStart(); }
  }

  private void buildCache() {
    auto modelAsset   = ModelManager.instance.get(_modelHandle);
    _drawCache.length = modelAsset.meshGroups.length;
    foreach (i, ref g; modelAsset.meshGroups)
      _drawCache[i].mesh = g.mesh;
    refreshMaterials();
  }

  version(Editor) {
    import editor.inspector.drawer;
    override void onEditorStart()   { onStart(); }
    override void onEditorDestroy() { onDestroy(); }
    private FieldState[string] fieldStates;

    override float drawInspector(float offsetX, float offsetY, float panelW) {
      auto  self = this;
      float endY = 0.0f;
      if (drawFields(self, fieldStates, offsetX, offsetY, panelW, &endY))
        reload();
      return endY;
    }
  }
}
