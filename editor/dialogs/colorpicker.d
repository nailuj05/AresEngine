module editor.dialog.colorpicker;
import raylib;
import raygui;
import std.algorithm : clamp;
import std.string    : toStringz;

struct ColorPickerDialog {
  bool   active;
  void delegate(Color) onAccept;
  void delegate() onCancel;
private:
  Rectangle _b;
  Vector2   _pan;
  bool      _drag;
  Color     _current;
  float     _alpha;           // 0.0 .. 1.0, source of truth for alpha
  enum W = 220, H = 290;     // +30 vs original to fit alpha bar + gaps

public:
  void show(Color initial, void delegate(Color) accept, void delegate() cancel = null) {
    active = true;

    onAccept = accept;
    onCancel = cancel;
    
    _current = initial;
    _alpha    = initial.a / 255.0f;
    _drag     = false;
    Vector2 m = GetMousePosition();
    _b = Rectangle(clamp(m.x - 24, 0.0f, GetScreenWidth()  - W - 24), clamp(m.y + 12, 0.0f, GetScreenHeight() - H), W, H);
  }

  // Returns true the frame it closes. Check `cancelled` and `result`.
  bool draw() {
    if (!active) return false;

    Vector2 mouse = GetMousePosition();
    if (IsMouseButtonPressed(MouseButton.MOUSE_BUTTON_LEFT) &&
        CheckCollisionPointRec(mouse, Rectangle(_b.x, _b.y, _b.width, 24))) {
      _drag = true;
      _pan  = Vector2(mouse.x - _b.x, mouse.y - _b.y);
    }
    if (_drag) {
      _b.x = clamp(mouse.x - _pan.x, 0.0f, cast(float)GetScreenWidth()  - _b.width);
      _b.y = clamp(mouse.y - _pan.y, 0.0f, cast(float)GetScreenHeight() - _b.height);
      if (IsMouseButtonReleased(MouseButton.MOUSE_BUTTON_LEFT)) _drag = false;
    }

    if (GuiWindowBox(_b, "#27# Color")) {
      if (onCancel)
        onCancel();

      active = false;
      return true;
    }

    float bot = _b.y + _b.height;
    float bx  = _b.x;
    float bw  = _b.width;

    // HSV panel + hue bar; alpha is untouched by this widget
    GuiColorPicker(Rectangle(bx + 10, _b.y + 34, bw - 20, _b.height - 34 - 72), null, &_current);

    // Alpha bar with raygui checkerboard background; sits 62px above bottom
    GuiColorBarAlpha(Rectangle(bx + 10, bot - 62, bw - 20, 20), null, &_alpha);
    _current.a = cast(ubyte)clamp(cast(int)(_alpha * 255.0f + 0.5f), 0, 255);

    if (GuiButton(Rectangle(bx + 10, bot - 34, bw/2 - 15, 24), "OK")) {
      if (onAccept)
        onAccept(_current);

      active = false;
      return true;
    }
    if (GuiButton(Rectangle(bx + bw/2 + 5, bot - 34, bw/2 - 15, 24), "Cancel")) {
      if (onCancel)
        onCancel();

      active = false;
      return true;
    }
    return false;
  }
}
