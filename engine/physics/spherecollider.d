module engine.physics.spherecollider;
 
import raylib   : Vector3;
import raylib.raymath;
 
import engine.core.component;
import engine.physics.aabb      : AABB;
import engine.physics.collider  : Collider;


class SphereCollider : Collider {
  mixin Named!"SphereCollider";
 
  float   radius = 0.5f;
  Vector3 center;          // local offset
 
  Vector3 worldCenter() {
    return owner.transform.transformPoint(center);
  }
 
  float worldRadius() {
    // uniform scale assumption: take the largest axis scale to be safe
    Vector3 s = owner.transform.scale;
    float   maxScale = s.x > s.y ? (s.x > s.z ? s.x : s.z)
                                  : (s.y > s.z ? s.y : s.z);
    return radius * maxScale;
  }
 
  override AABB bounds() {
    Vector3 wc = worldCenter();
    float   wr = worldRadius();
    return AABB(Vector3Subtract(wc, Vector3(wr, wr, wr)),
                Vector3Add     (wc, Vector3(wr, wr, wr)));
  }

  version(Editor) {
    import editor.inspector.drawer;

    private FieldState[string] fieldStates;
    
    override float drawInspector(float offsetX, float offsetY, float panelW) {
      auto self = this;
      return drawFields(self, fieldStates, offsetX, offsetY, panelW);
    }
  }
} 
