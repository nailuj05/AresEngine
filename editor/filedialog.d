module editor.filedialog;

import raylib;
import raygui;

import std.algorithm : clamp, sort;
import std.array     : array;
import std.file      : dirEntries, SpanMode, isDir, exists, getcwd;
import std.path      : buildNormalizedPath, dirName, baseName, extension;
import std.string    : fromStringz, toStringz, toLower, startsWith;

enum FileDialogMode { Open, Save }

// adapted / ported from: https://github.com/raysan5/raygui/blob/master/examples/custom_file_dialog/gui_window_file_dialog.h
struct FileDialog {

  bool           active;      // true while the dialog is open
  bool           cancelled;   // set on close: true = user cancelled
  string         result;      // set on confirm: full path chosen
  FileDialogMode mode;

private:
  Rectangle b;               // window bounds
  Vector2   pan;
  bool      drag;

  string   dir;
  string   filter;           // e.g. ".json", "" = show all files
  string   fileName;

  string[]        labels;    // icon-prefixed display names
  string[]        paths;     // corresponding absolute paths
  const(char)*[]  cPtrs;     // stable C-string view into labels (rebuilt on reload)

  char[1024] dirBuf;
  char[128]  nameBuf;

  int  scroll;
  int  sel     = -1;
  int  prevSel = -1;
  int  focus;

  bool dirEdit;
  bool nameEdit;

  //  Internals 

  static void fillBuf(char[] buf, string s) nothrow {
    buf[] = '\0';
    size_t n = s.length < buf.length - 1 ? s.length : buf.length - 1;
    buf[0 .. n] = s[0 .. n];
  }

  void reloadDir() {
    labels.length = 0;
    paths.length  = 0;
    sel     = -1;
    prevSel = -1;
    scroll  = 0;

    // Parent directory shortcut
    string parent = dirName(dir);
    if (parent != dir) {
      labels ~= "../";
      paths  ~= parent;
    }

    try {
      auto entries = dirEntries(dir, SpanMode.shallow).array; entries.sort!((a, b) {
          bool aD = isDir(a.name), bD = isDir(b.name);
          if (aD != bD) return aD > bD;   // dirs first
          return a.name < b.name;
        });

      foreach (e; entries) {
        string name = baseName(e.name);
        if (name.startsWith(".")) continue;  // skip hidden

        if (isDir(e.name)) {
          labels ~= name ~ "/";
          paths  ~= e.name;
        }
        else {
          if (filter.length > 0 && mode == FileDialogMode.Open
              && extension(name).toLower != filter.toLower)
            continue;

          labels ~= name;
          paths  ~= e.name;
        }
      }
    }
    catch (Exception) {}

    // Rebuild C-string pointer cache
    cPtrs.length = labels.length;
    foreach (i, ref l; labels) cPtrs[i] = l.toStringz;

    fillBuf(dirBuf[], dir);
  }

  void closeWith(bool cancel, string path = "") {
    cancelled = cancel;
    result    = path;
    active    = false;
  }

  //  Public API 
public:

  /// Open the dialog.
  /// Params:
  ///   m        = open or save mode
  ///   initPath = starting directory or file path (falls back to cwd)
  ///   filter   = file extension to show in open mode, e.g. ".json"
  ///              pass "" to show all files
  void show(FileDialogMode m, string initPath = "", string filter = "") {
    mode      = m;
    cancelled = false;
    result    = "";
    active    = true;
    filter   = filter;
    drag     = false;
    dirEdit  = false;
    nameEdit = false;

    b = Rectangle(
      GetScreenWidth()  / 2.0f - 440.0f,
      GetScreenHeight() / 2.0f - 320.0f,
      880.0f, 640.0f
    );
    

    if (initPath.length && isDir(initPath)) {
      dir = initPath;
    } else if (initPath.length && exists(initPath)) {
      dir      = dirName(initPath);
      fileName = baseName(initPath);
    } else {
      dir      = getcwd();
      fileName = "";
    }

    reloadDir();
    fillBuf(nameBuf[], fileName);
  }

