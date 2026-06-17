module editor.dialog.assetpicker;

import std.algorithm : clamp, canFind;
import std.string    : fromStringz, toStringz;
import std.uni       : toLower;

import raylib;
import raygui;

import editor.style;

private __gshared bool g_pickerOpen;

enum PICKER_W = 660.0f;
enum PICKER_H = 480.0f;

private enum ROW_H    = 28;
private enum PAD      =  8;
private enum HEADER   = 24;
private enum SEARCH_H = 24;
private enum BTN_W    = 96;
private enum BTN_H    = 28;
private enum SB_W     = 12;

struct AssetPickerDialog(T)
     if (__traits(hasMember, T, "displayName") && __traits(hasMember, T, "path")) {
public:
  bool active;
  bool cancelled;
  T    result;

private:
  string         title;
  const(T)[]     entries;   // full list, never mutated
  const(T)[]     filtered;  // search-filtered view
  string delegate(const ref T) metaFn;

  int    selectedIdx;

  char[128] searchBuf;
  bool      searchEdit;

  Rectangle b;
  Vector2   pan;
  bool      drag;
  Vector2   scroll;

  void applyFilter() {
    string q = fromStringz(searchBuf.ptr).idup;
    if (q.length == 0) { filtered = entries; return; }
    string ql = q.toLower();
    filtered = null;
    foreach (ref e; entries)
      if (e.displayName.toLower().canFind(ql) || e.path.toLower().canFind(ql))
        filtered ~= e;
    selectedIdx = -1;
  }

  void confirm() {
    if (selectedIdx >= 0 && selectedIdx < cast(int)filtered.length) {
      result    = filtered[selectedIdx];
      cancelled = false;
    } else {
      cancelled = true;
    }
    active       = false;
    g_pickerOpen = false;
  }

  void cancel() {
    cancelled    = true;
    active       = false;
    g_pickerOpen = false;
  }

public:
  // metaFn_ is optional; pass null for no metadata column.
  void show(string title_, const(T)[] entries_,
            string delegate(const ref T) metaFn_ = null)
  {
    if (g_pickerOpen) return;
    g_pickerOpen = true;

    title    = title_;
    entries  = entries_;
    metaFn   = metaFn_;
    active   = true;
    cancelled = false;
    selectedIdx   = -1;
    searchEdit    = false;
    scroll        = Vector2(0, 0);
    searchBuf[]   = '\0';
    filtered      = entries;

    b = Rectangle(
                  GetScreenWidth()  / 2.0f - PICKER_W / 2.0f,
                  GetScreenHeight() / 2.0f - PICKER_H / 2.0f,
                  PICKER_W, PICKER_H
                  );
  }

  // Returns true on the frame the dialog closes. Check .cancelled and .result.
  bool draw() {
    if (!active) return false;

    Vector2   mouse    = GetMousePosition();
    Rectangle titleBar = Rectangle(b.x, b.y, b.width, HEADER);

    if (IsMouseButtonPressed(MouseButton.MOUSE_BUTTON_LEFT) &&
        CheckCollisionPointRec(mouse, titleBar)) {
      drag = true;
      pan  = Vector2(mouse.x - b.x, mouse.y - b.y);
    }
    if (drag) {
      b.x = clamp(mouse.x - pan.x, 0.0f, cast(float)GetScreenWidth()  - b.width);
      b.y = clamp(mouse.y - pan.y, 0.0f, cast(float)GetScreenHeight() - b.height);
      if (IsMouseButtonReleased(MouseButton.MOUSE_BUTTON_LEFT)) drag = false;
    }

    if (GuiWindowBox(b, title.toStringz())) { cancel(); return true; }

    float cx = b.x + PAD;
    float cy = b.y + HEADER + PAD;
    float cw = b.width - PAD * 2;

    // search bar
    Rectangle searchRect = Rectangle(cx, cy, cw, SEARCH_H);
    if (GuiTextBox(searchRect, searchBuf.ptr, cast(int)searchBuf.length, searchEdit))
      searchEdit = !searchEdit;
    if (searchEdit) applyFilter();

    cy += SEARCH_H + PAD;

    // list
    float listH       = b.height - (cy - b.y) - BTN_H - PAD * 2;
    Rectangle view    = Rectangle(cx, cy, cw, listH);
    float contentH    = cast(float)(filtered.length * (ROW_H + 1));
    Rectangle content = Rectangle(0, 0, cw - SB_W, contentH);
    Rectangle scissor;

    GuiScrollPanel(view, null, content, &scroll, &scissor);
    scroll.x = 0;

    BeginScissorMode(cast(int)scissor.x, cast(int)scissor.y,
                     cast(int)scissor.width, cast(int)scissor.height);

    float ry = view.y + scroll.y;

    foreach (i, ref e; filtered) {
      float rowY = ry + i * (ROW_H + 1);
      if (rowY + ROW_H < view.y || rowY > view.y + listH) continue;

      Rectangle row = Rectangle(view.x, rowY, view.width - SB_W, ROW_H);
      bool hovered  = CheckCollisionPointRec(mouse, row) &&
        CheckCollisionPointRec(mouse, scissor);
      bool selected = (selectedIdx == cast(int)i);

      if (selected)      DrawRectangleRec(row, GetColor(0x5A5AE0AA));
      else if (hovered)  DrawRectangleRec(row, GetColor(0x3A3A3AFF));

      DrawLine(cast(int)row.x,         cast(int)(rowY + ROW_H),
               cast(int)(row.x + row.width), cast(int)(rowY + ROW_H),
               GetColor(0x2A2A2AFF));

      float colX  = row.x + PAD;
      float nameW = row.width * 0.28f;
      float pathW = row.width * (metaFn ? 0.47f : 0.67f);
      int   textY = cast(int)(rowY + (ROW_H - TEXT_SZ) / 2);

      DrawGuiText(e.displayName.toStringz(), cast(int)colX,          textY, TEXT_SZ, Colors.WHITE);
      DrawGuiText(e.path.toStringz(),        cast(int)(colX + nameW), textY, TEXT_SZ, GetColor(0xAAAAAFFF));
      if (metaFn)
        DrawGuiText(metaFn(e).toStringz(), cast(int)(colX + nameW + pathW), textY, TEXT_SZ, GetColor(0x888888FF));

      if (hovered && IsMouseButtonPressed(MouseButton.MOUSE_BUTTON_LEFT)) {
        selectedIdx   = cast(int)i;
      }
    }

    EndScissorMode();

    float bot = b.y + b.height;
    if (GuiButton(Rectangle(b.x + b.width - BTN_W - PAD,           bot - BTN_H - PAD, BTN_W, BTN_H), "Select"))
      { confirm(); return true; }
    if (GuiButton(Rectangle(b.x + b.width - BTN_W * 2 - PAD * 2,  bot - BTN_H - PAD, BTN_W, BTN_H), "Cancel"))
      { cancel();  return true; }

    return false;
  }
}
