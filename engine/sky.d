module engine.sky;

import std.math;
import std.string;

import raylib;

struct SkyGradient {
  Shader shader;

  private int invViewLoc;
  private int topColorLoc;
  private int bottomColorLoc;
  private int screenSizeLoc;
  private int aspectLoc;
  private int tanHalfFovLoc;

  static immutable string fragmentShader = q{
#version 330

    out vec4 fragColor;

    uniform mat4 invView;
    uniform vec3 topColor;
    uniform vec3 bottomColor;
    uniform vec2 screenSize;
    uniform float aspect;
    uniform float tanHalfFov;

    void main()
    {
      vec2 uv = gl_FragCoord.xy / screenSize;
      vec2 ndc = uv * 2.0 - 1.0;

      vec3 rayView = normalize(vec3(
                                    ndc.x * aspect * tanHalfFov,
                                    ndc.y * tanHalfFov,
                                    -1.0
                                    ));

      vec3 rayWorld = normalize((invView * vec4(rayView, 0.0)).xyz);

      float t = clamp(rayWorld.y * 0.5 + 0.5, 0.0, 1.0);

      fragColor = vec4(mix(bottomColor, topColor, t), 1.0);
    }
  };

  void init()
  {
    shader = LoadShaderFromMemory(null, fragmentShader.toStringz());
    assert(shader.id != 0);

    invViewLoc     = GetShaderLocation(shader, "invView");
    topColorLoc    = GetShaderLocation(shader, "topColor");
    bottomColorLoc = GetShaderLocation(shader, "bottomColor");
    screenSizeLoc  = GetShaderLocation(shader, "screenSize");
    aspectLoc      = GetShaderLocation(shader, "aspect");
    tanHalfFovLoc  = GetShaderLocation(shader, "tanHalfFov");
  }

  void unload()
  {
    UnloadShader(shader);
  }

  void draw(Camera3D camera, int width, int height, Color top, Color bottom)
  {
    Matrix invView = MatrixInvert(GetCameraMatrix(camera));

    SetShaderValueMatrix(shader, invViewLoc, invView);

    float[3] topF = [
                     top.r / 255.0f,
                     top.g / 255.0f,
                     top.b / 255.0f
                     ];

    float[3] bottomF = [
                        bottom.r / 255.0f,
                        bottom.g / 255.0f,
                        bottom.b / 255.0f
                        ];

    SetShaderValue(shader, topColorLoc, topF.ptr, ShaderUniformDataType.SHADER_UNIFORM_VEC3);
    SetShaderValue(shader, bottomColorLoc, bottomF.ptr, ShaderUniformDataType.SHADER_UNIFORM_VEC3);

    float[2] screenSize = [
                           cast(float)width,
                           cast(float)height
                           ];

    SetShaderValue(shader, screenSizeLoc, screenSize.ptr, ShaderUniformDataType.SHADER_UNIFORM_VEC2);

    float aspect = screenSize[0] / screenSize[1];
    float tanHalfFov = tan(camera.fovy * DEG2RAD * 0.5f);

    SetShaderValue(shader, aspectLoc, &aspect, ShaderUniformDataType.SHADER_UNIFORM_FLOAT);
    SetShaderValue(shader, tanHalfFovLoc, &tanHalfFov, ShaderUniformDataType.SHADER_UNIFORM_FLOAT);

    BeginShaderMode(shader);
    DrawRectangle(0, 0, width, height, Colors.WHITE);
    EndShaderMode();
  }
}
