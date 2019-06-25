library gol;

import 'package:chronosgl/chronosgl.dart';
import 'package:vector_math/vector_math.dart' as VM;
import 'dart:typed_data';

import 'dart:math';

// We only use the first 2*9 entries
// the first 9 are for [0-8] live neighbours with the center dead
// the second 9 are for [0-8] live neighbours with the center alive
// rounded to next power of two
const int kNumRules = 32;

final int kLiveThreshold = -5;

const String uRules = "uRules";
const String uState = "uState";
const String uScaleSize = "uScaleSize";
const String uUVRepeats = "uUVRepeats";

void RegisterShaderVars() {
  IntroduceNewShaderVar(uRules, ShaderVarDesc(VarTypeSampler2D, ""));
  IntroduceNewShaderVar(uState, ShaderVarDesc(VarTypeSampler2D, ""));
  IntroduceNewShaderVar(uScaleSize, ShaderVarDesc(VarTypeVec2, ""));
  IntroduceNewShaderVar(uUVRepeats, ShaderVarDesc(VarTypeVec2, ""));
}

// The vertex shader received a unit square
// The fragment shader uses pixel coordinates
final ShaderObject lifeStateVertexShader = ShaderObject("GOL-Vertex")
  ..AddAttributeVars([aPosition])
  ..SetBodyWithMain(["gl_Position = vec4(${aPosition}.xy, 0, 1.0);"]);

final ShaderObject lifeStateFragmentShader = ShaderObject("GOL-Fragment")
  ..AddUniformVars([uRules, uState])
  ..SetBody([
    """
int xget(ivec2 pos) {
    return texelFetch(${uState}, pos, 0).r > 0.0 ? 1 : 0;
}

int NumLiveNeighbors() {
    ivec2 p = ivec2(gl_FragCoord.xy);
    // ivec2 p = ivec2(gl_FragCoord.xy);
    return
        xget(p + ivec2(-1, -1)) +
        xget(p + ivec2(-1,  0)) +
        xget(p + ivec2(-1,  1)) +
        xget(p + ivec2( 0, -1)) +
        9 * xget(p + ivec2( 0, 0)) +
        xget(p + ivec2( 0,  1)) +
        xget(p + ivec2( 1, -1)) +
        xget(p + ivec2( 1,  0)) +
        xget(p + ivec2( 1,  1));
}


vec4 GetColor(int sum) {
  return texelFetch(${uRules}, ivec2(sum, 0), 0);
}

void main() {
    int sum = NumLiveNeighbors();
    ${oFragColor}.r = GetColor(sum).r;
    ${oFragColor}.g = float(sum) / 32.0;
}
"""
  ]);

final ShaderObject lifeVertexShader = ShaderObject("GOL-Vertex")
  ..AddAttributeVars([aPosition])
  ..AddVaryingVars([vTexUV])
  ..SetBodyWithMain(["gl_Position = vec4(${aPosition}.xy, 0, 1.0);"]);

final ShaderObject lifeFragmentShader = ShaderObject("GOL-Fragment")
  ..AddUniformVars([uRules, uState, uScaleSize])
  ..AddVaryingVars([vTexUV])
  ..SetBody([
    """
int get(vec2 offset) {
    vec2 uv = (gl_FragCoord.xy + offset) / ${uScaleSize};
    return texture(${uState}, uv).r > 0.0 ? 1 : 0;
}

int NumLiveNeighbors() {
    return
        get(vec2(-1.0, -1.0)) +
        get(vec2(-1.0,  0.0)) +
        get(vec2(-1.0,  1.0)) +
        get(vec2( 0.0, -1.0)) +
        9 * get(vec2( 0.0, 0.0)) +
        get(vec2( 0.0,  1.0)) +
        get(vec2( 1.0, -1.0)) +
        get(vec2( 1.0,  0.0)) +
        get(vec2( 1.0,  1.0));
}

vec4 GetColor(int sum) {
  return texelFetch(${uRules}, ivec2(sum, 0), 0);
}

void main() {
    int sum = NumLiveNeighbors();
    //int sum =  int(32.0 * texture(${uState}, ${vTexUV}).r);
    //vec2 uv = gl_FragCoord.xy / ${uScaleSize};
    //int sum =  int(texture(${uState}, uv).g * 32.0);
    ${oFragColor} = GetColor(sum);
}
"""
  ]);

