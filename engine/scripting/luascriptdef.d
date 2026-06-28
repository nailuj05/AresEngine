module engine.scripting.luascriptdef;

import std.string : fromStringz;
import lua;
import engine.scripting.luafielddef;

// Parsed once per script path; shared across all instances.
class LuaScriptDef {
  LuaFieldDef[] fields;

  void parseFrom(lua_State* L) {
    fields.length = 0;
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
      case "object": def.type = LuaFieldType.Object_; break;
      default: continue;
      }

      lua_getfield(L, -1, "default");
      scope(exit) lua_pop(L, 1);
      final switch (def.type) {
      case LuaFieldType.Float:   def.defaultFloat  = cast(float)lua_tonumber(L, -1);  break;
      case LuaFieldType.Int:     def.defaultInt    = cast(int)lua_tointeger(L, -1);   break;
      case LuaFieldType.Bool:    def.defaultBool   = lua_toboolean(L, -1) != 0;       break;
      case LuaFieldType.String_: def.defaultString = strField("default");             break;
      case LuaFieldType.Object_: def.defaultString = "";                              break;
      }

      fields ~= def;
    }
  }
}

private LuaScriptDef[string] _defCache;

LuaScriptDef getOrLoadScriptDef(lua_State* L, string path) {
  if (auto p = path in _defCache) return *p;

  import std.string : toStringz;
  if (luaL_loadfile(L, path.toStringz) != LUA_OK || lua_pcall(L, 0, 1, 0) != LUA_OK) {
    lua_pop(L, 1);
    return null;
  }
  auto def = new LuaScriptDef();
  def.parseFrom(L);
  lua_pop(L, 1);
  _defCache[path] = def;
  return def;
}

void invalidateScriptDef(string path) {
  _defCache.remove(path);
}
