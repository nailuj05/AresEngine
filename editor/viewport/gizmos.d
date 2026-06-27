module editor.viewport.gizmos;

import raylib;

import engine.core.gameobject;
import editor.viewport.viewport;

enum GizmoMode  { TRANSLATE = 0, ROTATE = 1, SCALE = 2 }
enum GizmoSpace { GLOBAL = 0, LOCAL = 1 }

static immutable Color[3] axisColors = [Colors.RED, Colors.GREEN, Colors.BLUE];

// TODO: separate from transform::Axis, maybe merge in the future?
enum Axis { NONE = -1, X = 0, Y = 1, Z = 2 }

struct GizmoState {
  GizmoMode  mode  = GizmoMode.TRANSLATE;
  GizmoSpace space = GizmoSpace.GLOBAL;
  Axis       hotAxis  = Axis.NONE;   // hovered
  Axis       dragAxis = Axis.NONE;   // locked during drag
  bool       dragging = false;
  Vector3    dragOrigin;             // world point where drag started
  Vector3    dragStartVec;           // rotate: unit vec in ring plane at drag start
  Vector3    transformOrigin;        // object position at drag start
  Quaternion rotOrigin;              // object rotation at drag start
  Vector3    scaleOrigin;            // object scale at drag start
}

// Axis helpers

// World-space direction of a canonical axis.
Vector3 axisDir(Axis axis) {
  final switch (axis) {
  case Axis.X:    return Vector3(1, 0, 0);
  case Axis.Y:    return Vector3(0, 1, 0);
  case Axis.Z:    return Vector3(0, 0, 1);
  case Axis.NONE: return Vector3(0, 0, 0);
  }
}

// Returns the gizmo axis direction in world space, respecting GizmoSpace.
// In LOCAL mode the object's rotation is applied to the canonical axis.
Vector3 getAxisDir(Axis axis, GizmoSpace space, Quaternion rotation) {
  Vector3 dir = axisDir(axis);
  return (space == GizmoSpace.LOCAL)
    ? Vector3RotateByQuaternion(dir, rotation)
    : dir;
}

// Drawing

void drawGizmo(GizmoState g, Vector3 origin, Quaternion rotation, Camera3D cam) {
  float sz = Vector3Distance(cam.position, origin) * 0.12f;
  static immutable Color[3] colors = [Colors.RED, Colors.GREEN, Colors.BLUE];

  foreach (i; 0 .. 3) {
    Axis    ax  = cast(Axis)i;
    Color   c   = (g.hotAxis == ax || g.dragAxis == ax) ? Colors.YELLOW : colors[i];
    Vector3 dir = getAxisDir(ax, g.space, rotation);

    final switch (g.mode) {

    case GizmoMode.TRANSLATE: {
      Vector3 end = Vector3Add(origin, Vector3Scale(dir, sz));
      DrawLine3D(origin, end, c);
      DrawSphere(end, sz * 0.06f, c);
      break;
    }

    case GizmoMode.ROTATE: {
      // The ring lies in the plane perpendicular to `dir`.
      // u and v are two orthogonal vectors spanning that plane.
      // In LOCAL mode these come from the object's rotated axes.
      Vector3 u, v;
      final switch (ax) {
      case Axis.X:    u = getAxisDir(Axis.Y, g.space, rotation);
        v = getAxisDir(Axis.Z, g.space, rotation); break;
      case Axis.Y:    u = getAxisDir(Axis.X, g.space, rotation);
        v = getAxisDir(Axis.Z, g.space, rotation); break;
      case Axis.Z:    u = getAxisDir(Axis.X, g.space, rotation);
        v = getAxisDir(Axis.Y, g.space, rotation); break;
      case Axis.NONE: u = Vector3(0,0,0); v = Vector3(0,0,0);    break;
      }
      import std.math : sin, cos, PI;
      enum SEGS = 32;
      foreach (s; 0 .. SEGS) {
        float a0 = 2.0f * PI * s       / SEGS;
        float a1 = 2.0f * PI * (s + 1) / SEGS;
        Vector3 p0 = Vector3Add(origin, Vector3Add(Vector3Scale(u, cos(a0) * sz),
                                                   Vector3Scale(v, sin(a0) * sz)));
        Vector3 p1 = Vector3Add(origin, Vector3Add(Vector3Scale(u, cos(a1) * sz),
                                                   Vector3Scale(v, sin(a1) * sz)));
        DrawLine3D(p0, p1, c);
      }
      break;
    }

    case GizmoMode.SCALE: {
      Vector3 end = Vector3Add(origin, Vector3Scale(dir, sz));
      DrawLine3D(origin, end, c);
      float cs = sz * 0.08f;
      DrawCube(end, cs, cs, cs, c);
      break;
    }
    }
  }
}

// Update 

