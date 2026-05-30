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

  // Returns the world-space inverse inertia tensor (diagonal 3x3 as Vector3).
  Vector3 worldInverseInertia() nothrow {
    if (inertiaTensor.x < 1e-10f) return Vector3(0, 0, 0);
    // Diagonal local inverse
    Vector3 localInv = Vector3(1.0f / inertiaTensor.x,
                               1.0f / inertiaTensor.y,
                               1.0f / inertiaTensor.z);
    // For a diagonal tensor, world-space inverse is R * diag(localInv) * R^T.
    // Applying it to a vector v: result = R * (localInv * (R^T * v))
    // We store it as a lambda-style method; callers use applyInverseInertia.
    return localInv;
  }

  // Apply world-space inverse inertia tensor to a vector.
  Vector3 applyInverseInertia(Vector3 v) nothrow {
    Vector3 localInv = worldInverseInertia();
    if (localInv.x < 1e-10f) return Vector3(0, 0, 0);

    // Bring v into local space, scale by localInv, bring back to world space.
    Quaternion q    = owner.transform.localRotation;
    Quaternion qInv = QuaternionInvert(q);

    Vector3 local  = Vector3RotateByQuaternion(v, qInv);
    Vector3 scaled = Vector3(local.x * localInv.x,
                             local.y * localInv.y,
                             local.z * localInv.z);
    return Vector3RotateByQuaternion(scaled, q);
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
    
    override ulong drawInspector(ulong offsetX, ulong offsetY, ulong panelW) {
      auto self = this;
      return drawFields(self, fieldStates, offsetX, offsetY, panelW);
    }
  }
}
