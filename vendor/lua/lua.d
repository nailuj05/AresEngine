module lua;

extern(C) @nogc nothrow:

// Opaque state
struct lua_State;

// Core types
alias lua_CFunction   = int function(lua_State* L);
alias lua_Integer     = long;
alias lua_Number      = double;
alias lua_Unsigned    = ulong;

// Thread status
enum LUA_OK        = 0;
enum LUA_YIELD     = 1;
enum LUA_ERRRUN    = 2;
enum LUA_ERRSYNTAX = 3;
enum LUA_ERRMEM    = 4;
enum LUA_ERRERR    = 5;

// Type tags
enum LUA_TNONE          = -1;
enum LUA_TNIL           =  0;
enum LUA_TBOOLEAN       =  1;
enum LUA_TLIGHTUSERDATA =  2;
enum LUA_TNUMBER        =  3;
enum LUA_TSTRING        =  4;
enum LUA_TTABLE         =  5;
enum LUA_TFUNCTION      =  6;
enum LUA_TUSERDATA      =  7;
enum LUA_TTHREAD        =  8;

// Stack pseudo-index
enum LUA_REGISTRYINDEX = -1001000;
enum LUA_MULTRET       = -1;

// State
lua_State* luaL_newstate();
void       lua_close(lua_State* L);
void       luaL_openlibs(lua_State* L);

// Stack
int  lua_gettop(lua_State* L);
void lua_settop(lua_State* L, int idx);
void lua_pushvalue(lua_State* L, int idx);
void lua_rotate(lua_State* L, int idx, int n);      // backing lua_insert
void lua_copy(lua_State* L, int fromidx, int toidx);
void lua_remove(lua_State* L, int idx);
int  lua_absindex(lua_State* L, int idx);
int  lua_checkstack(lua_State* L, int n);

// Push
void lua_pushnil(lua_State* L);
void lua_pushnumber(lua_State* L, lua_Number n);
void lua_pushinteger(lua_State* L, lua_Integer n);
void lua_pushboolean(lua_State* L, int b);
void lua_pushcclosure(lua_State* L, lua_CFunction fn, int n);
const(char)* lua_pushstring(lua_State* L, const(char)* s);
const(char)* lua_pushlstring(lua_State* L, const(char)* s, size_t len);
void lua_pushlightuserdata(lua_State* L, void* p);
void* lua_newuserdatauv(lua_State* L, size_t sz, int nuvalue); // backing lua_newuserdata

// Read
int          lua_type(lua_State* L, int idx);
int          lua_toboolean(lua_State* L, int idx);
lua_Number   lua_tonumberx(lua_State* L, int idx, int* isnum);
lua_Integer  lua_tointegerx(lua_State* L, int idx, int* isnum);
const(char)* lua_tolstring(lua_State* L, int idx, size_t* len);
void*        lua_touserdata(lua_State* L, int idx);
lua_CFunction lua_tocfunction(lua_State* L, int idx);

// Tables
void lua_createtable(lua_State* L, int narr, int nrec);
int  lua_rawget(lua_State* L, int idx);
void lua_rawset(lua_State* L, int idx);
int  lua_rawgeti(lua_State* L, int idx, lua_Integer n);
void lua_rawseti(lua_State* L, int idx, lua_Integer n);
int  lua_getfield(lua_State* L, int idx, const(char)* k);
void lua_setfield(lua_State* L, int idx, const(char)* k);

// Globals
int  lua_getglobal(lua_State* L, const(char)* name);
void lua_setglobal(lua_State* L, const(char)* name);

// Call / load

// Continuations (needed as backing functions for macros)
alias lua_KContext  = ptrdiff_t;
alias lua_KFunction = int function(lua_State* L, int status, lua_KContext ctx);

int lua_pcallk(lua_State* L, int nargs, int nresults, int msgh, lua_KContext ctx, lua_KFunction k); // backs lua_pcall
int luaL_loadfilex(lua_State* L, const(char)* filename, const(char)* mode); // backs luaL_loadfile

int luaL_loadstring(lua_State* L, const(char)* s);
int luaL_loadfile(lua_State* L, const(char)* filename);

// Error / aux
const(char)* luaL_tolstring(lua_State* L, int idx, size_t* len);
int          luaL_error(lua_State* L, const(char)* fmt, ...);
const(char)* luaL_checkstring(lua_State* L, int arg);
lua_Integer  luaL_checkinteger(lua_State* L, int arg);
lua_Number   luaL_checknumber(lua_State* L, int arg);
int          luaL_checktype(lua_State* L, int arg, int t);
int          luaL_newmetatable(lua_State* L, const(char)* tname);
void*        luaL_checkudata(lua_State* L, int ud, const(char)* tname);
void         luaL_setfuncs(lua_State* L, const(luaL_Reg)* l, int nup);

struct luaL_Reg {
  const(char)*  name;
  lua_CFunction func;
}

// D-side macro replacements
// These were macros in lua.h; we implement them in D calling the real functions above.

pragma(inline, true):

void lua_pop(lua_State* L, int n) {
  lua_settop(L, -n - 1);
}
void lua_insert(lua_State* L, int idx) {
  lua_rotate(L, idx, 1);
}
void lua_newuserdata(lua_State* L, size_t sz) {
  lua_newuserdatauv(L, sz, 1);
}
void lua_register(lua_State* L, const(char)* name, lua_CFunction f) {
  lua_pushcclosure(L, f, 0);
  lua_setfield(L, LUA_REGISTRYINDEX, name);
}
void lua_newtable(lua_State* L) {
  lua_createtable(L, 0, 0);
}
bool lua_isnil(lua_State* L, int idx) {
  return lua_type(L, idx) == LUA_TNIL;
}
bool lua_isstring(lua_State* L, int idx) {
  return lua_type(L, idx) == LUA_TSTRING;
}
bool lua_isnumber(lua_State* L, int idx) {
  return lua_type(L, idx) == LUA_TNUMBER;
}
bool lua_istable(lua_State* L, int idx) {
  return lua_type(L, idx) == LUA_TTABLE;
}
bool lua_isfunction(lua_State* L, int idx) {
  return lua_type(L, idx) == LUA_TFUNCTION;
}
const(char)* lua_tostring(lua_State* L, int idx) {
  return lua_tolstring(L, idx, null);
}
lua_Number lua_tonumber(lua_State* L, int idx) {
  return lua_tonumberx(L, idx, null);
}
lua_Integer lua_tointeger(lua_State* L, int idx) {
  return lua_tointegerx(L, idx, null);
}
int lua_pcall(lua_State* L, int nargs, int nresults, int msgh) {
    return lua_pcallk(L, nargs, nresults, msgh, 0, null);
}
int luaL_loadfile(lua_State* L, const(char)* filename) {
    return luaL_loadfilex(L, filename, null);
}
int luaL_dofile(lua_State* L, const(char)* filename) {
    return luaL_loadfilex(L, filename, null) || lua_pcallk(L, 0, LUA_MULTRET, 0, 0, null);
}
