module editor.hierarchy.hierarchy;

import std.string : toStringz;

import raylib;
import raygui;

import engine.scene.scene;
import engine.core.transform : removeFromHierarchy, insertSibling, Transform;
import engine.core.gameobject;

import editor.style;

private enum PAD         = 4;
private enum INSET       = 20;
private enum HEIGHT      = 20;
private enum DROP_STRIP  = 5;
private enum DRAG_THRESH = 4;

private GameObject dragging;
private Vector2    dragStart;
private bool       dragActive;

private Vector2 scroll;

private struct DropInfo {
  enum Zone { Before, Into, After }
  GameObject target;
  Zone       zone;
  bool       valid;
}
private DropInfo drop;

private bool isDescendant(Transform ancestor, Transform test) {
  foreach (c; ancestor.children) {
    if (c is test || isDescendant(c, test)) return true;
  }
  return false;
}

private void executeDrop(Scene scene) {
  auto d = dragging;
  if (d is null) return;

  if (!drop.valid) {
    removeFromHierarchy(scene.roots, d.transform);
    scene.roots ~= d.transform;
    return;
  }

  auto tgt = drop.target;
  if (tgt is d || isDescendant(d.transform, tgt.transform)) return;

  removeFromHierarchy(scene.roots, d.transform);
  final switch (drop.zone) {
  case DropInfo.Zone.Before: insertSibling(scene.roots, tgt.transform, d.transform, false); break;
  case DropInfo.Zone.After:  insertSibling(scene.roots, tgt.transform, d.transform, true);  break;
  case DropInfo.Zone.Into:   tgt.transform.addChild(d.transform); break;
  }
}

// measure total pixel height of all visible rows without drawing
private int measureHierarchy(Transform[] roots) {
  int h = 0;
  foreach (t; roots)
    h += measureGameObject(t.gameObject);
  return h;
}

private int measureGameObject(GameObject current) {
  int h = HEIGHT + PAD;
  if (current.expanded) {
    foreach (c; current.transform.children)
      h += measureGameObject(c.gameObject);
  }
  return h;
}

void drawHierarchy(Rectangle panel, Scene activeScene, ref GameObject selected) {
  DrawRectangle(cast(int)panel.x, cast(int)panel.y, cast(int)panel.width, cast(int)panel.height, GetColor(PANEL_BG));
  GuiPanel(panel, "Hierarchy");

  enum HEADER = 24;
  enum SB_W   = 0;
  Rectangle view = Rectangle(panel.x, panel.y + HEADER, panel.width - SB_W, panel.height - HEADER);

  int contentHeight = measureHierarchy(activeScene.roots);
  Rectangle content = Rectangle(0, 0, view.width - SB_W, cast(float)contentHeight);

  Rectangle scissor;
  GuiScrollPanel(view, null, content, &scroll, &scissor);
  scroll.x = 0;
  
  // clip all drawing to the view area
  BeginScissorMode(cast(int)scissor.x, cast(int)scissor.y, cast(int)scissor.width, cast(int)scissor.height);

  drop = DropInfo.init;

  // promote drag to active once threshold is exceeded
  if (dragging !is null && !dragActive) {
    Vector2 m = GetMousePosition();
    float dx  = m.x - dragStart.x;
    float dy  = m.y - dragStart.y;
    if (dx * dx + dy * dy > DRAG_THRESH * DRAG_THRESH)
      dragActive = true;
  }

  // scrollOffset shifts rows upward
  int y = cast(int)(view.y + scroll.y);
  foreach (go; activeScene.roots)
    y = drawGameObject(cast(int)view.x + PAD, y, cast(int)view.width, go.gameObject, selected, view);

  EndScissorMode();

  // floating drag label
  if (dragActive && dragging !is null) {
    Vector2 m = GetMousePosition();
    DrawGuiText(dragging.name.toStringz(), cast(int)m.x + 14, cast(int)m.y + 2, TEXT_SZ, Fade(Colors.WHITE, 0.85f));
  }

  if (IsMouseButtonReleased(MouseButton.MOUSE_BUTTON_LEFT) && dragging !is null) {
    if (dragActive) executeDrop(activeScene);
    dragging   = null;
    dragActive = false;
  }
}

private int drawGameObject(int ox, int oy, int width, GameObject current, ref GameObject selected, Rectangle view) {
  bool hasChildren = current.transform.children.length > 0;
  auto rowRect  = Rectangle(ox + HEIGHT, oy, width - ox - PAD - HEIGHT, HEIGHT);
  auto arrowRect = Rectangle(ox, oy, HEIGHT, HEIGHT);

  bool isDragged = dragActive && (current is dragging);
  Vector2 mouse  = GetMousePosition();

  // only interact when the row is actually visible in the panel
  bool inView  = (rowRect.y + rowRect.height > view.y) && (rowRect.y < view.y + view.height);
  bool hovered = inView && CheckCollisionPointRec(mouse, rowRect);

  if (hovered && IsMouseButtonPressed(MouseButton.MOUSE_BUTTON_LEFT)) {
    selected     = current;
    dragging   = current;
    dragStart  = mouse;
    dragActive = false;
  }

  if (dragActive && dragging !is null && !isDragged && hovered) {
    float rel       = mouse.y - rowRect.y;
    DropInfo.Zone z = rel < DROP_STRIP                  ? DropInfo.Zone.Before
                    : rel > rowRect.height - DROP_STRIP ? DropInfo.Zone.After
                    :                                     DropInfo.Zone.Into;
    drop = DropInfo(current, z, true);
  }

  Color bg = (current is selected) ? GetColor(0x5F5F5CFF)
           : hovered               ? GetColor(0x3A3A3AFF)
           :                         Colors.BLANK;
  DrawRectangleRec(rowRect, bg);
  DrawPolyLines(Vector2(rowRect.x + 10, rowRect.y + 10), 4, 6, 0.0f, Colors.WHITE);
  DrawGuiText(current.name.toStringz(), cast(int)rowRect.x + HEIGHT, cast(int)rowRect.y, TEXT_SZ, Colors.WHITE);
  DrawLineEx(Vector2(rowRect.x, rowRect.y + rowRect.height), Vector2(rowRect.x + rowRect.width, rowRect.y + rowRect.height), 1, Colors.GRAY);

  string arrow = current.expanded ? "#120#" : "#119#";
  if (hasChildren && inView && GuiButton(arrowRect, arrow.toStringz())) {
    current.expanded = !current.expanded;
  }

  if (drop.valid && drop.target is current) {
    final switch (drop.zone) {
    case DropInfo.Zone.Before:
      DrawLineEx(Vector2(rowRect.x, rowRect.y), Vector2(rowRect.x + rowRect.width, rowRect.y), 2, Colors.YELLOW);
      break;
    case DropInfo.Zone.After:
      DrawLineEx(Vector2(rowRect.x, rowRect.y + rowRect.height), Vector2(rowRect.x + rowRect.width, rowRect.y + rowRect.height), 2, Colors.YELLOW);
      break;
    case DropInfo.Zone.Into:
      DrawRectangleLinesEx(rowRect, 2, Colors.YELLOW);
      break;
    }
  }

  int childY = oy + HEIGHT + PAD;
  if (current.expanded) {
    foreach (c; current.transform.children)
      childY = drawGameObject(ox + INSET, childY, width, c.gameObject, selected, view);
  }

  return childY;
}
