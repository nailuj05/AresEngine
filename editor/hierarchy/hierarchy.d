module editor.hierarchy.hierarchy;

import std.string : toStringz;

import raylib;
import raygui;

import engine.scene.scene;
import engine.core.gameobject;

import editor.style;

// TODO: move other "magic" colors, numbers etc up here
private enum PAD         = 4;
private enum INSET       = 20;
private enum HEIGHT      = 20;
private enum DROP_STRIP  = 5;
private enum DRAG_THRESH = 4;

// "global" drag state
private GameObject g_dragging;
private Vector2    g_dragStart;
private bool       g_dragActive;

private struct DropInfo {
  enum Zone { Before, Into, After }
  GameObject target;
  Zone       zone;
  bool       valid;
}
private DropInfo g_drop;

// helpers

void DrawText(immutable(char*) text, int x, int y, int fs, Color color) { // mimic raygui text with regular raylib
  auto font = GuiGetFont();
  float fsize   = cast(float)GuiGetStyle(GuiControl.DEFAULT, GuiDefaultProperty.TEXT_SIZE);
  float fspacing = cast(float)GuiGetStyle(GuiControl.DEFAULT, GuiDefaultProperty.TEXT_SPACING);

  DrawTextEx(font, text, Vector2(x, y), fsize, fspacing, color);
}

private bool removeFromHierarchy(ref GameObject[] roots, GameObject node) {
  foreach (i, c; roots) {
    if (c is node) {
      roots = roots[0 .. i] ~ roots[i + 1 .. $];
      if (node.parent !is null)
        node.parent.removeChild(node, true);
      return true;
    }
    if (removeFromHierarchy(c.children, node)) return true;
  }
  return false;
}

private bool insertSibling(ref GameObject[] arr, GameObject target, GameObject node, bool after) {
  foreach (i, c; arr) {
    if (c is target) {
      size_t at = after ? i + 1 : i;
      arr = arr[0 .. at] ~ node ~ arr[at .. $];
      return true;
    }
    if (insertSibling(c.children, target, node, after)) return true;
  }
  return false;
}

private bool isDescendant(GameObject ancestor, GameObject test) {
  foreach (c; ancestor.children) {
    if (c is test || isDescendant(c, test)) return true;
  }
  return false;
}


private void executeDrop(Scene scene) {
  auto d = g_dragging;
  if (d is null) return;

  // dropped on empty space = detach to root
  if (!g_drop.valid) {
    removeFromHierarchy(scene.roots, d);
    scene.roots ~= d;
    return;
  }

  auto tgt = g_drop.target;
  if (tgt is d || isDescendant(d, tgt)) return; // dont drop on self or own children

  removeFromHierarchy(scene.roots, d);
  final switch (g_drop.zone) {
  case DropInfo.Zone.Before: insertSibling(scene.roots, tgt, d, false); break;
  case DropInfo.Zone.After:  insertSibling(scene.roots, tgt, d, true);  break;
  case DropInfo.Zone.Into:   tgt.addChild(d);                           break;
  }
}



void drawHierarchy(Rectangle r, Scene activeScene, ref GameObject selected) {
  DrawRectangle(cast(int)r.x, cast(int)r.y, cast(int)r.width, cast(int)r.height, GetColor(PANEL_BG));
  GuiPanel(r, "Hierarchy");

  g_drop = DropInfo.init;  // reset drop target every frame

  if (g_dragging !is null && !g_dragActive) {
    Vector2 m = GetMousePosition();
    float dx = m.x - g_dragStart.x;
    float dy = m.y - g_dragStart.y;
    if (dx * dx + dy * dy > DRAG_THRESH * DRAG_THRESH)
      g_dragActive = true;
  }

  int y = cast(int)r.y + 28;
  foreach (go; activeScene.roots)
    y = drawGameObject(cast(int)r.x + PAD, y, cast(int)r.width, go, selected);

  // floating label
  if (g_dragActive && g_dragging !is null) {
    Vector2 m = GetMousePosition();
    DrawText(g_dragging.name.toStringz(), cast(int)m.x + 14, cast(int)m.y + 2, 0, Fade(Colors.WHITE, 0.85f));
  }

  if (IsMouseButtonReleased(MouseButton.MOUSE_BUTTON_LEFT) && g_dragging !is null) {
    if (g_dragActive) executeDrop(activeScene);
    g_dragging   = null;
    g_dragActive = false;
  }
}

private int drawGameObject(int ox, int oy, int width, GameObject current, ref GameObject selected) {
  bool hasChildren = current.children.length > 0;
  auto rowRect = Rectangle(ox + HEIGHT, oy, width - ox - PAD - HEIGHT, HEIGHT);
  auto arrowRect = Rectangle(ox, oy, HEIGHT, HEIGHT);

  bool isDragged = g_dragActive && (current is g_dragging);
  Vector2 mouse  = GetMousePosition();
  bool hovered   = CheckCollisionPointRec(mouse, rowRect);

  // press: begin a potential drag
  if (hovered && IsMouseButtonPressed(MouseButton.MOUSE_BUTTON_LEFT)) {
    selected     = current;
    g_dragging   = current;
    g_dragStart  = mouse;
    g_dragActive = false;
  }

  // drop-zone detection
  if (g_dragActive && g_dragging !is null && !isDragged && hovered) {
    float rel      = mouse.y - rowRect.y;
        DropInfo.Zone z = rel < DROP_STRIP                  ? DropInfo.Zone.Before
                        : rel > rowRect.height - DROP_STRIP ? DropInfo.Zone.After
                        :                                     DropInfo.Zone.Into;
        g_drop = DropInfo(current, z, true);
    }

    // normal row
    Color bg = (current is selected) ? GetColor(0x5F5F5CFF)
             : hovered               ? GetColor(0x3A3A3AFF)
             :                         Colors.BLANK;
    DrawRectangleRec(rowRect, bg);
    DrawPolyLines(Vector2(rowRect.x + 10, rowRect.y + 10), 4, 6, 0.0f, Colors.WHITE);
    DrawText(current.name.toStringz(), cast(int)rowRect.x + HEIGHT, cast(int)rowRect.y, 0, Colors.WHITE);
    DrawLineEx(Vector2(rowRect.x, rowRect.y + rowRect.height), Vector2(rowRect.x + rowRect.width, rowRect.y + rowRect.height), 1, Colors.GRAY);

    // expand/collapse button
    string arrow = current.expanded ? "#120#" : "#119#";
    if (hasChildren && GuiButton(arrowRect, arrow.toStringz())) {
      current.expanded = !current.expanded;
    }
    
    // drop indicator overlay
    if (g_drop.valid && g_drop.target is current) {
        final switch (g_drop.zone) {
            case DropInfo.Zone.Before:
                DrawLineEx(Vector2(rowRect.x, rowRect.y),
                           Vector2(rowRect.x + rowRect.width, rowRect.y), 2, Colors.YELLOW);
                break;
            case DropInfo.Zone.After:
                DrawLineEx(Vector2(rowRect.x, rowRect.y + rowRect.height),
                           Vector2(rowRect.x + rowRect.width, rowRect.y + rowRect.height),
                           2, Colors.YELLOW);
                break;
            case DropInfo.Zone.Into:
                DrawRectangleLinesEx(rowRect, 2, Colors.YELLOW);
                break;
        }
    }

    int childY = oy + HEIGHT + PAD;

    if (current.expanded) {
      foreach (c; current.children) {
        childY = drawGameObject(ox + INSET, childY, width, c, selected);
      }
    }

    return childY;
}
