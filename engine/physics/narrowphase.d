module engine.physics.narrowphase;

import engine.physics.collider;

bool testSphereSphere  (SphereCollider  a, SphereCollider  b, out ContactInfo hit);
bool testSphereBox     (SphereCollider  a, BoxCollider     b, out ContactInfo hit);
bool testSphereCapsule (SphereCollider  a, CapsuleCollider b, out ContactInfo hit);
bool testBoxBox        (BoxCollider     a, BoxCollider     b, out ContactInfo hit);
bool testBoxCapsule    (BoxCollider     a, CapsuleCollider b, out ContactInfo hit);
bool testCapsuleCapsule(CapsuleCollider a, CapsuleCollider b, out ContactInfo hit);
