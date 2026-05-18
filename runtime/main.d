import raylib;
import raygui;

void main()
{
    InitWindow(800, 600, "AresEngineRuntime");

    while (!WindowShouldClose())
    {
        BeginDrawing();

        ClearBackground(Colors.BLACK);

        EndDrawing();
    }

    CloseWindow();
}
