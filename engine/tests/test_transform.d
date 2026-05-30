module test_transform;

//   - TRS matrix order (translation getting rotated)
//   - Parent-child world position composition
//   - keepWorldPos round-trip on reparent
//   - Dirty flag propagation
//   - removeFromHierarchy / insertSibling slice safety
//   - Double-removeChild on reparent

import std.math   : approxEqual, abs, PI;
import raylib     : Vector3, Quaternion, Matrix;
import raylib.raymath;
import engine.core.transform : removeFromHierarchy, insertSibling, Transform;
import engine.core.gameobject;

// Helpers

private Transform makeTransform() {
  auto go = new GameObject();
  return go.transform;
}

private bool vec3Eq(Vector3 a, Vector3 b, float eps = 1e-4f) {
  return abs(a.x - b.x) < eps
      && abs(a.y - b.y) < eps
      && abs(a.z - b.z) < eps;
}

float quatDot(Quaternion a, Quaternion b) {
  return a.x*b.x + a.y*b.y + a.z*b.z + a.w*b.w;
}

// TRS order: translation must NOT be rotated by local rotation.
// Bug: T*R*S order caused position (2,0,0) with Z+90 to read back as (0,2,0).
unittest {
  auto t = makeTransform();
  t.localPosition = Vector3(2, 0, 0);
  t.localRotation = QuaternionFromAxisAngle(Vector3(0, 0, 1), PI / 2); // Z 90 deg
  auto wm = t.worldMatrix();
  assert(vec3Eq(Vector3(wm.m12, wm.m13, wm.m14), Vector3(2, 0, 0)),
    "TRS order: translation must not be rotated by local rotation");
}

// Root object: position == localPosition (no parent).
unittest {
  auto t = makeTransform();
  t.localPosition = Vector3(3, 1, -2);
  assert(vec3Eq(t.position, t.localPosition),
    "Root object: world position must equal local position");
}

// Parent-child translation composition.
// Child at local (1,0,0), parent at world (2,0,0) -> child world = (3,0,0).
unittest {
  auto parent = makeTransform();
  auto child  = makeTransform();
  parent.localPosition = Vector3(2, 0, 0);
  parent.addChild(child, false);
  child.localPosition = Vector3(1, 0, 0);
  assert(vec3Eq(child.position, Vector3(3, 0, 0)),
    "Child world position = parent world + child local");
}

// ---------------------------------------------------------------------------
// Parent rotation orbits child.
// Parent at origin rotated Y+90, child at local (1,0,0) -> world ~(0,0,-1).
// ---------------------------------------------------------------------------
unittest {
  auto parent = makeTransform();
  auto child  = makeTransform();
  parent.localRotation = QuaternionFromAxisAngle(Vector3(0, 1, 0), PI / 2);
  parent.addChild(child, false);
  child.localPosition = Vector3(1, 0, 0);
  assert(vec3Eq(child.position, Vector3(0, 0, -1)),
    "Parent Y rotation must orbit child around parent, not scene origin");
}

// keepWorldPos = true: child stays at same world position after reparent.
unittest {
  auto parent = makeTransform();
  auto child  = makeTransform();
  parent.localPosition = Vector3(5, 0, 0);
  child.localPosition  = Vector3(2, 0, 0); // world (2,0,0)
  Vector3 worldBefore  = child.position;
  parent.addChild(child, true);            // keepWorldPos
  assert(vec3Eq(child.position, worldBefore),
    "keepWorldPos=true: child world position must be preserved after reparent");
}

// keepWorldPos = false: local position is kept as-is, world position changes.
unittest {
  auto parent = makeTransform();
  auto child  = makeTransform();
  parent.localPosition = Vector3(5, 0, 0);
  child.localPosition  = Vector3(1, 0, 0);
  parent.addChild(child, false);
  // local (1,0,0) under parent (5,0,0) -> world (6,0,0)
  assert(vec3Eq(child.position, Vector3(6, 0, 0)),
    "keepWorldPos=false: local position is unchanged, world position shifts");
}

// removeChild clears parent reference.
unittest {
  auto parent = makeTransform();
  auto child  = makeTransform();
  parent.addChild(child, false);
  assert(child.parent is parent);
  parent.removeChild(child, false);
  assert(child.parent is null,
    "removeChild must clear child.parent");
  assert(parent.children.length == 0,
    "removeChild must remove child from parent.children");
}

