module engine.scripting.api;

import lua;
import raylib;
import engine.core.gameobject;

void registerEngineAPI(lua_State* L) {
  registerTransform(L);
  registerInput(L);
  registerLog(L);
}

// helpers

private GameObject getGO(lua_State* L, int idx = 1) nothrow {
  return cast(GameObject)lua_touserdata(L, idx);
}

private void pushConstTable(lua_State* L, const(char)* name,
                            const(char)*[] keys, const(int)[] vals) nothrow {
  lua_newtable(L);
  foreach (i; 0 .. keys.length) {
    lua_pushinteger(L, vals[i]);
    lua_setfield(L, -2, keys[i]);
  }
  lua_setfield(L, -2, name); // sets parent[-2][name] = new table
}

// Transform

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
  lua_newtable(L);
  luaL_setfuncs(L, funcs.ptr, 0);
  lua_setglobal(L, "Transform");
}

extern(C) int lua_transform_getpos(lua_State* L) nothrow {
  auto go = getGO(L);
  if (!go) { lua_pushnumber(L, 0); lua_pushnumber(L, 0); lua_pushnumber(L, 0); return 3; }
  lua_pushnumber(L, go.transform.position.x);
  lua_pushnumber(L, go.transform.position.y);
  lua_pushnumber(L, go.transform.position.z);
  return 3;
}

extern(C) int lua_transform_setpos(lua_State* L) nothrow {
  auto go = getGO(L);
  if (!go) return 0;
  go.transform.position = Vector3(cast(float)lua_tonumber(L, 2),
                                  cast(float)lua_tonumber(L, 3),
                                  cast(float)lua_tonumber(L, 4));
  return 0;
}

extern(C) int lua_transform_translate(lua_State* L) nothrow {
  auto go = getGO(L);
  if (!go) return 0;
  auto p = go.transform.position;
  go.transform.position = Vector3(p.x + cast(float)lua_tonumber(L, 2),
                                  p.y + cast(float)lua_tonumber(L, 3),
                                  p.z + cast(float)lua_tonumber(L, 4));
  return 0;
}

extern(C) int lua_transform_getscale(lua_State* L) nothrow {
  auto go = getGO(L);
  if (!go) { lua_pushnumber(L, 1); lua_pushnumber(L, 1); lua_pushnumber(L, 1); return 3; }
  lua_pushnumber(L, go.transform.scale.x);
  lua_pushnumber(L, go.transform.scale.y);
  lua_pushnumber(L, go.transform.scale.z);
  return 3;
}

extern(C) int lua_transform_setscale(lua_State* L) nothrow {
  auto go = getGO(L);
  if (!go) return 0;
  go.transform.scale = Vector3(cast(float)lua_tonumber(L, 2),
                               cast(float)lua_tonumber(L, 3),
                               cast(float)lua_tonumber(L, 4));
  return 0;
}

// rotation exposed as euler degrees; assumes go.transform.rotation is a Quaternion
extern(C) int lua_transform_getrot(lua_State* L) nothrow {
  auto go = getGO(L);
  if (!go) { lua_pushnumber(L, 0); lua_pushnumber(L, 0); lua_pushnumber(L, 0); return 3; }
  Vector3 e = QuaternionToEuler(go.transform.rotation);
  lua_pushnumber(L, e.x * RAD2DEG);
  lua_pushnumber(L, e.y * RAD2DEG);
  lua_pushnumber(L, e.z * RAD2DEG);
  return 3;
}

extern(C) int lua_transform_setrot(lua_State* L) nothrow {
  auto go = getGO(L);
  if (!go) return 0;
  go.transform.rotation = QuaternionFromEuler(cast(float)lua_tonumber(L, 2) * DEG2RAD,
                                              cast(float)lua_tonumber(L, 3) * DEG2RAD,
                                              cast(float)lua_tonumber(L, 4) * DEG2RAD);
  return 0;
}

// Input

private void registerInput(lua_State* L) nothrow {
  static immutable luaL_Reg[10] funcs = [
    { "isKeyDown",             &lua_input_keyDown         },
    { "isKeyPressed",          &lua_input_keyPressed      },
    { "isKeyReleased",         &lua_input_keyReleased     },
    { "isMouseButtonDown",     &lua_input_mouseDown       },
    { "isMouseButtonPressed",  &lua_input_mousePressed    },
    { "isMouseButtonReleased", &lua_input_mouseReleased   },
    { "getMousePosition",      &lua_input_mousePosition   },
    { "getMouseDelta",         &lua_input_mouseDelta      },
    { "getMouseWheelMove",     &lua_input_mouseWheelMove  },
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

extern(C) int lua_input_keyDown(lua_State* L) nothrow {
  lua_pushboolean(L, IsKeyDown(cast(KeyboardKey)lua_tointeger(L, 1)));
  return 1;
}
extern(C) int lua_input_keyPressed(lua_State* L) nothrow {
  lua_pushboolean(L, IsKeyPressed(cast(KeyboardKey)lua_tointeger(L, 1)));
  return 1;
}
extern(C) int lua_input_keyReleased(lua_State* L) nothrow {
  lua_pushboolean(L, IsKeyReleased(cast(KeyboardKey)lua_tointeger(L, 1)));
  return 1;
}
extern(C) int lua_input_mouseDown(lua_State* L) nothrow {
  lua_pushboolean(L, IsMouseButtonDown(cast(MouseButton)lua_tointeger(L, 1)));
  return 1;
}
extern(C) int lua_input_mousePressed(lua_State* L) nothrow {
  lua_pushboolean(L, IsMouseButtonPressed(cast(MouseButton)lua_tointeger(L, 1)));
  return 1;
}
extern(C) int lua_input_mouseReleased(lua_State* L) nothrow {
  lua_pushboolean(L, IsMouseButtonReleased(cast(MouseButton)lua_tointeger(L, 1)));
  return 1;
}
extern(C) int lua_input_mousePosition(lua_State* L) nothrow {
  auto p = GetMousePosition();
  lua_pushnumber(L, p.x);
  lua_pushnumber(L, p.y);
  return 2;
}
extern(C) int lua_input_mouseDelta(lua_State* L) nothrow {
  auto d = GetMouseDelta();
  lua_pushnumber(L, d.x);
  lua_pushnumber(L, d.y);
  return 2;
}
extern(C) int lua_input_mouseWheelMove(lua_State* L) nothrow {
  lua_pushnumber(L, GetMouseWheelMove());
  return 1;
}

// Log
private void registerLog(lua_State* L) {
  lua_newtable(L);
  lua_pushcclosure(L, &lua_log_print, 0);
  lua_setfield(L, -2, "print");
  lua_setglobal(L, "Log");
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
