module editor.project.project;

import std.string    : toStringz;
import std.path      : buildPath, baseName, dirName, relativePath;
import std.file      : dirEntries, SpanMode, isDir, isFile, DirEntry;
import std.algorithm : filter, sort, partition;
import std.array     : array;

import raylib;
import raygui;

import editor.style;

static immutable ubyte[] ICON_FILE    = cast(immutable ubyte[]) import("icons/file.png");
static immutable ubyte[] ICON_FOLDER  = cast(immutable ubyte[]) import("icons/folder.png");
static immutable ubyte[] ICON_SCRIPT  = cast(immutable ubyte[]) import("icons/script.png");
static immutable ubyte[] ICON_TEXTURE = cast(immutable ubyte[]) import("icons/texture.png");
// TODO: Add model icon

private enum PAD         = 4;
private enum HEADER      = 28;
private enum CRUMB_H     = 22;
private enum CRUMB_PAD   = 6;
private enum SB_W        = 5;
private enum CELL_W      = 110;   // grid cell width
private enum CELL_H      = 75;   // grid cell height (icon + label)
private enum THUMB_SIZE  = 32;   // icon rendered size
private enum LABEL_H     = 20;   // text row below icon
private enum LABEL_SZ    = 20;
private immutable string[] TEXTURE_EXTS = [".png", ".jpg", ".jpeg"];
private immutable string[] MODEL_EXTS = [".obj", ".glb", ".gltf"];

private Texture2D iconFile;
private Texture2D iconFolder;
private Texture2D iconScript;
private Texture2D iconTexture;
private bool      iconsLoaded;

private string     currentPath;
private string[]   crumbs;
private DirEntry[] entries;
private int        selectedIdx = -1;
private Vector2    scroll;
private double     lastClickTime = -1.0;
private int        lastClickIdx  = -1;

string getCurrentProjectPath() {
  return currentPath;
}

void initProject(string projectPath) {
  if (iconsLoaded) return;

  Image img;

  img = LoadImageFromMemory(".png", ICON_FILE.ptr,    cast(int)ICON_FILE.length);
  iconFile = LoadTextureFromImage(img);
  UnloadImage(img);

  img = LoadImageFromMemory(".png", ICON_FOLDER.ptr,  cast(int)ICON_FOLDER.length);
  iconFolder = LoadTextureFromImage(img);
  UnloadImage(img);

  img = LoadImageFromMemory(".png", ICON_SCRIPT.ptr,  cast(int)ICON_SCRIPT.length);
  iconScript = LoadTextureFromImage(img);
  UnloadImage(img);

  img = LoadImageFromMemory(".png", ICON_TEXTURE.ptr, cast(int)ICON_TEXTURE.length);
  iconTexture = LoadTextureFromImage(img);
  UnloadImage(img);

  iconsLoaded = true;
  navigateTo(projectPath);
}

void unloadProject() {
  if (!iconsLoaded) return;
  UnloadTexture(iconFile);
  UnloadTexture(iconFolder);
  UnloadTexture(iconScript);
  UnloadTexture(iconTexture);
  iconsLoaded = false;
}

void reloadProjectView() {
  navigateTo(currentPath);
}

// navigation
private void navigateTo(string path) {
  currentPath  = path;
  selectedIdx  = -1;
  scroll       = Vector2(0, 0);

  // rebuild crumb list
  if (crumbs.length == 0) {
    crumbs = [path];
  } else {
    // going deeper or jumping back via breadcrumb
    bool found = false;
    foreach (i, c; crumbs) {
      if (c == path) { crumbs = crumbs[0 .. i + 1]; found = true; break; }
    }
    if (!found) crumbs ~= path;
  }

  // read and sort directory
  auto raw = dirEntries(path, SpanMode.shallow).array;
  auto dirs  = raw.filter!(e => e.isDir).array.sort!((a,b) => a.name < b.name).array;
  auto files = raw.filter!(e => e.isFile).array.sort!((a,b) => a.name < b.name).array;
  entries = dirs ~ files;
}

// helpers
private Texture2D iconFor(DirEntry e) {
  if (e.isDir) return iconFolder;
  import std.path : extension;
  import std.algorithm : canFind;
  string ext = e.name.extension;
  if (ext == ".lua")  return iconScript;
  if (TEXTURE_EXTS.canFind(ext)) return iconTexture;
  return iconFile;
}

private int measureLabel(string s) {
  auto font    = GuiGetFont();
  float fsize   = cast(float)GuiGetStyle(GuiControl.DEFAULT, GuiDefaultProperty.TEXT_SIZE);
  float fspacing = cast(float)GuiGetStyle(GuiControl.DEFAULT, GuiDefaultProperty.TEXT_SPACING);
  return cast(int)MeasureTextEx(font, s.toStringz(), fsize, fspacing).x;
}

