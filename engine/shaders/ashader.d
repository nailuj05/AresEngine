module engine.shaders.ashader;

import std.string;
import std.array;
import std.conv;

import raylib;

enum UniformOwner { Engine, Material }
enum UniformType  { Float, Vec2, Vec3, Vec4, Int, Sampler2D, Mat4 }

struct UniformMeta {
  string label;
  float  min = 0.0f;
  float  max = 1.0f;
}

struct ShaderUniform {
  string       name;
  int          loc  = -1;
  UniformType  type;
  UniformOwner owner;
  float[4]     data = 0;
  UniformMeta  meta;
}

// mat4 uniforms are always engine-owned and uploaded via SetShaderValueMatrix
struct MatrixUniform {
  string name;
  int    loc = -1;
}

struct ParsedShader {
  string          versionLine;
  ShaderUniform[] uniforms;  // float/vec/int/sampler, uploaded via SetShaderValue
  MatrixUniform[] matrices;  // mat4, uploaded via SetShaderValueMatrix
  string          vertSource;
  string          fragSource;
}

ParsedShader parseAShader(string src) {
  ParsedShader result;

  Appender!string shared_;
  Appender!string vert;
  Appender!string frag;
  Appender!string varyingOuts;
  Appender!string varyingIns;

  enum State { Top, Vertex, Fragment }
  State state = State.Top;

  foreach (rawLine; src.lineSplitter) {
    string line = rawLine.strip;

    if (line.startsWith("#version")) {
      result.versionLine = line;
      continue;
    }

    if (line.startsWith("@uniform")) {
      auto tokens = parseUniformLine(line);

      if (tokens.type == UniformType.Mat4) {
        MatrixUniform m;
        m.name = tokens.name;
        result.matrices ~= m;
      } else {
        result.uniforms ~= tokens;
      }

      string gl = "uniform " ~ typeToGLSL(tokens.type) ~ " " ~ tokens.name ~ ";";
      final switch (state) {
      case State.Top:      shared_.put(gl ~ "\n"); break;
      case State.Vertex:   vert.put(gl ~ "\n");    break;
      case State.Fragment: frag.put(gl ~ "\n");    break;
      }
      continue;
    }

    if (line.startsWith("@varying")) {
      string decl = line["@varying".length .. $].strip;
      varyingOuts.put("out " ~ decl ~ "\n");
      varyingIns.put("in "  ~ decl ~ "\n");
      continue;
    }

    if (line == "@vertex")   { state = State.Vertex;   continue; }
    if (line == "@fragment") { state = State.Fragment;  continue; }

    final switch (state) {
    case State.Top:      shared_.put(rawLine ~ "\n"); break;
    case State.Vertex:   vert.put(rawLine ~ "\n");    break;
    case State.Fragment: frag.put(rawLine ~ "\n");    break;
    }
  }

  string header     = result.versionLine ~ "\n" ~ shared_.data;
  result.vertSource = header ~ varyingOuts.data ~ vert.data;
  result.fragSource = header ~ varyingIns.data  ~ frag.data;
  return result;
}

// Returns a ShaderUniform with name/type/owner/meta filled; caller checks type for Mat4
private ShaderUniform parseUniformLine(string line) {
  ShaderUniform u;

  auto parenOpen  = line.indexOf('(');
  auto parenClose = line.indexOf(')');
  assert(parenOpen != -1 && parenClose != -1, "Malformed @uniform: " ~ line);

  string params = line[parenOpen + 1 .. parenClose];
  string rest   = line[parenClose + 1 .. $].strip;

  auto parts = params.split(',');
  u.owner = parts[0].strip == "engine" ? UniformOwner.Engine : UniformOwner.Material;

  foreach (part; parts[1 .. $]) {
    auto eq = part.indexOf('=');
    if (eq == -1) continue;
    string k = part[0 .. eq].strip;
    string v = part[eq + 1 .. $].strip;
    if (v.length >= 2 && v[0] == '"' && v[$-1] == '"')
      v = v[1 .. $-1];
    if      (k == "label") u.meta.label = v;
    else if (k == "min")   u.meta.min   = v.to!float;
    else if (k == "max")   u.meta.max   = v.to!float;
  }

  auto tokens = rest.split;
  assert(tokens.length >= 2, "Malformed @uniform type/name: " ~ rest);
  u.type = parseType(tokens[0]);
  string name = tokens[1];
  if (name.endsWith(";")) name = name[0 .. $-1];
  u.name = name;
  if (u.meta.label.length == 0) u.meta.label = u.name;
  return u;
}

private UniformType parseType(string t) {
  switch (t) {
  case "float":     return UniformType.Float;
  case "vec2":      return UniformType.Vec2;
  case "vec3":      return UniformType.Vec3;
  case "vec4":      return UniformType.Vec4;
  case "int":       return UniformType.Int;
  case "sampler2D": return UniformType.Sampler2D;
  case "mat4":      return UniformType.Mat4;
  default: assert(false, "Unknown uniform type: " ~ t);
  }
}

string typeToGLSL(UniformType t) {
  final switch (t) {
  case UniformType.Float:     return "float";
  case UniformType.Vec2:      return "vec2";
  case UniformType.Vec3:      return "vec3";
  case UniformType.Vec4:      return "vec4";
  case UniformType.Int:       return "int";
  case UniformType.Sampler2D: return "sampler2D";
  case UniformType.Mat4:      return "mat4";
  }
}

// -1 for Mat4 
int toRaylibUniformType(UniformType t) {
  final switch (t) {
  case UniformType.Float:     return ShaderUniformDataType.SHADER_UNIFORM_FLOAT;
  case UniformType.Vec2:      return ShaderUniformDataType.SHADER_UNIFORM_VEC2;
  case UniformType.Vec3:      return ShaderUniformDataType.SHADER_UNIFORM_VEC3;
  case UniformType.Vec4:      return ShaderUniformDataType.SHADER_UNIFORM_VEC4;
  case UniformType.Int:       return ShaderUniformDataType.SHADER_UNIFORM_INT;
  case UniformType.Sampler2D: return ShaderUniformDataType.SHADER_UNIFORM_SAMPLER2D;
  case UniformType.Mat4:      return -1;
  }
}
