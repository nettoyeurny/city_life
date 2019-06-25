import 'dart:math' as Math;

import 'package:vector_math/vector_math.dart' as VM;

import 'rgb.dart';

// If you add stuff here you must update the html
const String kModeDaySimple = "daySimple";
const String kModeDayFancy = "dayFancy";
const String kModeNight = "night";
const String kModeWireframe = "wireframe";
const String kModeDayShadow = "dayShadow";
const String kModeSketch = "sketch";

const String kNodeSky = "sky";
const String kNodeGround = "ground";
const String kNodeStreetLights = "streetlights";
const String kNodeCarBody = "carbody";
const String kNodeCarLight = "carlight";
const String kNodeBuilding = "building";
const String kNodeGlobeLight = "globelight";

const String kShaderSketchPrep = "kShaderSketchPrep";
const String kShaderTexturedInstanced = "kTexturedInstanced";
const String kShaderTextured = "kTextured";
const String kShaderTexturedWithFog = "kTexturedWithFog";
const String kShaderWireframe = "kWireframe";
const String kShaderPointSprites = "kPointSprites";
const String kShaderPointSpritesFlashing = "kPointSpritesFlashing";
const String kShaderTexturedWithShadow = "kTexturedWithShadow";

class RoofFeatures {
  bool allowLightStrip = true;
  bool allowGlobeLight = true;
  bool allowLogo = true;
  bool allowRadioTower = true;
}

const double kNonSaturated = 0.93;
const double kMildSaturated = 0.90;

final List<RGB> kBuildingColorsRGB = [
  RGB.fromHSL(0.04, 0.9, kNonSaturated), //Amber / pink
  RGB.fromHSL(0.055, 0.95, kNonSaturated), //Slightly brighter amber
  RGB.fromHSL(0.08, 0.7, kNonSaturated), //Very pale amber
  RGB.fromHSL(0.07, 0.9, kNonSaturated), //Very pale orange
  RGB.fromHSL(0.1, 0.9, kMildSaturated), //Peach
  RGB.fromHSL(0.13, 0.9, kNonSaturated), //Pale Yellow

  RGB.fromHSL(0.15, 0.9, kNonSaturated), //Yellow

  // RGB.fromHSL(0.17, 1.0, kMildSaturated), //Saturated Yellow

  RGB.fromHSL(0.55, 0.9, kNonSaturated), //Cyan

  RGB.fromHSL(0.55, 0.9, kMildSaturated), //Cyan - pale, almost white

  RGB.fromHSL(0.6, 0.9, kNonSaturated), //Pale blue
  RGB.fromHSL(0.65, 0.9, kNonSaturated), //Pale Blue II, The Palening
  RGB.fromHSL(0.65, 0.4, 0.99), //Pure white. Bo-ring.
  RGB.fromHSL(0.65, 0.0, 0.8), //Dimmer white.
  RGB.fromHSL(0.65, 0.0, 0.6) //Dimmest white
  //
  // Ledge Colors
];

List<VM.Vector3> _MakeBuildingColors(List<RGB> rgbs) {
  List<VM.Vector3> out = [];
  for (RGB c in rgbs) {
    out.add(c.GlColor());
  }
  return out;
}

final List<VM.Vector3> kBuildingColors =
    _MakeBuildingColors(kBuildingColorsRGB);

final List<VM.Vector3> kLedgeColors = [
  RGB(8, 8, 8).GlColor(),
  RGB(12, 12, 12).GlColor(),
  RGB(16, 16, 16).GlColor(),
];

final List<VM.Vector3> kOffsetColors = [
  RGB(4, 4, 4).GlColor(),
];

final List<VM.Vector3> kBaseColors = [
  RGB(2, 2, 2).GlColor(),
  RGB(4, 4, 4).GlColor(),
  RGB(6, 6, 6).GlColor(),
  RGB(8, 8, 8).GlColor(),
];

final List<VM.Vector3> kAcColors = [
  RGB(16, 16, 16).GlColor(),
];

final List<RGB> kDaylightBuildingColors = [
  // Lime
  RGB(0xdf, 0xd9, 0xbb),
  RGB(0xdf, 0xd9, 0xbb),
  // light blue
  RGB(0x7a, 0xce, 0xe8),
  RGB(0x7a, 0xce, 0xe8),
  // blue turquise
  RGB(0x12, 0x74, 0xdf),
  RGB(0x15, 0x94, 0xf7),
  // brown
  RGB(0xfc, 0xa6, 0x76),
  RGB(0xe3, 0x82, 0x3c),
  // red
  RGB(0xfb, 0x2d, 0x20),
  RGB(0x9e, 0x26, 0x14),
  // white
  RGB(0xdd, 0xde, 0xe3),
  RGB(0xf9, 0xfc, 0xfb),
  RGB(0xdd, 0xde, 0xe3),
  RGB(0xf9, 0xfc, 0xfb),
  RGB(0xdd, 0xde, 0xe3),
  RGB(0xf9, 0xfc, 0xfb),
  RGB(0xdd, 0xde, 0xe3),
  RGB(0xf9, 0xfc, 0xfb),
  RGB(0xdd, 0xde, 0xe3),
  RGB(0xf9, 0xfc, 0xfb),

  // yellow
  // RGB(0xfe,0xd8,0x5d),
  // RGB(0xfd,0xbf,0x39),
];

