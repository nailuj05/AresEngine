module engine.scene.loader;

import std.json;
import std.stdio;
import std.file   : readText, write;
import std.traits : FieldNameTuple, Unqual, hasUDA;

import raylib : Color, Vector3, Quaternion;

import engine.scene.scene;
import engine.core.gameobject;
import engine.core.component;
import engine.core.transform;
import engine.core.iextraserializable;

// -------------------------------------------------------------------------------------- //
// TODO: pull out the general serialization functions into a proper serialization package //
// -------------------------------------------------------------------------------------- //

template isSerializableField(T) {
    enum isSerializableField = is(T == bool)
                            || is(T == float)
                            || is(T == int)
                            || is(T == string)
                            || is(T == string[])
                            || is(T == Color)
                            || is(T == enum);
}

// public API
void saveScene(Scene scene, string path) {
  writefln("saving scene %s", scene.name);
  JSONValue[] roots;
  foreach (t; scene.roots)
    roots ~= serializeTransform(t);
  write(path, JSONValue(["name": JSONValue(scene.name), "roots": JSONValue(roots)]).toPrettyString());
}

Scene loadScene(string path) {
  writefln("loading scene %s", path);
  JSONValue j;
  try {
    j = parseJSON(readText(path));
  } catch (Exception e) {
    writeln("Failure opening scene");
    return null;
  }
  auto scene = new Scene(j["name"].str);
  foreach (rootJ; j["roots"].array)
    scene.roots ~= deserializeTransform(rootJ);
  return scene;
}


// fields

private JSONValue serializeFields(T)(T obj) {
  JSONValue result = JSONValue((JSONValue[string]).init);
  static foreach (field; FieldNameTuple!(Unqual!T)) {{
      enum prot = __traits(getProtection, __traits(getMember, Unqual!T, field));
      alias FT = typeof(__traits(getMember, obj, field));
      static if (prot == "public"
                 && !hasUDA!(__traits(getMember, Unqual!T, field), DontSerialize)
                 && isSerializableField!FT) {
        auto  v  = __traits(getMember, obj, field);

        static if      (is(FT == bool))     result[field] = JSONValue(v);
        else static if (is(FT == float))    result[field] = JSONValue(v);
        else static if (is(FT == int))      result[field] = JSONValue(v);
        else static if (is(FT == string))   result[field] = JSONValue(v);
        else static if (is(FT == string[])) result[field] = JSONValue(v);
        else static if (is(FT == Color))    result[field] = serializeColor(v);
        else static if (is(FT == enum))     result[field] = JSONValue(cast(long)v);
        else static if (is(FT == Vector3))  result[field] = serializeVec3(v);
      }
    }
  }
  static if (is(T : IExtraSerializable))
    foreach (k, v; obj.serializeExtra().object)
      result[k] = v;
  return result;
}

private void deserializeFields(T)(T obj, JSONValue fields) {
  static foreach (field; FieldNameTuple!(Unqual!T)) {{
      enum prot = __traits(getProtection, __traits(getMember, Unqual!T, field));
      alias FT = typeof(__traits(getMember, obj, field));
      static if (prot == "public"
                 && !hasUDA!(__traits(getMember, Unqual!T, field), DontSerialize)
                 && isSerializableField!FT) {
        if (auto p = field in fields.object) {
          auto jv = *p;
          static if      (is(FT == bool))   __traits(getMember, obj, field) = jv.boolean;
          else static if (is(FT == float))  __traits(getMember, obj, field) = jv.floating;
          else static if (is(FT == int))    __traits(getMember, obj, field) = cast(int)jv.integer;
          else static if (is(FT == string)) __traits(getMember, obj, field) = jv.str;
          else static if (is(FT == string[])) {
            string[] arr;
            foreach (ref e; jv.array)
              arr ~= e.str;
            __traits(getMember, obj, field) = arr;
          }
          else static if (is(FT == Color))  __traits(getMember, obj, field) = toColor(jv);
          else static if (is(FT == enum))   __traits(getMember, obj, field) = cast(FT)jv.integer;
          else static if (is(FT == Vector3))__traits(getMember, obj, field) = toVec3(jv);
        }
      }
    }
  }
  static if (is(T : IExtraSerializable))
    obj.deserializeExtra(fields);
}


