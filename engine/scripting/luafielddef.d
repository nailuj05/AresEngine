module engine.scripting.luafielddef;

enum LuaFieldType { Float, Int, Bool, String_ }

struct LuaFieldDef {
  string       name;
  LuaFieldType type;

  float  defaultFloat  = 0f;
  int    defaultInt    = 0;
  bool   defaultBool   = false;
  string defaultString = "";
}
