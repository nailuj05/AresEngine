module engine.scripting.luax;

// Every helper documents its stack effect as [before] -> [after], where the
// RIGHTMOST item is the top of the stack. The goal is that call sites read as
// plain D: `push(L, x)`, `setField(L, "name")`, `getField(L, "onUpdate")`.
//
// All helpers are `nothrow` so they can be used from `extern(C)` Lua callbacks.

import lua;

// --- reading arguments off the stack ---

float  toFloat (lua_State* L, int idx) nothrow { return cast(float)lua_tonumber(L, idx); }
double toDouble(lua_State* L, int idx) nothrow { return lua_tonumber(L, idx); }
int    toInt   (lua_State* L, int idx) nothrow { return cast(int)lua_tointeger(L, idx); }
long   toLong  (lua_State* L, int idx) nothrow { return lua_tointeger(L, idx); }
bool   toBool  (lua_State* L, int idx) nothrow { return lua_toboolean(L, idx) != 0; }

// Borrowed view of a Lua string. Valid only while the value stays on the stack.
const(char)[] toStr(lua_State* L, int idx) nothrow {
  size_t len;
  auto p = lua_tolstring(L, idx, &len);
  return p ? p[0 .. len] : null;
}

// Owned copy (allocates). Use when the string must outlive its stack slot.
string toStrCopy(lua_State* L, int idx) nothrow {
  auto s = toStr(L, idx);
  return s.length ? s.idup : null;
}

// Cast a light-userdata handle back to its D type (null if not userdata).
T toHandle(T)(lua_State* L, int idx) nothrow { return cast(T)lua_touserdata(L, idx); }

bool isHandle(lua_State* L, int idx) nothrow {
  return lua_type(L, idx) == LUA_TLIGHTUSERDATA;
}

bool isFunction(lua_State* L, int idx = -1) nothrow { return lua_isfunction(L, idx) != 0; }

// --- pushing values ---
// each: [...] -> [..., value]

void push(lua_State* L, float  v) nothrow { lua_pushnumber (L, v); }
void push(lua_State* L, double v) nothrow { lua_pushnumber (L, v); }
void push(lua_State* L, int    v) nothrow { lua_pushinteger(L, v); }
void push(lua_State* L, long   v) nothrow { lua_pushinteger(L, v); }
void push(lua_State* L, bool   v) nothrow { lua_pushboolean(L, v ? 1 : 0); }
void push(lua_State* L, const(char)[] v) nothrow {
  import std.string : toStringz;
  lua_pushstring(L, v.toStringz);   // your binding lacks lua_pushlstring
}
void pushNil(lua_State* L) nothrow { lua_pushnil(L); }

// Light-userdata handle, or nil if the pointer is null.
// [...] -> [..., handle|nil]
void pushHandle(lua_State* L, void* p) nothrow {
  if (p) lua_pushlightuserdata(L, p);
  else   lua_pushnil(L);
}

// t[key] = <top>, where t is the table at -2. Pops the value.
// `key` is a C string; string literals work directly, runtime names need .toStringz.
// [..., t, value] -> [..., t]
void setField(lua_State* L, const(char)* key) nothrow { lua_setfield(L, -2, key); }

// Pushes t[key], following __index, where t is the table on top.
// [..., t] -> [..., t, t[key]]
void getField(lua_State* L, const(char)* key) nothrow { lua_getfield(L, -1, key); }

// --- registry refs (keep a Lua value alive from D) ---

// Pops the top value and returns a registry ref that keeps it alive.
int  storeRef(lua_State* L)         nothrow { return luaL_ref(L, LUA_REGISTRYINDEX); }
void freeRef (lua_State* L, int r)  nothrow { luaL_unref(L, LUA_REGISTRYINDEX, r); }
// [...] -> [..., value]
void pushRef (lua_State* L, int r)  nothrow { lua_rawgeti(L, LUA_REGISTRYINDEX, r); }

// --- calling ---

// Protected call. Expects [fn, args...] on top and pops them.
// Logs the error and returns false on failure.
bool pcall(lua_State* L, int nargs, int nresults = 0) nothrow {
  if (lua_pcall(L, nargs, nresults, 0) == LUA_OK) return true;
  logLuaError(L);
  return false;
}

void logLuaError(lua_State* L) nothrow {
  import core.stdc.stdio : fprintf, stderr;
  auto msg = lua_tostring(L, -1);
  fprintf(stderr, "[Lua] %s\n", msg ? msg : "(unknown error)");
  lua_pop(L, 1);
}

// --- module registration ---

// Build a table from a luaL_Reg list and bind it as a global.
// `name` is expected to be a string literal (null-terminated).
void registerGlobalTable(lua_State* L, const(char)* name, const(luaL_Reg)[] funcs) nothrow {
  lua_newtable(L);
  luaL_setfuncs(L, funcs.ptr, 0);
  lua_setglobal(L, name);
}
