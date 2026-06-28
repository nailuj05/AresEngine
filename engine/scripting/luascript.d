module engine.scripting.luascript;

import std.json;
import std.string : fromStringz, toStringz;

import lua;

import engine.asset;
import engine.core.component;
import engine.core.iextraserializable;

import engine.scripting.luaruntime;
import engine.scripting.luafielddef;
import engine.scripting.luafieldvalue;
import engine.scripting.luascriptdef;

class LuaScript : Component, IExtraSerializable {
  mixin Named!"LuaScript";

  private string _scriptPath;

  @property string scriptPath() { return _scriptPath; }
  @property void scriptPath(string val) {
    if (val == _scriptPath) return;
    _scriptPath = val;
    reload();
  }

  // D-side value store
  LuaFieldValue[] fieldValues = [];

  private LuaScriptDef def;
  private int instanceRef = LUA_NOREF;
  private bool hasOnUpdate;

  // Convenience: look up field index by name
  int fieldIndex(string name) {
    if (!def) return -1;
    foreach (i, ref d; def.fields)
      if (d.name == name) return cast(int)i;
    return -1;
  }

  // --- Component Functions ---
  override void onStart() {
    loadScript();
    callMethod("onStart", 0);
  }

  override void onEditorStart() {
    loadScript();
  }

  override void onUpdate(float dt) {
    if (!hasOnUpdate) return;
    auto L = get_luaruntime();
    pushSelf(L);
    lua_getfield(L, -1, "onUpdate");
    lua_insert(L, -2);
    lua_pushnumber(L, dt);
    if (lua_pcall(L, 2, 0, 0) != LUA_OK) logLuaError(L);
  }

  override void onDestroy() {
    callMethod("onDestroy", 0);
    unloadScript();
  }

  override void onEditorDestroy() { unloadScript(); }

  // --- Messaging ---
  void sendMessage(lua_State* L, const(char)[] methodName, int nargs) {
    if (instanceRef == LUA_NOREF) return;
 
    // copy extra args to temporaries so we can push self underneath them
    // simplest: push self, push method, move extra args up
    // stack before: [..., arg1..argN]   (nargs items we must not disturb yet)
    int base = lua_gettop(L) - nargs; // index just below extra args
 
    pushSelf(L);                               // [..., arg1..argN, self]
    lua_getfield(L, -1, methodName.ptr);       // [..., arg1..argN, self, fn]
    if (!lua_isfunction(L, -1)) {
      lua_pop(L, 2); // pop nil + self
      return;
    }
 
    // reorder: fn, self, arg1..argN
    // currently: [..., arg1..argN, self, fn]
    // rotate the top (nargs+2) values left by 1 to get: fn, self, arg1..argN
    // easier to just: insert fn before self, then insert self before args
    lua_insert(L, base + 1);                   // [..., fn, arg1..argN, self]
    lua_insert(L, base + 2);                   // [..., fn, self, arg1..argN]
    // now copy the args since pcall will consume them
    // actually they are already in place; just call
    if (lua_pcall(L, nargs + 1, 0, 0) != LUA_OK) logLuaError(L);
  }

  // --- Serialization ---
  JSONValue serializeFields() {
    JSONValue obj = JSONValue(cast(JSONValue[string])null);
    if (!def) return obj;
    foreach (i, ref d; def.fields)
      obj[d.name] = fieldValues[i].toJson();
    return obj;
  }

  void deserializeFields(JSONValue data) {
    if (!def) return;
    foreach (i, ref d; def.fields) {
      if (auto v = d.name in data)
        fieldValues[i] = LuaFieldValue.fromJson(d.type, *v);
    }
  }

  JSONValue serializeExtra() {
    JSONValue obj = JSONValue((JSONValue[string]).init);
    // scriptPath accessed directly to avoid triggering a unneeded reload
    obj["scriptPath"] = JSONValue(_scriptPath);
    if (!def) return obj;
    foreach (i, ref d; def.fields)
      obj[d.name] = fieldValues[i].toJson();
    return obj;
  }

  void deserializeExtra(JSONValue data) {
    if (auto p = "scriptPath" in data.object)
      _scriptPath = p.get!string; // direct assignment, no reload triggered

    if (_scriptPath.length) {
      if (!def)
        def = getOrLoadScriptDef(get_luaruntime(), _scriptPath);
      if (!def) return;
    }

    fieldValues.length = def.fields.length;
    foreach (i, ref d; def.fields)
      fieldValues[i] = LuaFieldValue.fromDef(d);
    foreach (i, ref d; def.fields)
      if (auto p = d.name in data.object)
        fieldValues[i] = LuaFieldValue.fromJson(d.type, *p);
  }

  // --- Helpers ---
  private void reload() {
    if (_scriptPath.length) invalidateScriptDef(_scriptPath);
    def         = null;
    fieldValues = null;
    if (instanceRef != LUA_NOREF) unloadScript();
    if (_scriptPath.length) loadScript();
  }
  
