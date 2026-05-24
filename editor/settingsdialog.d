module editor.settingsdialog;
import raylib;
import raygui;
import std.algorithm : clamp;
import std.string    : fromStringz, toStringz;
import engine.manifest;

enum FIELD_H = 20;

struct SettingsDialog {
  bool     active;
  bool     cancelled;
  Manifest result;
private:
  Rectangle b;
  Vector2   pan;
  bool      drag;
  int       activeTab;

  char[256] nameBuf;
  bool      nameEdit;

  int  resX, resY;
  bool resXEdit, resYEdit;
  bool fullscreen;
  int fps;
  bool fpsEdit;

  static void fillBuf(char[] buf, string s) nothrow {
    buf[] = '\0';
    size_t n = s.length < buf.length - 1 ? s.length : buf.length - 1;
    buf[0 .. n] = s[0 .. n];
  }

  void closeWith(bool cancel) {
    if (!cancel) {
      result.projectName = fromStringz(nameBuf.ptr).idup;
      result.resolutionX = resX;
      result.resolutionY = resY;
      result.fullscreen  = fullscreen;
      result.targetFPS   = fps;
    }
    cancelled = cancel;
    active    = false;
  }

  void drawGeneral(Rectangle area) {
    float x  = area.x + 8;
    float w  = area.width - 16;
    float oy = area.y + 8;

    GuiLabel(Rectangle(x, oy, 120, 24), "Project Name:");
    if (GuiTextBox(Rectangle(x + 128, oy, w - 128, 24), nameBuf.ptr, cast(int)nameBuf.length, nameEdit))
      nameEdit = !nameEdit;

    oy += 24 + 8;

    GuiLabel(Rectangle(x, oy, 120, FIELD_H), "Resolution X:");
    if (GuiSpinner(Rectangle(x + 128, oy, 120, FIELD_H), "".toStringz, &resX, 1, 7680, resXEdit))
      resXEdit = !resXEdit;

    oy += FIELD_H + 8;

    GuiLabel(Rectangle(x, oy, 120, FIELD_H), "Resolution Y:");
    if (GuiSpinner(Rectangle(x + 128, oy, 120, FIELD_H), "".toStringz, &resY, 1, 4320, resYEdit))
      resYEdit = !resYEdit;

    oy += FIELD_H + 8;

    GuiLabel(Rectangle(x, oy, 120, FIELD_H), "Fullscreen:");
    GuiCheckBox(Rectangle(x + 128, oy, FIELD_H, FIELD_H), "".toStringz, &fullscreen);

    oy += FIELD_H + 8;

    GuiLabel(Rectangle(x, oy, 120, FIELD_H), "Target FPS:");
    if (GuiSpinner(Rectangle(x + 128, oy, 120, FIELD_H), "".toStringz, &fps, -1, 999, fpsEdit))
      fpsEdit = !fpsEdit;
  }

public:
  void show(Manifest m) {
    result    = m;
    active    = true;
    cancelled = false;
    activeTab = 0;
    drag      = false;

    nameEdit  = false;
    fillBuf(nameBuf[], m.projectName);

    resX       = m.resolutionX;
    resY       = m.resolutionY;
    fullscreen = m.fullscreen;
    fps        = m.targetFPS;
    resXEdit   = false;
    resYEdit   = false;
    fpsEdit    = false;

    b = Rectangle(
      GetScreenWidth()  / 2.0f - 380.0f,
      GetScreenHeight() / 2.0f - 280.0f,
      740.0f, 540.0f
    );
  }

  bool draw() {
    if (!active) return false;

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

    if (GuiWindowBox(b, "#154# Project Settings")) {
      closeWith(true);
      return true;
    }

    const(char)*[1] tabs = ["General".toStringz];
    GuiTabBar(
      Rectangle(b.x + 8, b.y + 32, b.width - 16, 24),
      tabs.ptr, cast(int)tabs.length, &activeTab
    );

    Rectangle content = Rectangle(b.x + 8, b.y + 64, b.width - 16, b.height - 64 - 44);
    GuiGroupBox(content, null);
    switch (activeTab) {
      default:
      case 0: drawGeneral(content); break;
    }

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
