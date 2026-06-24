module editor.dialog.material;

import raylib;
import raygui;

import std.algorithm : clamp;
import std.string    : toStringz, fromStringz;
import std.format    : format;
import std.conv      : to;
import std.path      : relativePath;

import engine.shaders.ashader;
import engine.materials.material;
import engine.materials.materialmanager;
import engine.models.model;
import engine.models.modelmanager;
import engine.core.gameobject;
import engine.core.component;
import engine.rendering.modelrenderer;
import engine.rendering.drawcontext;

import editor.project.project : getCurrentProjectPath;
import editor.editorcamera;
import editor.style;
import editor.inspector.drawer;

private enum WIN_W   = 820.0f;
private enum WIN_H   = 560.0f;
private enum HEADER  = 24;
private enum PAD     =  8;
private enum BTN_H   = 28;
private enum BTN_W   = 96;
private enum SB_W    = 12;

private enum PreviewPrimitive { Cube, Sphere }

// Primitive URI convention matches what ModelManager.acquire already handles.
private immutable string[2] PRIMITIVE_PATHS = ["primitive://cube", "primitive://sphere",];

struct MaterialDialog {
  bool active;

private:
  MaterialHandle     matHandle;
  string             path;

  // Preview scene objects -- one per primitive, swapped by setting modelPath.
  GameObject         previewObject;
  ModelRenderer      renderer;

  // layout
  Rectangle b;
  Vector2   pan;
  bool      drag;

  // 3D preview
  EditorCamera       previewCam;
  PreviewPrimitive   primitive;
  RenderTexture2D    previewRT;
  bool               rtReady;

  // inspector scroll + field states
  Vector2            scroll;
  FieldState[string] fieldStates;

  static bool s_open;

  // -------------------------------------------------------------------------
  void openRT(int w, int h) {
    if (rtReady) UnloadRenderTexture(previewRT);
    previewRT = LoadRenderTexture(w, h);
    rtReady   = true;
  }

  void closeRT() {
    if (rtReady) { UnloadRenderTexture(previewRT); rtReady = false; }
  }

  // Rebuild the preview object for the current primitive.
  // Releases the old renderer first so ModelManager refcounts stay correct.
  void resetPreviewObject() {
    if (previewObject !is null) {
      previewObject.editorDestroy();
      previewObject = null;
      renderer      = null;
    }

    previewObject      = new GameObject();
    previewObject.name = "__matPreview";
    renderer           = previewObject.addComponent!ModelRenderer();
    renderer.modelPath = PRIMITIVE_PATHS[cast(int)primitive];
    previewObject.editorStart();
    renderer.setMaterialOverride(0, path);
  }

  // -------------------------------------------------------------------------
  void drawPreview(Rectangle area) {
    int pw = cast(int)(area.width  - PAD * 2);
    int ph = cast(int)(area.height - PAD * 2);
    if (pw < 1 || ph < 1) return;

    if (!rtReady || previewRT.texture.width != pw || previewRT.texture.height != ph)
      openRT(pw, ph);

    Rectangle screenRect = Rectangle(area.x + PAD, area.y + PAD,
                                     cast(float)pw, cast(float)ph);
    previewCam.update(screenRect);

    DrawContext ctx = DrawContext(previewCam.cam);

    BeginTextureMode(previewRT);
    ClearBackground(GetColor(0x1A1A1AFF));
    BeginMode3D(previewCam.cam);
    if (previewObject !is null && renderer !is null)
      renderer.onDraw(ctx);
    EndMode3D();
    EndTextureMode();

    Rectangle src = Rectangle(0, 0, cast(float)pw, cast(float)-ph);
    DrawTexturePro(previewRT.texture, src, screenRect, Vector2(0, 0), 0.0f, Colors.WHITE);

    // Primitive toggle -- rebuild preview object only on change.
    float bx = area.x + PAD;
    float by  = area.y + PAD;
    PreviewPrimitive prev = primitive;
    if (GuiButton(Rectangle(bx,      by, 72, 20), "Cube"))   primitive = PreviewPrimitive.Cube;
    if (GuiButton(Rectangle(bx + 76, by, 72, 20), "Sphere")) primitive = PreviewPrimitive.Sphere;
    if (primitive != prev) resetPreviewObject();
  }

