module engine.physics.world;

import engine.core.transform : Axis;
import engine.physics.collider;
import engine.physics.rigidbody;
import engine.physics.narrowphase;

struct ContactPair {
  Collider a, b;
  ContactInfo contact;
}

class PhysicsWorld {
  // TODO: make part of the manifest and project settings
  enum physics_timestep = 1.0f / 50.0f;
  Axis broadphase_axis = Axis.X;

  // all registered rbs and colliders
  Rigidbody[] bodies;
  Collider[]  colliders;

  void register(Rigidbody rb);
  void register(Collider c);
  void unregister(Rigidbody rb);
  void unregister(Collider c);

  // called by scene
  void step(float dt);

private:
  float accumulator;
  ContactPair[] _previousContacts;
  
  void  fixedStep();

  // semi-implicit Euler on all awake bodies
  void  integrate(float dt);

  // sort-and-sweep on one axis
  ContactPair[] broadphase();

  // exact collision tests
  void  narrowphase(ContactPair[]); 

  // impulse resolution
  void  resolve(ref ContactPair);

  // dispatch listeners
  void fireCallbacks(ContactPair[] current);

  // check velocity threshold, toggle sleep state
  void  updateSleeping();
  
  bool dispatchNarrowphase(Collider a, Collider b, out ContactInfo hit) {
    if (auto sa = cast(SphereCollider)a) {
      if (auto sb = cast(SphereCollider)b)  return testSphereSphere(sa, sb, hit);
      if (auto bb = cast(BoxCollider)b)     return testSphereBox(sa, bb, hit);
      if (auto cb = cast(CapsuleCollider)b) return testSphereCapsule(sa, cb, hit);
    }
    if (auto ba = cast(BoxCollider)a) {
      if (auto sb = cast(SphereCollider)b)  return testSphereBox(sb, ba, hit);
      if (auto bb = cast(BoxCollider)b)     return testBoxBox(ba, bb, hit);
      if (auto cb = cast(CapsuleCollider)b) return testBoxCapsule(ba, cb, hit);
    }
    if (auto ca = cast(CapsuleCollider)a) {
      if (auto sb = cast(SphereCollider)b)  return testSphereCapsule(sb, ca, hit);
      if (auto bb = cast(BoxCollider)b)     return testBoxCapsule(bb, ca, hit);
      if (auto cb = cast(CapsuleCollider)b) return testCapsuleCapsule(ca, cb, hit);
    }
    return false;
  }
}
