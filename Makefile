DC      = dmd
CC      = gcc

RAYLIB_DIR  = vendor/raylib-6.0_linux_amd64

DFLAGS  = -I=vendor \
          -I=engine

LFLAGS = $(RAYLIB_DIR)/lib/libraylib.a \
         -L-lGL -L-lm -L-lpthread -L-ldl -L-lrt -L-lX11

BUILD    = build
LIB      = $(BUILD)/libengine.a

RUNTIME_SRC = $(shell find runtime/ -name '*.d')
ENGINE_SRC  = $(shell find engine/  -name '*.d')
EDITOR_SRC  = $(shell find editor/  -name '*.d')


RUNTIME = $(BUILD)/runtime
EDITOR  = $(BUILD)/editor

.PHONY: all runtime editor clean

all: runtime

# Raygui

RAYGUI_OBJ = $(BUILD)/raygui.o

$(RAYGUI_OBJ): vendor/raygui/raygui.c | $(BUILD)
	$(CC) -c -o $@ $<

# Engine lib 

$(LIB): $(ENGINE_SRC) | $(BUILD)
	$(DC) $(DFLAGS) lib -of=$@ $^

# Runtime

runtime: $(RUNTIME)

$(RUNTIME): $(RUNTIME_SRC) $(RAYGUI_OBJ) | $(BUILD)
	$(DC) $(DFLAGS) -of=$@ $^ $(LFLAGS)

# Editor

editor: $(EDITOR)

$(EDITOR): $(EDITOR_SRC) $(ENGINE_SRC) | $(BUILD)
	$(DC) $(DFLAGS) -of=$@ $^ $(LFLAGS)

# Util

$(BUILD):
	mkdir -p $(BUILD)

clean:
	rm -rf $(BUILD)
