module editor.viewport.gizmos;

import raylib;

import engine.core.gameobject;

import editor.viewport.viewport;

enum GizmoMode { SELECT, TRANSLATE, ROTATE, SCALE }

static immutable Color[3] axisColors = [Colors.RED, Colors.GREEN, Colors.BLUE];

// TODO: seperate from transform::Axis, maybe merge in the future?
enum Axis { NONE = -1, X = 0, Y = 1, Z = 2 }

struct GizmoState {
  GizmoMode  mode = GizmoMode.SELECT;
  Axis       hotAxis   = Axis.NONE;   // hovered
  Axis       dragAxis  = Axis.NONE;   // locked during drag
  bool       dragging  = false;
  Vector3    dragOrigin;              // world point where drag started
  Vector3    transformOrigin;         // object pos/rot/scale at drag start
}


void drawGizmo(GizmoState g, Vector3 origin, Camera3D cam) {
  float sz = Vector3Distance(cam.position, origin) * 0.12f;
  Vector3[3] ends = [
    Vector3Add(origin, Vector3(sz, 0, 0)),
    Vector3Add(origin, Vector3(0, sz, 0)),
    Vector3Add(origin, Vector3(0, 0, sz)),
  ];
  foreach (i, end; ends) {
    Color c = axisColors[i];
    if (g.hotAxis == i || g.dragAxis == i) {
      c = Colors.YELLOW;
    }
    DrawLine3D(origin, end, c);
    DrawSphere(end, sz * 0.06f, c);
  }
}

void updateGizmo(ref GizmoState g, Rectangle vp, Camera3D cam, ref GameObject selected) {
  if (selected is null) return;
  if (!isMouseInRect(GetMousePosition(), vp)) return;

  Ray ray = getViewportRay(GetMousePosition(), vp, cam);
  Vector3 pos = selected.transform.position;
  float   sz  = Vector3Distance(cam.position, pos) * 0.12f;

  if (!g.dragging) {
    g.hotAxis = Axis.NONE;
    float nearest = float.max;
    foreach (ax; [Axis.X, Axis.Y, Axis.Z]) {
      float dist;
      if (rayHitsAxis(ray, pos, ax, sz, dist) && dist < nearest) {
        nearest = dist;
        g.hotAxis = ax;
      }
    }

    if (IsMouseButtonPressed(MouseButton.MOUSE_BUTTON_LEFT) && g.hotAxis != Axis.NONE) {
      g.dragging        = true;
      g.dragAxis        = g.hotAxis;
      g.transformOrigin = pos;
      g.dragOrigin      = projectRayOntoAxis(ray, pos, axisDir(g.dragAxis),
                                             getDragPlaneNormal(g.dragAxis, cam, pos));
    }
  } else {
    Vector3 current = projectRayOntoAxis(ray, g.transformOrigin, axisDir(g.dragAxis), getDragPlaneNormal(g.dragAxis, cam, g.transformOrigin));
    selected.transform.position = Vector3Add(g.transformOrigin, Vector3Subtract(current, g.dragOrigin));

    if (IsMouseButtonReleased(MouseButton.MOUSE_BUTTON_LEFT)) {
      g.dragAxis = Axis.NONE;
      g.dragging = false;
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

// --- Rotation ---

// --- Scale ---
