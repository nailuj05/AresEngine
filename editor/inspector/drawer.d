module editor.inspector.drawer;

import raylib;
import raygui;

import std.stdio;
import std.format : format;
import std.string : join, toStringz, fromStringz;
import std.conv   : to;
import std.traits : hasUDA, getUDAs;

import engine.asset;
import engine.models.model;
import engine.models.modelmanager: ModelManager;
import engine.shaders.shadermanager;
import engine.materials.material;
import engine.materials.materialmanager : MaterialManager;
import engine.scene.objectmanager;
import engine.core.component;
import editor.dialog.colorpicker;
import editor.dialog.assetpicker;

Color* colorPickerOwner;
bool   colorPickerDirty;
ColorPickerDialog colorPicker;

bool ownsColorPicker(Color* p) {
  return colorPickerOwner == p;
}

void claimColorPicker(Color* target) {
  colorPickerOwner = target;
  colorPicker.show(*target, (Color c) {
    *target = c;
    colorPickerDirty = true;
  });
}

bool consumeColorChange(Color* p) {
  if (colorPickerDirty && colorPickerOwner == p) {
    colorPickerDirty = false;
    colorPickerOwner = null;
    return true;
  }
  return false;
}

AssetPickerDialog!ModelEntry modelPicker;
AssetPickerDialog!ShaderEntry shaderPicker;
AssetPickerDialog!MaterialEntry materialPicker;
AssetPickerDialog!ObjectEntry goPicker;

enum MAX_FIELD_BUFFER = 256;
enum float LABEL_W    = 120;
enum float FIELD_H    = 20;
enum float ROW_H      = 28;


// ------------------------------------------------------------------------- //
// TODO: This needs to be majorly refactored to be more readable and useable //
// ------------------------------------------------------------------------- //

struct FieldState {
  char[MAX_FIELD_BUFFER] buffer = 0;
  bool editing;
}

// Pointer to writeback field
private string* pendingAssetField;
bool drawAssetPickers() {
  bool changed = false;

  if (modelPicker.draw() && !modelPicker.cancelled) {
    if (pendingAssetField) {
      *pendingAssetField = modelPicker.result.path;
      changed = true;
    }
    pendingAssetField = null;
  }

  if (shaderPicker.draw() && !shaderPicker.cancelled) {
    if (pendingAssetField) {
      *pendingAssetField = shaderPicker.result.path;
      changed = true;
    }
    pendingAssetField = null;
  }

  if (materialPicker.draw() && !materialPicker.cancelled) {
    if (pendingAssetField) {
      *pendingAssetField = materialPicker.result.path;
      changed = true;
    }
    pendingAssetField = null;
  }

  if (goPicker.draw() && !goPicker.cancelled) {
    if (pendingAssetField) {
      *pendingAssetField = goPicker.result.path;
      changed = true;
    }
    pendingAssetField = null;
  }

  return changed;
}

