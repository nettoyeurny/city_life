/*
Copyright Robert Muth <robert@muth.org>

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; version 3
of the License.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
*/

/*
This file contains code to generate textures for facades.
We avoid using Canvas as much as possible so that this code
could be used outside of the browser
*/

library facade;

import 'dart:html' as HTML;
import 'dart:math' as Math;

import 'package:chronosgl/chronosgl.dart' as CGL;
import 'package:vector_math/vector_math.dart' as VM;

import 'config.dart';
import 'logging.dart' as log;
import 'rgb.dart';
import 'theme.dart' as THEME;

int defaultAnisoLevel = 1;

const String uWindowDim = "uWindowDim";
const String uAverageFurnitureW = "uAverageFurnitureW";
const String uMaxFurnitureH = "uMaxFurnitureH";
const String uFeatures = "uFeatures";
const String uWindowFrame = "uWindowFrame";
const String uRandSeed = "uRandSeed";

void IntroduceShaderVars() {
  CGL.IntroduceNewShaderVar(uRandSeed, CGL.ShaderVarDesc("float", ""));
  CGL.IntroduceNewShaderVar(uWindowDim, CGL.ShaderVarDesc("vec2", ""));
  CGL.IntroduceNewShaderVar(uWindowFrame, CGL.ShaderVarDesc("vec3", ""));
  CGL.IntroduceNewShaderVar(uAverageFurnitureW, CGL.ShaderVarDesc("float", ""));
  CGL.IntroduceNewShaderVar(uMaxFurnitureH, CGL.ShaderVarDesc("float", ""));
  CGL.IntroduceNewShaderVar(uFeatures, CGL.ShaderVarDesc("int", ""));
}

final CGL.ShaderObject facadeVertexShader = CGL.ShaderObject("facadeV")
  ..AddAttributeVars([CGL.aPosition])
  ..SetBody([CGL.NullVertexShaderString]);

