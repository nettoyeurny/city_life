import 'dart:html' as HTML;
import 'dart:math' as Math;
// import 'package:vector_math/vector_math.dart' as VM;

import 'floorplan.dart' as FLOORPLAN;

import 'torus.dart' as TORUS;

void main() {
  print("configure all options");
  final HTML.Element gContainer = HTML.document.getElementById("test");

  final Math.Random gRng = Math.Random();
  final FLOORPLAN.Floorplan floorplan =
      FLOORPLAN.Floorplan(TORUS.kWidth, TORUS.kHeight, 10, gRng);

  HTML.CanvasElement canvas =
      FLOORPLAN.RenderCanvasWorldMap(floorplan.world_map);
  gContainer.children.add(canvas);
}
