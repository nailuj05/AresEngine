module engine.scripting.api;

import lua;
import raylib;
import engine.core.gameobject;
import engine.core.transform : Transform;
import engine.scripting.luax;

void registerEngineAPI(lua_State* L) nothrow {
  registerTransform(L);
  registerInput(L);
  registerLog(L);
  registerGameObject(L);
  registerPrefab(L);
}

// --- helpers ---

// Casts the light-userdata argument back to a Transform. Returns null for a
// non-userdata argument (same behaviour as the original); add a check here if
// your binding gains an error helper and you want a louder failure.
private Transform getTF(lua_State* L, int idx = 1) nothrow {
  return cast(Transform)lua_touserdata(L, idx);
}

private void pushConstTable(lua_State* L, const(char)* name,
                            const(char)*[] keys, const(int)[] vals) nothrow {
  lua_newtable(L);
  foreach (i; 0 .. keys.length) {
    lua_pushinteger(L, vals[i]);
    lua_setfield(L, -2, keys[i]);
  }
  lua_setfield(L, -2, name);
}

// --- Transform ---

private void registerTransform(lua_State* L) nothrow {
  static immutable luaL_Reg[8] funcs = [
    { "getPosition", &lua_transform_getpos    },
    { "setPosition", &lua_transform_setpos    },
    { "translate",   &lua_transform_translate },
    { "getScale",    &lua_transform_getscale  },
    { "setScale",    &lua_transform_setscale  },
    { "getRotation", &lua_transform_getrot    },
    { "setRotation", &lua_transform_setrot    },
    { null, null }
  ];
  registerGlobalTable(L, "Transform", funcs[]);
}

extern(C) int lua_transform_getpos(lua_State* L) nothrow {
  auto tf = getTF(L);
  push(L, tf.position.x);
  push(L, tf.position.y);
  push(L, tf.position.z);
  return 3;
}

extern(C) int lua_transform_setpos(lua_State* L) nothrow {
  auto tf = getTF(L);
  tf.position = Vector3(toFloat(L, 2), toFloat(L, 3), toFloat(L, 4));
  return 0;
}

extern(C) int lua_transform_translate(lua_State* L) nothrow {
  auto tf = getTF(L);
  auto p = tf.position;
  tf.position = Vector3(p.x + toFloat(L, 2), p.y + toFloat(L, 3), p.z + toFloat(L, 4));
  return 0;
}

extern(C) int lua_transform_getscale(lua_State* L) nothrow {
  auto tf = getTF(L);
  push(L, tf.scale.x);
  push(L, tf.scale.y);
  push(L, tf.scale.z);
  return 3;
}

extern(C) int lua_transform_setscale(lua_State* L) nothrow {
  auto tf = getTF(L);
  tf.scale = Vector3(toFloat(L, 2), toFloat(L, 3), toFloat(L, 4));
  return 0;
}

// rotation exposed as euler degrees; assumes tf.rotation is a Quaternion
extern(C) int lua_transform_getrot(lua_State* L) nothrow {
  auto tf = getTF(L);
  Vector3 e = QuaternionToEuler(tf.rotation);
  push(L, e.x * RAD2DEG);
  push(L, e.y * RAD2DEG);
  push(L, e.z * RAD2DEG);
  return 3;
}

extern(C) int lua_transform_setrot(lua_State* L) nothrow {
  auto tf = getTF(L);
  tf.rotation = QuaternionFromEuler(toFloat(L, 2) * DEG2RAD,
                                    toFloat(L, 3) * DEG2RAD,
                                    toFloat(L, 4) * DEG2RAD);
  return 0;
}

// --- Input ---

// Generates an extern(C) predicate that pushes `fn(cast(EnumT) arg1)` as a bool.
// Each template instantiation gets its own mangled `impl`, so there are no
// extern(C) name collisions.
private template Predicate(alias fn, EnumT) {
  extern(C) int impl(lua_State* L) nothrow {
    push(L, cast(bool)fn(cast(EnumT)toInt(L, 1)));
    return 1;
  }
}