// https://www.khronos.org/opengl/wiki/Built-in_Variable_(GLSL)#Fragment_shader_inputs
final CGL.ShaderObject facadeFragmentShader = CGL.ShaderObject("facadeF")
  ..AddUniformVars([
    uWindowDim,
    uAverageFurnitureW,
    uMaxFurnitureH,
    uFeatures,
    CGL.uColor,
    uWindowFrame,
    uRandSeed,
  ])
  ..SetBody([
    """
    
const float spice1 = 1.0;
const float spice2 = 2.0;
const float spice3 = 4.0;
const float spice4 = 4.0;
const float spice5 = 5.0;
const float spice6 = 6.0;

float rand(vec2 co){
     return fract(sin(dot(co.xy, vec2(12.9898,78.233))) * (${uRandSeed} + 43758.5453));
}

float featureStart(float offset, vec2 salt) {
  float newFeatureProb = 2.0 / ${uAverageFurnitureW};
  float minFeatureWidth = floor(${uAverageFurnitureW} / 3.0);
  float start = 0.0;
  for (float i = 0.0; i < offset; i += 1.0) {
       if (rand(i * salt) < newFeatureProb) {
           start = i;
           i += minFeatureWidth;
       } 
  }
  return start;
}

float furnitureAlpha(vec2 offset, vec2 salt) {
    float h = ${uMaxFurnitureH} * rand(salt * spice1);
    if (offset.y >= h) return 1.0;
     
    float alpha1 = 0.5;
    float alpha2 =  0.25 + 0.25 * rand(salt * spice2);
    return 1.0 - mix(alpha1, alpha2, offset.y / h);
}


const float frame = 0.5;

bool isWindow(vec2 offset, float left, float bottom, float top) {
  return 
        offset.x >= left &&
        offset.y >= bottom &&
        offset.x <= ${uWindowDim}.x - left && 
        offset.y <= ${uWindowDim}.y - top;
}

bool isVerticalSplit(vec2 offset, float left) {
    float middle = ${uWindowDim}.x / 2.0;
    return offset.x >= middle - left && offset.x < middle + left; 
}

bool isHorizontalSplit(vec2 offset, float bottom, float top) {
    float middle = (${uWindowDim}.y + bottom - top) / 2.0;
    return offset.y >= middle - frame && offset.y < middle + frame; 
}


// TODO:  
// DrawFacadeWindowBlinds
// DrawFacadeWindowVerticalStripes

bool isLit(vec2 colRow) {
   float band = floor(colRow.y / 8.0);
   vec2 bandSalt = vec2(band, colRow.y);

   // this is per band
   float maxRunLength = 2.0 + 9.0 * rand(bandSalt * spice2);
   float lightDensity =  1.0 / (2.0 + 2.0 * rand(bandSalt * spice3) + 2.0 * rand(bandSalt * spice4));

   vec2 cellSalt = vec2(spice1, colRow.y);

   bool lit = false;
   float i = 0.0;
   do {
       vec2 cellSalt = vec2(i, colRow.y);
       float run = 1.0 + maxRunLength * rand(cellSalt * spice5);
       i += run;
       lit = lightDensity >= rand(cellSalt * spice6);
   } while (i <  colRow.x);

   return lit;
}

vec3 windowColor(bool lit, vec2 salt) {
    if (lit) {
        vec3 base = vec3(0.5);
        vec3 gray = vec3(0.25) * rand(salt + vec2(1.0, 6.0));
        vec3 color = vec3(rand(salt * 4.0), rand(salt * 2.0), rand(salt * 3.0)) * 0.15;
        return base + gray + color;
    } else {
       return  vec3(0.2) * rand(salt);
    }
}

float windowAlpha(vec2 offset, float left, float bottom, float top, int features, vec2 salt) {
    if ((features & 1) != 0 && 
        isVerticalSplit(offset, left)) return 0.3;
    
    if ((features & 2) != 0 && 
        isHorizontalSplit(offset, bottom, top)) return 0.3;
    
    float blindStart = (1.0 - rand(salt * spice1) * rand(salt * spice1)) * 
                       (${uWindowDim}.y - bottom - top);
    if ((features & 4) != 0 && blindStart < offset.y - bottom) return 0.3;
    
    if ((features & 8) != 0) {           
        salt.x += gl_FragCoord.x - offset.x + featureStart(offset.x, salt);
        // Note the salt is not feature specific instead of window specific
        return furnitureAlpha(offset, salt);
    }
    
    return 1.0;
}

// feature:
// bit 0: vertical split
// bit 1: horizontal split
// bit 2: blinds
// bit 3: furniture
// bit 4: always lit
void main() {
    vec2 colRow = floor(gl_FragCoord.xy / ${uWindowDim});
    
    vec2 offset = mod(gl_FragCoord.xy, ${uWindowDim});
    vec2 bottomLeft = gl_FragCoord.xy - offset;
    vec2 salt = bottomLeft + vec2(0.123, 0.456);
    // The salt is now the same for all pixels falling into the window
    
    float left = ${uWindowFrame}.x;
    float bottom = ${uWindowFrame}.y;
    float top =${uWindowFrame}.z;
    
    vec3 color = ${CGL.uColor};
    if (isWindow(offset, left, bottom, top)) {
        bool lit = (${uFeatures} & 16) != 0 || isLit(colRow);
        color = windowColor(lit, salt) *
                windowAlpha(offset, left, bottom, top, ${uFeatures}, salt);
    }
    ${CGL.oFragColor}.rgb = color; 
    ${CGL.oFragColor}.a = 1.0;
}
 """
  ]);

void _FillCanvas(HTML.CanvasElement canvas, RGB color) {
  canvas.context2D
    ..fillStyle = color.ToString()
    ..fillRect(0, 0, canvas.width, canvas.height);
}

HTML.CanvasElement NoiseCanvas(Math.Random rand, int w, int h) {
  final HTML.CanvasElement canvas = new HTML.CanvasElement();
  canvas.width = w;
  canvas.height = h;
  var context = canvas.context2D;
  var image = context.getImageData(0, 0, canvas.width, canvas.height);

  for (int i = 0; i < image.data.length; i += 4) {
    int v = 30 + rand.nextInt(225);
    image.data[i + 0] = v;
    image.data[i + 1] = v;
    image.data[i + 2] = v;
    image.data[i + 3] = 255;
  }
  context.putImageData(image, 0, 0);
  return canvas;
}

