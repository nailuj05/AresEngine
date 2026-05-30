module engine.physics.narrowphase;

import std.math : sqrt, abs;
import raylib   : Vector3;
import raylib.raymath;

import engine.physics.aabb : AABB;
import engine.physics.collider : ContactInfo, ContactManifold;

struct OBB {
  Vector3    center;
  Vector3[3] axes;    // normalized: axes[0]=right, axes[1]=up, axes[2]=forward
  Vector3    extents; // half-sizes along each axis
}

private float obbExtent(OBB box, int i) {
  return i == 0 ? box.extents.x : i == 1 ? box.extents.y : box.extents.z;
}

private float obbProject(OBB box, Vector3 axis) {
  return box.extents.x * abs(Vector3DotProduct(box.axes[0], axis))
    + box.extents.y * abs(Vector3DotProduct(box.axes[1], axis))
    + box.extents.z * abs(Vector3DotProduct(box.axes[2], axis));
}


// Manifold
private Vector3[4] obbFaceVerts(OBB box, int ai, float sign) {
  int bi = (ai + 1) % 3;
  int ci = (ai + 2) % 3;
  Vector3 fc   = Vector3Add(box.center, Vector3Scale(box.axes[ai], sign * obbExtent(box, ai)));
  Vector3 bPos = Vector3Scale(box.axes[bi],  obbExtent(box, bi));
  Vector3 bNeg = Vector3Scale(box.axes[bi], -obbExtent(box, bi));
  Vector3 cPos = Vector3Scale(box.axes[ci],  obbExtent(box, ci));
  Vector3 cNeg = Vector3Scale(box.axes[ci], -obbExtent(box, ci));
  return [Vector3Add(Vector3Add(fc, bPos), cPos),
          Vector3Add(Vector3Add(fc, bNeg), cPos),
          Vector3Add(Vector3Add(fc, bNeg), cNeg),
          Vector3Add(Vector3Add(fc, bPos), cNeg),
          ];
}

// Sutherland-Hodgman clip in-place; keeps vertices where dot(v, n) <= d.
private int clipAgainstPlane(ref Vector3[16] poly, int count, Vector3 n, float d) {
  if (count == 0) return 0;
  Vector3[16] buf;
  int k = 0;
  foreach (i; 0 .. count) {
    Vector3 curr = poly[i];
    Vector3 prev = poly[(i + count - 1) % count];
    float   cd   = Vector3DotProduct(curr, n) - d;
    float   pd   = Vector3DotProduct(prev, n) - d;
    if (pd <= 0 && cd <= 0) {
      if (k < 16) buf[k++] = curr;
    } else if (pd > 0 && cd <= 0) {
      float t = pd / (pd - cd);
      if (k < 16) buf[k++] = Vector3Add(prev, Vector3Scale(Vector3Subtract(curr, prev), t));
      if (k < 16) buf[k++] = curr;
    } else if (pd <= 0 && cd > 0) {
      float t = pd / (pd - cd);
      if (k < 16) buf[k++] = Vector3Add(prev, Vector3Scale(Vector3Subtract(curr, prev), t));
    }
    // both outside: skip
  }
  poly[0 .. k] = buf[0 .. k];
  return k;
}

