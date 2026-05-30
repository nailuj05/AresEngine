module engine.physics.collider;

import raylib;

import engine.core.component;
import engine.scene.scene;
import engine.physics.aabb;
import engine.physics.rigidbody;

interface ITriggerListener {
  void onTriggerEnter(Collider other);
  void onTriggerStay (Collider other);
  void onTriggerExit (Collider other);
}

interface ICollisionListener {
  void onCollisionEnter(ref ContactManifold m);
  void onCollisionStay (ref ContactManifold m);
  void onCollisionExit (ref ContactManifold m);
}

struct ContactInfo {
  Vector3 point;
  Vector3 normal; // b to a
  float   depth;
}

struct ContactManifold {
    ContactInfo[4] contacts;
    int            count;
}

abstract class Collider : Component {
  bool      isTrigger  = false;
  // layer mask for future filtering
  int       layer      = 0;
  
  // null -> static
  Rigidbody attachedRigidbody;

  abstract AABB   bounds();

  override void onStart() {
    attachedRigidbody = owner.getComponent!Rigidbody();
    activeScene().physicsWorld.register(this);
  }
 
  override void onDestroy() {
    activeScene().physicsWorld.unregister(this);
  }
}