  private void loadScript() {
    auto L = get_luaruntime();

    def = getOrLoadScriptDef(L, scriptPath);
    if (!def) return;

    if (fieldValues.length != def.fields.length) {
      fieldValues.length = def.fields.length;
      foreach (i, ref d; def.fields)
        fieldValues[i] = LuaFieldValue.fromDef(d);
    }
    
    // Re-execute script to get a fresh class table for this instance
    import std.string : toStringz;
    if (luaL_loadfile(L, scriptPath.toStringz) != LUA_OK
        || lua_pcall(L, 0, 1, 0) != LUA_OK) {
      logLuaError(L);
      return;
    }
    // [classTable]

    // Build instance with classTable as metatable/__index
    lua_newtable(L);
    lua_pushvalue(L, -2);
    lua_setfield(L, -2, "__index");
    lua_pushvalue(L, -2);
    lua_setmetatable(L, -2);
    // [classTable, instance]

    lua_pushlightuserdata(L, cast(void*)owner);
    lua_setfield(L, -2, "gameObject");

    instanceRef = luaL_ref(L, LUA_REGISTRYINDEX);
    lua_pop(L, 1); // pop classTable

    // Sync D-side values -> Lua, filling gaps with defaults
    syncFieldValues(L);

    pushSelf(L);
    lua_getfield(L, -1, "onUpdate");
    hasOnUpdate = lua_isfunction(L, -1) != 0;
    lua_pop(L, 2);
  }

  // Push current D-side fieldValues into the Lua instance.
  // Call after loadScript or after a bulk editor change.
  void syncFieldValues(lua_State* L) {
    if (!def || instanceRef == LUA_NOREF) return;

    // Resize/fill fieldValues to match def
    if (fieldValues.length != def.fields.length) {
      auto old = fieldValues;
      fieldValues.length = def.fields.length;
      foreach (i, ref d; def.fields) {
        if (i < old.length && old[i].type == d.type)
          fieldValues[i] = old[i];
        else
          fieldValues[i] = LuaFieldValue.fromDef(d);
      }
    }

    pushSelf(L);
    foreach (i, ref d; def.fields) {
      final switch (d.type) {
      case LuaFieldType.Float:
      case LuaFieldType.Int:
      case LuaFieldType.Bool:
      case LuaFieldType.String_:
        pushValue(L, fieldValues[i]);
        break;
      case LuaFieldType.Object_:
        pushResolvedObject(L, fieldValues[i].s);
        break;
      }
      lua_setfield(L, -2, d.name.toStringz);
    }
    lua_pop(L, 1);
  }

  private void unloadScript() {
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
    lua_getfield(L, -1, name.toStringz);
    if (!lua_isfunction(L, -1)) { lua_pop(L, 2); return; }
    lua_insert(L, -2);
    if (lua_pcall(L, 1, nresults, 0) != LUA_OK) logLuaError(L);
  }

  private static void pushValue(lua_State* L, ref LuaFieldValue v) {
    final switch (v.type) {
    case LuaFieldType.Float:   lua_pushnumber(L, v.f);           break;
    case LuaFieldType.Int:     lua_pushinteger(L, v.i);          break;
    case LuaFieldType.Bool:    lua_pushboolean(L, v.b ? 1 : 0);  break;
    case LuaFieldType.String_: lua_pushstring(L, v.s.toStringz); break;
    case LuaFieldType.Object_: assert(false, "use pushResolvedObject"); break;
    }
  }
 
  // scene:// -> resolve to Transform lightuserdata
  // anything else (prefab path) -> push as string so Lua can call Prefab.instantiate
  // empty / not found -> nil
  private static void pushResolvedObject(lua_State* L, string path) {
    import std.algorithm : startsWith;
    if (!path.length) { lua_pushnil(L); return; }
    if (path.startsWith("scene://")) {
      import engine.scene.scene : activeScene;
      auto scene = activeScene();
      if (!scene) { lua_pushnil(L); return; }
      auto t = scene.findByPath(path);
      if (!t)  { lua_pushnil(L); return; }
      lua_pushlightuserdata(L, cast(void*)t);
    } else {
      lua_pushstring(L, path.toStringz);
    }
  }

  private static void logLuaError(lua_State* L) {
    import std.stdio : writeln;
    import std.string : fromStringz;
    auto msg = lua_tostring(L, -1);
    writeln("[Lua] ", msg ? msg.fromStringz : "(null)");
    lua_pop(L, 1);
  }

  version(Editor) {
    import editor.inspector.drawer;

    private FieldState[string] fieldStates;
    private FieldState[] _fieldStates;
    private FieldState _scriptPathState;

    override float drawInspector(float offsetX, float offsetY, float panelW) {
      string sp = _scriptPath;
      drawField("scriptPath", sp, _scriptPathState, offsetX, offsetY, panelW);
      scriptPath = sp;
        
      offsetY += 28;

      auto self = this;
      drawFields(self, fieldStates, offsetX, offsetY, panelW, &offsetY);
      if (!def) return offsetY;

      if (_fieldStates.length != def.fields.length)
        _fieldStates.length = def.fields.length;

      foreach (i, ref d; def.fields) {
        final switch (d.type) {
        case LuaFieldType.Float:       drawField(d.name, fieldValues[i].f, _fieldStates[i], offsetX + 10, offsetY, panelW - 10); break;
        case LuaFieldType.Int:         drawField(d.name, fieldValues[i].i, _fieldStates[i], offsetX + 10, offsetY, panelW - 10); break;
        case LuaFieldType.Bool:        drawField(d.name, fieldValues[i].b, _fieldStates[i], offsetX + 10, offsetY, panelW - 10); break;
        case LuaFieldType.String_:     drawField(d.name, fieldValues[i].s, _fieldStates[i], offsetX + 10, offsetY, panelW - 10); break;
        case LuaFieldType.Object_:
          drawAssetField!(AssetKind.Object)(d.name, fieldValues[i].s, offsetX + 10, offsetY, panelW - 10);
          break;
        }
        offsetY += 28;
      }

      if (instanceRef != LUA_NOREF)
        syncFieldValues(get_luaruntime());

      return offsetY;
    }
  }
}
