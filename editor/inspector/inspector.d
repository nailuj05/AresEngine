module editor.inspector.inspector;

import raygui;
import raylib;
import engine.core.gameobject;
import editor.style;

enum INSPECTOR_W = 360;

// Use proper constants for styling and spacing
void drawInspector(GameObject selected, immutable int x, immutable int h) {
  DrawRectangle(x, 0, INSPECTOR_W, h, GetColor(PANEL_BG));
  GuiPanel(Rectangle(x, 0, INSPECTOR_W, h), "Inspector");

  if (selected is null) return;
  GuiLabel(Rectangle(x + 4, 32, INSPECTOR_W - 8, 20), selected.name.ptr);

  foreach (i, component; selected.components) {
    GuiLabel(Rectangle(x + 12, 32 * i + 64, INSPECTOR_W - 8, 20), component.name.ptr);
    component.drawInspector(x, 32 * i + 96);
  }
}