void set(Uint8List l, int p, int mul, List<int> color) {
  l[p * 4 + 0] = mul * color[0] ~/ 255;
  l[p * 4 + 1] = mul * color[1] ~/ 255;
  l[p * 4 + 2] = mul * color[2] ~/ 255;
  l[p * 4 + 3] = 255;
}

Uint8List SetPaletteRegular(List<int> fg, List<int> bg) {
  var r = Uint8List(kNumRules * 4);
  for (int i = 0; i < kNumRules; i++) {
    set(r, i, 256, bg);
  }

  set(r, 1, 0x40, fg);
  set(r, 2, 0x60, fg);
  set(r, 3, 0x80, fg);
  set(r, 4, 0xa0, fg);
  set(r, 5, 0xc0, fg);
  set(r, 6, 0xe0, fg);
  set(r, 7, 0xe0, fg);
  set(r, 8, 0xff, fg);

  set(r, 9, 0x40, fg);
  set(r, 10, 0x60, fg);
  set(r, 11, 0x80, fg);
  set(r, 12, 0xa0, fg);
  set(r, 13, 0xc0, fg);
  set(r, 14, 0xe0, fg);
  set(r, 15, 0xff, fg);

  set(r, 16, 0xff, fg);
  set(r, 17, 0xff, fg);
  return r;
}

const int ALIVE = 9;

Uint8List SetPaletteOutline(List<int> fg, List<int> bg) {
  var r = Uint8List(kNumRules * 4);
  for (int i = 0; i < kNumRules; i++) {
    set(r, i, 256, bg);
  }
  set(r, 3, 256, fg); // lines (outside)
  set(r, ALIVE + 3, 256, fg); // corner (inside)
  return r;
}

Uint8List SetPaletteBlur2(List<int> fg, List<int> bg) {
  var r = Uint8List(kNumRules * 4);
  for (int i = 0; i < kNumRules; i++) {
    set(r, i, 256, bg);
  }
  set(r, ALIVE + 4, 0xff, fg);
  set(r, ALIVE + 5, 0xf0, fg);
  set(r, ALIVE + 6, 0xe0, fg);
  set(r, ALIVE + 7, 0xd0, fg);
  set(r, ALIVE + 8, 0xc0, fg);
  return r;
}

Uint8List SetPaletteBlur3(List<int> fg, List<int> bg) {
  var r = Uint8List(kNumRules * 4);
  for (int i = 0; i < kNumRules; i++) {
    set(r, i, 256, bg);
  }

  set(r, ALIVE + 0, 0x20, fg);
  set(r, ALIVE + 1, 0x40, fg);
  set(r, ALIVE + 2, 0x60, fg);
  set(r, ALIVE + 3, 0x80, fg);
  set(r, ALIVE + 4, 0xa0, fg);
  set(r, ALIVE + 5, 0xc0, fg);
  set(r, ALIVE + 6, 0xe0, fg);
  set(r, ALIVE + 7, 0xff, fg);
  return r;
}

Uint8List SetPaletteMono(List<int> fg, List<int> bg) {
  var r = Uint8List(kNumRules * 4);
  for (int i = 0; i < kNumRules; i++) {
    set(r, i, 256, bg);
  }
  for (int i = ALIVE; i < ALIVE + 9; i++) {
    set(r, i, 256, fg);
  }
  return r;
}

