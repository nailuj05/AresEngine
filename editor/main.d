module main;

import std.getopt;
import std.format : format;
import std.file   : exists, isDir, readText, write, getcwd;

import raylib;
import raygui;

import engine.manifest;
import engine.versioninfo;
import engine.core.window;
import engine.core.component;
import engine.core.gameobject;
import engine.scene.scene;
import engine.scene.loader;
import engine.rendering.camera : Camera;
import engine.rendering.meshrenderer;
import engine.oscillator;

import editor.style;
import editor.layout;
import editor.topbar;
import editor.filedialog;
import editor.settingsdialog;
import editor.colorpickerdialog;
import editor.editorcamera;
import editor.viewport.gizmos;
import editor.viewport.viewport;
import editor.inspector.inspector;
import editor.hierarchy.hierarchy;

// Comp-time embedded assets
static immutable ubyte[] FONT_DATA  = cast(immutable ubyte[]) import("fonts/Inter.ttf");
static immutable ubyte[] ICON_DATA  = cast(immutable ubyte[]) import("icons/logo-icon.png");

// Project
private string   projectPath;
private scope Manifest projectManifest;

// Scene
private Scene           activeScene;
private GameObject      selected;
private RenderTexture2D sceneTarget;
private Camera3D        editorCam;

// Editor
private GizmoState gizmo;
private FileDialog fileDialog;
private SettingsDialog settingsDialog;
import editor.inspector.drawer : colorPicker; 

private bool exitRequested;

enum TOP_BAR_SIZE = 24;

void log(T...)(T args) {
  import std.stdio : write, writeln;
  write("[AresEditor] ");
  writeln(args);
}

int main(string[] args) {
  bool help, newp, profile;
  getopt(args, "help|h", &help, "new|n", &newp, "profile|p", &profile);

  if (help) {
    log("usage: editor [--new] [--profile] <path>");
    return 0;
  }

  if (newp) {
    if (args.length < 2) {
      log("error: missing path");
      return 1;
    }
    projectPath = args[1];
    projectManifest.projectName    = "New Project";
    projectManifest.projectVersion = VERSION;
    activeScene = new Scene("main");

    string mainPath = projectPath ~ "/main.json";
    saveScene(activeScene, mainPath);
    projectManifest.projectScenes["main"] = mainPath;
    saveManifest();
    log("Created new project in ", projectPath);
  } else {
    if (args.length < 2) {
      log("error: missing project path");
      return 1;
    }

    string manifestPath = args[1] ~ "/manifest.json";

    if (!isDir(args[1])) {
      log("Error with project path: ", args[1]);
      return 1;
    }

    if (!exists(manifestPath)) {
      log("Manifest file not found in ", args[1]);
      return 1;
    }

    Manifest loadedManifest;
    try {
      loadedManifest = Manifest(readText(manifestPath));
    } catch (Exception e) {
      log("Error parsing manifest file ", manifestPath, "\n", e.toString());
      return 1;
    }

    if (compareVersion(loadedManifest.projectVersion, VERSION) > 0) {
      log(format("Project version (%s) is newer than editor version (%s)",
                 loadedManifest.projectVersion, VERSION));
      return 1;
    }

    log("Opening project ", loadedManifest.projectName);
    projectPath     = args[1];
    projectManifest = loadedManifest;
  }

  SetTraceLogLevel(TraceLogLevel.LOG_WARNING);
  initWindow(WindowConfig(1920, 1080, "AresEngine - Editor", -1));
  scope(exit) closeWindow();

  Font font = LoadFontFromMemory(".ttf", FONT_DATA.ptr, cast(int)FONT_DATA.length, TEXT_SZ, null, 0);
  GuiSetFont(font);
  Image icon = LoadImageFromMemory(".png", ICON_DATA.ptr, cast(int)ICON_DATA.length);
  SetWindowIcon(icon);
  setDarkTheme();

  Rectangle topBar, hierarchy, viewport, inspector, folder;
  computeLayout(TOP_BAR_SIZE, 0.20f, 0.20f, 0.25f, topBar, hierarchy, viewport, inspector, folder);

  sceneTarget = LoadRenderTexture(cast(int)viewport.width, cast(int)viewport.height);
  scope(exit) UnloadRenderTexture(sceneTarget);

  editorCam = createEditorCamera();

  string mainScene = projectManifest.projectScenes["main"];
  if (mainScene == "") {
    log("Project has no main scene");
    return 1;
  }
  activeScene = loadScene(mainScene);
  activeScene.start();

  while (!exitRequested && !WindowShouldClose()) {
    immutable float dt = GetFrameTime();

    computeLayout(TOP_BAR_SIZE, 0.20f, 0.20f, 0.25f, topBar, hierarchy, viewport, inspector, folder);

    if (!fileDialog.active && !settingsDialog.active && !colorPicker.active && !gizmo.dragging)
      updateEditorCamera(editorCam, viewport);

    if (viewport.width != sceneTarget.texture.width || viewport.height != sceneTarget.texture.height)
      resizeSceneTarget(sceneTarget, cast(int)viewport.width, cast(int)viewport.height);

    if (selected !is null)
      updateGizmo(gizmo, viewport, editorCam, selected);

    renderScene(activeScene);

    BeginDrawing();
      ClearBackground(Colors.BLACK);
      if (activeMenu >= 0) GuiSetState(GuiState.STATE_DISABLED);
      drawHierarchy(hierarchy, activeScene, selected);
      auto selection = drawViewport(viewport, sceneTarget);
      drawInspector(inspector, selected);
      drawFolder(folder);
      GuiSetState(GuiState.STATE_NORMAL);
      auto action = drawTopBar(topBar, activeScene.name);
      drawSettingsDialog(settingsDialog);
      drawFileDialog(fileDialog);
      drawColorPickerDialog();
      if (profile) DrawFPS(GetScreenWidth() - 100, 2);
    EndDrawing();

    switch (action.menu) {
      case 0: handleProject(action.item);    break;
      case 1: handleScene(action.item);      break;
      case 2: handleGameObject(action.item); break;
      default: break;
    }

    if (action.play) handlePlay();

    gizmo.mode  = cast(GizmoMode)selection.gizmo;
    gizmo.space = cast(GizmoSpace)selection.space;
  }

  saveScene(activeScene, activeScene.name ~ ".json");
  saveManifest();

  return 0;
}