private void registerInput(lua_State* L) nothrow {
  static immutable luaL_Reg[10] funcs = [
    { "isKeyDown",             &Predicate!(IsKeyDown,             KeyboardKey).impl },
    { "isKeyPressed",          &Predicate!(IsKeyPressed,          KeyboardKey).impl },
    { "isKeyReleased",         &Predicate!(IsKeyReleased,         KeyboardKey).impl },
    { "isMouseButtonDown",     &Predicate!(IsMouseButtonDown,     MouseButton).impl  },
    { "isMouseButtonPressed",  &Predicate!(IsMouseButtonPressed,  MouseButton).impl  },
    { "isMouseButtonReleased", &Predicate!(IsMouseButtonReleased, MouseButton).impl  },
    { "getMousePosition",      &lua_input_mousePosition  },
    { "getMouseDelta",         &lua_input_mouseDelta     },
    { "getMouseWheelMove",     &lua_input_mouseWheelMove },
    { null, null }
  ];

  lua_newtable(L);
  luaL_setfuncs(L, funcs.ptr, 0);

  // Input.Key
  static const(char)*[] keyNames = [
    "A","B","C","D","E","F","G","H","I","J","K","L","M",
    "N","O","P","Q","R","S","T","U","V","W","X","Y","Z",
    "ZERO","ONE","TWO","THREE","FOUR","FIVE","SIX","SEVEN","EIGHT","NINE",
    "F1","F2","F3","F4","F5","F6","F7","F8","F9","F10","F11","F12",
    "SPACE","ENTER","ESCAPE","TAB","BACKSPACE","DELETE",
    "RIGHT","LEFT","DOWN","UP",
    "LEFT_SHIFT","LEFT_CTRL","LEFT_ALT",
    "RIGHT_SHIFT","RIGHT_CTRL","RIGHT_ALT"
  ];
  static int[] keyVals = [
    65,66,67,68,69,70,71,72,73,74,75,76,77,           // A-M
    78,79,80,81,82,83,84,85,86,87,88,89,90,           // N-Z
    48,49,50,51,52,53,54,55,56,57,                    // 0-9
    290,291,292,293,294,295,296,297,298,299,300,301,  // F1-F12
    32,257,256,258,259,261,                           // special
    262,263,264,265,                                  // arrows
    340,341,342,344,345,346                           // modifiers
  ];
  pushConstTable(L, "Key", keyNames, keyVals);

  // Input.Mouse
  static const(char)*[] mouseNames = ["LEFT", "RIGHT", "MIDDLE"];
  static int[]          mouseVals  = [0, 1, 2];
  pushConstTable(L, "Mouse", mouseNames, mouseVals);

  lua_setglobal(L, "Input");
}

extern(C) int lua_input_mousePosition(lua_State* L) nothrow {
  auto p = GetMousePosition();
  push(L, p.x);
  push(L, p.y);
  return 2;
}
extern(C) int lua_input_mouseDelta(lua_State* L) nothrow {
  auto d = GetMouseDelta();
  push(L, d.x);
  push(L, d.y);
  return 2;
}
extern(C) int lua_input_mouseWheelMove(lua_State* L) nothrow {
  push(L, GetMouseWheelMove());
  return 1;
}

// --- Log ---

private void registerLog(lua_State* L) nothrow {
  static immutable luaL_Reg[2] funcs = [
    { "print", &lua_log_print },
    { null, null }
  ];
  registerGlobalTable(L, "Log", funcs[]);
}

extern(C) int lua_log_print(lua_State* L) nothrow {
  import core.stdc.stdio : printf;
  size_t len;
  const(char)* msg = luaL_tolstring(L, 1, &len);
  if (msg)
    printf("[LUA] %s\n", msg);
  lua_pop(L, 1); // tolstring cleanup
  return 0;
}

// --- GameObject ---

private void registerGameObject(lua_State* L) nothrow {
  static immutable luaL_Reg[3] funcs = [
    { "find",        &lua_go_find        },
    { "sendMessage", &lua_go_sendMessage },
    { null, null }
  ];
  registerGlobalTable(L, "GameObject", funcs[]);
}

extern(C) int lua_go_find(lua_State* L) nothrow {
  try {
    import engine.scene.scene : activeScene;
    auto name = toStrCopy(L, 1);
    if (!name.length) { pushNil(L); return 1; }
    auto scene = activeScene();
    if (!scene) { pushNil(L); return 1; }
    pushHandle(L, cast(void*)scene.findByPath(name)); // null -> nil
    return 1;
  } catch (Exception) { pushNil(L); return 1; }
}

extern(C) int lua_go_sendMessage(lua_State* L) nothrow {
  try {
    import engine.scripting.luascript : LuaScript;
    auto t = getTF(L, 1);
    auto name = toStr(L, 2);            // borrowed: used immediately below
    if (!name.length) return 0;
    int nargs = lua_gettop(L) - 2;
    foreach (c; t.gameObject.components)
      if (auto ls = cast(LuaScript)c)
        ls.sendMessage(L, name, nargs); // args are reused per component (copied, not consumed)
    return 0;
  } catch (Exception) { return 0; }
}

// --- Prefab ---

private void registerPrefab(lua_State* L) nothrow {
  static immutable luaL_Reg[2] funcs = [
    { "instantiate", &lua_prefab_instantiate },
    { null, null }
  ];
  registerGlobalTable(L, "Prefab", funcs[]);
}

extern(C) int lua_prefab_instantiate(lua_State* L) nothrow {
  try {
    import engine.scene.objectmanager : ObjectManager;

    Transform t;
    if (isHandle(L, 1)) {
      t = ObjectManager.instance.instantiate(toHandle!Transform(L, 1));
    } else {
      auto path = toStrCopy(L, 1);
      if (!path.length) { pushNil(L); return 1; }
      t = ObjectManager.instance.instantiate(path);
    }
    pushHandle(L, cast(void*)t); // null -> nil
    return 1;
  } catch (Exception) { pushNil(L); return 1; }
}
