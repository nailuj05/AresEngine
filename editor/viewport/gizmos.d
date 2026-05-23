module editor.viewport.gizmos;

import raylib;

import engine.core.gameobject;

import editor.viewport.viewport;

enum GizmoMode { TRANSLATE,
                 ROTATE,
                 SCALE
}

static immutable Color[3] axisColors = [Colors.RED, Colors.GREEN, Colors.BLUE];

// TODO: seperate from transform::Axis, maybe merge in the future?
enum Axis { NONE = -1, X = 0, Y = 1, Z = 2 }

struct GizmoState {
  GizmoMode  mode = GizmoMode.TRANSLATE;
  Axis       hotAxis   = Axis.NONE;   // hovered
  Axis       dragAxis  = Axis.NONE;   // locked during drag
  bool       dragging  = false;
  Vector3    dragOrigin;              // world point where drag started
  Vector3    dragStartVec;            // rotation: unit vec in ring plane at drag start
  Vector3    transformOrigin;
  Quaternion rotOrigin;
  Vector3    scaleOrigin;
}


void drawGizmo(GizmoState g, Vector3 origin, Camera3D cam) {
  float sz = Vector3Distance(cam.position, origin) * 0.12f;
  static immutable Color[3] colors = [Colors.RED, Colors.GREEN, Colors.BLUE];

  foreach (i; 0 .. 3) {
    Axis  ax = cast(Axis)i;
    Color c  = (g.hotAxis == ax || g.dragAxis == ax) ? Colors.YELLOW : colors[i];

    final switch (g.mode) {
    case GizmoMode.TRANSLATE: {
      Vector3 end = Vector3Add(origin, Vector3Scale(axisDir(ax), sz));
      DrawLine3D(origin, end, c);
      DrawSphere(end, sz * 0.06f, c);
      break;
    }
    case GizmoMode.ROTATE: {
      Vector3 u, v;
      final switch (ax) {
      case Axis.X:    u = Vector3(0,1,0); v = Vector3(0,0,1); break;
      case Axis.Y:    u = Vector3(1,0,0); v = Vector3(0,0,1); break;
      case Axis.Z:    u = Vector3(1,0,0); v = Vector3(0,1,0); break;
      case Axis.NONE: u = Vector3(0,0,0); v = Vector3(0,0,0); break;
      }
      import std.math : sin, cos, PI;
      enum SEGS = 16;
      foreach (s; 0 .. SEGS) {
        float a0 = 2.0f * PI * s       / SEGS;
        float a1 = 2.0f * PI * (s + 1) / SEGS;
        Vector3 p0 = Vector3Add(origin, Vector3Add(Vector3Scale(u, cos(a0) * sz), Vector3Scale(v, sin(a0) * sz)));
        Vector3 p1 = Vector3Add(origin, Vector3Add(Vector3Scale(u, cos(a1) * sz), Vector3Scale(v, sin(a1) * sz)));
        DrawLine3D(p0, p1, c);
      }
      break;
    }
    case GizmoMode.SCALE: {
      Vector3 end = Vector3Add(origin, Vector3Scale(axisDir(ax), sz));
      DrawLine3D(origin, end, c);
      float cs = sz * 0.08f;
      DrawCube(end, cs, cs, cs, c);
      break;
    }
    }
  }
}

