module editor.inspector.drawer;

import raylib;
import raygui;

import std.format : format;
import std.string : join, toStringz, fromStringz;
import std.conv   : to;
import std.traits : hasUDA;

import engine.core.component;
import editor.dialog.colorpicker;

ColorPickerDialog colorPicker;

enum MAX_FIELD_BUFFER = 256;
enum float LABEL_W    = 120;
enum float FIELD_H    = 20;
enum float ROW_H      = 28;

struct FieldState {
  char[MAX_FIELD_BUFFER] buffer = 0;
  bool editing;
}

private void syncBuffer(T)(ref FieldState s, T value) {
  if (s.editing) return;
  static if (is(T == float))
    auto txt = format!"%.3f"(value);
  else
    auto txt = format!"%s"(value);
  size_t len = txt.length < MAX_FIELD_BUFFER - 1 ? txt.length : MAX_FIELD_BUFFER - 1;
  s.buffer[0 .. len] = txt[0 .. len];
  s.buffer[len] = '\0';
}

private bool textBoxRow(ref FieldState s, Rectangle r) {
  if (GuiTextBox(r, s.buffer.ptr, MAX_FIELD_BUFFER, s.editing)) {
    s.editing = !s.editing;
    return !s.editing; // true = just committed
  }
  return false;
}

private bool drawVec3Row(string label, ref float x, ref float y, ref float z, ref FieldState[3] fs, float ox, float oy, float pw) {
  syncBuffer(fs[0], x);
  syncBuffer(fs[1], y);
  syncBuffer(fs[2], z);

  float fw = (pw - LABEL_W - 28) / 3.0f;
  float cx = ox + 8 + LABEL_W + 4;
  bool changed = false;

  GuiLabel(Rectangle(ox + 8, oy, LABEL_W, FIELD_H), label.toStringz);

  float*[3] targets = [&x, &y, &z];
  foreach (i; 0 .. 3) {
    if (textBoxRow(fs[i], Rectangle(cx, oy, fw, FIELD_H))) {
      changed = true;
      try { *targets[i] = to!float(fromStringz(fs[i].buffer.ptr)); } catch (Exception) {}
    }
    cx += fw + 4;
  }
  return changed;
}

bool drawVec3Field(string label, ref Vector3 v, ref FieldState[3] fs, float ox, float oy, float pw) {
  return drawVec3Row(label, v.x, v.y, v.z, fs, ox, oy, pw);
}

bool drawEulerField(string label, ref Quaternion q, ref FieldState[3] fs, float ox, float oy, float pw) {
  if (!fs[0].editing && !fs[1].editing && !fs[2].editing) {
    Vector3 e = QuaternionToEuler(q);
    syncBuffer(fs[0], e.x * RAD2DEG);
    syncBuffer(fs[1], e.y * RAD2DEG);
    syncBuffer(fs[2], e.z * RAD2DEG);
  }

  float fw = (pw - LABEL_W - 28) / 3.0f;
  float cx = ox + 8 + LABEL_W + 4;
  bool changed = false;

  GuiLabel(Rectangle(ox + 8, oy, LABEL_W, FIELD_H), label.toStringz);

  foreach (i; 0 .. 3) {
    if (textBoxRow(fs[i], Rectangle(cx, oy, fw, FIELD_H)))
      changed = true;
    cx += fw + 4;
  }

  if (changed) {
    try {
      float ex = to!float(fromStringz(fs[0].buffer.ptr)) * DEG2RAD;
      float ey = to!float(fromStringz(fs[1].buffer.ptr)) * DEG2RAD;
      float ez = to!float(fromStringz(fs[2].buffer.ptr)) * DEG2RAD;
      q = QuaternionFromEuler(ex, ey, ez);
    } catch (Exception) {}
  }
  return changed; // fixed: was unconditionally returning true
}

// Non-template overload so drawFields can pass FieldState[3] without ambiguity.
// deferred omitted: vec3 fields are never dropdowns.
void drawField(string label, ref Vector3 value, ref FieldState[3] state, float ox, float oy, float pw) {
  drawVec3Field(label, value, state, ox, oy, pw);
}

