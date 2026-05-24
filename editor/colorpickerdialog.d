module editor.colorpickerdialog;

import raylib;
import raygui;

import std.algorithm : clamp;
import std.string    : toStringz;

struct ColorPickerDialog {
  bool   active;
  bool   cancelled;
  bool   hasResult;
  Color  result;

private:
  Rectangle _b;
  Vector2   _pan;
  bool      _drag;
  Color     _current;

  enum W = 220, H = 260;  // window size

public:
  void show(Color initial = Color(255, 255, 255, 255)) {
    active    = true;
    cancelled = false;
    hasResult = false;
    _current  = initial;
    _drag     = false;

    // Spawn near cursor, nudged so it stays on screen
    Vector2 m = GetMousePosition();
    _b = Rectangle(clamp(m.x - 24, 0.0f, GetScreenWidth() - W - 24), clamp(m.y + 12, 0.0f, GetScreenHeight() - H), W, H);
  }

  // Returns true the frame it closes. Check `cancelled` and `result`.
  bool draw() {
    if (!active) return false;

    // Drag
    Vector2 mouse = GetMousePosition();
    if (IsMouseButtonPressed(MouseButton.MOUSE_BUTTON_LEFT) && CheckCollisionPointRec(mouse, Rectangle(_b.x, _b.y, _b.width, 24))) {
      _drag = true;
      _pan  = Vector2(mouse.x - _b.x, mouse.y - _b.y);
    }
    if (_drag) {
      _b.x = clamp(mouse.x - _pan.x, 0.0f, cast(float)GetScreenWidth()  - _b.width);
      _b.y = clamp(mouse.y - _pan.y, 0.0f, cast(float)GetScreenHeight() - _b.height);
      if (IsMouseButtonReleased(MouseButton.MOUSE_BUTTON_LEFT)) _drag = false;
    }

    if (GuiWindowBox(_b, "#27# Color")) {
      cancelled = true;
      active    = false;
      return true;
    }

    GuiColorPicker(Rectangle(_b.x + 10, _b.y + 34, _b.width - 20, _b.height - 34 - 44), null, &_current);

    float bot = _b.y + _b.height;
    float bx  = _b.x;
    float bw  = _b.width;

    if (GuiButton(Rectangle(bx + 10, bot - 34, bw/2 - 15, 24), "OK")) {
      result    = _current;
      cancelled = false;
      active    = false;
      hasResult = true;
      return true;
    }
    if (GuiButton(Rectangle(bx + bw/2 + 5, bot - 34, bw/2 - 15, 24), "Cancel")) {
      cancelled = true;
      active    = false;
      hasResult = false;
      return true;
    }

    return false;
  }
}
