module engine.physics.rigidbody;

import raylib;

import engine.core.component;
import engine.physics.aabb;

class Rigidbody : Component {
  mixin Named!"Rigidbody";

  float   mass         = 1.0f;
  float   drag         = 0.01f;
  float   angularDrag  = 0.05f;
  bool    useGravity   = true;
  bool    isKinematic  = false;

  Vector3 velocity;
  Vector3 angularVelocity;

  // sleep state
  bool    isSleeping;

  void addForce(Vector3 force);
  void addImpulse(Vector3 impulse);
  void addTorque(Vector3 torque);

  override void onStart();
  override void onDestroy();

  // called by PhysicsWorld
package:
  void integrate(float dt);
  void wakeUp();
  AABB broadphaseAABB();
}
