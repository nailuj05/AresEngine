module engine.core.iextraserializable;
import std.json;

interface IExtraSerializable {
  JSONValue serializeExtra();
  void deserializeExtra(JSONValue fields);
}