HTML.CanvasElement FilledCanvas(RGB color, int w, int h) {
  final HTML.CanvasElement canvas = HTML.CanvasElement();
  canvas
    ..width = w
    ..height = h;
  _FillCanvas(canvas, color);
  return canvas;
}

HTML.CanvasElement MakeCanvasText(int w, int h, String fontProps,
    String fontName, List<String> lines, RGB colorText, RGB colorBG) {
  int lineH = h ~/ lines.length;
  int fontSize = (lineH * 0.85).floor();
  final HTML.CanvasElement canvas = colorBG == null
      ? NoiseCanvas(Math.Random(), w, h)
      : FilledCanvas(colorBG, w, h);
  HTML.CanvasRenderingContext2D c = canvas.context2D
    ..strokeStyle = colorText.ToString()
    ..fillStyle = colorText.ToString()
    ..textBaseline = "middle"
    ..font = '${fontProps} ${fontSize}px ${fontName}';

  //LogInfo("base ${c.textBaseline}");
  //LogInfo("asc ${c.measureText("qgMT").fontBoundingBoxAscent}");
  //LogInfo("des ${c.measureText("qgMT").fontBoundingBoxDescent}");
  int offset = lineH ~/ 2;
  for (String s in lines) {
    c..fillText(s, w / 16, offset);
    offset += lineH;
  }
  return canvas;
}

List<String> GetBuildingLogos(Math.Random rng) {
  List<String> lines = [];
  int rovingPrefix = rng.nextInt(kCompanyPrefix.length);
  int rovingMain = rng.nextInt(kCompanyMain.length);
  int rovingSuffix = rng.nextInt(kCompanySuffix.length);
  for (int i = 0; i < kNumBuildingLogos; i++) {
    if (rng.nextBool()) {
      lines.add(kCompanyPrefix[rovingPrefix] + kCompanyMain[rovingMain]);
    } else {
      lines.add(kCompanyMain[rovingMain] + kCompanySuffix[rovingSuffix]);
    }
    rovingPrefix = (rovingPrefix + 1) % kCompanyPrefix.length;
    rovingMain = (rovingMain + 1) % kCompanyMain.length;
    rovingSuffix = (rovingSuffix + 1) % kCompanySuffix.length;
  }
  return lines;
}

HTML.CanvasElement MakeCanvasBuildingLogos(
    List<String> lines, RGB colorText, RGB colorBG) {
  return MakeCanvasText(kStdCanvasDim, kStdCanvasDim * 2, "bold", "Arial",
      lines, colorText, colorBG);
}

// For reference how to write pixels directly
HTML.CanvasElement generateTexture() {
  HTML.CanvasElement canvas = HTML.CanvasElement();
  canvas.width = 256;
  canvas.height = 256;

  var context = canvas.context2D;
  var image = context.getImageData(0, 0, 256, 256);

  var x = 0, y = 0;

  for (var i = 0, j = 0, l = image.data.length; i < l; i += 4, j++) {
    x = j % 256;
    y = x == 0 ? y + 1 : y;

    image.data[i] = 255;
    image.data[i + 1] = 255;
    image.data[i + 2] = 255;
    image.data[i + 3] = (x ^ y).floor();
  }
  context.putImageData(image, 0, 0);
  return canvas;
}

