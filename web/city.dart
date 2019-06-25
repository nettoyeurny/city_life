library city;

import 'dart:math' as Math;

import 'package:chronosgl/chronosgl.dart' as CGL;
import 'package:vector_math/vector_math.dart' as VM;

import 'building.dart';
import 'floorplan.dart' as FLOORPLAN;
import 'geometry.dart';
import 'theme.dart' as THEME;
import 'torus.dart' as TORUS;

void ExtractTransformsAtTorusSurfaceCity(
    TORUS.TorusKnotHelper tkhelper,
    int kWidth,
    int kHeight,
    Rect base,
    double height,
    VM.Matrix4 mat,
    VM.Matrix3 matNormal) {
  VM.Vector3 GetVertex(double x, double y) {
    //assert(y < kHeight);
    //assert(x < kWidth);
    // -0.5 is intended to avoid having buildings flying above the surface
    tkhelper.surfacePoint(y / kHeight * 2.0 * Math.pi, TORUS.kTubeRadius - 1.0,
        x / kWidth * 2.0 * Math.pi);
    //var a2 = torus.vertices[x + y * (kWidth + 1)];
    //var a1 = tkhelper.point;
    //print("$x $kWidth  $y $kHeight    $a1  va $a2");

    return tkhelper.point.clone();
  }

  // Note x/y swap
  final double y = base.x;
  final double x = base.y;
  final double yc = y + base.w / 2.0;
  final double xc = x + base.h / 2.0;
  final double yh = y + base.w;
  final double xw = x + base.h;

  VM.Vector3 center = GetVertex(xc, yc);

  VM.Vector3 p0c = GetVertex(x, yc);
  VM.Vector3 p1c = GetVertex(xw, yc);

  VM.Vector3 pc0 = GetVertex(xc, y);
  VM.Vector3 pc1 = GetVertex(xc, yh);
  double dw = p0c.distanceTo(p1c);
  double dh = pc0.distanceTo(pc1);

  double scale = Math.min(dw / base.w, dh / base.h);

  VM.Vector3 dir1 = p1c - p0c;
  VM.Vector3 dir2 = pc1 - pc0;

  VM.Vector3 dir3 = dir1.cross(dir2)..normalize();
  VM.setViewMatrix(mat, VM.Vector3.zero(), dir3, dir1);
  mat.invert();
  mat.rotateX(-Math.pi / 2.0);
  mat.scale(scale * 0.90);
  mat.setTranslation(center);
  // TODO: this is not quite correct
  mat.copyRotation(matNormal);
}

void _AddOneBuilding(Shape shape, Math.Random rng, THEME.BuildingColors colors,
    RoofOptions roofOpt, THEME.RoofFeatures rf, FLOORPLAN.Building b) {
  //print ("building ${b}");
  switch (b.kind) {
    case FLOORPLAN.kTileBuildingTower:
      var opt = BuildingTowerOptions(rng, colors, b.height > 40.0);
      AddBuildingTower(shape, rng, b.base, b.height, opt, roofOpt, rf);
      break;
    case FLOORPLAN.kTileBuildingBlocky:
      var opt = BuildingBlockyOptions(rng, colors);

      AddBuildingBlocky(shape, rng, b.base, b.height, opt, roofOpt, rf);
      break;
    case FLOORPLAN.kTileBuildingModern:
      var opt = BuildingModernOptions(rng, colors, rf, b.height > 48.0);
      AddBuildingModern(shape, rng, b.base, b.height, opt);
      break;
    case FLOORPLAN.kTileBuildingSimple:
      var opt = BuildingSimpleOptions(rng, colors);
      AddBuildingSimple(shape, rng, b.base, b.height, opt);
      break;
    default:
      print("BAD ${b.kind}");
      assert(false);
  }
}

Shape MakeBuildings(
    CGL.ChronosGL cgl,
    Math.Random rng,
    double seed,
    List<FLOORPLAN.Building> buildings,
    TORUS.TorusKnotHelper tkhelper,
    int kWidth,
    int kHeight,
    List<String> logos,
    THEME.Theme theme) {
  print("Errecting building");
  Shape out = Shape([CGL.aNormal, CGL.aColor, CGL.aCenter, CGL.aTexUV], []);
  int count = 0;
  VM.Matrix4 mat = VM.Matrix4.zero();
  VM.Matrix3 matNormal = VM.Matrix3.zero();

  for (FLOORPLAN.Building b in buildings) {
    if (count % 100 == 0) {
      print("initialize buidings ${count}");
    }
    count++;
    Shape tmp = Shape([CGL.aNormal, CGL.aColor, CGL.aCenter, CGL.aTexUV], []);
    final THEME.BuildingColors colors = theme.colorFun(rng);
    final RoofOptions roofOpt = RoofOptions(rng, colors);
    final THEME.RoofFeatures rf = theme.roofFeatures;

    ExtractTransformsAtTorusSurfaceCity(
        tkhelper, kWidth, kHeight, b.base, b.height, mat, matNormal);

    Rect oldbase = b.base;

    b.base = Rect(-b.base.w / 2.0, -b.base.h / 2.0, b.base.w, b.base.h);

    _AddOneBuilding(tmp, rng, colors, roofOpt, rf, b);
    b.base = oldbase;

    for (String cm in tmp.builders.keys) {
      out.Get(cm).MergeAndTakeOwnership(tmp.builders[cm], mat, matNormal);
    }
  }
  print("Generate Mesh for Buildings");
  return out;
}
