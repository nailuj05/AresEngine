module engine.scripting.luascriptdef;

import std.string : toStringz;
import lua;
import engine.scripting.luafielddef;
import engine.scripting.luax;

// Compiled + parsed once per script path, shared across all instances.
// Holds the class table (methods + field schema) in the Lua registry, so
// instances never re-run the file — they just use it as their metatable.
final class LuaScriptDef {
  LuaFieldDef[] fields;
  private int classRef = LUA_NOREF;

  // [...] -> [..., class]
  void pushClass(lua_State* L) nothrow { pushRef(L, classRef); }

  // Runs the file once, keeps the returned class table, parses its `fields`.
  private bool load(lua_State* L, string path) {
    if (luaL_loadfile(L, path.toStringz) != LUA_OK || lua_pcall(L, 0, 1, 0) != LUA_OK) {
      logLuaError(L);
      return false;
    }
    if (!lua_istable(L, -1)) { lua_pop(L, 1); return false; }
    // [class]
    parseFields(L);

    // class.__index = class, so instances resolve methods via their metatable.
    lua_pushvalue(L, -1);     // [class, class]
    setField(L, "__index");   // class.__index = class   [class]

    classRef = storeRef(L);   // pops class, keeps it alive
    return true;
  }

  private void unload(lua_State* L) nothrow {
    if (classRef != LUA_NOREF) { freeRef(L, classRef); classRef = LUA_NOREF; }
  }

  // Reads the schema from class.fields. Expects [class] on top, leaves it there.
  private void parseFields(lua_State* L) {
    fields.length = 0;
    getField(L, "fields");          // [class, fields]
    scope(exit) lua_pop(L, 1);
    if (!lua_istable(L, -1)) return;

    int tbl = lua_gettop(L);
    for (int i = 1; ; i++) {
      lua_rawgeti(L, tbl, i);       // [.., entry]
      scope(exit) lua_pop(L, 1);
      if (lua_isnil(L, -1)) break;
      if (!lua_istable(L, -1)) continue;

      LuaFieldDef def;
      def.name = strField(L, "name");
      if (!def.name.length) continue;

      switch (strField(L, "type")) {
        case "float":  def.type = LuaFieldType.Float;   break;
        case "int":    def.type = LuaFieldType.Int;     break;
        case "bool":   def.type = LuaFieldType.Bool;    break;
        case "string": def.type = LuaFieldType.String_; break;
        case "object": def.type = LuaFieldType.Object_; break;
        default: continue;
      }

      getField(L, "default");       // [.., entry, default]
      scope(exit) lua_pop(L, 1);
      final switch (def.type) {
        case LuaFieldType.Float:   def.defaultFloat  = toFloat(L, -1);    break;
        case LuaFieldType.Int:     def.defaultInt    = toInt(L, -1);      break;
        case LuaFieldType.Bool:    def.defaultBool   = toBool(L, -1);     break;
        case LuaFieldType.String_: def.defaultString = toStrCopy(L, -1);  break;
        case LuaFieldType.Object_: def.defaultString = "";                break;
      }
      fields ~= def;
    }
  }
}

// Reads entry[key] as a string ("" if absent). Expects the entry table at -1.
private string strField(lua_State* L, const(char)* key) {
  getField(L, key);
  scope(exit) lua_pop(L, 1);
  return toStrCopy(L, -1);
}

// --- cache ---

private LuaScriptDef[string] _defCache;

LuaScriptDef getOrLoadScriptDef(lua_State* L, string path) {
  if (auto p = path in _defCache) return *p;
  auto def = new LuaScriptDef();
  if (!def.load(L, path)) return null;
  _defCache[path] = def;
  return def;
}

void invalidateScriptDef(lua_State* L, string path) {
  if (auto p = path in _defCache) {
    p.unload(L);
    _defCache.remove(path);
  }
}

// Releases every cached class table. Call before lua_close.
void clearScriptDefs(lua_State* L) {
  foreach (def; _defCache.values) def.unload(L);
  _defCache.clear();
}
