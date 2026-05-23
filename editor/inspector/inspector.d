module editor.inspector.inspector;

import raylib;
import raygui;

import engine.core.gameobject;

import editor.style;
import editor.inspector.drawer;

import std.string : toStringz;

void drawInspector(Rectangle r, GameObject selected) {
  DrawRectangle(cast(int)r.x, cast(int)r.y, cast(int)r.width, cast(int)r.height, GetColor(PANEL_BG));
  GuiPanel(r, "Inspector");
  if (selected is null) return;

  float x = r.x;
  float y = r.y + 32;
  float w = r.width;

  drawField("Name", selected.name, selected.nameFS, x, y, w);
  y += ROW_H;

  GuiLine(Rectangle(x, y, w, 1), null);
  y += 8;

  GuiLabel(Rectangle(x + 8, y, w, FIELD_H), "Transform");
  y += ROW_H;

  Vector3 pos = selected.transform.localPosition;
  if (drawVec3Field ("Position", pos, selected.posFS, x, y, w))
    selected.transform.localPosition = pos;
  y += ROW_H;

  Quaternion rot = selected.transform.localRotation;
  if (drawEulerField("Rotation", rot, selected.rotFS, x, y, w))
    selected.transform.localRotation = rot;
  y += ROW_H;

  Vector3 scl = selected.transform.localScale;
  if (drawVec3Field ("Scale", scl, selected.scaleFS, x, y, w))
    selected.transform.localScale = scl;
  y += ROW_H;

  foreach (component; selected.components) {
    GuiLine(Rectangle(x, y, w, 1), null);
    y += 8;
    GuiLabel(Rectangle(x + 8, y, w - 8, FIELD_H), component.name.toStringz);
    y += ROW_H;
    y = cast(float)component.drawInspector(cast(ulong)x, cast(ulong)y, cast(ulong)w);
  }

  GuiLine(Rectangle(x, y, w, 1), null);
  y += 8;
  if (GuiButton(Rectangle(x + 12, y, w - 20, FIELD_H), "Add Component")) {
    // TODO
  }
}
