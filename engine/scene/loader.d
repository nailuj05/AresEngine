module engine.scene.loader;

import std.json;
import std.stdio  : writeln;
import std.file   : readText, write;
import std.traits : FieldNameTuple, Unqual, hasUDA;

import raylib : Vector3, Quaternion;

import engine.scene.scene;
import engine.core.gameobject;
import engine.core.component;
import engine.core.transform;

// public API

void saveScene(Scene scene, string path) {
  JSONValue[] roots;
  foreach(go; scene.roots)
    roots ~= serializeGO(go);

  write(path, JSONValue(["name": JSONValue(scene.name), "roots": JSONValue(roots)]).toPrettyString());
}

Scene loadScene(string path) {
  JSONValue jsonT;
  try {
    jsonT = parseJSON(readText(path));
  } catch (Exception e) {
    writeln("Failure opening scene");
    return null;
  }

  auto scene = new Scene(jsonT["name"].str);
  
  foreach (goJson; jsonT["roots"].array) {
    scene.roots ~= deserializeGO(goJson);
  }

  return scene;
}


// fields

private JSONValue serializeFields(T)(T obj) {
  JSONValue result = JSONValue((JSONValue[string]).init);
  static foreach (field; FieldNameTuple!(Unqual!T)) {
    {
      enum prot = __traits(getProtection, __traits(getMember, Unqual!T, field));
      static if (prot == "public" && !hasUDA!(__traits(getMember, Unqual!T, field), DontSerialize)) {
        alias FT = typeof(__traits(getMember, obj, field));
        auto  v  = __traits(getMember, obj, field);

        static if      (is(FT == bool))    result[field] = JSONValue(v);
        else static if (is(FT == float))   result[field] = JSONValue(v);
        else static if (is(FT == string))  result[field] = JSONValue(v);
        // fail here
      }
    }
  }
  return result;
}

private void deserializeFields(T)(T obj, JSONValue fields) {
  static foreach (field; FieldNameTuple!(Unqual!T)) {
    {
      enum prot = __traits(getProtection, __traits(getMember, Unqual!T, field));
      static if (prot == "public" && !hasUDA!(__traits(getMember, Unqual!T, field), DontSerialize)) {
        alias FT = typeof(__traits(getMember, obj, field));
        if (auto p = field in fields.object) {
          auto jv = *p;
          static if      (is(FT == bool))   __traits(getMember, obj, field) = jv.boolean;
          else static if (is(FT == float))  __traits(getMember, obj, field) = jv.floating;
          else static if (is(FT == string)) __traits(getMember, obj, field) = jv.str;
        }
      }
    }
  }
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
    return Vector3(
                   cast(float)j["x"].floating,
                   cast(float)j["y"].floating,
                   cast(float)j["z"].floating);
  }

  private Quaternion toQuat(JSONValue j) {
    return Quaternion(
                      cast(float)j["x"].floating,
                      cast(float)j["y"].floating,
                      cast(float)j["z"].floating,
                      cast(float)j["w"].floating);
  }

  private JSONValue serializeTransform(ref const Transform t) {
    return JSONValue([
                      "position": serializeVec3(t.position),
                      "rotation": serializeQuat(t.rotation),
                      "scale":    serializeVec3(t.scale),
                      ]);
  }

  private void applyTransform(ref Transform t, JSONValue j) {
    t.position = toVec3(j["position"]);
    t.rotation = toQuat(j["rotation"]);
    t.scale    = toVec3(j["scale"]);
  }


  // gameobject

  private JSONValue serializeGO(GameObject go) {
    JSONValue[] comps;
    foreach (c; go.components)
      comps ~= serializeComponent(c);

    JSONValue[] children;
    foreach (child; go.children) {
      children ~= serializeGO(child);
    }

    return JSONValue([
                      "name":       JSONValue(go.name),
                      "active":     JSONValue(go.active),
                      "transform":  serializeTransform(go.transform),
                      "components": JSONValue(comps),
                      "children":   JSONValue(children),
                      ]);
  }

  private GameObject deserializeGO(JSONValue j) {
    auto go   = new GameObject();
    go.name   = j["name"].str;
    go.active = j["active"].boolean;
    applyTransform(go.transform, j["transform"]);

    foreach (cj; j["components"].array) {
      go.components ~= deserializeComponent(cj, go);
    }

    foreach (childJ; j["children"].array) {
      auto child = deserializeGO(childJ);
      go.children ~= child;
    }

    return go;
  }
