module editor.editorcamera;

import raylib;

struct EditorCamera {
  Camera3D cam;
  private bool dragStartedInViewport;

  static EditorCamera create(Vector3 pos = Vector3(0, 10, 10), Vector3 target = Vector3(0, 0 ,0), Vector3 up = Vector3(0, 1, 0)) {
    EditorCamera ec;
    ec.cam = Camera3D(
      pos,
      target,
      up,
      45.0f,
      CameraProjection.CAMERA_PERSPECTIVE
    );
    return ec;
  }

  void update(Rectangle r) {
    import std.math      : atan2, asin, sin, cos, PI;
    import std.algorithm : clamp;

    enum float SENSITIVITY = 0.15f * (PI / 180.0f);
    enum float PITCH_LIMIT = 89.0f * (PI / 180.0f);
    enum float PAN_FACTOR  = 0.0005f;
    enum float ZOOM_FACTOR = 0.05f;

    bool inViewport = CheckCollisionPointRec(GetMousePosition(), r);

    float wheel = GetMouseWheelMove();
    if (wheel != 0.0f && inViewport) {
      Vector3 toTarget = Vector3Subtract(cam.target, cam.position);
      float   dist     = Vector3Length(toTarget);
      dist = clamp(dist - wheel * dist * ZOOM_FACTOR, 0.5f, 1000.0f);
      cam.position = Vector3Subtract(cam.target,
                                     Vector3Scale(Vector3Normalize(toTarget), dist));
    }

    if (IsMouseButtonPressed(MouseButton.MOUSE_BUTTON_LEFT))
      dragStartedInViewport = inViewport;
    if (!IsMouseButtonDown(MouseButton.MOUSE_BUTTON_LEFT)) {
      dragStartedInViewport = false;
      return;
    }
    if (!dragStartedInViewport) return;

    Vector2 delta = GetMouseDelta();
    if (delta.x == 0 && delta.y == 0) return;

    bool shift = IsKeyDown(KeyboardKey.KEY_LEFT_SHIFT)
              || IsKeyDown(KeyboardKey.KEY_RIGHT_SHIFT);

    if (shift) {
      Vector3 forward = Vector3Normalize(Vector3Subtract(cam.target, cam.position));
      Vector3 right   = Vector3Normalize(Vector3CrossProduct(forward, cam.up));
      Vector3 camUp   = Vector3CrossProduct(right, forward);
      float   dist    = Vector3Length(Vector3Subtract(cam.target, cam.position));
      float   speed   = dist * PAN_FACTOR;
      Vector3 pan = Vector3Add(Vector3Scale(right, -delta.x * speed),
                               Vector3Scale(camUp,  delta.y * speed));
      cam.position = Vector3Add(cam.position, pan);
      cam.target   = Vector3Add(cam.target,   pan);
    } else {
      Vector3 offset = Vector3Subtract(cam.position, cam.target);
      float   dist   = Vector3Length(offset);
      float theta = atan2(offset.x, offset.z);
      float phi   = asin(clamp(offset.y / dist, -1.0f, 1.0f));
      theta -= delta.x * SENSITIVITY;
      phi    = clamp(phi + delta.y * SENSITIVITY, -PITCH_LIMIT, PITCH_LIMIT);
      cam.position = Vector3Add(cam.target, Vector3(
        dist * cos(phi) * sin(theta),
        dist * sin(phi),
        dist * cos(phi) * cos(theta)
      ));
    }
  }
}
