module main;

import raylib;
import raygui;

import engine.core.window;
import engine.core.component;
import engine.core.gameobject;
import engine.scene.scene;
import engine.renderer.meshrenderer;

import editor.style;
import editor.layout;
import editor.inspector.inspector;
import editor.viewport.viewport;
import editor.hierarchy.hierarchy;
import editor.editorcamera;

private Scene           activeScene;
private GameObject      selected;
private RenderTexture2D sceneTarget;
private Camera3D        editorCam;

enum TOP_BAR_SIZE = 20;

void main() {
  initWindow(WindowConfig(1920, 1080, "AresEngine - Editor", 60));

  Font font = LoadFontEx("vendor/fonts/Inter.ttf", TEXT_SZ, null, 0);
  GuiSetFont(font);

  setDarkTheme();

  Rectangle topBar, hierarchy, viewport, inspector, folder;
  computeLayout(TOP_BAR_SIZE, 0.15f, 0.20f, 0.25f, topBar, hierarchy, viewport, inspector, folder);
  
  scope(exit) closeWindow();

  sceneTarget = LoadRenderTexture(cast(int)viewport.width, cast(int)viewport.height);
  scope(exit) UnloadRenderTexture(sceneTarget);

  editorCam = createEditorCamera();
  
  // TODO: This will be replaced with the loading of a proper scene
  activeScene      = new Scene("untitled");
  activeScene.createObject("Camera");
  auto player = activeScene.createObject("Player");
  auto mesh   = player.addComponent!MeshRenderer();
  mesh.mesh   = GenMeshCube(1.0f, 1.0f, 1.0f);
  mesh.color  = Colors.RED;

  activeScene.start();

  while (!shouldClose()) {
    immutable float dt = GetFrameTime();
    activeScene.update(dt);

    computeLayout(TOP_BAR_SIZE, 0.15f, 0.20f, 0.25f, topBar, hierarchy, viewport, inspector, folder);

    updateEditorCamera(editorCam, viewport);
    if (viewport.width != sceneTarget.texture.width || viewport.height != sceneTarget.texture.height)
      resizeSceneTarget(sceneTarget, cast(int)viewport.width, cast(int)viewport.height);
 
    renderScene(activeScene);

    BeginDrawing();
      ClearBackground(Colors.BLACK);
      drawTopBar(topBar);
      drawHierarchy(hierarchy, activeScene, selected);
      drawViewport(viewport, sceneTarget);
      drawInspector(inspector, selected);
      drawFolder(folder);
    EndDrawing();
  }
}

void renderScene(Scene scene) {
  BeginTextureMode(sceneTarget);
  ClearBackground(Colors.DARKGRAY);
  BeginMode3D(editorCam);
    DrawGrid(20, 1.0f);
    scene.draw();
  EndMode3D();
  EndTextureMode();
}

void resizeSceneTarget(ref RenderTexture2D target, int w, int h) {
    UnloadRenderTexture(target);
    target = LoadRenderTexture(w, h);
}

void drawTopBar(Rectangle r) {
    DrawRectangle(cast(int)r.x, cast(int)r.y, cast(int)r.width, cast(int)r.height, GetColor(PANEL_BG));

    enum BUTTON_W = 80;
    enum BUTTON_PAD = 0;
    float x = r.x + BUTTON_PAD;

    if (GuiButton(Rectangle(x, r.y + BUTTON_PAD, BUTTON_W, r.height - BUTTON_PAD * 2), "File"))
        {} // open file menu
    x += BUTTON_W + BUTTON_PAD;

    if (GuiButton(Rectangle(x, r.y + BUTTON_PAD, BUTTON_W, r.height - BUTTON_PAD * 2), "Edit"))
        {}
    x += BUTTON_W + BUTTON_PAD;

    if (GuiButton(Rectangle(x, r.y + BUTTON_PAD, BUTTON_W, r.height - BUTTON_PAD * 2), "Scene"))
        {}
    x += BUTTON_W + BUTTON_PAD;
}

void drawFolder(Rectangle r) {
  DrawRectangle(cast(int)r.x, cast(int)r.y, cast(int)r.width, cast(int)r.height, GetColor(PANEL_BG));
  GuiPanel(r, "Project Folder");
}