HTML.CanvasElement MakeCanvasLightTrimTexture() {
  assert(kLightTrimContinousRows == 8); // must be power of 2
  final int cellDim = kLightTrimCellDim;
  HTML.CanvasElement canvas = HTML.CanvasElement()
    ..width = cellDim * kLightTrimGranularity
    ..height = cellDim * kLightTrimContinousRows;
  _FillCanvas(canvas, kRGBblack);
  HTML.CanvasRenderingContext2D c = canvas.context2D;

  for (int y = 0; y < kLightTrimPatterns.length; y++) {
    List<int> pattern = kLightTrimPatterns[y];
    int patWidth = LightTrimPatternLength(y) * cellDim;

    double cy = y * cellDim * 1.0;
    for (int x = 0; x < kLightTrimGranularity * cellDim; x += patWidth) {
      double cx = x * 1.0;
      for (int i = 0; i < pattern.length; i++) {
        double cw = pattern[i] * cellDim / 2.0;
        double ch = cellDim * 1.0;
        // only draw the full ones
        if (i % 2 == 1) {
          HTML.CanvasGradient g = c.createRadialGradient(cx + cw / 2,
              cy + ch / 2, 0.0, cx + cw / 2, cy + ch / 2, cw / 1.5);
          g..addColorStop(0.0, "#ffffff")..addColorStop(1.0, "#808080");
          c
            ..fillStyle = g
            ..fillRect(cx, cy, cw, ch);
        }
        cx += cw;
      }
    }
  }
  return canvas;
}

HTML.CanvasElement MakeOrientationTestPattern() {
  List<String> lines = [
    "9999999999",
    "8888888889",
    "7777777789",
    "6666666789",
    "5555556789",
    "4444456789",
    "3333456789",
    "2223456789",
    "1123456789",
    "0123456789",
  ];
  return MakeCanvasText(kStdCanvasDim ~/ 4, kStdCanvasDim ~/ 2, "bold", "Arial",
      lines, kRGBwhite, kRGBblack);
}

CGL.Texture MakeNoiseTexture(CGL.ChronosGL cgl, Math.Random rand) {
  final HTML.CanvasElement canvas = NoiseCanvas(rand, 512 * 2, 512 * 2);
  return CGL.ImageTexture(cgl, "noise", canvas, CGL.TexturePropertiesMipmap);
}

void _DrawOvalGradient(HTML.CanvasRenderingContext2D c, int cx, int cy, int rw,
    int rh, RGB color, RGB black) {
  HTML.CanvasGradient g =
      c.createRadialGradient(cx / rw, cy / rh, 0.0, cx / rw, cy / rh, 1.0);
  g..addColorStop(0.0, color.ToString())..addColorStop(1.0, black.ToString());
  c
    ..fillStyle = g
    ..setTransform(rw, 0, 0, rh, 0, 0)
    ..fillRect(cx / rw - 1.0, cy / rh - 1.0, 2, 2)
    ..setTransform(1.0, 0, 0, 1.0, 0, 0);
}

const int kStreetlightStretch = 4;
// A single street light in the middle of a rectangle
HTML.CanvasElement _MakeCommonLight(int r, RGB color, RGB bg, int stretch) {
  HTML.CanvasElement canvas = HTML.CanvasElement();
  canvas
    ..width = stretch * 2 * r
    ..height = 2 * r;
  HTML.CanvasRenderingContext2D c = canvas.context2D;
  c
    ..fillStyle = bg.ToString()
    ..fillRect(0, 0, stretch * 2 * r, 2 * r);
  _DrawOvalGradient(c, stretch * r, r, r, r, color, bg);
  return canvas;
}

HTML.CanvasElement MakeCanvasStreetLight(int r, RGB color, RGB bg) {
  return _MakeCommonLight(r, color, bg, kStreetlightStretch);
}

HTML.CanvasElement MakeCanvasPointLight(int r, RGB color, RGB bg) {
  return _MakeCommonLight(r, color, bg, 1);
}

