module editor.inspector.inspector;

import raygui;
import raylib;
import engine.core.gameobject;
import editor.style;

// Use proper constants for styling and spacing
void drawInspector(Rectangle r, GameObject selected) {
  import std.string : toStringz;

  DrawRectangle(cast(int)r.x, cast(int)r.y, cast(int)r.width, cast(int)r.height, GetColor(PANEL_BG));
  GuiPanel(r, "Inspector");

  if (selected is null) return;
  GuiLabel(Rectangle(r.x + 4, r.y + 32, r.width - 8, 20), selected.name.toStringz);

  foreach (i, component; selected.components) {
    GuiLabel(Rectangle(r.x + 12, r.y + 32 * i + 64, r.width - 8, 20), component.name.toStringz);
    component.drawInspector(cast(ulong)r.x, cast(ulong)(r.y + 32 * i + 96), cast(ulong)r.width);
  }
}
