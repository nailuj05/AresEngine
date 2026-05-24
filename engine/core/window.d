module engine.core.window;

import std.string : toStringz;

import raylib;

import engine.manifest;

struct WindowConfig {
    int    width     = 1280;
    int    height    = 720;
    string title     = "Game";
    int    targetFps = 60;
}

void initWindow(WindowConfig cfg) {
  InitWindow(cfg.width, cfg.height, cfg.title.toStringz());
  SetTargetFPS(cfg.targetFps);
}

void initWindow(Manifest manifest) {
  InitWindow(manifest.resolutionX, manifest.resolutionY, manifest.projectName.toStringz());
  SetTargetFPS(manifest.targetFPS);

  if (manifest.fullscreen)
    ToggleFullscreen();
}

void closeWindow() {
  CloseWindow();
}

bool shouldClose() {
  return WindowShouldClose();
}
