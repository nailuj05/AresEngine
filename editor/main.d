module main;

import std.getopt;
import std.format : format;
import std.path   : absolutePath;
import std.file   : chdir, exists, isDir, readText, write, getcwd;

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
import engine.rendering.modelrenderer;
import engine.rendering.drawcontext;
import engine.scripting.luaruntime;
import engine.models.modelmanager;
import engine.materials.materialmanager;
import engine.shaders.shadermanager;
import engine.oscillator;

import editor.style;
import editor.layout;
import editor.topbar;
import editor.dialog.file;
import editor.dialog.settings;
import editor.dialog.colorpicker;
import editor.dialog.material : MaterialDialog;
import editor.editorcamera;
import editor.project.project;
import editor.viewport.gizmos;
import editor.viewport.viewport;
import editor.inspector.inspector;
import editor.hierarchy.hierarchy;
import editor.inspector.drawer : colorPicker, modelPicker; 

// Comp-time embedded assets
static immutable ubyte[] FONT_DATA  = cast(immutable ubyte[]) import("fonts/Inter.ttf");
static immutable ubyte[] LOGO_DATA  = cast(immutable ubyte[]) import("logo/logo-icon.png");

// Project
private string   projectPath;
private scope Manifest projectManifest;

// Scene
private Scene           activeScene;
private GameObject      selected;
private RenderTexture2D sceneTarget;
private EditorCamera    editorCam;

// Editor
private GizmoState gizmo;
private InspectorState inspectorState;

private FileDialog fileDialog;
private SettingsDialog settingsDialog;
private MaterialDialog materialDialog;

private bool exitRequested;

enum TOP_BAR_SIZE = 24;

// TODO: Proper logging, logfile, console 
void log(T...)(T args) {
  import std.stdio : write, writeln;
  write("[AresEditor] ");
  writeln(args);
}

int main(string[] args) {
  // Argparse and init/load
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
    projectPath = absolutePath(args[1]);
    chdir(projectPath);
    projectManifest.projectName    = "New Project";
    projectManifest.projectVersion = VERSION;
    activeScene = new Scene("main");
    saveScene(activeScene, "main.json");
    projectManifest.projectScenes["main"] = "main.json";
    saveManifest();
    log("Created new project in ", projectPath);
  } else {
    if (args.length < 2) {
      log("error: missing project path");
      return 1;
    }

    projectPath = absolutePath(args[1]);

    if (!isDir(projectPath)) {
      log("Error with project path: ", projectPath);
      return 1;
    }

    if (!exists(projectPath ~ "/manifest.json")) {
      log("Manifest file not found in ", projectPath);
      return 1;
    }

    Manifest loadedManifest;
    try {
      loadedManifest = Manifest(readText(projectPath ~ "/manifest.json"));
    } catch (Exception e) {
      log("Error parsing manifest file ", projectPath ~ "/manifest.json", "\n", e.toString());
      return 1;
    }

    if (compareVersion(loadedManifest.projectVersion, VERSION) > 0) {
      log(format("Project version (%s) is newer than editor version (%s)",
                 loadedManifest.projectVersion, VERSION));
      return 1;
    }

    log("Opening project ", loadedManifest.projectName, " at ", projectPath);
    projectManifest = loadedManifest;
    chdir(projectPath);
  }

  // Raylib Init
  SetTraceLogLevel(TraceLogLevel.LOG_WARNING);
  initWindow(WindowConfig(1920, 1080, "AresEngine - Editor", 60));
  scope(exit) closeWindow();

  // UI Setup
  Font font = LoadFontFromMemory(".ttf", FONT_DATA.ptr, cast(int)FONT_DATA.length, TEXT_SZ, null, 0);
  GuiSetFont(font);
  Image logo = LoadImageFromMemory(".png", LOGO_DATA.ptr, cast(int)LOGO_DATA.length);
  SetWindowIcon(logo);
  setDarkTheme();

  Rectangle topBar, hierarchy, viewport, inspector, project;
  computeLayout(TOP_BAR_SIZE, 0.20f, 0.20f, 0.25f, topBar, hierarchy, viewport, inspector, project);

  sceneTarget = LoadRenderTexture(cast(int)viewport.width, cast(int)viewport.height);
  scope(exit) UnloadRenderTexture(sceneTarget);

  editorCam = EditorCamera.create();

  // Load Scene
  string mainScene = projectManifest.projectScenes["main"];
  if (mainScene == "") {
    log("Project has no main scene");
    return 1;
  }
  activeScene = loadScene(mainScene);
  log("Scene: ", activeScene.name, " loaded");

  setActiveScene(activeScene);

  // managers needs to be initialized before scene start
  ShaderManager.init(projectPath);
  
  MaterialManager.init(projectPath);
  
  ModelManager.init(projectPath);
  ModelManager.instance.loadAllAssets(); // a bit ugly, but fine for this engine
   
  activeScene.editorStart();
  log("Editor Start");

  initProject(projectPath);
  
  while (!exitRequested && !WindowShouldClose()) {
    immutable float dt = GetFrameTime();

    computeLayout(TOP_BAR_SIZE, 0.20f, 0.20f, 0.25f, topBar, hierarchy, viewport, inspector, project);

    if (!fileDialog.active && !settingsDialog.active && !colorPicker.active &&
        !modelPicker.active && !materialDialog.active && !gizmo.dragging)
      editorCam.update(viewport);

    if (viewport.width != sceneTarget.texture.width || viewport.height != sceneTarget.texture.height)
      resizeSceneTarget(sceneTarget, cast(int)viewport.width, cast(int)viewport.height);

    if (selected !is null)
      updateGizmo(gizmo, viewport, editorCam.cam, selected);

    renderScene(activeScene, editorCam);

    BeginDrawing();
    ClearBackground(Colors.BLACK);
    if (activeMenu >= 0) GuiSetState(GuiState.STATE_DISABLED);
    drawHierarchy(hierarchy, activeScene, selected);
    auto selection = drawViewport(viewport, sceneTarget);
    drawInspector(inspector, selected, inspectorState);
    auto inspect = drawProject(project);
    GuiSetState(GuiState.STATE_NORMAL);
    auto action = drawTopBar(topBar, activeScene.name);
      
    drawSettingsDialog(settingsDialog);
    drawFileDialog(fileDialog);
    drawMaterialDialog(inspect);
    drawColorPickerDialog();

    if (profile) DrawFPS(GetScreenWidth() - 100, 2);
    EndDrawing();

    switch (action.menu) {
    case 0: handleProject(action.item);    break;
    case 1: handleScene(action.item);      break;
    case 2: handleGameObject(action.item); break;
    case 3: handleCreate(action.item);     break;
    default: break;
    }

    // Delete either selection (or file?)
    if (IsKeyPressed(KeyboardKey.KEY_DELETE)) {
      if (!CheckCollisionPointRec(GetMousePosition(), project)) { // if not in project view
        if (selected !is null)
          activeScene.destroyObject(selected);
        selected = activeScene.roots.length > 0 ? activeScene.roots[0].gameObject : null;
      }
    }
    
    if (action.play) handlePlay();

    gizmo.mode  = cast(GizmoMode)selection.gizmo;
    gizmo.space = cast(GizmoSpace)selection.space;
  }

  unloadProject();
  
  close_luaruntime();

  // TODO: Proper "close without saving?" dialog
  saveScene(activeScene, activeScene.name ~ ".json");
  
  log("Editor Destroy");
  activeScene.editorDestroy();

  materialDialog.close();

  // unload in reverse order
  ModelManager.instance.shutdown();
  MaterialManager.instance.shutdown();
  ShaderManager.instance.shutdown();

  saveManifest();

  return 0;
}

