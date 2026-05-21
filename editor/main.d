module main;

import std.getopt;
import std.format : format;
import std.file   : exists, readText, write;

import raylib;
import raygui;

import engine.manifest;
import engine.versioninfo;
import engine.core.window;
import engine.core.component;
import engine.core.gameobject;
import engine.scene.scene;
import engine.scene.loader;
import engine.renderer.meshrenderer;

import editor.style;
import editor.layout;
import editor.topbar;
import editor.filedialog;
import editor.editorcamera;
import editor.viewport.viewport;
import editor.inspector.inspector;
import editor.hierarchy.hierarchy;

// Project
private string projectPath;
private Manifest projectManifest;

// Scene
private Scene           activeScene;
private GameObject      selected;
private RenderTexture2D sceneTarget;
private Camera3D        editorCam;

// Editor
private FileDialog fileDialog;
private bool exitRequested;

enum TOP_BAR_SIZE = 24;

int main(string[] args) {
  // getopt
  string path;
  bool help, test;
  getopt(args, "help|h", &help, "test|d", &test,);

  if (help) {
    log("usage: editor [--test] <path>");
    return 0;
  }

  if (!test) {
    if (args.length < 2) {
      log("error: missing project path");
      return 1;
    }
    path = args[1];

    
    Manifest loadedManifest;
    string manifestPath = path ~ "manifest.json";
    
    if (!exists(manifestPath)) {
      log("Manifest file not found in ", path);
      return 1;
    }

    try {
      loadedManifest = new Manifest(readText(manifestPath));
    } catch (Exception e) {
      log("Error parsing manifest file ", manifestPath, "\n", e.toString());
      return 1;
    }

    if (compareVersion(loadedManifest.projectVersion, VERSION) > 0) {
      log(format("Project version (%s) is newer than editor version (%s)",
                 loadedManifest.projectVersion, VERSION));
      return 0;
    }

    // TODO: Load default scene etc.
  }

  // Init Editor
  initWindow(WindowConfig(1920, 1080, "AresEngine - Editor", 60));
  SetExitKey(KeyboardKey.KEY_NULL);

  Font font = LoadFontEx("vendor/fonts/Inter.ttf", TEXT_SZ, null, 0);
  GuiSetFont(font);
  setDarkTheme();

  Rectangle topBar, hierarchy, viewport, inspector, folder;
  computeLayout(TOP_BAR_SIZE, 0.20f, 0.20f, 0.25f, topBar, hierarchy, viewport, inspector, folder);
  
  scope(exit) closeWindow();

  sceneTarget = LoadRenderTexture(cast(int)viewport.width, cast(int)viewport.height);
  scope(exit) UnloadRenderTexture(sceneTarget);

  editorCam = createEditorCamera();

  if (test) {
    activeScene      = new Scene("untitled");
    activeScene.createObject("Camera");
    auto player = activeScene.createObject("Player");
    auto mesh   = player.addComponent!MeshRenderer();
    mesh.mesh   = GenMeshCube(1.0f, 1.0f, 1.0f);
    mesh.color  = Colors.RED;
  }
  
  activeScene.start();

  while (!exitRequested) {
    immutable float dt = GetFrameTime();
    activeScene.update(dt);

    computeLayout(TOP_BAR_SIZE, 0.20f, 0.20f, 0.25f, topBar, hierarchy, viewport, inspector, folder);

    if (!fileDialog.active) // camera should not move when file dialog is open
      updateEditorCamera(editorCam, viewport);

    // resize viewport rt if viewport size changed
    if (viewport.width != sceneTarget.texture.width || viewport.height != sceneTarget.texture.height)
      resizeSceneTarget(sceneTarget, cast(int)viewport.width, cast(int)viewport.height);
 
    renderScene(activeScene);

    BeginDrawing();
      ClearBackground(Colors.BLACK);
      drawHierarchy(hierarchy, activeScene, selected);
      drawViewport(viewport, sceneTarget);
      drawInspector(inspector, selected);
      drawFolder(folder);
      auto action = drawTopBar(topBar, activeScene.name);

      drawFileDialog(fileDialog);
    EndDrawing();

    // handle action from topbar
    switch (action.menu) {
      case 0:  handleProject(action.item); break;
      default: break;
    }
  }
  return 0;
}

void renderScene(Scene scene) {
  BeginTextureMode(sceneTarget);
  ClearBackground(Color(60, 60, 60, 255));
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

void drawFolder(Rectangle r) {
  DrawRectangle(cast(int)r.x, cast(int)r.y, cast(int)r.width, cast(int)r.height, GetColor(PANEL_BG));
  GuiPanel(r, "Project Folder");
}

void drawFileDialog(ref FileDialog fileDialog) {
  import std.path : baseName;
  if (fileDialog.active) {
    if (fileDialog.draw()) {
      if (!fileDialog.cancelled) {
        final switch (fileDialog.mode) {
        case FileDialogMode.Open:
          loadScene(fileDialog.result);
          break;
        case FileDialogMode.Save:
          activeScene.name = baseName(fileDialog.result);
          saveScene(activeScene, fileDialog.result);
          break;
        }
      }
    }
  }
}

      
// TopBar Handlers
void handleProject(int item) {
  switch (item) {
  case 0: /*New    */ break;
  case 1: /*Open   */ fileDialog.show(FileDialogMode.Open, "", ".json"); break;
  case 2: /*Save   */ saveScene(activeScene, activeScene.name ~ ".json"); break;
  case 3: /*Save As*/ fileDialog.show(FileDialogMode.Save, "", ".json"); break;
  case 4: /*Exit   */ exitRequested = true; break;
  default: break;
  }
}

void log(T...)(T args) {
  import std.stdio : write, writeln;
  write("[AresEditor] ");
  writeln(args);
}
