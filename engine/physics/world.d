module engine.physics.world;

import std.stdio;
import std.math : abs;
import std.algorithm : max, sort, remove;
import std.datetime.stopwatch : StopWatch;
import std.parallelism : parallel, taskPool;

import raylib : Vector3, Quaternion, Matrix;
import raylib.raymath;

import engine.profiler;
import engine.core.transform : Axis;
import engine.physics.collider;
import engine.physics.rigidbody;
import engine.physics.narrowphase;
import engine.physics.aabb : AABB;
import engine.physics.boxcollider;
import engine.physics.spherecollider;

struct PhysicsProfile {
    long integrateUs;
    long broadphaseUs;
    long narrowphaseUs;
    long solverUs;
    long correctionUs;
    int  pairsAfterBroad;
    int  pairsAfterNarrow;
    int  totalContacts;
}

PhysicsProfile lastProfile;

struct ContactPair {
  Collider        a, b;
  ContactManifold manifold;
  float invMassA, invMassB;
}

// General TODO: use overloaded operators instead of raylib functions for vectors for readability (partially done already but should be consistent)

// TODO: also part of manifest?
enum float BAUMGARTE = 0.5f;
enum float SLOP      = 0.001f;

class PhysicsWorld {
  // TODO: make part of the manifest and project settings
  int solverIterations = 2; 
  float   fixedDt      = 1.0f / 60.0f;
  float   sleepVelocity = 0.05f;
  int     sleepFrames  = 90;
  Axis    broadphaseAxis = Axis.X;
  Vector3 gravity        = Vector3(0, -9.81f, 0);
 
  PhysicsProfile lastProfile;
  
  Rigidbody[] bodies;
  Collider[]  colliders;
 
  void register(Rigidbody rb) { bodies    ~= rb; }
  void register(Collider c)   { colliders ~= c;  }
 
  void unregister(Rigidbody rb) { bodies    = bodies.remove!(b => b is rb); }
  void unregister(Collider c)   { colliders = colliders.remove!(x => x is c); }
 
  void step(float dt) {
    import std.algorithm : min;
    _accumulator += min(dt, fixedDt * 4); // max 4 steps per frame, prevent death spiral
    while (_accumulator >= fixedDt) {
      fixedStep();
      _accumulator -= fixedDt;
    }
  }
 
private:
  float _accumulator = 0;
  int[]  _sleepCounters; // parallel to bodies[]
  ContactPair[] _pairs;
  ContactPair[] _previousPairs; 
 
  struct Entry { float min, max; Collider c; AABB aabb; }
  Entry[] _broadEntries;
  
  void fixedStep() {
    Profiler p;

    p.start();
    integrate(fixedDt);
    lastProfile.integrateUs = p.stop();

    p.start();
    broadphase();
    lastProfile.broadphaseUs = p.stop();
    lastProfile.pairsAfterBroad = cast(int)_pairs.length;

    p.start();
    narrowphase();
    lastProfile.narrowphaseUs = p.stop();
    version(Profile) {
      lastProfile.pairsAfterNarrow = cast(int)_pairs.length;
      lastProfile.totalContacts = 0;
      foreach (ref pa; _pairs)
        lastProfile.totalContacts += pa.manifold.count;
    }

    foreach (rb; bodies) {
      if (!rb.isSleeping && !rb.isKinematic)
        rb.cacheStepData();
    }

    p.start();
    foreach (ref pr; _pairs) {
      Rigidbody ra = pr.a.attachedRigidbody;
      Rigidbody rb = pr.b.attachedRigidbody;
      pr.invMassA = (ra !is null && !ra.isKinematic) ? 1.0f / ra.mass : 0.0f;
      pr.invMassB = (rb !is null && !rb.isKinematic) ? 1.0f / rb.mass : 0.0f;
    }
    foreach (_; 0 .. solverIterations) {
      foreach (ref pr; _pairs) {
        Rigidbody ra = pr.a.attachedRigidbody;
        Rigidbody rb = pr.b.attachedRigidbody;
        bool aAsleep = ra is null || ra.isSleeping || ra.isKinematic;
        bool bAsleep = rb is null || rb.isSleeping || rb.isKinematic;
        if (aAsleep && bAsleep) continue;
        resolve(pr);
      }
    }
    lastProfile.solverUs = p.stop();

    p.start();
    correctPositions(_pairs);
    lastProfile.correctionUs = p.stop();

    fireCallbacks(_pairs);
    import std.algorithm : swap;
    swap(_pairs, _previousPairs);
    updateSleeping();
  }
 
