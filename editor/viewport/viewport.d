module editor.viewport.viewport;

import std.string : toStringz;

import raylib;
import raygui;

import editor.style;

private string[] gizmoButtons = ["Move", "Rotate", "Scale"];
private int selectedGizmoButton = 0;

private string[] spaces = ["Global", "Local"];
private int selectedSpace = 0;

struct Selection { int gizmo, space; }

Selection drawViewport(Rectangle r, const RenderTexture2D rt) {
  immutable Rectangle src  = Rectangle(0, 0, cast(float)rt.texture.width, -cast(float)rt.texture.height);
  immutable Rectangle dest = Rectangle(r.x, r.y + TEXT_SZ + 2, r.width, r.height - TEXT_SZ - 2);
  GuiPanel(r, "Viewport");
  DrawTexturePro(rt.texture, src, dest, Vector2(0, 0), 0.0f, Colors.WHITE);

  // Draw overlay icons for gizmo
  float ox = r.x + 20;
  float oy = r.y + 40;
  foreach (i, txt; gizmoButtons) {
    if (selectedGizmoButton == i) GuiSetState(GuiState.STATE_PRESSED);
    if (GuiButton(Rectangle(ox + i * 65, oy, 65, 25), txt.toStringz))
      selectedGizmoButton = cast(int)i;
    GuiSetState(GuiState.STATE_NORMAL);
  }

  if (GuiButton(Rectangle(ox + 3 * 65 + 10, oy, 65, 25), spaces[selectedSpace].toStringz)) {
    selectedSpace = (selectedSpace + 1) % 2;
  }
  
  return Selection(selectedGizmoButton, selectedSpace);
}

Ray getViewportRay(Vector2 mouse, Rectangle vp, Camera3D cam) {
  float x = 2.0f * (mouse.x - vp.x) / vp.width  - 1.0f;
  float y = 1.0f - 2.0f * (mouse.y - vp.y) / vp.height;

  Matrix matView = MatrixLookAt(cam.position, cam.target, cam.up);
  Matrix matProj = MatrixPerspective(
    cam.fovy * DEG2RAD,
    cast(double)vp.width / cast(double)vp.height,
    RL_CULL_DISTANCE_NEAR,
    RL_CULL_DISTANCE_FAR
  );

  Vector3 nearPoint = Vector3Unproject(Vector3(x, y, 0.0f), matProj, matView);
  Vector3 farPoint  = Vector3Unproject(Vector3(x, y, 1.0f), matProj, matView);

  Ray ray;
  ray.position  = cam.position;
  ray.direction = Vector3Normalize(Vector3Subtract(farPoint, nearPoint));
  return ray;
}