// Reduce to <=4 points: deepest, then maximize covered area.
private int reduceManifold(ContactInfo[] inp, int count, ref ContactInfo[4] output) {
  if (count <= 4) {
    foreach (i; 0 .. count) output[i] = inp[i];
    return count;
  }

  // 1. deepest
  int p0 = 0;
  foreach (i; 1 .. count)
    if (inp[i].depth > inp[p0].depth) p0 = i;
  output[0] = inp[p0];
  int n = 1;

  // 2. furthest from p0
  float maxD = -1; int p1 = -1;
  foreach (i; 0 .. count) {
    if (i == p0) continue;
    Vector3 delta = Vector3Subtract(inp[i].point, output[0].point);
    float   d2    = Vector3DotProduct(delta, delta);
    if (d2 > maxD) { maxD = d2; p1 = i; }
  }
  if (p1 < 0 || maxD < 1e-8f) return n;
  output[1] = inp[p1]; n = 2;

  // 3. furthest from edge p0-p1
  Vector3 edge = Vector3Subtract(output[1].point, output[0].point);
  float maxC = -1; int p2 = -1;
  foreach (i; 0 .. count) {
    if (i == p0 || i == p1) continue;
    Vector3 cross = Vector3CrossProduct(edge, Vector3Subtract(inp[i].point, output[0].point));
    float   c2    = Vector3DotProduct(cross, cross);
    if (c2 > maxC) { maxC = c2; p2 = i; }
  }
  if (p2 < 0 || maxC < 1e-8f) return n;
  output[2] = inp[p2]; n = 3;

  // 4. furthest from centroid of p0-p1-p2
  Vector3 cen = Vector3Scale(
                             Vector3Add(Vector3Add(output[0].point, output[1].point), output[2].point),
                             1.0f / 3.0f);
  float maxE = -1; int p3 = -1;
  foreach (i; 0 .. count) {
    if (i == p0 || i == p1 || i == p2) continue;
    Vector3 delta = Vector3Subtract(inp[i].point, cen);
    float   d2    = Vector3DotProduct(delta, delta);
    if (d2 > maxE) { maxE = d2; p3 = i; }
  }
  if (p3 < 0) return n;
  output[3] = inp[p3];
  return 4;
}


// Sphere vs Sphere
bool testSphereSphere(Vector3 ca, float ra, Vector3 cb, float rb, out ContactManifold manifold) {
  Vector3 d     = Vector3Subtract(ca, cb);
  float   dist2 = Vector3DotProduct(d, d);
  float   rsum  = ra + rb;
  if (dist2 >= rsum * rsum) return false;
  float dist = sqrt(dist2);
  manifold.contacts[0].normal = dist > 1e-6f ? Vector3Scale(d, 1.0f / dist) : Vector3(0, 1, 0);
  manifold.contacts[0].depth  = rsum - dist;
  manifold.contacts[0].point  = Vector3Add(cb, Vector3Scale(manifold.contacts[0].normal, rb));
  manifold.count = 1;
  return true;
}

// Sphere vs OBB
bool testSphereOBB(Vector3 sc, float sr, OBB box, out ContactManifold manifold) {
  Vector3 d       = Vector3Subtract(sc, box.center);
  Vector3 closest = box.center;
  foreach (i; 0 .. 3) {
    float e    = obbExtent(box, i);
    float proj = Vector3DotProduct(d, box.axes[i]);
    proj = proj < -e ? -e : proj > e ? e : proj;
    closest = Vector3Add(closest, Vector3Scale(box.axes[i], proj));
  }
  Vector3 diff  = Vector3Subtract(sc, closest);
  float   dist2 = Vector3DotProduct(diff, diff);
  if (dist2 >= sr * sr) return false;
  float dist = sqrt(dist2);
  if (dist < 1e-6f) {
    float minPen = float.max;
    foreach (i; 0 .. 3) {
      float e    = obbExtent(box, i);
      float proj = Vector3DotProduct(d, box.axes[i]);
      float pen  = e - abs(proj);
      if (pen < minPen) {
        minPen = pen;
        manifold.contacts[0].normal = Vector3Scale(box.axes[i], proj < 0 ? -1.0f : 1.0f);
        manifold.contacts[0].depth  = pen + sr;
      }
    }
  } else {
    manifold.contacts[0].normal = Vector3Scale(diff, 1.0f / dist);
    manifold.contacts[0].depth  = sr - dist;
  }
  manifold.contacts[0].point = closest;
  manifold.count = 1;
  return true;
}

