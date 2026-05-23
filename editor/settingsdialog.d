module editor.settingsdialog;

import raylib;
import raygui;

import std.algorithm : clamp;
import std.string    : fromStringz, toStringz;

import engine.manifest;

struct SettingsDialog {

  bool     active;
  bool     cancelled;
  Manifest result;

private:
  Rectangle b;
  Vector2   pan;
  bool      drag;

  int  activeTab;
  bool nameEdit;

  char[256] nameBuf;

  //  Internals 

  static void fillBuf(char[] buf, string s) nothrow {
    buf[] = '\0';
    size_t n = s.length < buf.length - 1 ? s.length : buf.length - 1;
    buf[0 .. n] = s[0 .. n];
  }

  void closeWith(bool cancel) {
    if (!cancel)
      result.projectName = fromStringz(nameBuf.ptr).idup;
    cancelled = cancel;
    active    = false;
  }

  void drawGeneral(Rectangle area) {
    float x = area.x + 8;
    float y = area.y + 8;
    float w = area.width - 16;

    GuiLabel(Rectangle(x, y, 120, 24), "Project Name:");
    if (GuiTextBox(Rectangle(x + 128, y, w - 128, 24),
                   nameBuf.ptr, cast(int)nameBuf.length, nameEdit))
      nameEdit = !nameEdit;
  }

  //  Public API 
public:

  /// Snapshot `m` into the dialog and open it.
  void show(Manifest m) {
    result    = m;
    active    = true;
    cancelled = false;
    activeTab = 0;
    nameEdit  = false;
    drag      = false;

    b = Rectangle(
      GetScreenWidth()  / 2.0f - 440.0f,
      GetScreenHeight() / 2.0f - 320.0f,
      880.0f, 640.0f
    );

    fillBuf(nameBuf[], m.projectName);
  }

  /// Draw the dialog. Call every frame while `active` is true.
  /// Returns: true the frame the dialog closes.
  bool draw() {
    if (!active) return false;

    //  Drag 
    Vector2   mouse    = GetMousePosition();
    Rectangle titleBar = Rectangle(b.x, b.y, b.width, 24);

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

    //  Window box 
    if (GuiWindowBox(b, "Project Settings")) {
      closeWith(true);
      return true;
    }

    //  Tab bar
    const(char)*[1] tabs = ["General".toStringz];
    GuiTabBar(
      Rectangle(b.x + 8, b.y + 32, b.width - 16, 24),
      tabs.ptr, cast(int)tabs.length, &activeTab
    );

    //  Tab content 
    Rectangle content = Rectangle(b.x + 8, b.y + 64, b.width - 16, b.height - 64 - 44);
    GuiGroupBox(content, "");

    switch (activeTab) {
      default:
      case 0: drawGeneral(content); break;
      // case 1: drawPhysics(content);   break;
      // case 2: drawRendering(content); break;
    }

    //  Bottom buttons 
    float bot = b.y + b.height;
    float bx  = b.x;
    float bw  = b.width;

    if (GuiButton(Rectangle(bx + bw - 104, bot - 36, 96, 28), "Apply")) {
      closeWith(false);
      return true;
    }
    if (GuiButton(Rectangle(bx + bw - 208, bot - 36, 96, 28), "Cancel")) {
      closeWith(true);
      return true;
    }

    return false;
  }
}
