module engine.scripting.luafielddef;

enum LuaFieldType { Float, Int, Bool, String_, Object_ }

struct LuaFieldDef {
  string       name;
  LuaFieldType type;

  float  defaultFloat  = 0f;
  int    defaultInt    = 0;
  bool   defaultBool   = false;
  string defaultString = ""; // also used for Object_ (scene:// or prefab path)
}