bool drawAssetField(AssetKind kind)(string name, ref string field, float ox, float y, float pw) {
  Rectangle lr  = Rectangle(ox + 8,              y, LABEL_W,           FIELD_H);
  Rectangle fr  = Rectangle(ox + LABEL_W - 4,    y, pw - LABEL_W - 28, FIELD_H);
  Rectangle btn = Rectangle(fr.x + fr.width + 4, y, 20,                FIELD_H);

  GuiLabel(lr, name.humanize().toStringz());
  GuiLabel(fr, field.length ? field.toStringz() : "<none>".toStringz());
  DrawRectangleLinesEx(fr, 1, GetColor(GuiGetStyle(DEFAULT, BORDER_COLOR_NORMAL)));

  if (GuiButton(btn, "...".toStringz())) {
    static if (kind == AssetKind.Model) {
      pendingAssetField = &field;
      modelPicker.show("Pick Model",
                       ModelManager.instance.availableModels(),
                       (const ref ModelEntry e) => format!"%d mesh(es)"(e.meshCount));
    }
    else static if (kind == AssetKind.Shader) {
      pendingAssetField = &field;
      shaderPicker.show("Pick Shader",
                       ShaderManager.instance.availableShaders(),
                       (const ref ShaderEntry e) => "---");
    }
    else static if (kind == AssetKind.Material) {
      pendingAssetField = &field;
      materialPicker.show("Pick Material",
                       MaterialManager.instance.availableMaterials(),
                       (const ref MaterialEntry e) => "---");
    }
    else static if (kind == AssetKind.Object) {
      pendingAssetField = &field;
      goPicker.show("Pick Object",
                    ObjectManager.instance.availableObjects(),
                    (const ref ObjectEntry e) => ObjectManager.objectMeta(e));
    }
  }
  return drawAssetPickers();
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
    return !s.editing;
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

bool drawVec3Field(string label, ref float x, ref float y, ref float z, ref FieldState[3] fs, float ox, float oy, float pw) {
  return drawVec3Row(label, x, y, z, fs, ox, oy, pw);
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
  return changed;
}

bool drawField(string label, ref Vector3 value, ref FieldState[3] state, float ox, float oy, float pw) {
  return drawVec3Field(label, value, state, ox, oy, pw);
}

bool drawField(T)(string label, ref T value, ref FieldState state, float ox, float oy, float pw, bool delegate()* deferred = null) {
  syncBuffer(state, value);
  Rectangle lr = Rectangle(ox + 8,               oy, LABEL_W,            FIELD_H);
  Rectangle fr = Rectangle(ox + 8 + LABEL_W + 4, oy, pw - LABEL_W - 20, FIELD_H);
  GuiLabel(lr, label.humanize().toStringz());

  static if (is(T == bool)) {
    T old = value;
    GuiCheckBox(Rectangle(fr.x, oy, FIELD_H, FIELD_H), "".toStringz, &value);
    
    return value != old;
  }
  else static if (is(T == float) || is(T == int)) {
    // Return true on the frame editing transitions to committed (wasEditing && !state.editing).
    bool wasEditing = state.editing;

    if (GuiTextBox(fr, state.buffer.ptr, MAX_FIELD_BUFFER, state.editing))
      state.editing = !state.editing;
    
    if (!state.editing) {
      try {
        static if (is(T == float)) {
          value = to!float(fromStringz(state.buffer.ptr));
        }
        else {
          value = to!int(fromStringz(state.buffer.ptr));
        }
      }
      catch (Exception) {}
    }

    return wasEditing && !state.editing;
  }
  else static if (is(T == string)) {
    bool wasEditing = state.editing;

    if (GuiTextBox(fr, state.buffer.ptr, MAX_FIELD_BUFFER, state.editing))
      state.editing = !state.editing;

    if (!state.editing)
      value = fromStringz(state.buffer.ptr).idup;
    
    return wasEditing && !state.editing;
  }
  else static if (is(T == Color)) {
    DrawRectangleRec(fr, value);
    DrawRectangleLinesEx(fr, 1, GetColor(GuiGetStyle(DEFAULT, BORDER_COLOR_NORMAL)));

    if (IsMouseButtonPressed(MouseButton.MOUSE_BUTTON_LEFT) && CheckCollisionPointRec(GetMousePosition(), fr))
      claimColorPicker(&value);

    return consumeColorChange(&value);
  }
  else static if (is(T == enum)) {
    import std.traits : EnumMembers;
    enum opts = [__traits(allMembers, T)].join(";");
    
    int active = 0;

    static foreach (i, m; EnumMembers!T)
      if (value == m) active = cast(int) i;

    if (state.editing && deferred) {
      *deferred = () {
        // Return true when the user commits a selection (GuiDropdownBox fires in open mode).
        bool committed = false;
        if (GuiDropdownBox(fr, opts.ptr, &active, true)) {
          state.editing = false;
          committed = true;
        }

        static foreach (i, m; EnumMembers!T)
          if (active == cast(int) i) value = m;

        return committed;
      };
    }
    else {
      if (GuiDropdownBox(fr, opts.ptr, &active, false))
        state.editing = true;
    }
    return false;
  }
  return false;
}

// Returns true if any field was modified this frame.
// Pass endY to receive the y position after the last drawn row.
bool drawFields(T)(ref T obj, ref FieldState[string] states, float ox, float oy, float pw, float* endY = null) {
  float y = oy;
  bool changed = false;
  bool delegate() deferred = null;

  foreach (i, ref field; obj.tupleof) {
    static if (__traits(getProtection, obj.tupleof[i]) == "public" && !hasUDA!(obj.tupleof[i], DontSerialize)) {
      enum name     = __traits(identifier, obj.tupleof[i]);
      alias FieldType = typeof(field);

      static if (is(FieldType == Vector3)) {
        enum kx = name ~ ".x";
        enum ky = name ~ ".y";
        enum kz = name ~ ".z";
        if (kx !in states) states[kx] = FieldState.init;
        if (ky !in states) states[ky] = FieldState.init;
        if (kz !in states) states[kz] = FieldState.init;
        FieldState[3] fs = [states[kx], states[ky], states[kz]];
        if (drawField(name, field, fs, ox, y, pw)) changed = true;
        states[kx] = fs[0];
        states[ky] = fs[1];
        states[kz] = fs[2];
      }
      else static if (hasUDA!(obj.tupleof[i], Asset)) {
        enum assetKind = getUDAs!(obj.tupleof[i], Asset)[0].kind;
        if (name !in states) states[name] = FieldState.init;
        changed = drawAssetField!assetKind(name, field, ox, y, pw);
      }
      else {
        if (name !in states) states[name] = FieldState.init;
        if (drawField(name, field, states[name], ox, y, pw, &deferred)) changed = true;
      }

      y += ROW_H;
    }
  }
  if (deferred && deferred()) changed = true;

  if (endY) *endY = y;

  return changed;
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
