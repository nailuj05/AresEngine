module engine.scripting.luascript;

import std.string : toStringz;

import lua;

import engine.core.component;
import engine.scripting.luaruntime;

class LuaScript : Component {
  mixin Named!"LuaScript";

  string scriptPath;

  private int instanceRef = LUA_NOREF;
  private bool hasOnUpdate;
  
  override void onStart() {
    auto L = get_luaruntime();

    if (luaL_loadfile(L, scriptPath.toStringz) != LUA_OK || lua_pcall(L, 0, 1, 0) != LUA_OK) {
        logError(L);
        return;
    }
    // stack: [classTable]

    // Create instance: setmetatable({}, classTable)
    lua_newtable(L);                     // [classTable, instance]
    lua_pushvalue(L, -2);                // [classTable, instance, classTable]
    lua_setfield(L, -2, "__index");      // instance.__index = classTable (manual; see note)
    lua_pushvalue(L, -2);                // [classTable, instance, classTable]
    lua_setmetatable(L, -2);             // setmetatable(instance, classTable)
    // stack: [classTable, instance]

    // Inject self.gameObject = this owner
    lua_pushlightuserdata(L, cast(void*)owner);
    lua_setfield(L, -2, "gameObject");

    // Pin the instance in the registry, prevents Lua GC from collecting it
    instanceRef = luaL_ref(L, LUA_REGISTRYINDEX);
    lua_pop(L, 1);

    // Cache whether onUpdate exists
    pushSelf(L);
    lua_getfield(L, -1, "onUpdate");
    hasOnUpdate = lua_isfunction(L, -1);
    lua_pop(L, 2);

    callMethod("onStart", 0);
  }

  override void onUpdate(float dt) {
    if (!hasOnUpdate) return;

    auto L = get_luaruntime();
    pushSelf(L);
    lua_getfield(L, -1, "onUpdate");
    lua_insert(L, -2);              // reorder: [onUpdate, self]
    lua_pushnumber(L, dt);          // [onUpdate, self, dt]

    if (lua_pcall(L, 2, 0, 0) != LUA_OK)
      logError(L);
  }

  override void onDestroy() {
    callMethod("onDestroy", 0);
    auto L = get_luaruntime();
    luaL_unref(L, LUA_REGISTRYINDEX, instanceRef);
    instanceRef = LUA_NOREF;
  }

  private void pushSelf(lua_State* L) {
    lua_rawgeti(L, LUA_REGISTRYINDEX, instanceRef);
  }

  private void callMethod(string name, int nresults) {
    if (instanceRef == LUA_NOREF) return;
    auto L = get_luaruntime();
    pushSelf(L);
    lua_getfield(L, cast(int)-1, name.toStringz);
    if (!lua_isfunction(L, -1)) { lua_pop(L, 2); return; }
    lua_insert(L, -2);              // [fn, self]
    if (lua_pcall(L, 1, nresults, 0) != LUA_OK)
      logError(L);
  }

  private void logError(lua_State* L) {
    import std.stdio : writeln;
    import std.string : fromStringz;
    auto msg = lua_tostring(L, -1);
    writeln("[Lua error] ", msg ? msg.fromStringz : "(null)");
    lua_pop(L, 1);
  }
  
  version(Editor) {
    import editor.inspector.drawer;

    override void onEditorStart() {
      auto L = get_luaruntime();
      if (luaL_loadfile(L, scriptPath.toStringz) != LUA_OK || lua_pcall(L, 0, 1, 0) != LUA_OK) {
        logError(L);
        return;
      }
    }
    
    override void onEditorDestroy() {
      auto L = get_luaruntime();
      luaL_unref(L, LUA_REGISTRYINDEX, instanceRef);
      instanceRef = LUA_NOREF;
    }

    private FieldState[string] fieldStates;
    
    override ulong drawInspector(ulong offsetX, ulong offsetY, ulong panelW) {
      auto self = this;
      ulong offset = drawFields(self, fieldStates, offsetX, offsetY, panelW);

      // TODO: Draw Lua exposed variables here

      return offset;
    }
  }
}
