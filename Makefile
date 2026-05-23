DC      = dmd
CC      = gcc
RAYLIB_DIR  = vendor/raylib-6.0_linux_amd64
DFLAGS  = -I=vendor -I=engine -J=assets
LFLAGS  = $(RAYLIB_DIR)/lib/libraylib.a \
          -L-lGL -L-lm -L-lpthread -L-ldl -L-lrt -L-lX11
BUILD   = build

RUNTIME_SRC = $(shell find runtime/ -name '*.d')
ENGINE_SRC  = $(shell find engine/  -name '*.d')
EDITOR_SRC  = $(shell find editor/  -name '*.d')
RAYLIB_D_SRC = $(shell find vendor/raylib/ -name '*.d')

RUNTIME = $(BUILD)/runtime
EDITOR  = $(BUILD)/editor

.PHONY: all runtime editor clean

all: runtime

# raygui
RAYGUI_OBJ = $(BUILD)/raygui.o
$(RAYGUI_OBJ): vendor/raygui/raygui.c | $(BUILD)
	$(CC) -I$(RAYLIB_DIR)/include -c -o $@ $<

# runtime
runtime: $(RUNTIME)
$(RUNTIME): $(RUNTIME_SRC) $(ENGINE_SRC) $(RAYLIB_D_SRC) | $(BUILD)
	$(DC) $(DFLAGS) -of=$@ $^ $(LFLAGS)

# editor -- engine + raygui
editor: $(EDITOR)
$(EDITOR): $(EDITOR_SRC) $(ENGINE_SRC) $(RAYLIB_D_SRC) $(RAYGUI_OBJ) | $(BUILD)
	$(DC) $(DFLAGS) -version=Editor -of=$@ $^ $(LFLAGS)

$(BUILD):
	mkdir -p $(BUILD)

run-editor:	editor
	./build/editor --test

clean:
	rm -rf $(BUILD)
