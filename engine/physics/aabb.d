module engine.physics.aabb;

import raylib;

struct AABB {
  Vector3 min;
  Vector3 max;

  Vector3 center()  const { return Vector3((min.x + max.x) * 0.5f, (min.y + max.y) * 0.5f, (min.z + max.z) * 0.5f); }
  Vector3 extents() const { return Vector3((max.x - min.x) * 0.5f, (max.y - min.y) * 0.5f, (max.z - min.z) * 0.5f); }

  bool overlaps(AABB other) const {
    return min.x <= other.max.x && max.x >= other.min.x
      && min.y <= other.max.y && max.y >= other.min.y
      && min.z <= other.max.z && max.z >= other.min.z;
  }
}
