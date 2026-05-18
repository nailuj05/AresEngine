module main;

import raylib;
import raygui;
import engine.core.window;
import engine.core.component;
import engine.scene.scene;
import engine.scene.gameobject;
import engine.renderer.meshrenderer;
import editor.style;
import editor.inspector.inspector;

private Scene           activeScene;
private GameObject      selected;
private RenderTexture2D sceneTarget;
private Camera3D        editorCam;

enum HIERARCHY_W = 220;

int vpX() { return HIERARCHY_W; }
int vpW() { return GetScreenWidth()  - HIERARCHY_W - INSPECTOR_W; }
int vpH() { return GetScreenHeight(); }


void main() {
  initWindow(WindowConfig(1600, 900, "AresEngine - Editor", 60));

  Font font = LoadFontEx("vendor/fonts/Inter.ttf", TEXT_SZ, null, 0);
  GuiSetFont(font);

  setDarkTheme();

  scope(exit) closeWindow();

  sceneTarget = LoadRenderTexture(vpW(), vpH());
  scope(exit) UnloadRenderTexture(sceneTarget);

  editorCam = Camera3D(
                       Vector3(0, 10, 10),  // position
                       Vector3(0,  0,  0),  // target
                       Vector3(0,  1,  0),  // up
                       45.0f,
                       CameraProjection.CAMERA_PERSPECTIVE
                       );

  activeScene      = new Scene();
  activeScene.name = "untitled";
  activeScene.createObject("Camera");
  auto player = activeScene.createObject("Player");
  auto mesh   = player.addComponent!MeshRenderer();
  mesh.mesh   = GenMeshCube(1.0f, 1.0f, 1.0f);
  mesh.color  = Colors.RED;

  activeScene.start();
    
  while (!shouldClose()) {
    immutable float dt = GetFrameTime();
    activeScene.update(dt);

    renderScene(activeScene);

    BeginDrawing();
      ClearBackground(Colors.PINK);
      drawHierarchy();
      drawViewport();
      drawInspector(selected, GetScreenWidth() - INSPECTOR_W, GetScreenHeight());
    EndDrawing();
  }
}

void renderScene(Scene scene) {
  BeginTextureMode(sceneTarget);
  ClearBackground(Colors.BLUE);
  BeginMode3D(editorCam);
  DrawGrid(20, 1.0f);
  // TODO: traverse scene and call each renderer component
  scene.draw();
  EndMode3D();
  EndTextureMode();
}

void drawHierarchy() {
  immutable int h = GetScreenHeight();
  DrawRectangle(0, 0, HIERARCHY_W, h, GetColor(PANEL_BG));
  GuiPanel(Rectangle(0, 0, HIERARCHY_W, h), "Hierarchy");

  int y = 28;
  foreach (go; activeScene.roots) {
    if (GuiButton(Rectangle(4, y, HIERARCHY_W - 8, 22), go.name.ptr))
      selected = go;
    y += 26;
  }
}

void drawViewport() {
  // RenderTexture is stored upside-down in OpenGL -> negative height flips it
  immutable Rectangle src  = Rectangle(0, 0,  cast(float)  sceneTarget.texture.width,
                                       -cast(float)  sceneTarget.texture.height);
  immutable Rectangle dest = Rectangle(vpX(), TEXT_SZ + 2, vpW(), vpH());
  GuiPanel(Rectangle(vpX(), 0, vpW(), vpH()), "Viewport");
  DrawTexturePro(sceneTarget.texture, src, dest, Vector2(0, 0), 0.0f, Colors.WHITE);
}

