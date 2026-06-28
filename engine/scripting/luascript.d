module engine.scripting.luascript;

import std.json;

import lua;

import engine.asset;
import engine.core.component;
import engine.core.iextraserializable;

import engine.scripting.luaruntime;
import engine.scripting.luafielddef;
import engine.scripting.luafieldvalue;
import engine.scripting.luascriptdef;
import engine.scripting.luax;

class LuaScript : Component, IExtraSerializable {
  mixin Named!"LuaScript";

  private string _scriptPath;

  @property string scriptPath() { return _scriptPath; }
  @property void scriptPath(string val) {
    if (val == _scriptPath) return;
    _scriptPath = val;
    reload();
  }

  // D-side value store, one entry per def field.
  LuaFieldValue[] fieldValues = [];

  private LuaScriptDef def;
  private int  instanceRef = LUA_NOREF;
  private bool hasOnUpdate;

  int fieldIndex(string name) {
    if (!def) return -1;
    foreach (i, ref d; def.fields)
      if (d.name == name) return cast(int)i;
    return -1;
  }

  // --- Component lifecycle ---
  override void onStart() {
    loadScript();
    callMethod(get_luaruntime(), "onStart", 0);
  }

  override void onEditorStart() { loadScript(); }

  override void onUpdate(float dt) {
    if (!hasOnUpdate) return;          // hot path: skip the lookup when absent
    auto L = get_luaruntime();
    push(L, dt);
    callMethod(L, "onUpdate", 1);
    lua_pop(L, 1);                     // callMethod copies args, so drop our dt
  }

  override void onDestroy() {
    callMethod(get_luaruntime(), "onDestroy", 0);
    unloadScript();
  }

  override void onEditorDestroy() { unloadScript(); }

  // --- Messaging ---
  // Args are already on L. callMethod copies them, so the same args can be
  // delivered to several components without re-pushing.
  void sendMessage(lua_State* L, const(char)[] methodName, int nargs) {
    // methodName comes from lua_tolstring, which Lua null-terminates, so .ptr
    // is a valid C string without copying.
    callMethod(L, methodName.ptr, nargs);
  }

  // --- Serialization ---
  JSONValue serializeExtra() {
    JSONValue obj = JSONValue((JSONValue[string]).init);
    obj["scriptPath"] = JSONValue(_scriptPath); // direct: avoids a reload
    writeFields(obj);
    return obj;
  }

  void deserializeExtra(JSONValue data) {
    if (auto p = "scriptPath" in data.object)
      _scriptPath = p.get!string;               // direct: no reload triggered

    if (_scriptPath.length && !def)
      def = getOrLoadScriptDef(get_luaruntime(), _scriptPath);

    readFields(data);
  }

  private void writeFields(ref JSONValue obj) {
    if (!def) return;
    foreach (i, ref d; def.fields)
      obj[d.name] = fieldValues[i].toJson();
  }

  private void readFields(JSONValue data) {
    ensureFieldValues();
    if (!def) return;
    foreach (i, ref d; def.fields)
      if (auto p = d.name in data.object)
        fieldValues[i] = LuaFieldValue.fromJson(d.type, *p);
  }

  // --- Core helpers ---

  // Calls instance:name(args...) where the `nargs` arguments sit on top of L.
  //
  // INVARIANT: the stack is left exactly as the caller had it, plus `nresults`
  // values on success. The arguments are COPIED, never consumed — so callers
  // own (and must clean up) anything they pushed, and the same args can be
  // reused across calls. Returns false if the method does not exist.
  private bool callMethod(lua_State* L, const(char)* name, int nargs, int nresults = 0) {
    if (instanceRef == LUA_NOREF) return false;
    int argsBase = lua_gettop(L) - nargs;   // args occupy argsBase+1 .. top

    pushSelf(L);                            // [args, self]
    getField(L, name);                      // [args, self, fn]   (follows __index)
    if (!isFunction(L)) { lua_pop(L, 2); return false; }

    lua_insert(L, -2);                      // [args, fn, self]
    foreach (i; 0 .. nargs)
      lua_pushvalue(L, argsBase + 1 + i);   // [args, fn, self, argcopies...]
    return pcall(L, nargs + 1, nresults);   // consumes fn,self,argcopies; leaves [args]
  }

