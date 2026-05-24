module editor.hierarchy.hierarchy;

import std.string : toStringz;

import raylib;
import raygui;

import engine.scene.scene;
import engine.core.gameobject;

import editor.style;

void drawHierarchy(Rectangle r, const Scene activeScene, ref GameObject selected) {
  DrawRectangle(cast(int)r.x, cast(int)r.y, cast(int)r.width, cast(int)r.height, GetColor(PANEL_BG));
  GuiPanel(r, "Hierarchy");
  int y = cast(int)r.y + 28;
  foreach (go; activeScene.roots) {
    if (GuiButton(Rectangle(r.x + 4, y, r.width - 8, 22), go.name.toStringz()))
      selected = cast(GameObject)go;
    y += 26;
  }
}