void updateGizmo(ref GizmoState g, Rectangle vp, Camera3D cam, ref GameObject selected) {
  if (!isMouseInRect(GetMousePosition(), vp)) return;

  Ray     ray = getViewportRay(GetMousePosition(), vp, cam);
  Vector3 pos = selected.transform.position;
  float   sz  = Vector3Distance(cam.position, pos) * 0.12f;


  if (!g.dragging) {
    g.hotAxis = Axis.NONE;
    float nearest = float.max;
    foreach (ax; [Axis.X, Axis.Y, Axis.Z]) {
      float dist;
      bool hit = false;
      final switch (g.mode) {
      case GizmoMode.TRANSLATE: hit = rayHitsAxis(ray, pos, ax, sz, dist); break;
      case GizmoMode.ROTATE:    hit = rayHitsRing(ray, pos, ax, sz, dist); break;
      case GizmoMode.SCALE:     hit = rayHitsAxis(ray, pos, ax, sz, dist); break;
      }
      if (hit && dist < nearest) { nearest = dist; g.hotAxis = ax; }
    }

    if (IsMouseButtonPressed(MouseButton.MOUSE_BUTTON_LEFT) && g.hotAxis != Axis.NONE) {
      g.dragging        = true;
      g.dragAxis        = g.hotAxis;
      g.transformOrigin = pos;
      g.rotOrigin       = selected.transform.rotation;
      g.scaleOrigin     = selected.transform.scale;

      final switch (g.mode) {
      case GizmoMode.TRANSLATE:
      case GizmoMode.SCALE: {
        Vector3 pn   = getDragPlaneNormal(g.dragAxis, cam, pos);
        g.dragOrigin = projectRayOntoAxis(ray, pos, axisDir(g.dragAxis), pn);
        break;
      }
      case GizmoMode.ROTATE: {
        import std.math : isNaN;
        float t = rayPlaneT(ray, axisDir(g.dragAxis), pos);
        if (isNaN(t)) { g.dragging = false; break; }
        Vector3 hit    = Vector3Add(ray.position, Vector3Scale(ray.direction, t));
        g.dragStartVec = Vector3Normalize(Vector3Subtract(hit, pos));
        break;
      }
      }
    }
  } else {
    if (IsMouseButtonReleased(MouseButton.MOUSE_BUTTON_LEFT)) { g.dragging = false; return; }

    final switch (g.mode) {
    case GizmoMode.TRANSLATE: {
      Vector3 pn = getDragPlaneNormal(g.dragAxis, cam, g.transformOrigin);
      Vector3 cur = projectRayOntoAxis(ray, g.transformOrigin, axisDir(g.dragAxis), pn);
      selected.transform.position = Vector3Add(g.transformOrigin,
                                               Vector3Subtract(cur, g.dragOrigin));
      break;
    }
    case GizmoMode.ROTATE: {
      import std.math : isNaN, atan2;
      Vector3 axDir = axisDir(g.dragAxis);
      float t = rayPlaneT(ray, axDir, g.transformOrigin);
      if (isNaN(t)) break;
      Vector3 hit        = Vector3Add(ray.position, Vector3Scale(ray.direction, t));
      Vector3 currentVec = Vector3Normalize(Vector3Subtract(hit, g.transformOrigin));
      float   dot        = Vector3DotProduct(g.dragStartVec, currentVec);
      Vector3 cross      = Vector3CrossProduct(g.dragStartVec, currentVec);
      float   angle      = atan2(Vector3DotProduct(cross, axDir), dot);
      selected.transform.rotation = QuaternionMultiply(
                                                       QuaternionFromAxisAngle(axDir, angle), g.rotOrigin
                                                       );
      break;
    }
    case GizmoMode.SCALE: {
      import std.math : abs;
      Vector3 pn  = getDragPlaneNormal(g.dragAxis, cam, g.transformOrigin);
      Vector3 cur = projectRayOntoAxis(ray, g.transformOrigin, axisDir(g.dragAxis), pn);
      Vector3 ax  = axisDir(g.dragAxis);
      float startD = Vector3DotProduct(Vector3Subtract(g.dragOrigin,    g.transformOrigin), ax);
      float currD  = Vector3DotProduct(Vector3Subtract(cur,             g.transformOrigin), ax);
      float ratio  = abs(startD) > 1e-6f ? currD / startD : 1.0f;
      Vector3 s    = g.scaleOrigin;
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

bool rayHitsAxis(Ray ray, Vector3 origin, Axis axis, float size, out float dist) {
  float r = size * 0.08f;
  Vector3 end = Vector3Add(origin, Vector3Scale(axisDir(axis), size));

  import std.algorithm : min, max;
  BoundingBox bb = {
    min: Vector3(
      min(origin.x, end.x) - r,
      min(origin.y, end.y) - r,
      min(origin.z, end.z) - r,
    ),
    max: Vector3(
      max(origin.x, end.x) + r,
      max(origin.y, end.y) + r,
      max(origin.z, end.z) + r,
    ),
  };
  auto col = GetRayCollisionBox(ray, bb);
  dist = col.distance;
  return col.hit;
}

private float rayPlaneT(Ray ray, Vector3 normal, Vector3 point) {
  import std.math : abs;
  float denom = Vector3DotProduct(normal, ray.direction);
  if (abs(denom) < 1e-6f) return float.nan;
  float t = Vector3DotProduct(Vector3Subtract(point, ray.position), normal) / denom;
  return t > 0.0f ? t : float.nan;
}

bool rayHitsRing(Ray ray, Vector3 origin, Axis axis, float size, out float dist) {
  import std.math : isNaN;
  float t = rayPlaneT(ray, axisDir(axis), origin);
  if (isNaN(t)) return false;
  Vector3 hit = Vector3Add(ray.position, Vector3Scale(ray.direction, t));
  float d = Vector3Distance(hit, origin);
  if (d >= size * 0.8f && d <= size * 1.1f) { dist = t; return true; }
  return false;
}

Vector3 axisDir(Axis axis) {
  final switch (axis) {
    case Axis.X:    return Vector3(1, 0, 0);
    case Axis.Y:    return Vector3(0, 1, 0);
    case Axis.Z:    return Vector3(0, 0, 1);
    case Axis.NONE: return Vector3(0, 0, 0);
  }
}

bool isMouseInRect(Vector2 mouse, Rectangle rect) {
  return mouse.x >= rect.x && mouse.x <= rect.x + rect.width
    && mouse.y >= rect.y && mouse.y <= rect.y + rect.height;
}

// --- Translation ---
Vector3 getDragPlaneNormal(Axis axis, Camera3D cam, Vector3 origin) {
  Vector3[3] axDirs = [Vector3(1,0,0), Vector3(0,1,0), Vector3(0,0,1)];
  Vector3 toCamera = Vector3Normalize(Vector3Subtract(cam.position, origin));
  // plane normal = component of toCamera perpendicular to drag axis
  Vector3 ax = axDirs[axis];
  Vector3 n  = Vector3Subtract(toCamera, Vector3Scale(ax, Vector3DotProduct(toCamera, ax)));
  return Vector3Normalize(n);
}

Vector3 projectRayOntoAxis(Ray ray, Vector3 origin, Vector3 axisDir, Vector3 planeNormal) {
  float d = Vector3DotProduct(planeNormal, origin);
  float t = (d - Vector3DotProduct(planeNormal, ray.position)) / Vector3DotProduct(planeNormal, ray.direction);
  Vector3 hit = Vector3Add(ray.position, Vector3Scale(ray.direction, t));
  // constrain to axis
  float proj = Vector3DotProduct(Vector3Subtract(hit, origin), axisDir);
  return Vector3Add(origin, Vector3Scale(axisDir, proj));
}
