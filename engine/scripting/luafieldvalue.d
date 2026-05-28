module engine.scripting.luafieldvalue;

import std.json;
import engine.scripting.luafielddef;

struct LuaFieldValue {
  LuaFieldType type;
  union { float f; int i; bool b; }
  string s; // outside union (has destructor)

  static LuaFieldValue fromDef(ref LuaFieldDef def) {
    LuaFieldValue v;
    v.type = def.type;
    final switch (def.type) {
    case LuaFieldType.Float:   v.f = def.defaultFloat;   break;
    case LuaFieldType.Int:     v.i = def.defaultInt;      break;
    case LuaFieldType.Bool:    v.b = def.defaultBool;     break;
    case LuaFieldType.String_: v.s = def.defaultString;   break;
    }
    return v;
  }

  JSONValue toJson() const {
    final switch (type) {
    case LuaFieldType.Float:   return JSONValue(f);
    case LuaFieldType.Int:     return JSONValue(i);
    case LuaFieldType.Bool:    return JSONValue(b);
    case LuaFieldType.String_: return JSONValue(s);
    }
  }

  static LuaFieldValue fromJson(LuaFieldType t, JSONValue j) {
    LuaFieldValue v;
    v.type = t;
    final switch (t) {
    case LuaFieldType.Float:   v.f = cast(float)j.get!double; break;
    case LuaFieldType.Int:     v.i = cast(int)j.get!long;     break;
    case LuaFieldType.Bool:    v.b = j.get!bool;              break;
    case LuaFieldType.String_: v.s = j.get!string;            break;
    }
    return v;
  }
}