  void integrate(float dt) {
    import std.math : isNaN;

    foreach (rb; bodies) {
      if (rb.isSleeping || rb.isKinematic) continue;

      if (rb.useGravity)
        rb.velocity = Vector3Add(rb.velocity, Vector3Scale(gravity, dt));

      rb.velocity        = Vector3Scale(rb.velocity,        1.0f - rb.drag        * dt);
      rb.angularVelocity = Vector3Scale(rb.angularVelocity, 1.0f - rb.angularDrag * dt);

      auto t = rb.owner.transform;

      t.position = Vector3Add(t.position, Vector3Scale(rb.velocity, dt));

      float angle = Vector3Length(rb.angularVelocity) * dt;
      if (angle > 1e-6f) {
        Vector3    axis = Vector3Normalize(rb.angularVelocity);
        Quaternion dq   = QuaternionFromAxisAngle(axis, angle);
        t.rotation      = QuaternionNormalize(QuaternionMultiply(dq, t.rotation));
      }
    }
  } 

  void broadphase() {
    if (_broadEntries.length != colliders.length)
      _broadEntries.length = colliders.length;

    foreach (i, c; colliders) {
      AABB b = c.bounds();
      float mn, mx;
      final switch (broadphaseAxis) {
      case Axis.X: mn = b.min.x; mx = b.max.x; break;
      case Axis.Y: mn = b.min.y; mx = b.max.y; break;
      case Axis.Z: mn = b.min.z; mx = b.max.z; break;
      }
      _broadEntries[i] = Entry(mn, mx, c, b);
    }

    // Insertion Sort
    foreach (i; 1 .. _broadEntries.length) {
      auto key = _broadEntries[i];
      long j = cast(long)i - 1;
      while (j >= 0 && _broadEntries[j].min > key.min) {
        _broadEntries[j + 1] = _broadEntries[j];
        j--;
      }
      _broadEntries[j + 1] = key;
    }
    
    bool aabbOverlap(AABB a, AABB b) {
      return a.max.x >= b.min.x && a.min.x <= b.max.x
        && a.max.y >= b.min.y && a.min.y <= b.max.y
        && a.max.z >= b.min.z && a.min.z <= b.max.z;
    }

    // Sweep: emit candidate pairs while intervals overlap on sort axis
    size_t count = 0;
    foreach (i; 0 .. _broadEntries.length) {
      foreach (j; i + 1 .. _broadEntries.length) {
        if (_broadEntries[j].min > _broadEntries[i].max) break;
        auto ca = _broadEntries[i].c;
        auto cb = _broadEntries[j].c;
        if (ca.attachedRigidbody is null && cb.attachedRigidbody is null) continue;
        if (!aabbOverlap(_broadEntries[i].aabb, _broadEntries[j].aabb)) continue;

        if (count >= _pairs.length)
          _pairs.length = count + 64; // grow in chunks, not one-by-one

        _pairs[count++] = ContactPair(ca, cb);
      }
    }
    _pairs.length = count; // trim to size
  }
 