void updateGizmo(ref GizmoState g, Rectangle vp, Camera3D cam, ref GameObject selected) {
  if (!isMouseInRect(GetMousePosition(), vp)) return;

  Ray        ray = getViewportRay(GetMousePosition(), vp, cam);
  Vector3    pos = selected.transform.position;
  Quaternion rot = selected.transform.rotation;
  float      sz  = Vector3Distance(cam.position, pos) * 0.12f;

  if (!g.dragging) {
    // Hover detection 
    g.hotAxis = Axis.NONE;
    float nearest = float.max;
    foreach (ax; [Axis.X, Axis.Y, Axis.Z]) {
      Vector3 dir = getAxisDir(ax, g.space, rot);
      float dist;
      bool hit = false;
      final switch (g.mode) {
      case GizmoMode.TRANSLATE: hit = rayHitsAxis(ray, pos, dir, sz, dist); break;
      case GizmoMode.ROTATE:    hit = rayHitsRing(ray, pos, dir, sz, dist); break;
      case GizmoMode.SCALE:     hit = rayHitsAxis(ray, pos, dir, sz, dist); break;
      }
      if (hit && dist < nearest) { nearest = dist; g.hotAxis = ax; }
    }

    // Begin drag 
    if (IsMouseButtonPressed(MouseButton.MOUSE_BUTTON_LEFT) && g.hotAxis != Axis.NONE) {
      g.dragging        = true;
      g.dragAxis        = g.hotAxis;
      g.transformOrigin = pos;
      g.rotOrigin       = rot;
      g.scaleOrigin     = selected.transform.scale;

      // Freeze the axis direction at drag start so it doesn't drift during
      // the drag (matters for LOCAL rotate where the object spins live).
      Vector3 dragDir = getAxisDir(g.dragAxis, g.space, rot);

      final switch (g.mode) {
      case GizmoMode.TRANSLATE:
      case GizmoMode.SCALE: {
        Vector3 pn   = getDragPlaneNormal(dragDir, cam, pos);
        g.dragOrigin = projectRayOntoAxis(ray, pos, dragDir, pn);
        break;
      }
      case GizmoMode.ROTATE: {
        import std.math : isNaN;
        float t = rayPlaneT(ray, dragDir, pos);
        if (isNaN(t)) { g.dragging = false; break; }
        Vector3 hit    = Vector3Add(ray.position, Vector3Scale(ray.direction, t));
        g.dragStartVec = Vector3Normalize(Vector3Subtract(hit, pos));
        break;
      }
      }
    }

  } else {
    // End drag 
    if (IsMouseButtonReleased(MouseButton.MOUSE_BUTTON_LEFT)) { g.dragging = false; return; }

    // Use the axis direction frozen at drag start (rotOrigin) so the handle
    // is stable throughout the drag even if the object rotates.
    Vector3 dragDir = getAxisDir(g.dragAxis, g.space, g.rotOrigin);

    final switch (g.mode) {

    case GizmoMode.TRANSLATE: {
      Vector3 pn  = getDragPlaneNormal(dragDir, cam, g.transformOrigin);
      Vector3 cur = projectRayOntoAxis(ray, g.transformOrigin, dragDir, pn);
      selected.transform.position = Vector3Add(g.transformOrigin, Vector3Subtract(cur, g.dragOrigin));
      break;
    }

    case GizmoMode.ROTATE: {
      import std.math : isNaN, atan2;
      float t = rayPlaneT(ray, dragDir, g.transformOrigin);
      if (isNaN(t)) break;
      Vector3 hit        = Vector3Add(ray.position, Vector3Scale(ray.direction, t));
      Vector3 currentVec = Vector3Normalize(Vector3Subtract(hit, g.transformOrigin));
      float   dot        = Vector3DotProduct(g.dragStartVec, currentVec);
      Vector3 cross      = Vector3CrossProduct(g.dragStartVec, currentVec);
      float   angle      = atan2(Vector3DotProduct(cross, dragDir), dot);
      // Apply delta rotation on top of the captured start rotation.
      // QuaternionFromAxisAngle uses the frozen world-space dragDir, which
      // is identical for GLOBAL and LOCAL (the local axis was already
      // resolved to world space in dragDir).
      selected.transform.rotation = QuaternionMultiply(QuaternionFromAxisAngle(dragDir, angle), g.rotOrigin);
      break;
    }

    case GizmoMode.SCALE: {
      import std.math : abs;
      Vector3 pn     = getDragPlaneNormal(dragDir, cam, g.transformOrigin);
      Vector3 cur    = projectRayOntoAxis(ray, g.transformOrigin, dragDir, pn);
      float   startD = Vector3DotProduct(Vector3Subtract(g.dragOrigin, g.transformOrigin), dragDir);
      float   currD  = Vector3DotProduct(Vector3Subtract(cur,          g.transformOrigin), dragDir);
      float   ratio  = abs(startD) > 1e-6f ? currD / startD : 1.0f;
      Vector3 s      = g.scaleOrigin;
      // Scale is always applied to the object's local scale components
      // regardless of GizmoSpace — matching Unity's behaviour.
      final switch (g.dragAxis) {
      case Axis.X:    s.x *= ratio; break;
      case Axis.Y:    s.y *= ratio; break;
      case Axis.Z:    s.z *= ratio; break;
      case Axis.NONE: break;
      }
      selected.transform.scale = s;
      break;
    }
    }
  }
}