// No double-removeChild on reparent.
// addChild calls removeChild internally; calling removeFromHierarchy before
// addChild must not leave the child in a corrupt state.
unittest {
  auto root   = makeTransform();
  auto parent = makeTransform();
  auto child  = makeTransform();
  // start: child under root
  root.addChild(child, false);
  // reparent to parent via addChild (mirrors what executeDrop does)
  auto roots = [root];
  removeFromHierarchy(roots, child); // slice-local, just testing no crash
  parent.addChild(child, false);
  assert(child.parent is parent,
    "After reparent, child.parent must be new parent");
  assert(root.children.length == 0,
    "Old parent must have no children after reparent");
}

// ---------------------------------------------------------------------------
// Dirty flag propagation: moving parent marks child world-dirty.
// ---------------------------------------------------------------------------
unittest {
  auto parent = makeTransform();
  auto child  = makeTransform();
  parent.addChild(child, false);
  child.localPosition = Vector3(1, 0, 0);
  // Force a clean world matrix on both
  cast(void) child.worldMatrix();
  assert(!child._worldDirty, "Sanity: child should be clean after worldMatrix()");
  // Move parent -> child must become dirty
  parent.localPosition = Vector3(3, 0, 0);
  assert(child._worldDirty,
    "Moving parent must propagate worldDirty to child");
  // Child world position must reflect new parent position
  assert(vec3Eq(child.position, Vector3(4, 0, 0)),
    "Child world position must update after parent moves");
}

// markWorldDirty does not re-enter if already dirty (no infinite loop).
// Tests the early-return guard in markWorldDirty with a deep chain.
unittest {
  Transform[] chain;
  foreach (i; 0 .. 20) {
    auto t = makeTransform();
    if (chain.length > 0)
      chain[$-1].addChild(t, false);
    chain ~= t;
  }
  // Dirtify root repeatedly: should not hang or stack-overflow
  foreach (_; 0 .. 1000)
    chain[0].localPosition = Vector3(cast(float)_, 0, 0); // basically a "markDirty" call
  assert(true, "markWorldDirty must not recurse infinitely on already-dirty nodes");
}

// removeFromHierarchy: finds and removes a deeply nested node.
unittest {
  auto root  = makeTransform();
  auto mid   = makeTransform();
  auto leaf  = makeTransform();
  root.addChild(mid,  false);
  mid.addChild(leaf, false);

  Transform[] roots = [root];
  bool removed = removeFromHierarchy(roots, leaf);
  assert(removed, "removeFromHierarchy must find and remove a nested node");
  assert(mid.children.length == 0, "Leaf must be removed from mid.children");
}

// removeFromHierarchy: removing a root-level node.
unittest {
  auto a = makeTransform();
  auto b = makeTransform();
  Transform[] roots = [a, b];
  bool removed = removeFromHierarchy(roots, a);
  assert(removed,          "removeFromHierarchy must remove root-level node");
  assert(roots.length == 1, "roots must shrink by one");
  assert(roots[0] is b,    "remaining root must be b");
}

// Scale inheritance: child world scale reflects parent scale.
unittest {
  auto parent = makeTransform();
  auto child  = makeTransform();
  parent.localScale = Vector3(2, 2, 2);
  parent.addChild(child, false);
  child.localScale = Vector3(1, 1, 1);
  Vector3 ws = child.scale;
  assert(vec3Eq(ws, Vector3(2, 2, 2)),
    "Child world scale must be parent scale * local scale");
}

// World rotation round-trip: set world rotation, read it back.
unittest {
  auto t   = makeTransform();
  auto q   = QuaternionFromAxisAngle(Vector3(0, 1, 0), PI / 4);
  t.rotation = q;
  auto got = t.rotation;
  // dot product close to 1 means quaternions are equivalent
  float d = abs(quatDot(q, got));
  assert(d > 0.9999f,
    "World rotation round-trip must preserve quaternion");
}

// position setter with parent: writing world pos must update local correctly.
unittest {
  auto parent = makeTransform();
  auto child  = makeTransform();
  parent.localPosition = Vector3(10, 0, 0);
  parent.addChild(child, false);
  child.position = Vector3(12, 0, 0); // world pos
  assert(vec3Eq(child.localPosition, Vector3(2, 0, 0)),
    "Setting world position must compute correct local position under parent");
}