void renderScene(Scene scene) {
  BeginTextureMode(sceneTarget);
  ClearBackground(Color(60, 60, 60, 255));
  BeginMode3D(editorCam);
    DrawGrid(20, 1.0f);
    scene.draw();
    if (selected !is null) {
      drawGizmo(gizmo, selected.transform.position, selected.transform.rotation, editorCam);
    }
    
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

// Todo save project instead of scene here
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

void drawSettingsDialog(ref SettingsDialog settingsDialog) {
  if (settingsDialog.active) {
    if (settingsDialog.draw()) {
      if (!settingsDialog.cancelled) {
        projectManifest = settingsDialog.result;
        log("Saved project manifest");
        saveManifest();
      }
    }
  }
}

void drawColorPickerDialog() {
  if (colorPicker.active) {
    colorPicker.draw();
  }
}
      
// TopBar Handlers
void handleProject(int item) {
  switch (item) {
    case 0: /*Save    */ saveManifest(); break;
    case 1: /*Settings*/ settingsDialog.show(projectManifest); break; // TODO: Settings Panel
    case 2: /*Exit    */ exitRequested = true; break;
  default: break;
  }
}

void handleScene(int item) {
  switch (item) {
    case 0: /*New    */ break; // TODO: New Scene
    case 1: /*Open   */ fileDialog.show(FileDialogMode.Open, "", ".json"); break; 
    case 2: /*Save   */ saveScene(activeScene, activeScene.name ~ ".json"); break; 
    case 3: /*Save As*/ fileDialog.show(FileDialogMode.Save, "", ".json"); break; 
  default: break;
  }
}

void handleGameObject(int item) {
  switch (item) {
  default: break;
  }
}

void handlePlay() {
  import std.process : spawnProcess;
  import std.file    : readLink;
  import std.path    : dirName, buildPath;

  saveScene(activeScene, activeScene.name ~ ".json");
  spawnProcess(["ares-runtime", "--scene", activeScene.name ~ ".json"]);
}

// Project Functions
void saveManifest() {
  string json = projectManifest.toString();
  write(projectPath ~ "/manifest.json", json);
}