  private ContactManifold[] _manifoldScratch;
  private bool[]            _hitScratch;
  void narrowphase() {
    if (_manifoldScratch.length < _pairs.length)
      _manifoldScratch.length = _pairs.length;
    if (_hitScratch.length < _pairs.length)
      _hitScratch.length = _pairs.length;

    foreach (c; colliders) {
      if (auto bc = cast(BoxCollider)c)
        bc.obb(); // populates cache, safe to read in parallel after this
    }
 
    foreach (i, ref p; taskPool.parallel(_pairs)) {
      _hitScratch[i] = dispatchNarrowphase(p.a, p.b, _manifoldScratch[i]);
    }

    size_t keep = 0;
    foreach (i, ref p; _pairs) {
      if (_hitScratch[i]) {
        p.manifold        = _manifoldScratch[i];
        _pairs[keep++] = p;
      }
    }
    _pairs.length = keep;
  }

  void resolve(ref ContactPair p) {
    if (p.a.isTrigger || p.b.isTrigger) return;
    Rigidbody ra = p.a.attachedRigidbody;
    Rigidbody rb = p.b.attachedRigidbody;
    if (ra is null && rb is null) return;
    foreach (ci; 0 .. p.manifold.count)
      resolveContact(ra, rb, p.invMassA, p.invMassB, p.manifold.contacts[ci], p.manifold.count);
  }

  void resolveContact(Rigidbody ra, Rigidbody rb, float invMassA, float invMassB, ref ContactInfo c, int manifoldCount) {
    import std.math : isNaN;
    if (isNaN(c.normal.x) || isNaN(c.depth) || c.depth < 1e-10f) return;

    Vector3 rA = ra !is null
      ? Vector3Subtract(c.point, ra.owner.transform.position)
      : Vector3(0, 0, 0);
    Vector3 rB = rb !is null
      ? Vector3Subtract(c.point, rb.owner.transform.position)
      : Vector3(0, 0, 0);
    Vector3 n = c.normal;

    float angTermA = 0, angTermB = 0;
    if (ra !is null && !ra.isKinematic) {
      Vector3 rAxN  = Vector3CrossProduct(rA, n);
      Vector3 iInvR = ra.applyInverseInertia(rAxN);
      angTermA = Vector3DotProduct(Vector3CrossProduct(iInvR, rA), n);
    }
    if (rb !is null && !rb.isKinematic) {
      Vector3 rBxN  = Vector3CrossProduct(rB, n);
      Vector3 iInvR = rb.applyInverseInertia(rBxN);
      angTermB = Vector3DotProduct(Vector3CrossProduct(iInvR, rB), n);
    }
    float invMassSum = invMassA + invMassB + angTermA + angTermB;
    if (invMassSum < 1e-10f) return;

    Vector3 vA = ra !is null
      ? Vector3Add(ra.velocity, Vector3CrossProduct(ra.angularVelocity, rA))
      : Vector3(0, 0, 0);
    Vector3 vB = rb !is null
      ? Vector3Add(rb.velocity, Vector3CrossProduct(rb.angularVelocity, rB))
      : Vector3(0, 0, 0);

    float velAlongNormal = Vector3DotProduct(Vector3Subtract(vB, vA), n);
    if (velAlongNormal > -0.001f && c.depth < SLOP) return;

    float restitution = velAlongNormal > -0.5f ? 0.0f
      : (ra !is null && rb !is null) ? (ra.restitution + rb.restitution) * 0.5f
      : 0.0f;

    float   j       = -(1.0f + restitution) * velAlongNormal / invMassSum;
    Vector3 impulse = Vector3Scale(n, j);

    if (ra !is null && !ra.isKinematic) {
      ra.velocity        = Vector3Subtract(ra.velocity, Vector3Scale(impulse, invMassA));
      ra.angularVelocity = Vector3Subtract(ra.angularVelocity, ra.applyInverseInertia(Vector3CrossProduct(rA, impulse)));
      ra.wakeUp();
    }
    if (rb !is null && !rb.isKinematic) {
      rb.velocity        = Vector3Add(rb.velocity, Vector3Scale(impulse, invMassB));
      rb.angularVelocity = Vector3Add(rb.angularVelocity, rb.applyInverseInertia(Vector3CrossProduct(rB, impulse)));
      rb.wakeUp();
    }

    // Friction
    vA = ra !is null
      ? Vector3Add(ra.velocity, Vector3CrossProduct(ra.angularVelocity, rA))
      : Vector3(0, 0, 0);
    vB = rb !is null
      ? Vector3Add(rb.velocity, Vector3CrossProduct(rb.angularVelocity, rB))
      : Vector3(0, 0, 0);

    Vector3 rv      = Vector3Subtract(vB, vA);
    Vector3 tangent = Vector3Subtract(rv, Vector3Scale(n, Vector3DotProduct(rv, n)));
    float   tLen    = Vector3Length(tangent);
    if (tLen < 1e-6f) return;
    tangent = Vector3Scale(tangent, 1.0f / tLen);

    float frAngA = 0, frAngB = 0;
    if (ra !is null && !ra.isKinematic) {
      Vector3 rAxT  = Vector3CrossProduct(rA, tangent);
      Vector3 iInvR = ra.applyInverseInertia(rAxT);
      frAngA = Vector3DotProduct(Vector3CrossProduct(iInvR, rA), tangent);
    }
    if (rb !is null && !rb.isKinematic) {
      Vector3 rBxT  = Vector3CrossProduct(rB, tangent);
      Vector3 iInvR = rb.applyInverseInertia(rBxT);
      frAngB = Vector3DotProduct(Vector3CrossProduct(iInvR, rB), tangent);
    }
    float frMass = invMassA + invMassB + frAngA + frAngB;
    if (frMass < 1e-10f) return;

    float   jt = -Vector3DotProduct(rv, tangent) / frMass;
    float   mu = 0.5f; // TODO: per-material
    Vector3 fi = abs(jt) < j * mu
      ? Vector3Scale(tangent, jt)
      : Vector3Scale(tangent, -j * mu);
 
    if (ra !is null && !ra.isKinematic) {
      ra.velocity        = Vector3Subtract(ra.velocity, Vector3Scale(fi, invMassA));
      ra.angularVelocity = Vector3Subtract(ra.angularVelocity, ra.applyInverseInertia(Vector3CrossProduct(rA, fi)));
    }
    if (rb !is null && !rb.isKinematic) {
      rb.velocity        = Vector3Add(rb.velocity, Vector3Scale(fi, invMassB));
      rb.angularVelocity = Vector3Add(rb.angularVelocity, rb.applyInverseInertia(Vector3CrossProduct(rB, fi)));
    }
  }
 
