module engine.physics.rigidbody;

import raylib : Vector3, Matrix, Quaternion;
import raylib.raymath;

import engine.scene.scene;
import engine.core.component;

class Rigidbody : Component {
  mixin Named!"Rigidbody";

  float mass        = 1.0f;
  float drag        = 0.01f;
  float angularDrag = 0.05f;
  float restitution = 0.3f;
  bool  useGravity  = true;
  bool  isKinematic = false;

  @DontSerialize Vector3 velocity;
  @DontSerialize Vector3 angularVelocity;
  @DontSerialize bool    isSleeping;

  @DontSerialize Vector3 inertiaTensor;

  // cached per fixed step, written by PhysicsWorld
  package Vector3 _c0, _c1, _c2; // rotation matrix columns
  package Vector3 _localInv;

  // Returns the world-space inverse inertia tensor (diagonal 3x3 as Vector3).
  Vector3 worldInverseInertia() nothrow {
    if (inertiaTensor.x < 1e-10f) return Vector3(0, 0, 0);
    // Diagonal local inverse
    Vector3 localInv = Vector3(1.0f / inertiaTensor.x,
                               1.0f / inertiaTensor.y,
                               1.0f / inertiaTensor.z);
    return localInv;
  }

  // Apply world-space inverse inertia tensor to a vector.
  void cacheStepData() nothrow {
    Vector3 li = worldInverseInertia();
    _localInv  = li;
    Matrix m   = QuaternionToMatrix(owner.transform.localRotation);
    // raylib Matrix is column-major: col0 = (m0,m1,m2), col1 = (m4,m5,m6), col2 = (m8,m9,m10)
    _c0 = Vector3(m.m0, m.m1, m.m2);
    _c1 = Vector3(m.m4, m.m5, m.m6);
    _c2 = Vector3(m.m8, m.m9, m.m10);
  }

  Vector3 applyInverseInertia(Vector3 v) nothrow {
    if (_localInv.x < 1e-10f) return Vector3(0, 0, 0);
    float ux = _c0.x*v.x + _c0.y*v.y + _c0.z*v.z;
    float uy = _c1.x*v.x + _c1.y*v.y + _c1.z*v.z;
    float uz = _c2.x*v.x + _c2.y*v.y + _c2.z*v.z;
    ux *= _localInv.x; uy *= _localInv.y; uz *= _localInv.z;
    return Vector3(_c0.x*ux + _c1.x*uy + _c2.x*uz,
                   _c0.y*ux + _c1.y*uy + _c2.y*uz,
                   _c0.z*ux + _c1.z*uy + _c2.z*uz);
  }

  void addForce(Vector3 force) {
    if (isKinematic) return;
    velocity = Vector3Add(velocity, Vector3Scale(force, 1.0f / mass));
    wakeUp();
  }

  void addImpulse(Vector3 impulse) {
    if (isKinematic) return;
    velocity = Vector3Add(velocity, Vector3Scale(impulse, 1.0f / mass));
    wakeUp();
  }

  void addTorque(Vector3 torque) {
    if (isKinematic) return;
    angularVelocity = Vector3Add(angularVelocity, applyInverseInertia(torque));
    wakeUp();
  }

  override void onStart() {
    computeInertiaTensor();
    activeScene().physicsWorld.register(this);
  }

  override void onDestroy() {
    activeScene().physicsWorld.unregister(this);
  }

  void recomputeInertiaTensor() {
    computeInertiaTensor();
  }
  
package:
  void wakeUp() {
    isSleeping = false;
  }

  void computeInertiaTensor() {
    import engine.physics.boxcollider    : BoxCollider;
    import engine.physics.spherecollider : SphereCollider;

    // TODO: Move this to collider? 
    if (auto box = owner.getComponent!BoxCollider()) {
      Vector3 s = owner.transform.localScale;
      float x = box.size.x * s.x;
      float y = box.size.y * s.y;
      float z = box.size.z * s.z;
      inertiaTensor = Vector3((1.0f / 12.0f) * mass * (y*y + z*z),
                              (1.0f / 12.0f) * mass * (x*x + z*z),
                              (1.0f / 12.0f) * mass * (x*x + y*y));
      return;
    }
    if (auto sphere = owner.getComponent!SphereCollider()) {
      // Use max scale axis to keep sphere as sphere
      Vector3 s       = owner.transform.localScale;
      float   maxScale = s.x > s.y ? (s.x > s.z ? s.x : s.z)
        : (s.y > s.z ? s.y : s.z);
      float r = sphere.radius * maxScale;
      float i = (2.0f / 5.0f) * mass * r * r;
      inertiaTensor = Vector3(i, i, i);
      return;
    }
    // Fallback: unit sphere inertia
    float i = (2.0f / 5.0f) * mass;
    inertiaTensor = Vector3(i, i, i);
  }

public:
  version(Editor) {
    import editor.inspector.drawer;

    private FieldState[string] fieldStates;
    
    override float drawInspector(float offsetX, float offsetY, float panelW) {
      auto self = this;
      float endY = 0.0f;
      drawFields(self, fieldStates, offsetX, offsetY, panelW, &endY);
      return endY;
    }
  }
}