HTML.CanvasElement MakeCanvasHeadLights() {
  // TODO: this should kRGBtransparent;
  final int w = kStdCanvasDim ~/ 4;
  final int h = kStdCanvasDim ~/ 4;
  final double ratio = w / kCarSpriteSizeW;
  final double carFront = ratio * (kCarSpriteSizeW - kCarLength) / 2;
  final double carBack = ratio * (kCarSpriteSizeW + kCarLength) / 2;
  final double carLeft = ratio * (kCarSpriteSizeW - kCarWidth) / 2;
  final double carRight = ratio * (kCarSpriteSizeW + kCarWidth) / 2;
  final double radHead = ratio * kCarWidth / 6;
  final double radTail = ratio * kCarWidth / 8;

  final RGB bg = RGB.fromGray(0)..a = 0.0;
  final RGB fg = RGB.fromGray(255)..a = 1.0;
  HTML.CanvasElement canvas = HTML.CanvasElement();
  canvas
    ..width = w
    ..height = h;
  _FillCanvas(canvas, bg);
  HTML.CanvasRenderingContext2D c = canvas.context2D;

  final double r1 = 0.0;
  final double r2 = ratio * kCarSpriteSizeW / 4.0;
  final double d = radHead;
  HTML.CanvasGradient gr = c.createRadialGradient(
      carLeft + d, carFront, r1, carLeft + d, carFront / 2, r2);
  gr..addColorStop(0.0, fg.ToString())..addColorStop(1.0, bg.ToString());
  HTML.CanvasGradient gl = c.createRadialGradient(
      carRight - d, carFront, r1, carRight - d, carFront / 2, r2);
  gl..addColorStop(0.0, fg.ToString())..addColorStop(1.0, bg.ToString());

  // head light spots
  c
    ..fillStyle = "white"
    ..fillRect(carLeft + radHead * 0.5, carFront - radHead, radHead, radHead)
    ..fillRect(carRight - radHead * 1.5, carFront - radHead, radHead, radHead);

  // tail light spots
  c
    ..fillStyle = "red"
    ..fillRect(carLeft + radTail, carBack, radTail, radTail)
    ..fillRect(carRight - 2 * radTail, carBack, radTail, radTail);

  // light cloud
  c
    ..fillStyle = gr
    ..fillRect(0, 0, w, h / 2)
    ..fillStyle = gl
    ..fillRect(0, 0, w, h / 2);

  // draw car shape
  c
    ..fillStyle = "black"
    ..fillRect(carLeft, carFront, ratio * kCarWidth, ratio * kCarLength);
  return canvas;
}

HTML.CanvasElement MakeRadioTowerTexture() {
  int dim = kStdCanvasDim ~/ 4;
  double lineW = dim / 16;
  HTML.CanvasElement canvas = HTML.CanvasElement();
  canvas
    ..width = dim
    ..height = dim;
  RGB fg = RGB.fromGray(32);
  RGB bg = RGB.fromGray(8);
  bg = kRGBtransparent;
  _FillCanvas(canvas, bg);
  HTML.CanvasRenderingContext2D c = canvas.context2D;
  c
    ..fillStyle = fg.ToString()
    ..strokeStyle = fg.ToString()
    ..lineWidth = lineW;

  void drawline(num x1, num y1, num x2, num y2) {
    c
      ..moveTo(x1, y1)
      ..lineTo(x2, y2);
  }

  drawline(dim / 2, 0, dim / 2, dim);
  drawline(0, dim / 2, dim, dim / 2);
  c..stroke();
  return canvas;
}

CGL.Material MakeStandardTextureMaterial(
    String name, CGL.ChronosGL cgl, HTML.CanvasElement canvas,
    {bool clamp = false, bool flipY = true}) {
  CGL.TextureProperties tp = CGL.TextureProperties();
  if (clamp) {
    tp.clamp = true;
  }
  if (!flipY) {
    tp.flipY = false;
  }
  tp.SetMipmapLinear();
  tp.mipmap = true;
  if (defaultAnisoLevel != 1) {
    tp.anisotropicFilterLevel = defaultAnisoLevel;
  }

  var t = CGL.ImageTexture(cgl, name, canvas, tp);

  return CGL.Material(name)..SetUniform(CGL.uTexture, t);
}

class WindowStyle {
  WindowStyle(this.name, this.features, double left, double bottom, double top)
      : frame = VM.Vector3(left, bottom, top);

  String name;
  int features;
  VM.Vector3 frame;
}

List<WindowStyle> AllNightWindowStyles(int w, int h) {
  return <WindowStyle>[
    WindowStyle("square top to bottom", 8, 1.0, 1.0, 2.0),
    WindowStyle("vertical top to bottom", 8, w / 4.5, 1.0, 2.0),
    WindowStyle("vertical with base", 8, w / 4.5, h / 3, 2.0),
    WindowStyle("with base", 8, 1.0, h / 3.5, 1.0),
    WindowStyle("horizontal left to right", 8, 1.0, h / 4.5, h / 4.5),
    WindowStyle("square with blinds", 4 + 8, 1.0, 1.0, 2.0),
    WindowStyle("two pane split", 1 + 8, 1.0, 1.0, 2.0),
    WindowStyle("four pane split", 1 + 2 + 8, 1.0, h / 4.0, 2.0),
  ];
}

