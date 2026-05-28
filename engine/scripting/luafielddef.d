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

  version(Editor) {
    import editor.inspector.drawer : FieldState;
    FieldState fieldState;
  }
}
