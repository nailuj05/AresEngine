module engine.rendering.modelrenderer;

import std.string : toStringz;
import std.format : format;

import raylib;
import raygui;

import engine.asset;
import engine.models.model;
import engine.models.modelmanager;
import engine.materials.material;
import engine.materials.materialmanager;
import engine.shaders.ashader : toRaylibUniformType, ShaderUniform;
import engine.rendering.drawcontext;
import engine.core.component;

class ModelRenderer : Component {
  mixin Named!"ModelRenderer";

  @Asset(AssetKind.Model) string modelPath;
  string[] materials; // parallel to meshGroups; empty = default material

  private struct CachedDraw {
    Mesh            mesh;
    Material        mat;
    ShaderUniform[] matUniforms;
    EngineUniformLocs engineLocs;
  }

  private ModelHandle    modelHandle;
  private MaterialHandle[] matHandles;
  private CachedDraw[]   drawCache;

  override void onStart() {
    modelHandle = ModelManager.instance.acquire(modelPath);
    auto asset  = ModelManager.instance.get(modelHandle);

    // pad materials to mesh count, preserving any already set
    if (materials.length < asset.meshGroups.length)
      materials.length = asset.meshGroups.length;

    matHandles.length = asset.meshGroups.length;
    foreach (i, ref h; matHandles)
      h = materials[i].length
        ? MaterialManager.instance.acquire(materials[i])
        : MaterialManager.instance.defaultMaterial();

    buildCache();
  }

  override void onDraw(DrawContext ctx) {
    if (!modelHandle) return;
    Matrix world = owner.transform.worldMatrix();
    foreach (ref cd; drawCache) {
      Material mat = cd.mat;
      if (cd.engineLocs.viewPos != -1)
        SetShaderValue(mat.shader, cd.engineLocs.viewPos, &ctx.camera.position, ShaderUniformDataType.SHADER_UNIFORM_VEC3);
      if (cd.engineLocs.time != -1)
        SetShaderValue(mat.shader, cd.engineLocs.time, &ctx.time, ShaderUniformDataType.SHADER_UNIFORM_FLOAT);
      foreach (ref u; cd.matUniforms)
        SetShaderValue(mat.shader, u.loc, u.data.ptr, toRaylibUniformType(u.type));
      DrawMesh(cd.mesh, mat, world);
    }
  }

  override void onDestroy() {
    foreach (ref h; matHandles)
      MaterialManager.instance.release(h);
    matHandles = null;
    drawCache  = null;
    ModelManager.instance.release(modelHandle);
    modelHandle = ModelHandle.init;
  }
  
  void setMaterial(size_t slot, string matPath) {
    assert(slot < matHandles.length);
    MaterialManager.instance.release(matHandles[slot]);
    materials[slot]  = matPath;
    matHandles[slot] = matPath.length
      ? MaterialManager.instance.acquire(matPath)
      : MaterialManager.instance.defaultMaterial();
    drawCache[slot]  = buildCachedDraw(drawCache[slot].mesh, matHandles[slot]);
  }
  
  void reload() {
    version(Editor) { onEditorDestroy(); onEditorStart(); }
    else             { onDestroy();       onStart(); }
  }

  private void buildCache() {
    auto asset    = ModelManager.instance.get(modelHandle);
    drawCache.length = asset.meshGroups.length;
    foreach (i, ref g; asset.meshGroups)
      drawCache[i] = buildCachedDraw(g.mesh, matHandles[i]);
  }

  private CachedDraw buildCachedDraw(Mesh mesh, MaterialHandle h) {
    auto a = MaterialManager.instance.get(h);
    CachedDraw cd;
    cd.mesh        = mesh;
    cd.mat         = a.raylibMaterial;
    cd.matUniforms = a.uniforms;
    cd.engineLocs  = a.engineLocs;
    return cd;
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

      foreach (i, ref mat; materials) {
        if (drawAssetField!(AssetKind.Material)(format!"Material %d"(i), mat, offsetX, endY, panelW)) {
          reload();
        }
        endY += ROW_H;
      }
      return endY;
    }
  }
}
