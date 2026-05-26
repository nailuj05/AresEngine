module engine.scripting.luafielddef;

import std.json;
import std.string : fromStringz, toStringz;

import lua;

import engine.scripting.luaruntime;

enum LuaFieldType { Float, Int, Bool, String_ }

struct LuaFieldDef {
  string       name;
  LuaFieldType type;
  // defaults
  float  defaultFloat  = 0f;
  int    defaultInt    = 0;
  bool   defaultBool   = false;
  string defaultString = "";
}

// Lua Field Def to D struct
private LuaFieldDef parseFieldDefs(lua_State* L) {
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
    return def;
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
  case LuaFieldType.Float:   lua_pushnumber(L, def.defaultFloat);           break;
  case LuaFieldType.Int:     lua_pushinteger(L, def.defaultInt);            break;
  case LuaFieldType.Bool:    lua_pushboolean(L, def.defaultBool ? 1 : 0);  break;
  case LuaFieldType.String_: lua_pushstring(L, def.defaultString.toStringz); break;
  }
}
