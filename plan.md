# Ares Game Engine -- Design Plan

## Overview

A simple, self-contained 2D/3D game engine written in **D**, using **Raylib** for rendering/input
and **RayGUI** for UI layout.

---

## Technology Stack

| Layer       | Technology                                      |
|-------------|-------------------------------------------------|
| Language    | D                                               |
| Rendering   | Raylib                                          |
| UI Layout   | RayGUI                                          |
| Scripting   | Lua                                             |
| Scene data  | JSON (human-readable, good enough for own use)  |


## Rendering Philosophy

No separate 2D/3D modes. Everything lives in a unified 3D scene:

- All entities carry a `Transform3D`
- Default camera: `CAMERA_ORTHOGRAPHIC` looking down -Z (Raylib native)
- "Sprites" are textured quads in 3D space
- Parallax layers, 2.5D, and mixed 3D geometry all work without special casing
- Z-sorting convention for sprites must be decided early (depth buffer alone is
  insufficient for flat quads rendered by artists)

---

## Project Structure

```
engine/              -- static or shared library
  core/              -- window, loop, time, input
  assets/            -- texture, sound, font cache
  scene/             -- scene graph, serialization
  renderer/          -- Raylib wrapper, camera, Z-sort
  scripting/         -- Lua VM + engine bindings
  ui/                -- Clay bindings + Clay render backend

editor/              -- standalone binary, links engine
  inspector/         -- property panel, component editing
  viewport/          -- scene view, gizmos
  assets/            -- asset browser
  uilayout/          -- visual UI editor (Clay layouts)

runtime/             -- thin game binary, links engine
  main.d             -- load scene, run loop
```

The editor and game runtime are separate binaries that both link the same engine library.
Scenes are files on disk. This keeps the boundary clean and avoids the complexity of
full self-hosting (editor-as-engine) upfront.

---

## Scene Graph: Unity-style GameObject + Component

OOP component model with virtual lifecycle callbacks. Chosen over Godot-style node
hierarchy for familiarity, simplicity of implementation, and natural fit with a Lua
scripting component.

### Core Types

```d
struct Transform {
    Vector3    position;
    Quaternion rotation;
    Vector3    scale;
    Transform* parent;
    Transform*[] children;
}

class GameObject {
    string      name;
    bool        active;
    Transform   transform;
    Component[] components;
}

class Component {
    GameObject owner;
    bool       enabled;

    void onStart()   {}
    void onUpdate()  {}
    void onDestroy() {}
}
```

### Built-in Components

```d
class SpriteRenderer : Component { Texture2D tex; Color tint; int zOrder; }
class Camera         : Component { bool orthographic; float fov; float near, far; }
class LuaScript      : Component { string scriptPath; LuaState* L; }
```

### Design Decisions

- Components own their own update logic (virtual `onUpdate`), not processed by external systems
- Scene is a flat `GameObject[]` root list; hierarchy is expressed through `Transform.parent/children`
- No ECS -- data-oriented optimization deferred until profiling demands it
- Serialization is straightforward: iterate GameObjects, iterate components, dump fields

---

## Lua Scripting

`LuaScript` is a first-class component. Each instance owns a `LuaState*` and a path to
a `.lua` file. The engine calls lifecycle hooks into Lua at the appropriate points.

Benefits:
- Clean separation of logic from structure
- Hot-reload is almost free
- Maps naturally onto the component model

The binding surface should be kept minimal and explicit. Lua should not reach deep into
engine internals.

---

## Build Phases

Ordered to keep each phase independently testable before the next begins.

| Phase | Deliverable                                           |
|-------|-------------------------------------------------------|
| 1     | Core loop, Raylib window, input                       |
| 2     | Scene graph, Transform hierarchy                      |
| 3     | Sprite/mesh renderer, orthographic camera, Z-sort     |
| 4     | Asset cache (textures, sounds, fonts)                 |
| 5     | Scene serialization / deserialization (JSON)          |
| 6     | Lua VM wired to component lifecycle                   |
| 7     | Editor UI via Clay (inspector first, then viewport)   |
| 8     | Visual UI editor (most complex, least blocking)       |
