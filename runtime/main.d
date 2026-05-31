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
import engine.scripting.luaruntime;
import engine.rendering.camera : Camera;
import engine.physics.world;

static immutable ubyte[] ICON_DATA  = cast(immutable ubyte[]) import("logo/logo-icon.png");

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
  bool physProfile;
  string scenePath;
  getopt(args,
         "help|h",    &help,
         "scene|s",   &scenePath,
         "phys-prof", &physProfile);
  if (help) {
    log("usage: runtime [--scene <path>] [--phys-prof]");
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

  activeScene.physicsWorld = new PhysicsWorld();
  setActiveScene(activeScene);
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
    DrawGrid(20, 1.0f);
    activeScene.draw();
    EndMode3D();
    DrawFPS(10, 10);
    if (physProfile)
      drawPhysicsProfile(activeScene.physicsWorld.lastProfile);
    EndDrawing();
  }

  // Destory, unload, end lua
  close_luaruntime();
  activeScene.destroy();

  return 0;
}

private void drawPhysicsProfile(ref PhysicsProfile p) {
  import std.string : toStringz;
  import std.format : format;
  import raylib : DrawRectangle, DrawText, Color, Colors;
  enum int fz = 20;

  immutable int x  = 10;
  immutable int y  = 30;
  immutable int lh = 24;
  immutable Color bg  = Color(0, 0, 0, 160);
  immutable Color fg  = Colors.WHITE;
  immutable Color dim = Color(180, 180, 180, 255);

  immutable long total = p.integrateUs + p.broadphaseUs
    + p.narrowphaseUs + p.solverUs + p.correctionUs;

  DrawRectangle(x - 4, y - 4, 260, lh * 8 + 8, bg);

  void row(string label, long us, int line) {
    DrawText((label ~ ":").toStringz,         x,       y + line * lh, fz, dim);
    DrawText(format("%4d us", us).toStringz,  x + 130, y + line * lh, fz, fg);
  }

  row("integrate",   p.integrateUs,   0);
  row("broadphase",  p.broadphaseUs,  1);
  row("narrowphase", p.narrowphaseUs, 2);
  row("solver",      p.solverUs,      3);
  row("correction",  p.correctionUs,  4);
  row("total",       total,           5);

  DrawText(format("pairs  broad/narrow: %d / %d",
                  p.pairsAfterBroad, p.pairsAfterNarrow).toStringz, x, y + 6 * lh, fz, dim);
  DrawText(format("contacts: %d", p.totalContacts).toStringz,
           x, y + 7 * lh, fz, dim);
}