  // -------------------------------------------------------------------------
  void drawUniforms(Rectangle area) {
    auto asset = MaterialManager.instance.get(matHandle);
    if (!asset) {
      DrawGuiText("Asset not loaded.".toStringz,
                  cast(int)(area.x + PAD), cast(int)(area.y + PAD),
                  TEXT_SZ, GetColor(0x888888FF));
      return;
    }

    float x  = area.x + PAD;
    float y  = area.y + PAD;
    float pw = area.width - PAD * 2;

    GuiLabel(Rectangle(x, y, LABEL_W, FIELD_H), "Path:");
    string relPath = relativePath(path, getCurrentProjectPath());
    DrawGuiText(relPath.toStringz,
                cast(int)(x + LABEL_W + 4), cast(int)y,
                TEXT_SZ, GetColor(0xAAAAAFFF));
    y += ROW_H;

    GuiLine(Rectangle(x, y, pw, 1), null);
    y += PAD;

    GuiLabel(Rectangle(x, y, pw, FIELD_H), "Uniforms");
    y += ROW_H;

    float listH = area.height - (y - area.y) - PAD;
    if (listH < 1) return;

    float rowsH = cast(float)(asset.uniforms.length * ROW_H + PAD);
    Rectangle view    = Rectangle(x, y, pw, listH);
    Rectangle content = Rectangle(0, 0, pw - SB_W, rowsH);
    Rectangle scissor;

    GuiScrollPanel(view, null, content, &scroll, &scissor);
    scroll.x = 0;

    BeginScissorMode(cast(int)scissor.x, cast(int)scissor.y,
                     cast(int)scissor.width, cast(int)scissor.height);

    float ry = y + scroll.y + PAD;

    foreach (i, ref u; asset.uniforms) {
      float rowY = ry + cast(float)i * ROW_H;
      if (rowY + ROW_H < view.y || rowY > view.y + listH) continue;

      string kbase = format!"u%d"(i);
      bool   changed = false;

      switch (u.type) {
      case UniformType.Float: {
        string k = kbase ~ ".x";
        if (k !in fieldStates) fieldStates[k] = FieldState.init;
        changed = drawField(u.name, u.data[0], fieldStates[k], x, rowY, pw);
        if (changed)
          SetShaderValue(asset.raylibMaterial.shader, u.loc,
                         &u.data[0], ShaderUniformDataType.SHADER_UNIFORM_FLOAT);
        break;
      }
      case UniformType.Int: {
        string k = kbase ~ ".x";
        if (k !in fieldStates) fieldStates[k] = FieldState.init;
        int iv = cast(int)u.data[0];
        changed = drawField(u.name, iv, fieldStates[k], x, rowY, pw);
        if (changed) {
          u.data[0] = cast(float)iv;
          SetShaderValue(asset.raylibMaterial.shader, u.loc,
                         &iv, ShaderUniformDataType.SHADER_UNIFORM_INT);
        }
        break;
      }
      case UniformType.Vec2: {
        string kx = kbase ~ ".x", ky = kbase ~ ".y";
        if (kx !in fieldStates) fieldStates[kx] = FieldState.init;
        if (ky !in fieldStates) fieldStates[ky] = FieldState.init;
        FieldState[3] fs = [fieldStates[kx], fieldStates[ky], FieldState.init];
        changed = drawVec3Field(u.name, u.data[0], u.data[1], u.data[2], fs, x, rowY, pw);
        fieldStates[kx] = fs[0]; fieldStates[ky] = fs[1];
        if (changed)
          SetShaderValue(asset.raylibMaterial.shader, u.loc,
                         u.data.ptr, ShaderUniformDataType.SHADER_UNIFORM_VEC2);
        break;
      }
      case UniformType.Vec3: {
        string kx = kbase ~ ".x", ky = kbase ~ ".y", kz = kbase ~ ".z";
        if (kx !in fieldStates) fieldStates[kx] = FieldState.init;
        if (ky !in fieldStates) fieldStates[ky] = FieldState.init;
        if (kz !in fieldStates) fieldStates[kz] = FieldState.init;
        FieldState[3] fs = [fieldStates[kx], fieldStates[ky], fieldStates[kz]];
        changed = drawVec3Field(u.name, u.data[0], u.data[1], u.data[2], fs, x, rowY, pw);
        fieldStates[kx] = fs[0]; fieldStates[ky] = fs[1]; fieldStates[kz] = fs[2];
        if (changed)
          SetShaderValue(asset.raylibMaterial.shader, u.loc,
                         u.data.ptr, ShaderUniformDataType.SHADER_UNIFORM_VEC3);
        break;
      }
      case UniformType.Vec4: {
        string kx = kbase ~ ".x", ky = kbase ~ ".y",
          kz = kbase ~ ".z", kw = kbase ~ ".w";
        if (kx !in fieldStates) fieldStates[kx] = FieldState.init;
        if (ky !in fieldStates) fieldStates[ky] = FieldState.init;
        if (kz !in fieldStates) fieldStates[kz] = FieldState.init;
        if (kw !in fieldStates) fieldStates[kw] = FieldState.init;
        FieldState[3] fs = [fieldStates[kx], fieldStates[ky], fieldStates[kz]];
        changed = drawVec3Field(u.name, u.data[0], u.data[1], u.data[2], fs, x, rowY, pw);
        fieldStates[kx] = fs[0]; fieldStates[ky] = fs[1]; fieldStates[kz] = fs[2];
        if (drawField("w", u.data[3], fieldStates[kw],
                      x + LABEL_W, rowY + FIELD_H + 2, pw - LABEL_W))
          changed = true;
        if (changed)
          SetShaderValue(asset.raylibMaterial.shader, u.loc,
                         u.data.ptr, ShaderUniformDataType.SHADER_UNIFORM_VEC4);
        break;
      }
      default: break;
        // TODO: map slots (diffuse, normal, etc.)
      }
    }

    EndScissorMode();
  }

public:
  void show(string materialPath) {
    if (s_open) return;
    s_open = true;

    path        = materialPath;
    matHandle   = MaterialManager.instance.acquire(materialPath);
    active      = true;
    primitive   = PreviewPrimitive.Sphere;
    scroll      = Vector2(0, 0);
    fieldStates = null;
    drag        = false;
    previewCam  = EditorCamera.create(Vector3(0, 2, 4));

    b = Rectangle(
                  GetScreenWidth()  / 2.0f - WIN_W / 2.0f,
                  GetScreenHeight() / 2.0f - WIN_H / 2.0f,
                  WIN_W, WIN_H
                  );

    resetPreviewObject();
  }