TypedTextureMutable MakeStateTexture(
        String name, ChronosGL cgl, int w, int h, bool wrapped) =>
    TypedTextureMutable(
        cgl,
        name,
        w,
        h,
        GL_RGBA,
        wrapped
            ? TexturePropertiesFramebufferWrapped
            : TexturePropertiesFramebuffer,
        GL_RGBA,
        GL_UNSIGNED_BYTE,
        null);

class Life {
  Life(ChronosGL cgl, this._w, this._h, this._scale, bool wrapped)
      : _rules = TypedTextureMutable(cgl, "rules", kNumRules, 1, GL_RGBA,
            TexturePropertiesFramebuffer, GL_RGBA, GL_UNSIGNED_BYTE, null),
        _palette = TypedTextureMutable(cgl, "palette", kNumRules, 1, GL_RGBA,
            TexturePropertiesFramebuffer, GL_RGBA, GL_UNSIGNED_BYTE, null),
        _states = [
          MakeStateTexture("s0", cgl, _w, _h, wrapped),
          MakeStateTexture("s1", cgl, _w, _h, wrapped),
        ] {
    _fbs = [Framebuffer(cgl, _states[0]), Framebuffer(cgl, _states[1])];

    _uniformsCompute = UniformGroup("compute")..SetUniform(uRules, _rules);

    _uniformsDraw = UniformGroup("compute")
      ..SetUniform(uRules, _palette)
      ..SetUniform(
          uScaleSize, VM.Vector2(_w * _scale + 0.0, _h * _scale + 0.0));

    _programState = RenderProgram(
        "life", cgl, lifeStateVertexShader, lifeStateFragmentShader);
    _program = RenderProgram("life", cgl, lifeVertexShader, lifeFragmentShader);
    _unit = ShapeQuad(_program, 1);
  }

  final int _scale;
  final int _w;
  final int _h;
  final TypedTextureMutable _rules;
  final TypedTextureMutable _palette;
  final List<TypedTextureMutable> _states;

  List<Framebuffer> _fbs;
  RenderProgram _program;
  RenderProgram _programState;

  UniformGroup _uniformsCompute;
  UniformGroup _uniformsDraw;
  MeshData _unit;

  int _round = 0;

  void Step(bool stir, Random rng) {
    TypedTextureMutable src = _states[(1 + _round) % 2];
    _uniformsDraw.ForceUniform(uState, src);
    _uniformsCompute.ForceUniform(uState, src);
    if (stir) {
      StirBorder(src, rng);
    }
    Framebuffer fb = _fbs[_round % 2];
    fb.Activate(GL_CLEAR_ALL, 0, 0, _w, _h);
    _programState.Draw(_unit, [_uniformsCompute]);
    ++_round;
  }

  void DrawToScreen() {
    _program.Draw(_unit, [_uniformsDraw]);
  }

  void SetRandom(Random rng, int percent) {
    Uint8List rgba = Uint8List(_w * _h * 4);
    for (var i = 0; i < _w * _h * 4; i += 4) {
      rgba[i + 0] = rng.nextInt(100) < percent ? kLiveThreshold : 0;
      rgba[i + 1] = 0;
      rgba[i + 2] = 0;
      rgba[i + 3] = 255;
    }
    LogInfo("Updating textures with random data ${_w} ${_h}");
    _states[0].UpdateContent(rgba, GL_RGBA, GL_UNSIGNED_BYTE);
    _states[1].UpdateContent(rgba, GL_RGBA, GL_UNSIGNED_BYTE);
  }

