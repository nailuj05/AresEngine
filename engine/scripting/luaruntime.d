module engine.scripting.luaruntime;

import lua;

import engine.scripting.api;

private lua_State* _L;

lua_State* get_luaruntime() {
  if (!_L) {
    _L = luaL_newstate();
    luaL_openlibs(_L);
    registerEngineAPI(_L);   // bind Transform, Input, Log etc.
  }
  return _L;
}

void close_luaruntime() {
  if (_L) { lua_close(_L); _L = null; }
}
