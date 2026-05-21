module engine.manifest;

import std.json;
import std.algorithm : cmp, map, max;
import std.array : array;
import std.conv : to;
import std.string : split;
import std.range : zip;

class Manifest {
public:
  string projectName;
  string projectVersion;

  this(string json) {
    JSONValue parsed = parseJSON(json);
    this.projectName    = parsed["name"].str;
    this.projectVersion = parsed["version"].str;
  }

  string asJson() {
    JSONValue j = ["name": JSONValue(projectName), "version": JSONValue(projectVersion)];
    return j.toString();
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