List<WindowStyle> AllDayWindowStyles(int w, int h) {
  return <WindowStyle>[
    WindowStyle("square top to bottom", 8 + 16, 1.0, 1.0, 2.0),
    WindowStyle("vertical top to bottom", 8 + 16, w / 4.5, 1.0, 2.0),
    WindowStyle("vertical with base", 8 + 16, w / 4.5, h / 3, 2.0),
    WindowStyle("with base", 8 + 16, 1.0, h / 3.5, 2.0),
    WindowStyle("horizontal left to right", 8 + 16, 1.0, h / 4.5, h / 4.5),
    WindowStyle("two pane split", 1 + 8 + 16, 1.0, 1.0, 2.0),
    WindowStyle("four pane split", 1 + 2 + 8 + 16, 1.0, h / 4.0, 2.0),
  ];
}

List<CGL.Material> MakeWalls(
    CGL.ChronosGL cgl, double seed, RGB wallColor, List<WindowStyle> styles) {
  log.LogInfo("start generating ${styles.length} facades");
  CGL.RenderProgram program = CGL.RenderProgram(
      "facade", cgl, facadeVertexShader, facadeFragmentShader);

  final int w = kStdCanvasDim ~/ kWindowsHorizontal;
  final int h = kStdCanvasDim ~/ kWindowsVertical;

  CGL.UniformGroup uniforms = CGL.UniformGroup("plain")
    ..SetUniform(uAverageFurnitureW, w * 0.3)
    ..SetUniform(uMaxFurnitureH, h * 0.7)
    ..SetUniform(CGL.uColor, wallColor.GlColor())
    ..SetUniform(uRandSeed, (seed / 10000.0) % 1.0)
    ..SetUniform(uWindowDim, VM.Vector2(w + 0.0, h + 0.0));
  CGL.MeshData unitQuad = CGL.ShapeQuad(program, 1);

  CGL.Framebuffer fb =
      CGL.Framebuffer.Default(cgl, kStdCanvasDim, kStdCanvasDim);

  CGL.TextureProperties tp = CGL.TextureProperties()
    ..SetMipmapLinear()
    ..clamp = false
    ..mipmap = true;

  List<CGL.Material> m = [];
  CGL.Texture tex;
  for (WindowStyle ws in styles) {
    fb.Activate(CGL.GL_CLEAR_ALL, 0, 0, kStdCanvasDim, kStdCanvasDim);
    uniforms
      ..ForceUniform(uFeatures, ws.features)
      ..ForceUniform(uWindowFrame, ws.frame);
    program.Draw(unitQuad, [uniforms]);
    tex = CGL.Texture(cgl, CGL.GL_TEXTURE_2D, ws.name, tp);
    tex.CopyFromFramebuffer2D(0, 0, kStdCanvasDim, kStdCanvasDim);
    m.add(CGL.Material(ws.name)..SetUniform(CGL.uTexture, tex));
  }
  log.LogInfo("done generating  ${styles.length} facades");
  return m;
}

List<CGL.Material> MakeWindowWalls(
    CGL.ChronosGL cgl, double seed, RGB wallColor, bool night) {
  final int w = kStdCanvasDim ~/ kWindowsHorizontal;
  final int h = kStdCanvasDim ~/ kWindowsVertical;
  return MakeWalls(cgl, seed, wallColor,
      night ? AllNightWindowStyles(w, h) : AllDayWindowStyles(w, h));
}

CGL.Material MakeSolid(CGL.ChronosGL cgl) {
  return MakeStandardTextureMaterial(
      kSolidMat, cgl, CGL.MakeSolidColorCanvas("white"));
}