// OBB vs OBB
bool testOBBOBB(OBB a, OBB b, out ContactManifold manifold) {
  Vector3 d      = Vector3Subtract(b.center, a.center);
  float   minPen = float.max;
  Vector3 bestAxis;

  bool testAxis(Vector3 axis) {
    float len2 = Vector3DotProduct(axis, axis);
    if (len2 < 1e-10f) return true; // degenerate cross product, skip
    axis = Vector3Scale(axis, 1.0f / sqrt(len2));
    float pa  = obbProject(a, axis);
    float pb  = obbProject(b, axis);
    float pen = pa + pb - abs(Vector3DotProduct(d, axis));
    if (pen <= 0) return false;
    if (pen < minPen) {
      minPen   = pen;
      bestAxis = Vector3DotProduct(d, axis) < 0 ? Vector3Negate(axis) : axis;
    }
    return true;
  }
  foreach (i; 0 .. 3) if (!testAxis(a.axes[i])) return false;
  foreach (i; 0 .. 3) if (!testAxis(b.axes[i])) return false;
  foreach (i; 0 .. 3)
    foreach (j; 0 .. 3)
      if (!testAxis(Vector3CrossProduct(a.axes[i], b.axes[j]))) return false;

  // Reference face of A: outward normal most aligned with bestAxis (toward B)
  int refAi = 0; float refSign = 1.0f, refBest = -1;
  foreach (i; 0 .. 3) {
    float dt = abs(Vector3DotProduct(a.axes[i], bestAxis));
    if (dt > refBest) {
      refBest = dt; refAi = i;
      refSign = Vector3DotProduct(a.axes[i], bestAxis) > 0 ? 1.0f : -1.0f;
    }
  }

  // Incident face of B: outward normal most aligned with -bestAxis (toward A)
  int incAi = 0; float incSign = 1.0f, incBest = -1;
  foreach (i; 0 .. 3) {
    float dt = abs(Vector3DotProduct(b.axes[i], bestAxis));
    if (dt > incBest) {
      incBest = dt; incAi = i;
      incSign = Vector3DotProduct(b.axes[i], bestAxis) < 0 ? 1.0f : -1.0f;
    }
  }

  // Reference face plane
  float   refExt    = obbExtent(a, refAi);
  Vector3 refNormal = Vector3Scale(a.axes[refAi], refSign);
  Vector3 refCenter = Vector3Add(a.center, Vector3Scale(refNormal, refExt));
  float   refPlaneD = Vector3DotProduct(refNormal, refCenter);

  // Side planes of reference face (the two axes perpendicular to refNormal)
  int     sB   = (refAi + 1) % 3;
  int     sC   = (refAi + 2) % 3;
  float   eb   = obbExtent(a, sB);
  float   ec   = obbExtent(a, sC);
  Vector3 axB  = a.axes[sB];
  Vector3 axC  = a.axes[sC];
  float   cenB = Vector3DotProduct(refCenter, axB);
  float   cenC = Vector3DotProduct(refCenter, axC);

  // Build polygon from incident face, clip against 4 side planes
  Vector3[4]  inc = obbFaceVerts(b, incAi, incSign);
  Vector3[16] poly;
  foreach (i; 0 .. 4) poly[i] = inc[i];
  int pc = 4;

  pc = clipAgainstPlane(poly, pc,              axB,            cenB + eb); if (pc == 0) return false;
  pc = clipAgainstPlane(poly, pc, Vector3Negate(axB), -(cenB - eb));       if (pc == 0) return false;
  pc = clipAgainstPlane(poly, pc,              axC,            cenC + ec); if (pc == 0) return false;
  pc = clipAgainstPlane(poly, pc, Vector3Negate(axC), -(cenC - ec));       if (pc == 0) return false;

  // Keep points at or below the reference face plane (penetrating)
  ContactInfo[16] contacts;
  int cc = 0;
  foreach (i; 0 .. pc) {
    float depth = refPlaneD - Vector3DotProduct(poly[i], refNormal);
    if (depth >= -1e-3f) {
      contacts[cc].point  = poly[i];
      contacts[cc].normal = bestAxis;
      contacts[cc].depth  = depth > 0 ? depth : 0;
      cc++;
    }
  }
  if (cc == 0) return false;

  manifold.count = reduceManifold(contacts[0 .. cc], cc, manifold.contacts);
  return manifold.count > 0;
}
