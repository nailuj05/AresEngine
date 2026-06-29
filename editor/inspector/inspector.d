module editor.inspector.inspector;

import std.string : toStringz;

import raylib;
import raygui;

import engine.core.gameobject;
import engine.core.component;

import editor.style;
import editor.inspector.drawer;

struct InspectorState {
  bool addCompOpen;
  int  addCompActive; // reserved for keyboard navigation in the add-component list
}

static immutable string[] COMPONENT_NAMES = () {
  string[] names;
  foreach (C; KnownComponents)
    names ~= __traits(identifier, C);
  return names;
}();

void drawInspector(Rectangle r, GameObject selected, ref InspectorState state, bool disableAdd) {
  DrawRectangle(cast(int) r.x, cast(int) r.y, cast(int) r.width, cast(int) r.height, GetColor(PANEL_BG));
  GuiPanel(r, "Inspector");
  if (selected is null) return;

  float x = r.x;
  float y = r.y + 32;
  float w = r.width;

  // Name + Transform
  drawField("Name", selected.name, selected.nameFS, x, y, w);
  y += ROW_H;

  GuiLine(Rectangle(x, y, w, 1), null);
  y += 8;

  GuiLabel(Rectangle(x + 8, y, w, FIELD_H), "Transform");
  y += ROW_H;

  Vector3 pos = selected.transform.localPosition;
  if (drawVec3Field("Position", pos, selected.posFS, x + 8, y, w - 8))
    selected.transform.localPosition = pos;
  y += ROW_H;

  Quaternion rot = selected.transform.localRotation;
  if (drawEulerField("Rotation", rot, selected.rotFS, x + 8, y, w - 8))
    selected.transform.localRotation = rot;
  y += ROW_H;

  Vector3 scl = selected.transform.localScale;
  if (drawVec3Field("Scale", scl, selected.scaleFS, x + 8, y, w - 8))
    selected.transform.localScale = scl;
  y += ROW_H;

  // Per-component sections
  foreach (component; selected.components) {
    GuiLine(Rectangle(x, y, w, 1), null);
    y += 8;

    GuiLabel(Rectangle(x + 8, y, w - 8, FIELD_H), component.name.toStringz);
    if (GuiButton(Rectangle(x + w - 28, y, 20, 20), "x"))
      selected.removeComponent(component);

    y += ROW_H;
    y = component.drawInspector(x + 8, y, w - 8);
  }

  GuiLine(Rectangle(x, y, w, 1), null);
  y += 8;

  // Add Component dropdown
  if (GuiButton(Rectangle(x + 12, y, w - 20, FIELD_H), "Add Component") && disableAdd)
    state.addCompOpen = !state.addCompOpen;

  if (state.addCompOpen) {
    float dropH = FIELD_H * cast(float) COMPONENT_NAMES.length;
    Rectangle dropRect = Rectangle(x + 12, y + FIELD_H, w - 20, dropH);
    DrawRectangleRec(dropRect, GetColor(PANEL_BG));
    DrawRectangleLinesEx(dropRect, 1, Fade(Colors.BLACK, 0.45f));

    foreach (i, C; KnownComponents) {
      if (GuiButton(Rectangle(x + 12, y + FIELD_H * (i + 1), w - 20, FIELD_H), COMPONENT_NAMES[i].toStringz)) {
        selected.addComponent!C();
        state.addCompOpen = false;
      }
    }

    if (IsMouseButtonPressed(MouseButton.MOUSE_BUTTON_LEFT) &&
        !CheckCollisionPointRec(GetMousePosition(), dropRect))
      state.addCompOpen = false;
  }
}
