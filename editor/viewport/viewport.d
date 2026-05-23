module editor.viewport.viewport;

import raylib;
import raygui;

import editor.style;

void drawViewport(Rectangle r, const RenderTexture2D rt) {
  immutable Rectangle src  = Rectangle(0, 0, cast(float)rt.texture.width,
                                       -cast(float)rt.texture.height);
  immutable Rectangle dest = Rectangle(r.x, r.y + TEXT_SZ + 2, r.width, r.height - TEXT_SZ - 2);
  GuiPanel(r, "Viewport");
  DrawTexturePro(rt.texture, src, dest, Vector2(0, 0), 0.0f, Colors.WHITE);
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
