module editor.topbar;

import std.string : toStringz;
import std.format : format;
import std.stdio;

import raylib;
import raygui;

import editor.style;

struct MenuItem {
  string label;
}

struct MenuDef {
  string     label;
  MenuItem[] items;
}

immutable MenuDef[] MENUS = [
  MenuDef("Project", [
    MenuItem("New"),
    MenuItem("Open"),
    MenuItem("Save"),
    MenuItem("Save As"),
    MenuItem("Exit"),
  ]),
  MenuDef("Edit", [
    MenuItem("Undo"),
    MenuItem("Redo"),
    MenuItem("Cut"),
    MenuItem("Copy"),
    MenuItem("Paste"),
  ]),
  MenuDef("Scene", [
    MenuItem("Add Object"),
    MenuItem("Remove Object"),
    MenuItem("Scene Settings"),
  ]),
];

// State
int activeMenu = -1; // index into MENUS; -1 = closed

struct MenuAction {
  int menu = -1;
  int item = -1;
  bool opCast(T : bool)() const { return menu >= 0 && item >= 0; }
}

MenuAction drawTopBar(Rectangle r, string sceneName) {
  MenuAction result;

  enum BUTTON_W   = 80;
  enum BUTTON_PAD = 0;
  enum ITEM_H     = 24;
  enum DROPDOWN_W = 140;
  enum SEP_H      = 8;

  DrawRectangle(cast(int)r.x, cast(int)r.y,
                cast(int)r.width, cast(int)r.height, GetColor(PANEL_BG));

  // Build button rects once so we can reuse them for hit-testing below.
  Rectangle[MENUS.length] btnRects;
  {
    float x = r.x + BUTTON_PAD;
    foreach (i; 0 .. MENUS.length) {
      btnRects[i] = Rectangle(x, r.y + BUTTON_PAD,
                              BUTTON_W, r.height - BUTTON_PAD * 2);
      x += BUTTON_W + BUTTON_PAD;
    }
  }

  // Topbar buttons
  foreach (i, ref menu; MENUS) {
    if (GuiButton(btnRects[i], menu.label.toStringz))
      activeMenu = (activeMenu == cast(int)i) ? -1 : cast(int)i;
  }

  // Scene Name
  auto sn = format!"Scene: %s"(sceneName).toStringz();
  auto sz = MeasureText(sn, TEXT_SZ) / 2;
  GuiLabel(Rectangle(r.width / 2 - sz, r.y, r.width / 2 + sz, r.height), sn);
  
  // Dropdown for the active menu
  if (activeMenu >= 0) {
    // Snapshot in case an item click modifies activeMenu mid-loop.
    immutable int mi = activeMenu;

    float dx = btnRects[mi].x;
    float dy = r.y + r.height;

    float totalH = MENUS[mi].items.length * ITEM_H;

    Rectangle dropRect = Rectangle(dx, dy, DROPDOWN_W, totalH);
    DrawRectangleRec(dropRect, GetColor(PANEL_BG));
    DrawRectangleLinesEx(dropRect, 1, Fade(Colors.BLACK, 0.45f));

    float iy = dy;
    foreach (j, ref item; MENUS[mi].items) {
      if (GuiButton(Rectangle(dx, iy, DROPDOWN_W, ITEM_H),
                    item.label.toStringz)) {
        result      = MenuAction(mi, cast(int)j);
        activeMenu = -1;
      }
      iy += ITEM_H;
    }

    // Close on any click that lands outside both the dropdown and its button.
    if (IsMouseButtonPressed(MouseButton.MOUSE_BUTTON_LEFT)) {
      Vector2 mouse = GetMousePosition();
      if (!CheckCollisionPointRec(mouse, dropRect) &&
          !CheckCollisionPointRec(mouse, btnRects[mi]))
        activeMenu = -1;
    }
  }

  return result;
}
