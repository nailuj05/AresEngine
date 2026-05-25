DC          = dmd
CC          = gcc
RAYLIB_SRC  = vendor/raylib-6.0/src
RAYLIB_LIB  = $(BUILD_DIR)/libraylib.a
INSTALL_DIR = $(HOME)/.local/bin
BUILD_DIR   = build
TEST_DIR    = build/testproject

# Platform: PLATFORM_DESKTOP (default), PLATFORM_WEB, PLATFORM_DESKTOP (macOS/Windows future)
PLATFORM ?= PLATFORM_DESKTOP

# lua flags
LUA_SRC_DIR = vendor/lua-5.4.8/src
LUA_LIB     = $(BUILD_DIR)/liblua.a
LUA_OBJ_DIR = $(BUILD_DIR)/lua_obj
LUA_C_SRC = $(filter-out \
    $(LUA_SRC_DIR)/lua.c \
    $(LUA_SRC_DIR)/luac.c, \
    $(wildcard $(LUA_SRC_DIR)/*.c))
LUA_OBJS = $(patsubst $(LUA_SRC_DIR)/%.c, $(LUA_OBJ_DIR)/%.o, $(LUA_C_SRC))

# general flags
DFLAGS         = -I=vendor -I=engine -J=assets
DFLAGS_RELEASE = -I=vendor -I=engine -J=assets -O -release
CFLAGS_EXTRA   = 

# Platform-specific link flags
ifeq ($(PLATFORM), PLATFORM_DESKTOP)
  LFLAGS = $(RAYLIB_LIB) $(LUA_LIB) -L-lGL -L-lm -L-lpthread -L-ldl -L-lrt -L-lX11
endif
ifeq ($(PLATFORM), PLATFORM_WEB)
  CC     = emcc
  DC     = ldc2
  LFLAGS = $(RAYLIB_LIB)  # emscripten provides everything else
endif

RUNTIME_SRC  = $(shell find runtime/ -name '*.d')
ENGINE_SRC   = $(shell find engine/  -name '*.d')
EDITOR_SRC   = $(shell find editor/  -name '*.d')
RAYLIB_D_SRC = $(shell find vendor/raylib/ -name '*.d')
LUA_D_SRC = vendor/lua/lua.d

RUNTIME = $(BUILD_DIR)/runtime
EDITOR  = $(BUILD_DIR)/editor

.PHONY: all runtime editor release install run-editor test-project clean clean-raylib

all: runtime editor

# lua
$(LUA_OBJ_DIR)/%.o: $(LUA_SRC_DIR)/%.c | $(LUA_OBJ_DIR)
	$(CC) -O2 -c $< -o $@

$(LUA_OBJ_DIR):
	mkdir -p $@

$(LUA_LIB): $(LUA_OBJS)
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

# runtime
runtime: $(RUNTIME)
$(RUNTIME): $(RUNTIME_SRC) $(ENGINE_SRC) $(RAYLIB_D_SRC) $(LUA_D_SRC) | $(BUILD_DIR) $(RAYLIB_LIB) $(LUA_LIB)
	$(DC) $(DFLAGS) -of=$@ $^ $(LFLAGS)

# editor
editor: $(EDITOR) runtime
$(EDITOR):  $(EDITOR_SRC)  $(ENGINE_SRC) $(RAYLIB_D_SRC) $(RAYGUI_OBJ) $(LUA_D_SRC) | $(BUILD_DIR) $(RAYLIB_LIB) $(LUA_LIB)
	$(DC) $(DFLAGS) -version=Editor -of=$@ $^ $(LFLAGS)


release: DFLAGS = $(DFLAGS_RELEASE)
release: CFLAGS_EXTRA = -O2
release: editor runtime

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

install: editor runtime
	mkdir -p $(INSTALL_DIR)
	cp $(BUILD_DIR)/editor   $(INSTALL_DIR)/ares-editor
	cp $(BUILD_DIR)/runtime  $(INSTALL_DIR)/ares-runtime

run-editor: install
	ares-editor $(TEST_DIR)

$(TEST_DIR): install
	mkdir -p $(TEST_DIR)
	ares-editor --new $(TEST_DIR)

test-project: install $(TEST_DIR)

clean-raylib:
	$(MAKE) -C $(RAYLIB_SRC) clean
	rm -f $(RAYLIB_LIB)

clean-lua:
	rm -f $(LUA_LIB)
	rm -rf $(LUA_OBJ_DIR)

clean:
	rm -rf $(BUILD_DIR)