  /// Draw the dialog. Call every frame while `active` is true.
  /// Returns: true the frame the dialog closes (confirm or cancel).
  ///          Inspect `cancelled` and `result` afterward.
  bool draw() {
    if (!active) return false;

    //  Drag 
    Vector2 mouse = GetMousePosition();
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
    string title = (mode == FileDialogMode.Open)
      ? "Open File"
      : "Save File";

    if (GuiWindowBox(b, title.toStringz)) {
      closeWith(true);
      return true;
    }

    //  Up-directory button 
    if (GuiButton(Rectangle(b.x + b.width - 48, b.y + 36, 40, 24), "< ..")) {
      dir = dirName(dir);
      reloadDir();
      fileName = "";
      fillBuf(nameBuf[], "");
    }

    //  Directory text box 
    if (GuiTextBox(Rectangle(b.x + 8, b.y + 36, b.width - 56, 24),
                   dirBuf.ptr, cast(int)dirBuf.length, dirEdit)) {
      if (dirEdit) {
        string typed = fromStringz(dirBuf.ptr).idup; if (isDir(typed)) { dir = typed; reloadDir(); }
        else              fillBuf(dirBuf[], dir);  // reject invalid
      }
      dirEdit = !dirEdit;
    }

    //  File list 
    int prevAlign  = GuiGetStyle(GuiControl.LISTVIEW, GuiControlProperty.TEXT_ALIGNMENT);
    int prevHeight = GuiGetStyle(GuiControl.LISTVIEW, GuiListViewProperty.LIST_ITEMS_HEIGHT);
    GuiSetStyle(GuiControl.LISTVIEW, GuiControlProperty.TEXT_ALIGNMENT,     GuiTextAlignment.TEXT_ALIGN_LEFT);
    GuiSetStyle(GuiControl.LISTVIEW, GuiListViewProperty.LIST_ITEMS_HEIGHT, 24);

    Rectangle listR = Rectangle(
                                b.x + 8,
                                b.y + 68,
                                b.width - 16,
                                b.height - 68 - 16 - 76   // leave room for two bottom rows
                                );
    GuiListViewEx(listR, cPtrs.ptr, cast(int)labels.length,
                  &scroll, &sel, &focus);


    GuiSetStyle(GuiControl.LISTVIEW, GuiControlProperty.TEXT_ALIGNMENT,     prevAlign);
    GuiSetStyle(GuiControl.LISTVIEW, GuiListViewProperty.LIST_ITEMS_HEIGHT, prevHeight);

    //  Handle selection change 
    if (sel >= 0 && sel != prevSel) {
      string picked = paths[sel];
      if (isDir(picked)) {
        // Navigate into directory
        dir = picked;
        reloadDir();
        fileName = "";
        fillBuf(nameBuf[], "");
        sel = -1;
      }
      else {
        fileName = baseName(picked);
        fillBuf(nameBuf[], fileName);
      }
      prevSel = sel;
    }

    //  Bottom controls 
    float bot = b.y + b.height;
    float bx  = b.x;
    float bw  = b.width;

    GuiLabel(Rectangle(bx + 8, bot - 76, 140, 24), "File name:");
    if (GuiTextBox(Rectangle(bx + 100, bot - 76, bw - 210, 24),
                   nameBuf.ptr, cast(int)nameBuf.length, nameEdit)) {
      if (nameEdit) fileName = fromStringz(nameBuf.ptr).idup;
      nameEdit = !nameEdit;
    }

    // Confirm / Cancel
    string confirmLabel = (mode == FileDialogMode.Save) ? "Save" : "Open";

    if (GuiButton(Rectangle(bx + bw - 104, bot - 76, 96, 24), confirmLabel.toStringz)) {
      // Save mode: allow returning a bare directory if nothing typed
      if (fileName.length == 0 && mode == FileDialogMode.Save &&
          sel >= 0 && sel < cast(int)paths.length && isDir(paths[sel])) {
        closeWith(false, paths[sel]);
        return true;
      }
      if (fileName.length > 0) {
        closeWith(false, buildNormalizedPath(dir, fileName));
        return true;
      }
      // Nothing selected yet — do nothing
    }

    if (GuiButton(Rectangle(bx + bw - 104, bot - 44, 96, 24), "Cancel")) {
      closeWith(true);
      return true;
    }

    return false;
  }
}