private string truncateLabel(string s, int maxWidth) {
  if (MeasureText(s.toStringz(), TEXT_SZ) <= maxWidth) return s;
  while (s.length > 0) {
    s = s[0 .. $ - 1];
    if (MeasureText((s ~ "..").toStringz(), TEXT_SZ) <= maxWidth) return s ~ "..";
  }
  return "~";
}

private int contentHeight(int cols) {
  if (entries.length == 0 || cols == 0) return 0;
  int rows = (cast(int)entries.length + cols - 1) / cols;
  return rows * (CELL_H + PAD) + PAD;
}

// drawing
string drawProject(Rectangle panel) {
  assert(iconsLoaded);

  string inspect = "";

  DrawRectangle(cast(int)panel.x, cast(int)panel.y, cast(int)panel.width, cast(int)panel.height, GetColor(PANEL_BG));
  GuiPanel(panel, "Project");

  // breadcrumb bar
  int bx = cast(int)panel.x + PAD;
  int by = cast(int)panel.y + HEADER;

  foreach (i, crumb; crumbs) {
    string label = (i == 0) ? "/" : baseName(crumb);
    int lw = cast(int)measureLabel(label) + CRUMB_PAD * 2;

    Rectangle br = Rectangle(bx, by, lw, CRUMB_H);
    bool last = (i == crumbs.length - 1);

    if (last) {
      DrawRectangleRec(br, GetColor(0x3A3A3AFF));
      DrawRectangleLinesEx(br, 1, GetColor(0x5F5F5CFF));
      if (GuiButton(br, label.toStringz())) {};
      bx += lw;
    } else {
      if (GuiButton(br, label.toStringz())) navigateTo(crumb);
      bx += lw;
      // separator
      DrawGuiText(">".toStringz(), bx + 3, by + (CRUMB_H - TEXT_SZ) / 2, TEXT_SZ, GetColor(0x888888FF));
      bx += 20;
    }
  }

  // grid scroll area
  float viewY = panel.y + HEADER + CRUMB_H + PAD;
  float viewH = panel.height - HEADER - CRUMB_H - PAD;
  Rectangle view = Rectangle(panel.x, viewY, panel.width - SB_W, viewH);

  // how many columns fit
  int cols = (cast(int)view.width - PAD) / (CELL_W + PAD);
  if (cols < 1) cols = 1;

  Rectangle content = Rectangle(0, 0, view.width - SB_W, cast(float)contentHeight(cols));

  Rectangle scissor;
  GuiScrollPanel(view, null, content, &scroll, &scissor);
  scroll.x = 0;

  BeginScissorMode(cast(int)scissor.x, cast(int)scissor.y, cast(int)scissor.width, cast(int)scissor.height);

  int gridW    = cols * (CELL_W + PAD) - PAD;
  int originX = cast(int)view.x + PAD;
  int originY  = cast(int)(view.y + scroll.y) + PAD;

  Vector2 mouse = GetMousePosition();

  foreach (i, ref e; entries) {
    int col = cast(int)i % cols;
    int row = cast(int)i / cols;

    int cx = originX + col * (CELL_W + PAD);
    int cy = originY + row * (CELL_H + PAD);

    Rectangle cell = Rectangle(cx, cy, CELL_W, CELL_H);

    bool inView = (cy + CELL_H > view.y) && (cy < view.y + view.height);
    bool hovered = inView && CheckCollisionPointRec(mouse, cell);

    // interaction
    if (hovered && IsMouseButtonPressed(MouseButton.MOUSE_BUTTON_LEFT)) {
      double now = GetTime();
      if (lastClickIdx == cast(int)i && now - lastClickTime < 0.35) { // double click
        if (e.isDir)
          navigateTo(e.name);  // enter folder
        else
          inspect = e.name; // inspect 
      } else {
        selectedIdx   = cast(int)i;
        lastClickIdx  = cast(int)i;
        lastClickTime = now;
      }
    }

    // cell background
    Color bg = (selectedIdx == cast(int)i) ? GetColor(COL_ACCENT)
             : hovered                     ? GetColor(0x3A3A3AFF)
             :                               Colors.BLANK;
    if (bg.a > 0) {
      DrawRectangleRec(cell, bg);
      if (selectedIdx == cast(int)i)
        DrawRectangleRec(cell, GetColor(COL_ACCENT));
    }

    // icon
    if (inView) {
      int ix = cx + (CELL_W - THUMB_SIZE) / 2;
      int iy = cy + PAD;
      DrawTexture(iconFor(e), ix, iy, Colors.WHITE);
    }

    // label
    string name  = baseName(e.name);
    string label = truncateLabel(name, CELL_W + 5);
    int tw = cast(int)measureLabel(label);
    int tx = cx + (CELL_W - tw) / 2;
    int ty = cy + PAD + THUMB_SIZE + 4;
    DrawGuiText(label.toStringz(), tx, ty, LABEL_SZ, Colors.WHITE);
  }

  EndScissorMode();

  return inspect;
}
