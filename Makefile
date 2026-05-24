DC = dmd # ldc for better optimization in the future?
CC = gcc

RAYLIB_DIR  = vendor/raylib-6.0_linux_amd64
INSTALL_DIR = $(HOME)/.local/bin
BUILD_DIR		= build
TEST_DIR = build/testproject

DFLAGS = -I=vendor -I=engine -J=assets
LFLAGS = $(RAYLIB_DIR)/lib/libraylib.a \
          -L-lGL -L-lm -L-lpthread -L-ldl -L-lrt -L-lX11

DFLAGS_RELEASE = -I=vendor -I=engine -J=assets -O -release

RUNTIME_SRC		= $(shell find runtime/ -name '*.d')
ENGINE_SRC		= $(shell find engine/  -name '*.d')
EDITOR_SRC		= $(shell find editor/  -name '*.d')
RAYLIB_D_SRC	= $(shell find vendor/raylib/ -name '*.d')

RUNTIME = $(BUILD_DIR)/runtime
EDITOR  = $(BUILD_DIR)/editor

.PHONY: all runtime editor clean

all: runtime editor 

release: DFLAGS = $(DFLAGS_RELEASE)
release: CFLAGS_EXTRA = -O2
release: editor runtime

# raygui
RAYGUI_OBJ = $(BUILD_DIR)/raygui.o
$(RAYGUI_OBJ): vendor/raygui/raygui.c | $(BUILD_DIR)
	$(CC) -I$(RAYLIB_DIR)/include -c $(CFLAGS_EXTRA) -o $@ $<

# runtime
runtime: $(RUNTIME)
$(RUNTIME): $(RUNTIME_SRC) $(ENGINE_SRC) $(RAYLIB_D_SRC) | $(BUILD_DIR)
	$(DC) $(DFLAGS) -of=$@ $^ $(LFLAGS)

# editor -- engine + raygui
editor: $(EDITOR) runtime
$(EDITOR): $(EDITOR_SRC) $(ENGINE_SRC) $(RAYLIB_D_SRC) $(RAYGUI_OBJ) | $(BUILD_DIR)
	$(DC) $(DFLAGS) -version=Editor -of=$@ $^ $(LFLAGS)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

install: editor runtime
	mkdir -p $(INSTALL_DIR)
	cp $(BUILD_DIR)/editor   $(INSTALL_DIR)/ares-editor
	cp $(BUILD_DIR)/runtime  $(INSTALL_DIR)/ares-runtime

run-editor: install
	ares-editor $(TEST_DIR)

$(TEST_DIR):
	mkdir -p $(TEST_DIR)
	ares-editor --new $(TEST_DIR)

test-project: install $(TEST_DIR)

clean:
	rm -rf $(BUILD_DIR)
