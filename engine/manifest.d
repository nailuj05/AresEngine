module engine.manifest;

import std.json;
import std.conv      : to;
import std.range     : zip;
import std.string    : split;
import std.typecons  : tuple;
import std.algorithm : cmp, map, max;
import std.array     : array , assocArray;

struct Manifest {
  string projectName;
  string projectVersion;

  string[string] projectScenes;

  int resolutionX = 600;
  int resolutionY = 400;

  bool fullscreen = false; 

  int targetFPS   = 60;

  this(string json) {
    JSONValue parsed = parseJSON(json);

    this.projectName    = parsed["name"].str;
    this.projectVersion = parsed["version"].str;
    this.resolutionX    = cast(int)parsed["resX"].integer;
    this.resolutionY    = cast(int)parsed["resY"].integer;
    this.fullscreen     = parsed["fullscreen"].boolean;
    this.targetFPS      = cast(int)parsed["targetFPS"].integer;

    foreach (k, v; parsed["scenes"].object)
        this.projectScenes[k] = v.str;
  }

  string toString() {
    JSONValue j = [
      "name":       JSONValue(projectName),
      "version":    JSONValue(projectVersion),
      "scenes":     JSONValue(projectScenes),
      "resX":       JSONValue(resolutionX),
      "resY":       JSONValue(resolutionY),
      "fullscreen": JSONValue(fullscreen),
      "targetFPS":  JSONValue(targetFPS),
    ];
    return j.toPrettyString();
  }
}

int compareVersion(string v1, string v2) {
  auto a = v1.split(".").map!(s => s.to!int).array;
  auto b = v2.split(".").map!(s => s.to!int).array;

  foreach (i; 0 .. max(a.length, b.length)) {
    int x = (i < a.length) ? a[i] : 0;
    int y = (i < b.length) ? b[i] : 0;

    if (x < y) return -1;
    if (x > y) return 1;
  }

  return 0;
}

// dmd -unittest -main mainfest.d && ./manifest
unittest {
  assert(compareVersion("1.2.0", "1.2") == 0);
  assert(compareVersion("1.2.1", "1.2") > 0);
  assert(compareVersion("1.2", "1.2.1") < 0);
  assert(compareVersion("2.0", "1.9.9") > 0);
}
