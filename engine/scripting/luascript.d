module engine.scripting.luascript;

import std.json;
import std.string : fromStringz, toStringz;

import lua;

import engine.core.component;
import engine.scripting.luaruntime;
import engine.scripting.luafielddef;

class LuaScript : Component {
  mixin Named!"LuaScript";

  string scriptPath;

  //TODO: serialize
  @DontSerialize LuaFieldDef[] fieldDefs;
  private int instanceRef = LUA_NOREF;
  private bool hasOnUpdate;
  
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
    lua_insert(L, -2);              // reorder: [onUpdate, self]
    lua_pushnumber(L, dt);          // [onUpdate, self, dt]

    if (lua_pcall(L, 2, 0, 0) != LUA_OK)
      logError(L);
  }

  override void onDestroy() {
    callMethod("onDestroy", 0);
    unloadScript();
  }

  override void onEditorDestroy() {
    unloadScript();
  }

  // Helpers
  private void loadScript() {
    auto L = get_luaruntime();
    if (luaL_loadfile(L, scriptPath.toStringz) != LUA_OK || lua_pcall(L, 0, 1, 0) != LUA_OK) {
      logError(L);
      return;
    }
    // [classTable]

    parseFieldDefs(L);

    // create instance and set classTable as its metatable
    lua_newtable(L);                         // [classTable, instance]
    lua_pushvalue(L, -2);                    // [classTable, instance, classTable]
    lua_setfield(L, -2, "__index");          // instance.__index = classTable
    lua_pushvalue(L, -2);                    // [classTable, instance, classTable]
    lua_setmetatable(L, -2);                 // setmetatable(instance, classTable)
    // [classTable, instance]

    lua_pushlightuserdata(L, cast(void*)owner);
    lua_setfield(L, -2, "gameObject");       // instance.gameObject = owner

    instanceRef = luaL_ref(L, LUA_REGISTRYINDEX); // pin instance; pops it
    lua_pop(L, 1);                           // pop classTable
    
    // write defaults into instance
    applyFields(L);

    pushSelf(L);
    lua_getfield(L, -1, "onUpdate");
    hasOnUpdate = lua_isfunction(L, -1);
    lua_pop(L, 2);
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

  
  // Inspector Read/Write
  
  // read a single field value from the Lua instance into a JSONValue
  JSONValue readField(ref LuaFieldDef def) {
    auto L = get_luaruntime();
    pushSelf(L);
    lua_getfield(L, -1, def.name.toStringz);
    scope(exit) lua_pop(L, 2);
    final switch (def.type) {
    case LuaFieldType.Float:   return JSONValue(lua_tonumber(L, -1));
    case LuaFieldType.Int:     return JSONValue(lua_tointeger(L, -1));
    case LuaFieldType.Bool:    return JSONValue(lua_toboolean(L, -1) != 0);
    case LuaFieldType.String_:
      auto p = lua_tostring(L, -1);
      return JSONValue(p ? p.fromStringz.idup : "");
    }
  }

  // write a single edited value back into the Lua instance
  void writeField(T)(ref LuaFieldDef def, T val) {
    auto L = get_luaruntime();
    pushSelf(L);

    static if      (is(T == float))  lua_pushnumber(L, val);
    else static if (is(T == int))    lua_pushinteger(L, val);
    else static if (is(T == bool))   lua_pushboolean(L, val ? 1 : 0);
    else static if (is(T == string)) lua_pushstring(L, val.toStringz);
    else static assert(false, "Unsupported field type: " ~ val.stringof);

    lua_setfield(L, -2, def.name.toStringz);
    lua_pop(L, 1);
  }

  private void pushFromJSON(lua_State* L, ref LuaFieldDef def, JSONValue val) {
    final switch (def.type) {
    case LuaFieldType.Float:   lua_pushnumber(L, val.get!double);           break;
    case LuaFieldType.Int:     lua_pushinteger(L, val.get!long);            break;
    case LuaFieldType.Bool:    lua_pushboolean(L, val.get!bool ? 1 : 0);    break;
    case LuaFieldType.String_: lua_pushstring(L, val.get!string.toStringz); break;
    }
  }

  // Field Serialization
  JSONValue serializeFields() {
    JSONValue obj = JSONValue(cast(JSONValue[string])null);
    foreach (ref def; fieldDefs)
      obj[def.name] = readField(def);
    return obj;
  }

  void deserializeFields(JSONValue data) {
    auto L = get_luaruntime();
    applyFields(L, &data);
  }

  // Lua Field Def to D struct
  private void parseFieldDefs(lua_State* L) {
    lua_getfield(L, -1, "fields");
    scope(exit) lua_pop(L, 1);
    if (!lua_istable(L, -1)) return;

    int tbl = lua_gettop(L);
    for (int i = 1; ; i++) {
      lua_rawgeti(L, tbl, i);
      scope(exit) lua_pop(L, 1);
      if (lua_isnil(L, -1)) break;
      if (!lua_istable(L, -1)) continue;

      LuaFieldDef def;

      string strField(const(char)* key) {
        lua_getfield(L, -1, key);
        scope(exit) lua_pop(L, 1);
        auto p = lua_tostring(L, -1);
        return p ? p.fromStringz.idup : "";
      }

      def.name = strField("name");
      if (!def.name.length) continue;

      switch (strField("type")) {
      case "float":  def.type = LuaFieldType.Float;   break;
      case "int":    def.type = LuaFieldType.Int;     break;
      case "bool":   def.type = LuaFieldType.Bool;    break;
      case "string": def.type = LuaFieldType.String_; break;
      default: continue;
      }

      lua_getfield(L, -1, "default");
      final switch (def.type) {
      case LuaFieldType.Float:   def.defaultFloat  = cast(float)lua_tonumber(L, -1);   break;
      case LuaFieldType.Int:     def.defaultInt    = cast(int)lua_tointeger(L, -1);    break;
      case LuaFieldType.Bool:    def.defaultBool   = lua_toboolean(L, -1) != 0;        break;
      case LuaFieldType.String_: def.defaultString = strField("default");              break;
      }
      lua_pop(L, 1);

      fieldDefs ~= def;
    }
  }

  // write defaults into instance before onStart
  private void applyFields(lua_State* L, JSONValue* saved = null) {
    pushSelf(L);
    foreach (ref def; fieldDefs) {
      if (saved && def.name in *saved)
        pushFromJSON(L, def, (*saved)[def.name]);
      else
        pushDefault(L, def);
      lua_setfield(L, -2, def.name.toStringz);
    }
    lua_pop(L, 1);
  }

  private void pushDefault(lua_State* L, ref LuaFieldDef def) {
    final switch (def.type) {
    case LuaFieldType.Float:   lua_pushnumber(L, def.defaultFloat);            break;
    case LuaFieldType.Int:     lua_pushinteger(L, def.defaultInt);             break;
    case LuaFieldType.Bool:    lua_pushboolean(L, def.defaultBool ? 1 : 0);    break;
    case LuaFieldType.String_: lua_pushstring(L, def.defaultString.toStringz); break;
    }
  }
  
  // Editor + Inspector
  version(Editor) {
    import editor.inspector.drawer;

    private FieldState[string] fieldStates;
    
    override ulong drawInspector(ulong offsetX, ulong offsetY, ulong panelW) {
      auto self = this;
      offsetY = drawFields(self, fieldStates, offsetX, offsetY, panelW);

      foreach (ref def; fieldDefs) {
        auto current = readField(def);

        final switch (def.type) {
        case LuaFieldType.Float:
          float f = cast(float)current.get!double;
          drawField!float(def.name, f, def.fieldState, offsetX, offsetY, panelW);
          writeField(def, f);
          break;
        case LuaFieldType.Int:
          int i = cast(int)current.get!long;
          drawField(def.name, i, def.fieldState, offsetX, offsetY, panelW);
          writeField(def, i);
          break;
        case LuaFieldType.Bool:
          bool b = current.get!bool;
          drawField(def.name, b, def.fieldState, offsetX, offsetY, panelW);
          writeField(def, b);
          break;
        case LuaFieldType.String_:
          string s = current.get!string;
          drawField(def.name, s, def.fieldState, offsetX, offsetY, panelW);
          writeField(def, s);
          break;
        }
        offsetY += 28; // <- ROW:H TODO: Proper shared style
      }
      return offsetY;
    }
  }
}
