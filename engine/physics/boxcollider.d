module engine.physics.boxcollider;
 
import std.math : abs;
import raylib   : Vector3, Matrix;
import raylib.raymath;
 
import engine.core.component;
import engine.physics.aabb      : AABB;
import engine.physics.collider  : Collider;
import engine.physics.narrowphase : OBB;


class BoxCollider : Collider {
  mixin Named!"BoxCollider";
 
  Vector3 size   = Vector3(1, 1, 1);
  Vector3 center;          // local offset
 
  OBB obb() {
    Matrix  wm     = owner.transform.worldMatrix();
    Vector3 wscale = owner.transform.scale;
    OBB box;
    box.center  = Vector3Add(
      Vector3(wm.m12, wm.m13, wm.m14),
      owner.transform.transformDirection(center));
    box.axes[0] = Vector3Normalize(Vector3(wm.m0, wm.m1, wm.m2));
    box.axes[1] = Vector3Normalize(Vector3(wm.m4, wm.m5, wm.m6));
    box.axes[2] = Vector3Normalize(Vector3(wm.m8, wm.m9, wm.m10));
    box.extents = Vector3(size.x * wscale.x * 0.5f,
                          size.y * wscale.y * 0.5f,
                          size.z * wscale.z * 0.5f);
    return box;
  }
 
  override AABB bounds() {
    OBB b = obb();
    // Project OBB onto world axes to get tight AABB
    Vector3 ext = Vector3(
      abs(b.axes[0].x) * b.extents.x + abs(b.axes[1].x) * b.extents.y + abs(b.axes[2].x) * b.extents.z,
      abs(b.axes[0].y) * b.extents.x + abs(b.axes[1].y) * b.extents.y + abs(b.axes[2].y) * b.extents.z,
      abs(b.axes[0].z) * b.extents.x + abs(b.axes[1].z) * b.extents.y + abs(b.axes[2].z) * b.extents.z,
    );
    return AABB(Vector3Subtract(b.center, ext),
                Vector3Add     (b.center, ext));
  }

  version(Editor) {
    import editor.inspector.drawer;

    private FieldState[string] fieldStates;
    
    override ulong drawInspector(ulong offsetX, ulong offsetY, ulong panelW) {
      auto self = this;
      return drawFields(self, fieldStates, offsetX, offsetY, panelW);
    }
  }
}
