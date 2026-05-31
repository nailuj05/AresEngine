DC          = dmd
DC_RELEASE  = ldc2
CC          = gcc
RAYLIB_SRC  = vendor/raylib-6.0/src
RAYLIB_LIB  = $(BUILD_DIR)/libraylib.a
INSTALL_DIR = $(HOME)/.local/bin
BUILD_DIR   = build
TEST_DIR    = build/testproject

# Platform: PLATFORM_DESKTOP (default), future: PLATFORM_WEB
PLATFORM ?= PLATFORM_DESKTOP

# lua
LUA_SRC_DIR      = vendor/lua-5.4.8/src
LUA_LIB          = $(BUILD_DIR)/liblua.a
LUA_LIB_RELEASE  = $(BUILD_DIR)/liblua_release.a
LUA_OBJ_DIR      = $(BUILD_DIR)/lua_obj
LUA_C_SRC = $(filter-out \
    $(LUA_SRC_DIR)/lua.c \
    $(LUA_SRC_DIR)/luac.c, \
    $(wildcard $(LUA_SRC_DIR)/*.c))
LUA_OBJS         = $(patsubst $(LUA_SRC_DIR)/%.c, $(LUA_OBJ_DIR)/%.o,         $(LUA_C_SRC))
LUA_OBJS_RELEASE = $(patsubst $(LUA_SRC_DIR)/%.c, $(LUA_OBJ_DIR)/%.release.o, $(LUA_C_SRC))

# general flags
DFLAGS         = -I=vendor -I=engine -J=assets
DFLAGS_RELEASE = -I=vendor -I=engine -J=assets -O3 -release
CFLAGS_EXTRA   =

# Platform-specific link flags
ifeq ($(PLATFORM), PLATFORM_DESKTOP)
  LFLAGS         = $(RAYLIB_LIB) $(LUA_LIB)         -L-lGL -L-lm -L-lpthread -L-ldl -L-lrt -L-lX11
	LFLAGS_RELEASE = $(RAYLIB_LIB) $(LUA_LIB_RELEASE) -L-lGL -L-lm -L-lpthread -L-ldl -L-lrt -L-lX11 -L--allow-multiple-definition
endif
# ifeq ($(PLATFORM), PLATFORM_WEB)
#   CC     = emcc
#   DC     = ldc2
#   LFLAGS = $(RAYLIB_LIB)  # emscripten provides everything else
# endif

RUNTIME_SRC  = $(shell find runtime/ -name '*.d')
ENGINE_SRC   = $(shell find engine/ -path engine/tests -prune -o -name '*.d' -print) # prune tests
EDITOR_SRC   = $(shell find editor/ -name '*.d')
TEST_SRC     = $(shell find engine/tests/ -name '*.d')
RAYLIB_D_SRC = $(shell find vendor/raylib/ -name '*.d')
LUA_D_SRC    = vendor/lua/lua.d

RUNTIME         = $(BUILD_DIR)/runtime
EDITOR          = $(BUILD_DIR)/editor
RUNTIME_RELEASE = $(BUILD_DIR)/runtime_release
EDITOR_RELEASE  = $(BUILD_DIR)/editor_release

.PHONY: all test runtime editor release install run-editor test-project clean clean-raylib clean-lua

all: runtime editor

# lua debug
$(LUA_OBJ_DIR)/%.o: $(LUA_SRC_DIR)/%.c | $(LUA_OBJ_DIR)
	$(CC) -O2 -c $< -o $@

# lua release (no LTO to avoid symbol conflicts with lld)
$(LUA_OBJ_DIR)/%.release.o: $(LUA_SRC_DIR)/%.c | $(LUA_OBJ_DIR)
	$(CC) -O3 -fno-lto -c $< -o $@

$(LUA_OBJ_DIR):
	mkdir -p $@

$(LUA_LIB): $(LUA_OBJS)
	ar rcs $@ $^

$(LUA_LIB_RELEASE): $(LUA_OBJS_RELEASE)
	ar rcs $@ $^

# raylib
$(RAYLIB_LIB): | $(BUILD_DIR)
	$(MAKE) -C $(RAYLIB_SRC) PLATFORM=$(PLATFORM) CC=$(CC) RAYLIB_BUILD_MODE=RELEASE
	cp $(RAYLIB_SRC)/libraylib.a $(RAYLIB_LIB)
	$(MAKE) -C $(RAYLIB_SRC) clean

# raygui
RAYGUI_OBJ = $(BUILD_DIR)/raygui.o
$(RAYGUI_OBJ): vendor/raygui/raygui.c | $(BUILD_DIR)
	$(CC) -I$(RAYLIB_SRC) -c $(CFLAGS_EXTRA) $< -o $@

test: $(RAYLIB_LIB) $(LUA_LIB)
	$(DC) $(DFLAGS) -unittest -main -of=$(BUILD_DIR)/test_runner \
		$(ENGINE_SRC) $(TEST_SRC) $(RAYLIB_D_SRC) $(LUA_D_SRC) $(LFLAGS)
	$(BUILD_DIR)/test_runner

# runtime
runtime: $(RUNTIME)

$(RUNTIME): $(RUNTIME_SRC) $(ENGINE_SRC) $(RAYLIB_D_SRC) $(LUA_D_SRC) | $(BUILD_DIR) $(RAYLIB_LIB) $(LUA_LIB)
	$(DC) $(DFLAGS) -version=Profile -of=$@ $^ $(LFLAGS)

$(RUNTIME_RELEASE): $(RUNTIME_SRC) $(ENGINE_SRC) $(RAYLIB_D_SRC) $(LUA_D_SRC) | $(BUILD_DIR) $(RAYLIB_LIB) $(LUA_LIB_RELEASE)
	$(DC_RELEASE) $(DFLAGS_RELEASE) -d-version=Profile -of=$@ $^ $(LFLAGS_RELEASE)

# editor
editor: $(EDITOR) runtime

$(EDITOR): $(EDITOR_SRC) $(ENGINE_SRC) $(RAYLIB_D_SRC) $(RAYGUI_OBJ) $(LUA_D_SRC) | $(BUILD_DIR) $(RAYLIB_LIB) $(LUA_LIB)
	$(DC) $(DFLAGS) -version=Editor -of=$@ $^ $(LFLAGS)

$(EDITOR_RELEASE): $(EDITOR_SRC) $(ENGINE_SRC) $(RAYLIB_D_SRC) $(RAYGUI_OBJ) $(LUA_D_SRC) | $(BUILD_DIR) $(RAYLIB_LIB) $(LUA_LIB_RELEASE)
	$(DC_RELEASE) $(DFLAGS_RELEASE) -d-version=Editor -of=$@ $^ $(LFLAGS_RELEASE)

release: $(EDITOR_RELEASE) $(RUNTIME_RELEASE)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

install: editor runtime
	mkdir -p $(INSTALL_DIR)
	cp $(BUILD_DIR)/editor  $(INSTALL_DIR)/ares-editor
	cp $(BUILD_DIR)/runtime $(INSTALL_DIR)/ares-runtime

install-release: $(EDITOR_RELEASE) $(RUNTIME_RELEASE)
	mkdir -p $(INSTALL_DIR)
	cp $(BUILD_DIR)/editor_release  $(INSTALL_DIR)/ares-editor
	cp $(BUILD_DIR)/runtime_release $(INSTALL_DIR)/ares-runtime

run-editor: install
	ares-editor --profile $(TEST_DIR)

$(TEST_DIR): install
	mkdir -p $(TEST_DIR)
	ares-editor --new $(TEST_DIR)

test-project: install $(TEST_DIR)

clean-raylib:
	$(MAKE) -C $(RAYLIB_SRC) clean
	rm -f $(RAYLIB_LIB)

clean-lua:
	rm -f $(LUA_LIB) $(LUA_LIB_RELEASE)
	rm -rf $(LUA_OBJ_DIR)

clean:
	rm -rf $(BUILD_DIR)