CGL.Material MakeLogo(
    CGL.ChronosGL cgl, List<String> logos, RGB textColor, RGB wallColor) {
  return MakeStandardTextureMaterial(
      kLogoMat, cgl, MakeCanvasBuildingLogos(logos, textColor, wallColor));
}

CGL.Material MakeLightTrims(CGL.ChronosGL cgl) {
  return MakeStandardTextureMaterial(
      kLightTrimMat, cgl, MakeCanvasLightTrimTexture());
}

CGL.Material MakePointLight(CGL.ChronosGL cgl) {
  RGB white = RGB.fromGray(255)..a = 0.99;
  return MakeStandardTextureMaterial(
      kPointLightMat, cgl, MakeCanvasPointLight(64, white, kRGBtransparent))
    ..ForceUniform(CGL.cBlendEquation, CGL.BlendEquationStandard)
    ..ForceUniform(CGL.cDepthWrite, false);
}

CGL.Material MakeFlashingLight(CGL.ChronosGL cgl) {
  RGB white = RGB.fromGray(255)..a = 0.99;
  return MakeStandardTextureMaterial(
      "pointlightFlash", cgl, MakeCanvasPointLight(64, white, kRGBtransparent))
    ..ForceUniform(CGL.cBlendEquation, CGL.BlendEquationStandard);
}

CGL.Material MakeRadioTower(CGL.ChronosGL cgl) {
  return MakeStandardTextureMaterial("radiotower", cgl, MakeRadioTowerTexture())
    ..ForceUniform(CGL.cBlendEquation, CGL.BlendEquationStandard)
    ..ForceUniform(CGL.cDepthWrite, false);
}

CGL.Material MakeHeadLights(CGL.ChronosGL cgl) {
  return MakeStandardTextureMaterial("headlight", cgl, MakeCanvasHeadLights(),
      clamp: true)
    ..ForceUniform(CGL.cBlendEquation, CGL.BlendEquationStandard)
    ..ForceUniform(CGL.cDepthWrite, false);
}

CGL.Material MakeLogoMaterial(
    CGL.ChronosGL cgl, String theme, List<String> logos) {
  switch (theme) {
    case THEME.kModeNight:
      return MakeLogo(cgl, logos, kRGBwhite, kRGBblack);
    case THEME.kModeWireframe:
      return MakeLogo(cgl, logos, kRGBred, kRGBblack);
    case THEME.kModeSketch:
      return MakeLogo(cgl, logos, kRGBblack, kRGBwhite);
    default:
      assert(false, "bad theme ${theme}");
      return null;
  }
}

List<CGL.Material> MakeWallMaterials(
    CGL.ChronosGL cgl, Math.Random rng, double seed, int style) {
  switch (style) {
    case THEME.kWallStyleNone:
      return [CGL.Material("no-wall")];
    case THEME.kWallStyleDay:
      return MakeWindowWalls(cgl, seed, kRGBwhite, false);
    case THEME.kWallStyleNight:
      return MakeWindowWalls(cgl, seed, kRGBblack, true);
    case THEME.kWallStyleSketch:
      CGL.Texture noise = MakeNoiseTexture(cgl, Math.Random());
      return [CGL.Material("sketch")..SetUniform(CGL.uTexture, noise)];
    default:
      assert(false, "unknown mode ${style}");
      return null;
  }
}

Map<String, CGL.Material> MakeMaterialsForTheme(CGL.ChronosGL cgl,
    THEME.Theme theme, List<String> logos, Math.Random rng, double seed) {
  Map<String, CGL.Material> out = {
    kLightTrimMat: MakeLightTrims(cgl),
    kPointLightMat: MakePointLight(cgl),
    kFlashingLightMat: MakeFlashingLight(cgl),
    kRadioTowerMat: MakeRadioTower(cgl),
    kSolidMat: MakeSolid(cgl),
    kLogoMat: MakeLogoMaterial(cgl, theme.name, logos)
  };

  List<CGL.Material> walls = MakeWallMaterials(cgl, rng, seed, theme.wallStyle);
  assert(walls.length <= kMaxWindowTextures);
  for (int i = 0; i < kMaxWindowTextures; ++i) {
    out["window-$i"] = walls[i % walls.length];
  }
  return out;
}
