module engine.physics.aabb;

import raylib;

struct AABB {
  Vector3 min, max;
  bool    overlaps(AABB other);
  Vector3 center();
  Vector3 extents();
}