  void SetRules(Random rng, String s) {
    List<int> dead = [0, 0, 0];
    List<int> live = [255, 255, 255];
    var r = Uint8List(kNumRules * 4);
    for (int i = 0; i < kNumRules; i++) {
      set(r, i, 0x80, dead);
    }
    if (s == "random") {
      List<bool> rule = List.filled(kNumRules, false);
      for (int i = 0; i < kNumRules; i++) {
        if (rng.nextBool()) {
          rule[i] = true;
          set(r, i, 0x80, live);
        }
      }
      StringBuffer sb = StringBuffer();
      for (int i = 0; i < 9; i++) {
        if (rule[i + 9]) sb.writeCharCode(48 + i);
      }
      sb.write("/");
      for (int i = 0; i < 9; i++) {
        if (rule[i]) sb.writeCharCode(48 + i);
      }
      print("rule ${sb.toString()}");
    } else {
      int base = 9;
      for (int i = 0; i < s.length; i++) {
        String x = s[i];
        if (x == "/") {
          base = 0;
        }
        if (RegExp(r"[0-8]").hasMatch(x)) {
          set(r, base + int.parse(x), 0x80, live);
        }
      }
    }
    _rules.UpdateContent(r, GL_RGBA, GL_UNSIGNED_BYTE);
  }

  void SetPalette(String mode, List<int> fg, List<int> bg) {
    Uint8List r;
    switch (mode) {
      case "Outline":
        r = SetPaletteOutline(fg, bg);
        break;
      case "Mono":
        r = SetPaletteMono(fg, bg);
        break;
      case "Blur2":
        r = SetPaletteBlur2(fg, bg);
        break;
      case "Blur3":
        r = SetPaletteBlur3(fg, bg);
        break;
      default:
        r = SetPaletteRegular(fg, bg);
        break;
    }
    _palette.UpdateContent(r, GL_RGBA, GL_UNSIGNED_BYTE);
  }

  void StirBorder(TypedTextureMutable tex, Random rng) {
    List<int> dead = [0, 0, 0];
    List<int> live = [255, 255, 255];
    var rgbaw = Uint8List(_w * 4);
    for (int i = 0; i < _w; i++) {
      if (rng.nextBool()) {
        set(rgbaw, i, 0, dead);
      } else {
        set(rgbaw, i, 0x80, live);
      }
    }
    tex.UpdateContentPartial(rgbaw, GL_RGBA, GL_UNSIGNED_BYTE, 0, 0, _w, 1);
    tex.UpdateContentPartial(
        rgbaw, GL_RGBA, GL_UNSIGNED_BYTE, 0, _h - 1, _w, 1);

    var rgbah = Uint8List(_h * 4);
    for (int i = 0; i < _h; i++) {
      if (rng.nextBool()) {
        set(rgbah, i, 0, dead);
      } else {
        set(rgbah, i, 0x80, live);
      }
    }
    tex.UpdateContentPartial(rgbah, GL_RGBA, GL_UNSIGNED_BYTE, 0, 0, 1, _h);
    tex.UpdateContentPartial(
        rgbah, GL_RGBA, GL_UNSIGNED_BYTE, _w - 1, 0, 1, _h);
  }
}

final ShaderObject texturedVertexShaderWithRepeats = ShaderObject("Textured")
  ..AddAttributeVars([aPosition, aTexUV])
  ..AddUniformVars([uPerspectiveViewMatrix, uModelMatrix])
  ..AddVaryingVars([vTexUV])
  ..SetBody([
    """
void main() {
  gl_Position = ${uPerspectiveViewMatrix} * 
                ${uModelMatrix} * 
                vec4(${aPosition}, 1.0);
  ${vTexUV} = ${aTexUV};
}
"""
  ]);

final ShaderObject texturedFragmentShaderWithRepeats = ShaderObject("TexturedF")
  ..AddVaryingVars([vTexUV])
  ..AddUniformVars([uColor, uTexture, uUVRepeats])
  ..SetBodyWithMain([
    """
    vec2 uv = mod(${vTexUV} * ${uUVRepeats}, vec2(1.0, 1.0));
    //vec2 uv = ${vTexUV} * ${uUVRepeats};
    ${oFragColor} = texture(${uTexture}, uv) + vec4( ${uColor}, 0.0 );
    """
  ]);