  // Linear position projection; no velocity side-effects
  void correctPositions(ref ContactPair[] pairs) {
    foreach (ref p; pairs) {
      if (p.a.isTrigger || p.b.isTrigger) continue;

      Rigidbody ra = p.a.attachedRigidbody;
      Rigidbody rb = p.b.attachedRigidbody;
      if (ra is null && rb is null) continue;

      float invTotal = p.invMassA + p.invMassB;
      if (invTotal < 1e-10f) continue;

      foreach (ci; 0 .. p.manifold.count) {
        ref ContactInfo c = p.manifold.contacts[ci];

        float pen = max(c.depth - SLOP, 0.0f);
        if (pen < 1e-6f) continue;

        Vector3 corr = Vector3Scale(c.normal, BAUMGARTE * pen / (invTotal * p.manifold.count));
        
        if (ra !is null && !ra.isKinematic)
          ra.owner.transform.position = Vector3Subtract(ra.owner.transform.position, Vector3Scale(corr, p.invMassA));
        if (rb !is null && !rb.isKinematic)
          rb.owner.transform.position = Vector3Add(rb.owner.transform.position, Vector3Scale(corr, p.invMassB));
      }
    }
  }
  
  private bool[ulong] _prevContactSet;

  static ulong contactKey(Collider a, Collider b) {
    ulong pa = cast(ulong)cast(void*)a;
    ulong pb = cast(ulong)cast(void*)b;
    return pa < pb ? (pa << 32) | pb : (pb << 32) | pa;  // order-independent
  }

