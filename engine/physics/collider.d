module engine.physics.collider;

import raylib;

import engine.core.component;
import engine.physics.aabb;

interface ITriggerListener {
  void onTriggerEnter(Collider other);
  void onTriggerStay (Collider other);
  void onTriggerExit (Collider other);
}

interface ICollisionListener {
  void onCollisionEnter(ref ContactInfo hit);
  void onCollisionStay (ref ContactInfo hit);
  void onCollisionExit (ref ContactInfo hit);
}

struct ContactInfo {
  Vector3 point;
  // b to a
  Vector3 normal;
  float   depth;
}

abstract class Collider : Component {
  bool      isTrigger  = false;
  // layer mask for future filtering
  int       layer      = 0;
  
  // null -> static
  private Rigidbody attachedRigidbody;

  abstract AABB   bounds();
  abstract bool   intersects(Collider other, out ContactInfo hit);

  override void onStart();
  override void onDestroy();
}

// primitive colliders
class SphereCollider : Collider {
  mixin Named!"SphereCollider";
  float   radius = 0.5f;
  Vector3 center;
  override AABB bounds();
}

class BoxCollider : Collider {
  mixin Named!"BoxCollider";
  Vector3 size = Vector3(1, 1, 1);
  Vector3 center;
  override AABB bounds();
}

class CapsuleCollider : Collider {
  mixin Named!"CapsuleCollider";
  float   radius = 0.5f;
  float   height = 2.0f;
  int     axis   = 1;
  Vector3 center;
  override AABB bounds();
}
