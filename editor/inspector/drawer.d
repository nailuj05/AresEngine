module editor.inspector.drawer;

import std.format: format;
import std.string: toStringz;
import raygui;
import raylib;
import editor.inspector.inspector;

enum MAX_FIELD_BUFFER = 256;

struct FieldState {
  char[MAX_FIELD_BUFFER] buffer;
  bool initialized;
  bool editing;
}

void drawFields(T)(ref T obj, ref FieldState[string] states, ulong ox, ulong oy) {
  ulong row = 0;
  foreach (i, ref field; obj.tupleof) {
    static if (__traits(getProtection, obj.tupleof[i]) == "public") {
      enum name = __traits(identifier, obj.tupleof[i]);

      if (name !in states) {
        FieldState s;
        initFieldState(s, field);
        states[name] = s;
      }
      
      drawField(name, field, states[name], ox, oy + row * 32);
      row++;
    }
  }
}

void initFieldState(T)(ref FieldState state, ref T value) {
  if (state.initialized)
    return;
  static if (is(T == string)) {
    auto len = value.length < MAX_FIELD_BUFFER - 1
      ? value.length : MAX_FIELD_BUFFER - 1;
    state.buffer[0 .. len] = value[0 .. len];
    state.buffer[len] = '\0';
  } else {
    auto txt = format!"%s"(value);
    auto len = txt.length < MAX_FIELD_BUFFER - 1
      ? txt.length : MAX_FIELD_BUFFER - 1;
    state.buffer[0 .. len] = txt[0 .. len];
    state.buffer[len] = '\0';
  }
  state.initialized = true;
}

void drawField(T)(string name, ref T value, ref FieldState state, ulong ox, ulong oy) {
  import std.format : format;
  import std.string : toStringz, fromStringz;
  import std.conv : to;

  enum LABEL_W = 120;
  enum FIELD_H = 20;
  ox += 24;

  Rectangle labelRect = Rectangle(ox, oy, LABEL_W, FIELD_H);
  Rectangle fieldRect = Rectangle(ox + LABEL_W + 4, oy,
                                  INSPECTOR_W - LABEL_W - 12 - 24, FIELD_H);

  GuiLabel(labelRect, name.toStringz);

  static if (is(T == bool)) {
    GuiCheckBox(fieldRect, "".toStringz, &value);
  }
  else static if (is(T == int)) {
    if (GuiTextBox(fieldRect, state.buffer.ptr, MAX_FIELD_BUFFER, state.editing))
      state.editing = !state.editing;
    if (!state.editing) {  // only parse when user finishes editing
      try { value = to!int(fromStringz(state.buffer.ptr)); }
      catch (Exception) {}
    }
  }
  else static if (is(T == float)) {
    if (GuiTextBox(fieldRect, state.buffer.ptr, MAX_FIELD_BUFFER, state.editing))
      state.editing = !state.editing;
    if (!state.editing) {
      try { value = to!float(fromStringz(state.buffer.ptr)); }
      catch (Exception) {}
    }
  }
  else static if (is(T == string)) {
    if (GuiTextBox(fieldRect, state.buffer.ptr, MAX_FIELD_BUFFER, state.editing))
      state.editing = !state.editing;
    if (!state.editing)
      value = fromStringz(state.buffer.ptr).idup;
  }
  else {
    GuiLabel(fieldRect, format!"%s"(value).toStringz);
  }
}
