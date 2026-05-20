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