class BuildingColors {
  const BuildingColors(this.wall, this.base, this.ledge, this.offset, this.ac,
      this.logo, this.logoOther);

  final VM.Vector3 wall;
  final VM.Vector3 base;
  final VM.Vector3 ledge;
  final VM.Vector3 offset;
  final VM.Vector3 ac;
  final VM.Vector3 logo;
  final VM.Vector3 logoOther;
}

VM.Vector3 RandomColor(Math.Random rng) {
  return VM.Vector3(rng.nextDouble(), rng.nextDouble(), rng.nextDouble());
}

BuildingColors DayBuildingColors(Math.Random rng) {
  final VM.Vector3 theColor =
      kDaylightBuildingColors[rng.nextInt(kDaylightBuildingColors.length)]
          .GlColor();
  return BuildingColors(
      theColor + RandomColor(rng) * 0.2,
      theColor + RandomColor(rng) * 0.1,
      theColor + RandomColor(rng) * 0.1,
      theColor + RandomColor(rng) * 0.1,
      theColor + RandomColor(rng) * 0.2,
      theColor,
      theColor);
}

BuildingColors NightBuildingColors(Math.Random rng) {
  return BuildingColors(
      kBuildingColors[rng.nextInt(kBuildingColors.length)],
      kBaseColors[rng.nextInt(kBaseColors.length)],
      kLedgeColors[rng.nextInt(kLedgeColors.length)],
      kOffsetColors[rng.nextInt(kOffsetColors.length)],
      kAcColors[rng.nextInt(kAcColors.length)],
      kRGBwhite.GlColor(),
      kRGBblack.GlColor());
}

typedef BuildingColors ColorFactoryFun(Math.Random rng);

final _FullFeaturedRoof = RoofFeatures()
  ..allowRadioTower = false
  ..allowGlobeLight = false;
final _WireframeRoof = RoofFeatures()
  ..allowRadioTower = false
  ..allowGlobeLight = false;
final _OnlyLogoRoof = RoofFeatures()
  ..allowGlobeLight = false
  ..allowRadioTower = false;

const int kWallStyleNone = 1;
const int kWallStyleNight = 2;
const int kWallStyleDay = 3;
const int kWallStyleSketch = 4;

class Theme {
  Theme(
      this.name,
      this.laneColor,
      this.otherColor,
      this.wallStyle,
      this.hasLights,
      this.shaderBuilding,
      this.shaderLogo,
      this.shaderStreet,
      this.shaderSky,
      this.colorFun,
      this.roofFeatures);

  //static final Map<String, Theme> allThemes = {};

  final String name;
  final RGB laneColor;
  final RGB otherColor;
  final int wallStyle;
  final bool hasLights;
  final String shaderBuilding;
  final String shaderLogo;
  final String shaderStreet;
  final String shaderSky;
  final ColorFactoryFun colorFun;
  final RoofFeatures roofFeatures;
}

Map<String, Theme> allThemes = {
  kModeNight: Theme(
      kModeNight,
      RGB.fromGray(0x10),
      RGB.fromGray(0x15),
      kWallStyleNight,
      true,
      kShaderTexturedWithFog,
      kShaderTexturedWithFog,
      kShaderTexturedWithFog,
      kShaderTexturedWithFog,
      NightBuildingColors,
      _FullFeaturedRoof),
  kModeWireframe: Theme(
      kModeWireframe,
      RGB.fromGray(0x20),
      RGB.fromGray(0x30),
      kWallStyleNone,
      true,
      kShaderWireframe,
      kShaderTextured,
      kShaderTextured,
      kShaderTextured,
      DayBuildingColors,
      _WireframeRoof),
  kModeSketch: Theme(
      kModeSketch,
      RGB.fromGray(0x80),
      RGB.fromGray(0xa0),
      kWallStyleSketch,
      true,
      kShaderSketchPrep,
      kShaderTextured,
      kShaderTextured,
      kShaderTextured,
      DayBuildingColors,
      _OnlyLogoRoof),
};
