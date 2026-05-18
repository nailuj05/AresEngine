module engine.core.window;

import raylib;

struct WindowConfig {
    int    width     = 1280;
    int    height    = 720;
    string title     = "Game";
    int    targetFps = 60;
}

void initWindow(WindowConfig cfg) {
    InitWindow(cfg.width, cfg.height, cfg.title.ptr);
    SetTargetFPS(cfg.targetFps);
}

void closeWindow() {
    CloseWindow();
}

bool shouldClose() {
    return WindowShouldClose();
}
