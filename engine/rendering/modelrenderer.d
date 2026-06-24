module engine.rendering.modelrenderer;

import std.string : toStringz;
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

  private ModelHandle modelHandle;

  private struct CachedDraw {
    Mesh              mesh;
    Material          mat;
    ShaderUniform[]   matUniforms;
    EngineUniformLocs engineLocs;
  }

  // base[i] always valid after onStart; override[i] valid only if overrideHandles[i] is set
  private CachedDraw[]   base;
  private CachedDraw[]   overrides;
  private MaterialHandle[] baseHandles;
  private MaterialHandle[] overrideHandles;

  override void onStart() {
    if (modelPath == "") return;
    modelHandle = ModelManager.instance.acquire(modelPath);
    auto asset   = ModelManager.instance.get(modelHandle);
    size_t n     = asset.meshGroups.length;

    base            = new CachedDraw[n];
    overrides       = new CachedDraw[n];
    baseHandles     = new MaterialHandle[n];
    overrideHandles = new MaterialHandle[n];

    MaterialHandle def = MaterialManager.instance.defaultMaterial();
    foreach (i, ref g; asset.meshGroups) {
      baseHandles[i] = def;
      base[i]        = buildCachedDraw(g.mesh, def);
    }
  }

  override void onDraw(DrawContext ctx) {
    if (!modelHandle) return;
    Matrix world = owner.transform.worldMatrix();
    foreach (i, ref b; base) {
      ref CachedDraw cd = overrideHandles[i] ? overrides[i] : b;
      Material mat = cd.mat;
      foreach (ref u; cd.matUniforms)
        SetShaderValue(mat.shader, u.loc, u.data.ptr, toRaylibUniformType(u.type));
      DrawMesh(cd.mesh, mat, world);
    }
  }

  override void onDestroy() {
    import std.stdio;
    writeln("destroy");
    foreach (i; 0 .. base.length) {
      if (overrideHandles[i]) {
        MaterialManager.instance.release(overrideHandles[i]);
        overrideHandles[i] = MaterialHandle.init;
      }
    }
    // default material is pinned, release is a no-op but kept for correctness
    foreach (ref h; baseHandles)
      MaterialManager.instance.release(h);

    base            = null;
    overrides       = null;
    baseHandles     = null;
    overrideHandles = null;
    ModelManager.instance.release(modelHandle);
    modelHandle = ModelHandle.init;
  }

  void setMaterialOverride(size_t slot, string matPath) {
    auto handle = MaterialManager.instance.acquire(matPath);
    assert(slot < base.length);
    if (overrideHandles[slot])
      MaterialManager.instance.release(overrideHandles[slot]);
    overrideHandles[slot] = handle;
    overrides[slot]       = buildCachedDraw(base[slot].mesh, handle);
  }

  void clearMaterialOverride(size_t slot) {
    assert(slot < base.length);
    if (!overrideHandles[slot]) return;
    MaterialManager.instance.release(overrideHandles[slot]);
    overrideHandles[slot] = MaterialHandle.init;
    overrides[slot]       = CachedDraw.init;
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
      auto self = this;
      float endY = 0.0f;
      if (drawFields(self, fieldStates, offsetX, offsetY, panelW, &endY))
        reload();
      Rectangle btn = Rectangle(offsetX + 8, endY, panelW - 16, 20);
      if (GuiButton(btn, "Load Materials from Model".toStringz()))  {
        import std.stdio;
        writeln("reload");
      }
      endY += 28;
      return endY;
    }
  }
}