  void fireCallbacks(ContactPair[] current) {
    _prevContactSet.clear();
    foreach (ref p; _previousPairs)
      _prevContactSet[contactKey(p.a, p.b)] = true;

    bool wasContact(Collider a, Collider b) {
      return (contactKey(a, b) in _prevContactSet) !is null;
    }

    void notify(ref ContactPair p, bool isTrigger) {
      bool wasActive = wasContact(p.a, p.b);
      void dispatchTo(Collider self, Collider other) {
        foreach (comp; self.owner.components) {
          if (isTrigger) {
            if (auto l = cast(ITriggerListener)comp) {
              if (!wasActive) l.onTriggerEnter(other);
              else            l.onTriggerStay(other);
            }
          } else {
            if (auto l = cast(ICollisionListener)comp) {
              if (!wasActive) l.onCollisionEnter(p.manifold);
              else            l.onCollisionStay(p.manifold);
            }
          }
        }
      }
      dispatchTo(p.a, p.b);
      dispatchTo(p.b, p.a);
    }

    foreach (ref p; current)
      notify(p, p.a.isTrigger || p.b.isTrigger);

    foreach (ref prev; _previousPairs) {
      bool stillActive = false;
      foreach (ref cur; current)
        if ((cur.a is prev.a && cur.b is prev.b) || (cur.a is prev.b && cur.b is prev.a)) {
          stillActive = true; break;
        }
      if (stillActive) continue;

      bool isTrigger = prev.a.isTrigger || prev.b.isTrigger;
      void dispatchExit(Collider self, Collider other) {
        foreach (comp; self.owner.components) {
          if (isTrigger) { if (auto l = cast(ITriggerListener)comp)  l.onTriggerExit(other); }
          else           { if (auto l = cast(ICollisionListener)comp) l.onCollisionExit(prev.manifold); }
        }
      }
      dispatchExit(prev.a, prev.b);
      dispatchExit(prev.b, prev.a);
    }
  }
 
  void updateSleeping() {
    // grow counter array if new bodies were registered
    while (_sleepCounters.length < bodies.length)
      _sleepCounters ~= 0;
 
    foreach (i, rb; bodies) {
      if (rb.isKinematic) continue;
      float linVel = Vector3Length(rb.velocity);
      float angVel = Vector3Length(rb.angularVelocity);
      if (linVel + angVel < sleepVelocity) {
        _sleepCounters[i]++;
        if (_sleepCounters[i] >= sleepFrames) {
          rb.isSleeping     = true;
          rb.velocity       = Vector3(0, 0, 0);
          rb.angularVelocity = Vector3(0, 0, 0);
        }
      } else {
        _sleepCounters[i] = 0;
        rb.isSleeping      = false;
      }
    }
  }
 
  bool dispatchNarrowphase(Collider a, Collider b, out ContactManifold manifold) {
    bool result = false;
    if (auto sa = cast(SphereCollider)a) {
      if (auto sb = cast(SphereCollider)b)
        result = testSphereSphere(sa.worldCenter, sa.worldRadius,
                                  sb.worldCenter, sb.worldRadius, manifold);
      else if (auto bb = cast(BoxCollider)b)
        result = testSphereOBB(sa.worldCenter, sa.worldRadius, bb.obb(), manifold);
    } else if (auto ba = cast(BoxCollider)a) {
      if (auto sb = cast(SphereCollider)b)
        result = testSphereOBB(sb.worldCenter, sb.worldRadius, ba.obb(), manifold);
      else if (auto bb = cast(BoxCollider)b)
        result = testOBBOBB(ba.obb(), bb.obb(), manifold);
    }
    if (result) {
      Vector3 ab = Vector3Subtract(b.owner.transform.position,
                                   a.owner.transform.position);
      if (Vector3DotProduct(manifold.contacts[0].normal, ab) < 0)
        foreach (i; 0 .. manifold.count)
          manifold.contacts[i].normal = Vector3Negate(manifold.contacts[i].normal);
    }
    return result;
  }
}
