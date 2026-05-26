import std.file;
import std.getopt;

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

static immutable ubyte[] ICON_DATA  = cast(immutable ubyte[]) import("icons/logo-icon.png");

Scene activeScene;
Camera mainCamera;
Manifest manifest;
bool exitRequested;

void log(T...)(T args) {
  import std.stdio : write, writeln;
  write("[AresEngine] ");
  writeln(args);
}

int main(string[] args) {
  bool help;
  string scenePath;
  getopt(args, "help|h", &help, "scene|s", &scenePath);

  if (help) {
    log("usage: runtime [--scene <path>]");
    return 0;
  }

  string manifestPath = "manifest.json";
  if (!exists(manifestPath)) {
    log("Manifest file not found");
    return 1;
  }
  try {
    manifest = Manifest(readText(manifestPath));
  } catch (Exception e) {
    log("Error parsing manifest file ", manifestPath, "\n", e.toString());
    return 1;
  }

  if (scenePath == "") {
    scenePath = manifest.projectScenes["main"];
    if (scenePath == "") {
      log("Project has no main scene");
      return 1;
    }
  }

  SetTraceLogLevel(TraceLogLevel.LOG_WARNING);
  SetConfigFlags(ConfigFlags.FLAG_MSAA_4X_HINT);
  initWindow(manifest);
  SetExitKey(KeyboardKey.KEY_NULL);
  scope(exit) CloseWindow();

  Image icon = LoadImageFromMemory(".png", ICON_DATA.ptr, cast(int)ICON_DATA.length);
  SetWindowIcon(icon);

  activeScene = loadScene(scenePath);
  activeScene.start();
  mainCamera = activeScene.getMainCamera();

  if (mainCamera is null) {
    log("main camera is null");
    return 1;
  }

  while (!exitRequested && !WindowShouldClose()) {
    immutable float dt = GetFrameTime();
    activeScene.update(dt);

    BeginDrawing();
      ClearBackground(Colors.BLACK);
      BeginMode3D(mainCamera.rcamera);
        activeScene.draw();
      EndMode3D();
      DrawFPS(10, 10);
    EndDrawing();
  }

  // Destory, unload, end lua

  return 0;
}