  private void loadScript() {
    auto L = get_luaruntime();
    def = getOrLoadScriptDef(L, scriptPath);
    if (!def) return;

    ensureFieldValues();

    // Fresh instance table whose metatable is the shared class.
    def.pushClass(L);                 // [class]
    lua_newtable(L);                  // [class, instance]
    lua_pushvalue(L, -2);             // [class, instance, class]
    lua_setmetatable(L, -2);          // setmetatable(instance, class)   [class, instance]

    pushHandle(L, cast(void*)owner);  // [class, instance, owner]
    setField(L, "gameObject");        // instance.gameObject = owner     [class, instance]

    instanceRef = storeRef(L);        // keep instance alive             [class]
    lua_pop(L, 1);                    // pop class                       []

    syncFieldValues(L);

    // Cache whether onUpdate exists (checked every frame).
    def.pushClass(L);
    getField(L, "onUpdate");
    hasOnUpdate = isFunction(L);
    lua_pop(L, 2);
  }

  private void unloadScript() {
    if (instanceRef == LUA_NOREF) return;
    freeRef(get_luaruntime(), instanceRef);
    instanceRef = LUA_NOREF;
    hasOnUpdate = false;
  }

  private void reload() {
    if (_scriptPath.length) invalidateScriptDef(get_luaruntime(), _scriptPath);
    def         = null;
    fieldValues = null;
    hasOnUpdate = false;
    if (instanceRef != LUA_NOREF) unloadScript();
    if (_scriptPath.length) loadScript();
  }

  // Reconcile fieldValues against def.fields, preserving values whose type
  // still matches and filling the rest with defaults. The single source of
  // truth for sizing/initializing fieldValues.
  private void ensureFieldValues() {
    if (!def) { fieldValues = null; return; }
    if (fieldValues.length == def.fields.length) {
      bool ok = true;
      foreach (i, ref d; def.fields)
        if (fieldValues[i].type != d.type) { ok = false; break; }
      if (ok) return;
    }
    auto old = fieldValues;
    fieldValues = new LuaFieldValue[def.fields.length];
    foreach (i, ref d; def.fields)
      fieldValues[i] = (i < old.length && old[i].type == d.type)
        ? old[i]
        : LuaFieldValue.fromDef(d);
  }

  // Push current D-side fieldValues into the Lua instance.
  void syncFieldValues(lua_State* L) {
    if (!def || instanceRef == LUA_NOREF) return;
    import std.string : toStringz;
    ensureFieldValues();

    pushSelf(L);                        // [instance]
    foreach (i, ref d; def.fields) {
      pushValue(L, fieldValues[i]);     // [instance, value]   (resolves Object_ too)
      setField(L, d.name.toStringz);    // instance[name] = value   [instance]
    }
    lua_pop(L, 1);
  }

  private void pushSelf(lua_State* L) { pushRef(L, instanceRef); }

  private static void pushValue(lua_State* L, ref LuaFieldValue v) {
    final switch (v.type) {
    case LuaFieldType.Float:   push(L, v.f); break;
    case LuaFieldType.Int:     push(L, v.i); break;
    case LuaFieldType.Bool:    push(L, v.b); break;
    case LuaFieldType.String_: push(L, v.s); break;
    case LuaFieldType.Object_: pushResolvedObject(L, v.s); break;
    }
  }

  // scene:// -> resolve to a Transform handle
  // anything else (prefab path) -> push as string for Prefab.instantiate
  // empty / not found -> nil
  private static void pushResolvedObject(lua_State* L, string path) {
    import std.algorithm : startsWith;
    if (!path.length) { pushNil(L); return; }
    if (path.startsWith("scene://")) {
      try {
        import engine.scene.scene : activeScene;
        auto scene = activeScene();
        pushHandle(L, scene ? cast(void*)scene.findByPath(path) : null);
      } catch (Exception) { pushNil(L); }
    } else {
      push(L, path);
    }
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
        case LuaFieldType.Float:   drawField(d.name, fieldValues[i].f, _fieldStates[i], offsetX + 10, offsetY, panelW - 10); break;
        case LuaFieldType.Int:     drawField(d.name, fieldValues[i].i, _fieldStates[i], offsetX + 10, offsetY, panelW - 10); break;
        case LuaFieldType.Bool:    drawField(d.name, fieldValues[i].b, _fieldStates[i], offsetX + 10, offsetY, panelW - 10); break;
        case LuaFieldType.String_: drawField(d.name, fieldValues[i].s, _fieldStates[i], offsetX + 10, offsetY, panelW - 10); break;
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
