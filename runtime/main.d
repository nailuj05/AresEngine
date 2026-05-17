import raylib;
import raygui;

void SetDarkTheme()
{
    GuiSetStyle(DEFAULT, TEXT_SIZE, 18);

    GuiSetStyle(DEFAULT, BACKGROUND_COLOR, 0x1E1E1EFF);
    GuiSetStyle(DEFAULT, BASE_COLOR_NORMAL, 0x2B2B2BFF);
    GuiSetStyle(DEFAULT, BASE_COLOR_FOCUSED, 0x3C3C3CFF);
    GuiSetStyle(DEFAULT, BASE_COLOR_PRESSED, 0x555555FF);

    GuiSetStyle(DEFAULT, BORDER_COLOR_NORMAL, 0x3A3A3AFF);
    GuiSetStyle(DEFAULT, TEXT_COLOR_NORMAL, 0xE6E6E6FF);
}

void main()
{
    InitWindow(800, 600, "AresEngineRuntime");

    Font font = LoadFontEx("vendor/fonts/Inter.ttf", 18, null, 0);
    GuiSetFont(font);
  
    SetDarkTheme();
  
    float slider = 0.5f;
  
    while (!WindowShouldClose())
    {
        BeginDrawing();

        ClearBackground(Colors.BLACK);

        if (GuiButton(Rectangle(50, 50, 140, 30), "Click Me")) {
      
        }

        GuiSlider(Rectangle(50, 100, 200, 20), "Low", "High", &slider, 0.0f, 1.0f);

        EndDrawing();
    }

    CloseWindow();
}