// Ray / geometry tests 

// Minimum distance between the camera ray and the axis line segment.
// Works for any axis direction (world or local), unlike an AABB test.
bool rayHitsAxis(Ray ray, Vector3 origin, Vector3 dir, float size, out float dist) {
  import std.math : abs, sqrt;

  float threshold = size * 0.08f;
  Vector3 w0 = Vector3Subtract(ray.position, origin);
  float   a  = Vector3DotProduct(ray.direction, ray.direction); // ≈ 1
  float   b  = Vector3DotProduct(ray.direction, dir);
  float   c  = Vector3DotProduct(dir, dir);                     // ≈ 1
  float   d  = Vector3DotProduct(ray.direction, w0);
  float   e  = Vector3DotProduct(dir, w0);
  float   dv = a * c - b * b;

  float t, s;
  if (abs(dv) < 1e-6f) {        // ray and axis are (nearly) parallel
    t = 0.0f;
    s = e / c;
  } else {
    t = (b * e - c * d) / dv;
    s = (a * e - b * d) / dv;
  }

  if (t < 0.0f)   t = 0.0f;    // behind camera
  if (s < 0.0f)   s = 0.0f;    // clamp to segment start
  if (s > size)   s = size;     // clamp to segment end

  Vector3 p1 = Vector3Add(ray.position, Vector3Scale(ray.direction, t));
  Vector3 p2 = Vector3Add(origin,       Vector3Scale(dir, s));

  if (Vector3Distance(p1, p2) <= threshold) { dist = t; return true; }
  return false;
}

// Intersect ray with the ring plane, accept if the hit is within the ring band.
bool rayHitsRing(Ray ray, Vector3 origin, Vector3 dir, float size, out float dist) {
  import std.math : isNaN;
  float t = rayPlaneT(ray, dir, origin);
  if (isNaN(t)) return false;
  Vector3 hit = Vector3Add(ray.position, Vector3Scale(ray.direction, t));
  float   d   = Vector3Distance(hit, origin);
  if (d >= size * 0.8f && d <= size * 1.1f) { dist = t; return true; }
  return false;
}

// Ray–plane intersection; returns NaN when ray is parallel to the plane or
// the intersection is behind the ray origin.
private float rayPlaneT(Ray ray, Vector3 normal, Vector3 point) {
  import std.math : abs;
  float denom = Vector3DotProduct(normal, ray.direction);
  if (abs(denom) < 1e-6f) return float.nan;
  float t = Vector3DotProduct(Vector3Subtract(point, ray.position), normal) / denom;
  return t > 0.0f ? t : float.nan;
}

// Drag plane helpers 

// The drag plane's normal is chosen so it faces the camera as much as possible
// while remaining perpendicular to the drag axis — the same heuristic Unity uses.
Vector3 getDragPlaneNormal(Vector3 axisDirection, Camera3D cam, Vector3 origin) {
  Vector3 toCamera = Vector3Normalize(Vector3Subtract(cam.position, origin));
  // Remove the component along the drag axis → plane faces the camera.
  Vector3 n = Vector3Subtract(toCamera, Vector3Scale(axisDirection, Vector3DotProduct(toCamera, axisDirection)));
  return Vector3Normalize(n);
}

// Projects the ray onto a 3-D line (origin + t*axisDirection) by first
// intersecting the ray with a plane whose normal is `planeNormal`.
Vector3 projectRayOntoAxis(Ray ray, Vector3 origin, Vector3 axisDirection,
                           Vector3 planeNormal) {
  float d    = Vector3DotProduct(planeNormal, origin);
  float t    = (d - Vector3DotProduct(planeNormal, ray.position))
    / Vector3DotProduct(planeNormal, ray.direction);
  Vector3 hit  = Vector3Add(ray.position, Vector3Scale(ray.direction, t));
  float   proj = Vector3DotProduct(Vector3Subtract(hit, origin), axisDirection);
  return Vector3Add(origin, Vector3Scale(axisDirection, proj));
}

// Misc 

bool isMouseInRect(Vector2 mouse, Rectangle rect) {
  return mouse.x >= rect.x && mouse.x <= rect.x + rect.width
    && mouse.y >= rect.y && mouse.y <= rect.y + rect.height;
}