void drawField(T)(string label, ref T value, ref FieldState state, float ox, float oy, float pw,
    void delegate()* deferred = null)
{
  syncBuffer(state, value);
  Rectangle lr = Rectangle(ox + 8,               oy, LABEL_W,              FIELD_H);
  Rectangle fr = Rectangle(ox + 8 + LABEL_W + 4, oy, pw - LABEL_W - 20,   FIELD_H);
  GuiLabel(lr, label.humanize().toStringz());

  static if (is(T == bool)) {
    GuiCheckBox(Rectangle(fr.x, oy, FIELD_H, FIELD_H), "".toStringz, &value);

  } else static if (is(T == float) || is(T == int)) {
    if (GuiTextBox(fr, state.buffer.ptr, MAX_FIELD_BUFFER, state.editing))
      state.editing = !state.editing;
    if (!state.editing) {
      try {
        static if (is(T == float)) value = to!float(fromStringz(state.buffer.ptr));
        else                        value = to!int  (fromStringz(state.buffer.ptr));
      } catch (Exception) {}
    }

  } else static if (is(T == string)) {
    if (GuiTextBox(fr, state.buffer.ptr, MAX_FIELD_BUFFER, state.editing))
      state.editing = !state.editing;
    if (!state.editing)
      value = fromStringz(state.buffer.ptr).idup;

  } else static if (is(T == Color)) {
    DrawRectangleRec(fr, value);
    DrawRectangleLinesEx(fr, 1, GetColor(GuiGetStyle(DEFAULT, BORDER_COLOR_NORMAL)));
    if (IsMouseButtonPressed(MouseButton.MOUSE_BUTTON_LEFT) && CheckCollisionPointRec(GetMousePosition(), fr))
      colorPicker.show(value);
    if (colorPicker.hasResult) {
      value = colorPicker.result;
      colorPicker.hasResult = false;
    }

  } else static if (is(T == enum)) {
    import std.traits : EnumMembers;
    enum opts = [__traits(allMembers, T)].join(";");
    int active = 0;
    static foreach (i, m; EnumMembers!T)
      if (value == m) active = cast(int) i;
    if (state.editing && deferred) {
      *deferred = () {
        if (GuiDropdownBox(fr, opts.ptr, &active, true))
          state.editing = false;
        static foreach (i, m; EnumMembers!T)
          if (active == cast(int) i) value = m;
      };
    } else {
      if (GuiDropdownBox(fr, opts.ptr, &active, false))
        state.editing = true;
    }
  }
}

// Returns y position after the last drawn row.
// NOTE: requires Component.drawInspector(float, float, float) : float
float drawFields(T)(ref T obj, ref FieldState[string] states, float ox, float oy, float pw) {
  float y = oy;
  void delegate() deferred = null;

  foreach (i, ref field; obj.tupleof) {
    static if (__traits(getProtection, obj.tupleof[i]) == "public"
        && !hasUDA!(obj.tupleof[i], DontSerialize)) {
      enum name      = __traits(identifier, obj.tupleof[i]);
      alias FieldType = typeof(field);

      static if (is(FieldType == Vector3)) {
        // Subkeys are compile-time constants, so no runtime overhead beyond the AA lookup.
        enum kx = name ~ ".x";
        enum ky = name ~ ".y";
        enum kz = name ~ ".z";
        if (kx !in states) states[kx] = FieldState.init;
        if (ky !in states) states[ky] = FieldState.init;
        if (kz !in states) states[kz] = FieldState.init;
        FieldState[3] fs = [states[kx], states[ky], states[kz]];
        drawField(name, field, fs, ox, y, pw);
        states[kx] = fs[0];
        states[ky] = fs[1];
        states[kz] = fs[2];
      } else {
        if (name !in states) states[name] = FieldState.init;
        drawField(name, field, states[name], ox, y, pw, &deferred);
      }

      y += ROW_H;
    }
  }
  if (deferred) deferred();
  return y;
}

string humanize(string s) {
  import std.uni   : isUpper;
  import std.array : appender;
  import std.ascii : toUpper;
  if (s.length == 0) return s;
  auto o = appender!string();
  o.put(cast(char) toUpper(s[0]));
  foreach (i; 1 .. s.length) {
    if (isUpper(s[i])) o.put(' ');
    o.put(s[i]);
  }
  return o.data;
}