void renderScene(Scene scene, EditorCamera cam) {
  DrawContext ctx = { cam.cam };

  BeginTextureMode(sceneTarget);
  ClearBackground(Color(60, 60, 60, 255));
  BeginMode3D(editorCam.cam);

  DrawGrid(20, 1.0f);
  scene.draw(ctx);
  if (selected !is null) {
    drawGizmo(gizmo, selected.transform.position, selected.transform.rotation, editorCam.cam);
  }
    
  EndMode3D();
  EndTextureMode();
}

void resizeSceneTarget(ref RenderTexture2D target, int w, int h) {
  UnloadRenderTexture(target);
  target = LoadRenderTexture(w, h);
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

void drawMaterialDialog(string inspect) {
  import editor.dialog.material;

  if (inspect != "")
    materialDialog.show(inspect);

  materialDialog.draw();
}

// TopBar Handlers
void handleProject(int item) {
  switch (item) {
  case 0: /*Save    */ saveManifest(); break;
  case 1: /*Settings*/ settingsDialog.show(projectManifest); break;
  case 2: /*Exit    */ exitRequested = true; break;
  default: break;
  }
}

void handleScene(int item) {
  switch (item) {
  case 0: /*New    */ break; // TODO: New Scene
  case 1: /*Open   */ fileDialog.show(FileDialogMode.Open, "", ".json"); break; 
  case 2: /*Save   */ saveScene(activeScene, projectPath ~ "/" ~ activeScene.name ~ ".json"); break; 
  case 3: /*Save As*/ fileDialog.show(FileDialogMode.Save, "", ".json"); break; 
  default: break;
  }
}

void handleGameObject(int item) {
  switch (item) {
  case 0: /*Add Empty */ activeScene.createObject("Empty"); break;
  case 1: /*Add Cube  */
    auto cube = activeScene.createObject("Cube");
    auto mr   = cube.addComponent!ModelRenderer();
    mr.modelPath = "primitive://cube";
    mr.reload();
    break;
  case 2: /*Add Camera*/ activeScene.createObject("Camera").addComponent!Camera(); break;
  default: break;
  }
}

void handleCreate(int item) {
  switch (item) {
  case 0: /*New Material*/
    auto mat = MaterialManager.instance.defaultMaterial();
    MaterialManager.instance.save(mat, getCurrentProjectPath() ~ "/Material.mat");
    MaterialManager.instance.release(mat);
    reloadProjectView();
    break;
  default: break;
  }
}

void handlePlay() {
  import std.process : spawnProcess;
  saveScene(activeScene, activeScene.name ~ ".json");
  spawnProcess(["ares-runtime", "--scene", activeScene.name ~ ".json", "--phys-prof"]);
}

// Project Functions
void saveManifest() {
  write("manifest.json", projectManifest.toString());
}
