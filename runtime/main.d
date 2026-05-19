import raylib;
import raygui;

void main() {
  InitWindow(800, 600, "AresEngineRuntime");

  // when rendering to the full framebuffer (in the runtime) we can enable MSA
  SetConfigFlags(ConfigFlags.FLAG_MSAA_4X_HINT); 
  
  while (!WindowShouldClose()) {
    BeginDrawing();

    ClearBackground(Colors.BLACK);

    EndDrawing();
  }

  CloseWindow();
}