// components

private JSONValue serializeComponent(Component c) {
  static foreach (T; KnownComponents) {
    if (auto t = cast(T)c) {
      return JSONValue([
                        "type":    JSONValue(T.typeName),
                        "enabled": JSONValue(c.enabled),
                        "fields":  serializeFields(t),
                        ]);
    }
  }

  assert(false, "Unknown component: " ~ c.name);
}

private Component deserializeComponent(JSONValue j, GameObject owner) {
  immutable type = j["type"].str;
  static foreach (T; KnownComponents) {
    if (T.typeName == type) {
      auto c  = new T();
      c.owner   = owner;
      c.enabled = j["enabled"].boolean;
      deserializeFields(c, j["fields"]);
      return c;
    }
  }

  assert(false, "Unknown component type in scene file: " ~ type);
}


// transform

private JSONValue serializeVec3(Vector3 v) {
  return JSONValue(["x": JSONValue(v.x), "y": JSONValue(v.y), "z": JSONValue(v.z)]);
}

private JSONValue serializeQuat(Quaternion q) {
  return JSONValue(["x": JSONValue(q.x), "y": JSONValue(q.y),
                    "z": JSONValue(q.z), "w": JSONValue(q.w)]);
}

private Vector3 toVec3(JSONValue j) {
  return Vector3(cast(float)j["x"].floating,
                 cast(float)j["y"].floating,
                 cast(float)j["z"].floating);
}

private Quaternion toQuat(JSONValue j) {
  return Quaternion(cast(float)j["x"].floating,
                    cast(float)j["y"].floating,
                    cast(float)j["z"].floating,
                    cast(float)j["w"].floating);
}

private JSONValue serializeTransform(ref const Transform t) {
  return JSONValue(["position": serializeVec3(t.localPosition),
                    "rotation": serializeQuat(t.localRotation),
                    "scale":    serializeVec3(t.localScale),
                    ]);
}

private void applyTransform(ref Transform t, JSONValue j) {
  t.localPosition = toVec3(j["position"]);
  t.localRotation = toQuat(j["rotation"]);
  t.localScale    = toVec3(j["scale"]);
}


// transform

private JSONValue serializeTransform(Transform t) {
  JSONValue[] children;
  foreach (child; t.children)
    children ~= serializeTransform(child);

  JSONValue[] comps;
  foreach (c; t.gameObject.components)
    comps ~= serializeComponent(c);

  return JSONValue(["name":       JSONValue(t.gameObject.name),
                    "active":     JSONValue(t.gameObject.active),
                    "position":   serializeVec3(t.localPosition),
                    "rotation":   serializeQuat(t.localRotation),
                    "scale":      serializeVec3(t.localScale),
                    "components": JSONValue(comps),
                    "children":   JSONValue(children),
                    ]);
}

private Transform deserializeTransform(JSONValue j, Transform parent = null) {
  auto go       = new GameObject();
  go.name       = j["name"].str;
  go.active     = j["active"].boolean;
  // go.transform is created by GameObject ctor, grab the reference
  auto t        = go.transform;
  t.localPosition = toVec3(j["position"]);
  t.localRotation = toQuat(j["rotation"]);
  t.localScale    = toVec3(j["scale"]);

  if (parent !is null)
    parent.addChild(t, false); // local coords already set, no world roundtrip

  foreach (cj; j["components"].array)
    go.components ~= deserializeComponent(cj, go);

  foreach (childJ; j["children"].array)
    deserializeTransform(childJ, t);

  return t;
}

// helpers

private JSONValue serializeColor(Color c) {
  return JSONValue(["r": JSONValue(c.r), "g": JSONValue(c.g),
                    "b": JSONValue(c.b), "a": JSONValue(c.a)]);
}

private Color toColor(JSONValue j) {
  return Color(cast(ubyte)j["r"].integer,
               cast(ubyte)j["g"].integer,
               cast(ubyte)j["b"].integer,
               cast(ubyte)j["a"].integer);
}
