module editor.layout;

import raylib;

void computeLayout(
                   int   topBarHeight,
                   float hierarchyRatio,
                   float inspectorRatio,
                   float folderRatio,
                   out Rectangle topBar,
                   out Rectangle hierarchy,
                   out Rectangle viewport,
                   out Rectangle inspector,
                   out Rectangle folder)
{
  immutable int W       = GetScreenWidth();
  immutable int H       = GetScreenHeight();
  immutable int folderH = cast(int)(H * folderRatio);
  immutable int hierW   = cast(int)(W * hierarchyRatio);
  immutable int inspW   = cast(int)(W * inspectorRatio);
  immutable int midH    = H - topBarHeight - folderH;
  immutable int vpW     = W - hierW - inspW;

  topBar    = Rectangle(0,          0,               W,          topBarHeight);
  hierarchy = Rectangle(0,          topBarHeight,    hierW,      midH        );
  viewport  = Rectangle(hierW,      topBarHeight,    vpW,        midH        );
  inspector = Rectangle(W - inspW,  topBarHeight,    inspW,      H - topBarHeight);
  folder    = Rectangle(0,          topBarHeight + midH, W - inspW, folderH  );
}