  void close() {
    if (!s_open) return;

    if (previewObject !is null) {
      previewObject.editorDestroy();
      previewObject = null;
      renderer      = null;
    }

    if (matHandle) MaterialManager.instance.release(matHandle);
    matHandle = MaterialHandle.init;

    closeRT();
    active = false;
    s_open = false;
  }

  // Returns true on the frame the window closes.
  bool draw() {
    if (!active) return false;

    Vector2   mouse    = GetMousePosition();
    Rectangle titleBar = Rectangle(b.x, b.y, b.width, HEADER);

    if (IsMouseButtonPressed(MouseButton.MOUSE_BUTTON_LEFT) &&
        CheckCollisionPointRec(mouse, titleBar)) {
      drag = true;
      pan  = Vector2(mouse.x - b.x, mouse.y - b.y);
    }
    if (drag) {
      b.x = clamp(mouse.x - pan.x, 0.0f, cast(float)GetScreenWidth()  - b.width);
      b.y = clamp(mouse.y - pan.y, 0.0f, cast(float)GetScreenHeight() - b.height);
      if (IsMouseButtonReleased(MouseButton.MOUSE_BUTTON_LEFT)) drag = false;
    }

    if (GuiWindowBox(b, "Material Inspector")) { close(); return true; }

    float contentY   = b.y + HEADER + PAD;
    float contentH   = b.height - HEADER - PAD * 2;
    float previewW   = b.width * (2.0f / 3.0f);
    float inspectorW = b.width - previewW;

    Rectangle previewArea   = Rectangle(b.x,            contentY, previewW,   contentH);
    Rectangle inspectorArea = Rectangle(b.x + previewW, contentY, inspectorW, contentH);

    DrawLine(cast(int)(b.x + previewW), cast(int)contentY,
             cast(int)(b.x + previewW), cast(int)(contentY + contentH),
             GetColor(0x2A2A2AFF));

    drawPreview(previewArea);
    drawUniforms(inspectorArea);

    return false;
  }
}
