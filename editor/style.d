module editor.style;

import raylib;
import raygui;

enum PANEL_BG    = 0x252526FF;
enum TEXT_SZ     = 20;
enum COL_ACCENT  = 0xF54927FF;


void DrawGuiText(immutable(char*) text, int x, int y, int fs, Color color) {
  auto font    = GuiGetFont();
  float fspacing = cast(float)GuiGetStyle(GuiControl.DEFAULT, GuiDefaultProperty.TEXT_SPACING);
  DrawTextEx(font, text, Vector2(x, y), fs, fspacing, color);
}

void setDarkTheme() {
  // Background + base
  GuiSetStyle(DEFAULT, BACKGROUND_COLOR,      0x1E1E1EFF);
  GuiSetStyle(DEFAULT, BASE_COLOR_NORMAL,     0x1E1E1EFF);
  GuiSetStyle(DEFAULT, BASE_COLOR_FOCUSED,    0x3C3C3CFF);
  GuiSetStyle(DEFAULT, BASE_COLOR_PRESSED,    0x555555FF);
  GuiSetStyle(DEFAULT, BASE_COLOR_DISABLED,   0x1E1E1EFF);

  // Borders
  GuiSetStyle(DEFAULT, BORDER_COLOR_NORMAL,   0x505050FF);
  GuiSetStyle(DEFAULT, BORDER_COLOR_FOCUSED,  0x7A7A7AFF);
  GuiSetStyle(DEFAULT, BORDER_COLOR_PRESSED,  0xA0A0A0FF);
  GuiSetStyle(DEFAULT, BORDER_COLOR_DISABLED, 0x505050FF);
  GuiSetStyle(DEFAULT, LINE_COLOR,            0x505050FF);

  GuiSetStyle(DEFAULT, BORDER_WIDTH, 1);
  GuiSetStyle(BUTTON,  BORDER_WIDTH, 1);

  // Text
  GuiSetStyle(DEFAULT, TEXT_COLOR_NORMAL,     0xE6E6E6FF);
  GuiSetStyle(DEFAULT, TEXT_COLOR_FOCUSED,    0xFFFFFFFF);
  GuiSetStyle(DEFAULT, TEXT_COLOR_PRESSED,    0xFFFFFFFF);
  GuiSetStyle(DEFAULT, TEXT_COLOR_DISABLED,   0xE6E6E6FF);
  
  // General sizing
  GuiSetStyle(DEFAULT, BORDER_WIDTH, 2);
  GuiSetStyle(DEFAULT, TEXT_SIZE, TEXT_SZ);
  GuiSetStyle(DEFAULT, TEXT_SPACING, 1);
    
  // Buttons
  GuiSetStyle(BUTTON, BORDER_WIDTH, 2);
  GuiSetStyle(BUTTON, BASE_COLOR_NORMAL,      0x353535FF);
  GuiSetStyle(BUTTON, BASE_COLOR_FOCUSED,     0x454545FF);
  GuiSetStyle(BUTTON, BASE_COLOR_PRESSED,     0x5A5A5AFF);
  GuiSetStyle(BUTTON, BASE_COLOR_DISABLED,    0x353535FF);
  GuiSetStyle(BUTTON, BORDER_COLOR_DISABLED,  0x505050FF);
  GuiSetStyle(BUTTON, TEXT_COLOR_DISABLED,    0xE6E6E6FF);
  
  // Sliders
  GuiSetStyle(SLIDER, BASE_COLOR_NORMAL,      0x404040FF);
  GuiSetStyle(SLIDER, BASE_COLOR_FOCUSED,     0x5A5A5AFF);
  GuiSetStyle(SLIDER, BORDER_COLOR_NORMAL,    0x707070FF);
  
  // TextBox
  GuiSetStyle(TEXTBOX, BASE_COLOR_NORMAL,     0x252525FF);
  GuiSetStyle(TEXTBOX, BORDER_COLOR_NORMAL,   0x606060FF);
  GuiSetStyle(TEXTBOX, TEXT_COLOR_NORMAL,     0xF0F0F0FF);
  
  // ListView
  GuiSetStyle(LISTVIEW, BASE_COLOR_NORMAL,    0x252525FF);
  GuiSetStyle(LISTVIEW, BASE_COLOR_FOCUSED,   0x404040FF);
  
  // Scrollbar
  GuiSetStyle(SCROLLBAR, BASE_COLOR_NORMAL,   0x303030FF);
  GuiSetStyle(SCROLLBAR, BASE_COLOR_FOCUSED,  0x505050FF);
}
