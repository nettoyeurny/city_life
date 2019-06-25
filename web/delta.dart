import 'dart:html' as HTML;
import 'dart:math' as Math;

import 'package:chronosgl/chronosgl.dart' as CGL;
import 'package:vector_math/vector_math.dart' as VM;

import 'city.dart' as CITY;
import 'floorplan.dart';
import 'geometry.dart';
import 'gol.dart' as GOL;
import 'logging.dart';
import 'portal.dart' as PORTAL;
import 'shaders.dart';
import 'sky.dart' as SKY;
import 'theme.dart' as THEME;
import 'torus.dart' as TORUS;
import 'facade.dart' as FACADE;
import 'config.dart' as CONFIG;

final double zNear = 0.1;
final double zFar = 20000.0;
final double cameraFov = 60.0;

final HTML.SelectElement gMode =
    HTML.document.querySelector('#mode') as HTML.SelectElement;

final HTML.SelectElement gCameraRoute =
    HTML.document.querySelector('#routecam') as HTML.SelectElement;

final HTML.SelectElement gTheme =
    HTML.document.querySelector('#theme') as HTML.SelectElement;

final HTML.Element gClock = HTML.document.querySelector('#clock');

final HTML.Element gStatus = HTML.document.querySelector('#status');

final HTML.AudioElement gSoundtrack =
    HTML.document.querySelector("#soundtrack");

final HTML.Element gPaused = HTML.document.querySelector('#paused');

final HTML.Element gInitializing = HTML.document.querySelector('#initializing');
final List<String> kLogos8 = [
  "@Party Somerville",
  "June 2019",
  "moria.us",
  "muth.org",
  "nettoyeurny",
  "Ebb Industries",
  "Muth Inc",
  "dartlang",
];

// This needs to have size 32
final List<String> kLogos = []
  ..addAll(kLogos8)
  ..addAll(kLogos8)
  ..addAll(kLogos8)
  ..addAll(kLogos8);

class ScriptScene {
  ScriptScene(this.name, this.durationMs, this.speed, this.route, this.radius);

  final String name;
  final double durationMs;
  final double speed;
  final int route;
  final double radius;
}

double kTimeUnit = 1000;

final List<ScriptScene> gScript = [
  ScriptScene("night-orbit", 16.0 * kTimeUnit, 1.0, 0, 0.0),
  ScriptScene(
      "night-outside", 32.0 * kTimeUnit, 0.5, 9, TORUS.kTubeRadius + 50.0),
  ScriptScene("gol-inside", 32.0 * kTimeUnit, 1.0, 6, 1.0),
  ScriptScene(
      "wireframe-outside", 32.0 * kTimeUnit, 0.7, 3, TORUS.kTubeRadius + 50.0),
  ScriptScene("gol2-inside", 16.0 * kTimeUnit, 1.3, 6, 1.0),
  ScriptScene(
      "sketch-outside", 32.0 * kTimeUnit, 0.5, 0, TORUS.kTubeRadius + 50.0),
  ScriptScene("finale", 16.0 * kTimeUnit, 1.0, 0, 0.0),
];

Map<String, String> HashParameters() {
  final Map<String, String> out = {};

  String hash = HTML.window.location.hash;
  if (hash == "") return out;
  for (String p in hash.substring(1).split("&")) {
    List<String> tv = p.split("=");
    if (tv.length == 1) {
      tv.add("");
    }
    out[tv[0]] = tv[1];
  }
  return out;
}

class CameraInterpolation {
  VM.Quaternion qsrc = VM.Quaternion.identity();
  VM.Vector3 tsrc = VM.Vector3.zero();
  VM.Vector3 ssrc = VM.Vector3.zero();

  VM.Quaternion qdst = VM.Quaternion.identity();
  VM.Vector3 tdst = VM.Vector3.zero();
  VM.Vector3 sdst = VM.Vector3.zero();

  VM.Vector3 ptmp = VM.Vector3.zero();
  VM.Quaternion qtmp = VM.Quaternion.identity();
  VM.Matrix3 mtmp = VM.Matrix3.identity();

  void setSrc(VM.Matrix4 src) {
    src.decompose(tsrc, qsrc, ssrc);
  }

  void setDst(VM.Matrix4 dst) {
    dst.decompose(tdst, qdst, sdst);
  }

  void setInterpolated(VM.Matrix4 m, double x) {
    m.setFromTranslationRotationScale(
        //
        tsrc + (tdst - tsrc).scaled(x),
        qsrc + (qdst - qsrc).scaled(x),
        ssrc + (sdst - ssrc).scaled(x));
  }
}

class InitialApproachCamera extends CGL.Spatial {
  InitialApproachCamera() : super("initial");

  CameraInterpolation ci = CameraInterpolation();

  final VM.Matrix4 cameraTransitionState = null;
  final VM.Vector3 cameraFinalPos = VM.Vector3.zero();

  double range = 100000.0;
  double radius = 1.0;
  double azimuth = 0.0;
  double polar = 0.0;
  double lastTime = 0.0;
  final VM.Vector3 _lookAtPos = VM.Vector3.zero();

  void animate(double timeMs) {
    range = (transform.getTranslation() - ci.tdst).length;
    double dur = 11000;
    double dur2 = gScript[0].durationMs;

    if (timeMs >= dur) {
      if (lastTime < dur) {
        ci.setSrc(transform);
      }
      double t = (timeMs - dur) / (dur2 - dur);
      if (t > 1.0) {
        return;
      }
      ci.setInterpolated(transform, t);
    } else {
      // azimuth += 0.03;
      azimuth = Math.pi + timeMs * 0.0001;
      azimuth = azimuth % (2.0 * Math.pi);
      polar = polar.clamp(-Math.pi / 2 + 0.1, Math.pi / 2 - 0.1);
      double r = (radius - timeMs * 0.1) * 0.3;
      setPosFromSpherical(r * 2.0, azimuth, polar);
      addPosFromVec(_lookAtPos);
      lookAt(_lookAtPos);
    }
    lastTime = timeMs;
  }
}

class FinaleCamera extends CGL.Spatial {
  FinaleCamera() : super("finale");

  double radius = 10.0;
  double azimuth = 0.0;
  double polar = 0.0;
  double lastTime = 0.0;
  final VM.Vector3 _lookAtPos = VM.Vector3.zero();

  void animate(double timeMs) {
    double dur = 17000;

    if (timeMs >= dur) {
      timeMs = dur;
    }

    // azimuth += 0.03;
    azimuth = Math.pi + timeMs * 0.001;
    azimuth = azimuth % (2.0 * Math.pi);
    polar = polar.clamp(-Math.pi / 2 + 0.1, Math.pi / 2 - 0.1);
    double r = radius + timeMs * Math.log(timeMs) * 0.014;
    setPosFromSpherical(r * 2.0, azimuth, polar);
    addPosFromVec(_lookAtPos);
    lookAt(_lookAtPos);
  }
}

CGL.Texture MakeFloorplanTexture(CGL.ChronosGL cgl, Floorplan floorplan) {
  LogInfo("make floorplan ${TORUS.kWidth}x${TORUS.kHeight}");
  final HTML.CanvasElement canvas =
      RenderCanvasWorldMap(floorplan.world_map, kTileToColorsStandard);
  CGL.TextureProperties tp = CGL.TexturePropertiesMipmap;
  LogInfo("make floorplan done ${canvas.width}x${canvas.height}");
  return CGL.ImageTexture(cgl, "noise", canvas, tp);
}

class Scene {
  Scene();

  Scene.OutsideStreet(
      CGL.ChronosGL cgl, Floorplan floorplan, CGL.GeometryBuilder torus) {
    mat = CGL.Material("street")
      ..SetUniform(CGL.uModelMatrix, VM.Matrix4.identity())
      ..SetUniform(CGL.uTexture, MakeFloorplanTexture(cgl, floorplan))
      ..SetUniform(CGL.uColor, VM.Vector3.zero());
    program = CGL.RenderProgram(
        "street", cgl, texturedVertexShader, texturedFragmentShader);
    mesh = CGL.GeometryBuilderToMeshData("torusknot", program, torus);
  }

  Scene.OutsideWireframeBuildings(
      CGL.ChronosGL cgl, CGL.GeometryBuilder building) {
    mat = CGL.Material("wf")
      ..SetUniform(CGL.uModelMatrix, VM.Matrix4.identity())
      ..SetUniform(uWidth, 1.5)
      ..SetUniform(CGL.uColor, VM.Vector3(1.0, 1.0, 0.0))
      ..SetUniform(CGL.uColorAlpha, VM.Vector4(1.0, 0.0, 0.0, 1.0))
      ..SetUniform(CGL.uColorAlpha2, VM.Vector4(0.1, 0.0, 0.0, 1.0));

    program = CGL.RenderProgram(
        "wf", cgl, wireframeVertexShader, wireframeFragmentShader);
    mesh = CGL.GeometryBuilderToMeshData("wf", program, building);
  }

  Scene.OutsideNightBuildings(
      CGL.ChronosGL cgl, CGL.GeometryBuilder buildings) {
    mat = CGL.Material("building")
      ..SetUniform(CGL.uModelMatrix, VM.Matrix4.identity());
    program = CGL.RenderProgram(
        "building", cgl, multiColorVertexShader, multiColorFragmentShader);
    mesh = CGL.GeometryBuilderToMeshData("buildings", program, buildings);
  }

  Scene.InsideWireframe(CGL.ChronosGL cgl, CGL.GeometryBuilder torus) {
    mat = CGL.Material("wf")
      ..SetUniform(CGL.uModelMatrix, VM.Matrix4.identity())
      ..SetUniform(uWidth, 1.5)
      ..ForceUniform(CGL.cBlendEquation, CGL.BlendEquationStandard)
      ..SetUniform(CGL.uColorAlpha, VM.Vector4(0.0, 0.0, 1.0, 1.0))
      ..SetUniform(CGL.uColorAlpha2, VM.Vector4(0.0, 0.0, 0.1, 0.1));

    program = CGL.RenderProgram(
        "wf", cgl, wireframeVertexShader, wireframeFragmentShader);
    mesh = CGL.GeometryBuilderToMeshData("wf", program, torus);
  }

  Scene.Portal(CGL.ChronosGL cgl) {
    mat = CGL.Material("portal")
      ..SetUniform(CGL.uModelMatrix, VM.Matrix4.identity())
      ..SetUniform(CGL.uTime, 0.0)
      ..SetUniform(CGL.uPointSize, 300.0);

    program = CGL.RenderProgram(
        "portal", cgl, PORTAL.VertexShader, PORTAL.FragmentShader);

    mesh = PORTAL.MakePortal(program);
  }

  Scene.Finale(CGL.ChronosGL cgl) {
    mat = CGL.Material("finale")
      ..SetUniform(CGL.uModelMatrix, VM.Matrix4.identity())
      ..SetUniform(CGL.uTransformationMatrix, VM.Matrix4.zero())
      ..SetUniform(CGL.uTime, 0.0);

    program = CGL.RenderProgram("finale", cgl, CGL.perlinNoiseVertexShader,
        CGL.makePerlinNoiseColorFragmentShader(false));
    mesh = CGL.ShapeTorusKnot(program);
  }

  Scene.Sky(CGL.ChronosGL cgl, int w, int h) {
    program =
        CGL.RenderProgram("sky", cgl, SKY.VertexShader, SKY.FragmentShader);
    mesh = CGL.ShapeQuad(program, 1);
    mat = CGL.Material('sky');
  }

  Scene.Sky2(CGL.ChronosGL cgl, int w, int h) {
    program = CGL.RenderProgram(
        "sky2", cgl, SKY.VertexShader, SKY.GradientFragmentShader);
    mesh = CGL.ShapeQuad(program, 1);
    mat = CGL.Material('sky');
  }

  void Draw(CGL.ChronosGL cgl, CGL.Perspective perspective) {
    program.Draw(mesh, [perspective, mat]);
  }

  CGL.Material mat;
  CGL.RenderProgram program;
  CGL.MeshData mesh;
}

class SceneGOL extends Scene {
  SceneGOL(CGL.ChronosGL cgl, this.w, this.h, CGL.GeometryBuilder torus) {
    program = CGL.RenderProgram("gol", cgl, GOL.texturedVertexShaderWithRepeats,
        GOL.texturedFragmentShaderWithRepeats);
    mesh = CGL.GeometryBuilderToMeshData("gol", program, torus);

    fb = CGL.Framebuffer.Default(cgl, TORUS.GOLHeight * 4, TORUS.GOLWidth * 4);
    gol = GOL.Life(cgl, TORUS.GOLHeight, TORUS.GOLWidth, 4, true);

    screen = CGL.Framebuffer.Screen(cgl);

    mat = CGL.Material("gol")
      ..SetUniform(CGL.uModelMatrix, VM.Matrix4.identity())
      ..SetUniform(CGL.uTexture, fb.colorTexture)
      ..SetUniform(
          GOL.uUVRepeats, VM.Vector2(TORUS.GOLHeightRepeats + 0.0, 1.0))
      ..SetUniform(CGL.uColor, VM.Vector3(0.1, 0.0, 0.0));
  }

  factory SceneGOL.Variant1(CGL.ChronosGL cgl, int w, int h,
      CGL.GeometryBuilder torus, Math.Random rng) {
    var res = SceneGOL(cgl, w, h, torus);
    res.gol
      ..SetRandom(rng, 10)
      ..SetRules(rng, "23/3")
      ..SetPalette("Regular", [0, 255, 0], [0, 0, 0]);
    return res;
  }

  factory SceneGOL.Variant2(CGL.ChronosGL cgl, int w, int h,
      CGL.GeometryBuilder torus, Math.Random rng) {
    var res = SceneGOL(cgl, w, h, torus);
    res.gol
      ..SetRandom(rng, 35)
      ..SetRules(rng, "45678/3")
      ..SetPalette("Blur", [255, 0, 0], [0, 0, 128]);
    for (int i = 0; i < 100; ++i) res.gol.Step(false, rng);
    return res;
  }

  void Draw(CGL.ChronosGL cgl, CGL.Perspective perspective) {
    if (count % 3 == 0) {
      gol.Step(false, null);
    }
    ++count;
    fb.Activate(CGL.GL_CLEAR_ALL, 0, 0, TORUS.kHeight * 4, TORUS.kWidth * 4);
    gol.DrawToScreen();
    screen.Activate(CGL.GL_CLEAR_ALL, 0, 0, w, h);
    program.Draw(mesh, [perspective, mat]);
  }

  int count = 0;
  int w, h;
  GOL.Life gol;
  CGL.Framebuffer fb;
  CGL.Framebuffer screen;
}

class SceneSketch extends Scene {
  SceneSketch(
      CGL.ChronosGL cgl,
      Math.Random rng,
      this.w,
      this.h,
      Floorplan floorplan,
      CGL.GeometryBuilder torus,
      TORUS.TorusKnotHelper tkhelper,
      int kWidth,
      int kHeight) {
    final THEME.Theme theme = THEME.allThemes[THEME.kModeSketch];
    final Shape shape = CITY.MakeBuildings(
        cgl,
        rng,
        666.0,
        floorplan.GetBuildings(),
        tkhelper,
        kWidth,
        kHeight,
        ["delta", "alpha"],
        theme);

    fb = CGL.Framebuffer.Default(cgl, w, h);

    final VM.Vector3 dirLight = VM.Vector3(2.0, -1.2, 0.5);
    CGL.Light light = CGL.DirectionalLight(
        "dir", dirLight, CGL.ColorWhite, CGL.ColorBlack, 1000.0);

    illumination = CGL.Illumination()..AddLight(light);

    screen = CGL.Framebuffer.Screen(cgl);

    programPrep = CGL.RenderProgram(
        "sketch-prep", cgl, sketchPrepVertexShader, sketchPrepFragmentShader);
    program = CGL.RenderProgram(
        "final", cgl, sketchVertexShader, sketchFragmentShader);

    Map<String, CGL.Material> materials =
        FACADE.MakeMaterialsForTheme(cgl, theme, kLogos, rng, 0.0);

    Map<CGL.Material, CGL.GeometryBuilder> consolidator = {};

    final VM.Matrix4 id4 = VM.Matrix4.identity();
    final VM.Matrix3 id3 = VM.Matrix3.identity();

    for (String m in shape.builders.keys) {
      final CGL.Material mat = materials[m];
      final CGL.GeometryBuilder gb = shape.builders[m];
      if (consolidator.containsKey(mat)) {
        consolidator[mat].MergeAndTakeOwnership(gb, id4, id3);
      } else {
        consolidator[mat] = gb;
      }
    }
    for (CGL.Material mat in consolidator.keys) {
      mat
        ..SetUniform(CGL.uModelMatrix, VM.Matrix4.identity())
        ..SetUniform(CGL.uShininess, 10.0)
        ..SetUniform(CGL.uTexture2, fb.colorTexture);
      meshes[mat] =
          CGL.GeometryBuilderToMeshData("", program, consolidator[mat]);
    }
  }

  void Draw(CGL.ChronosGL cgl, CGL.Perspective perspective) {
    fb.Activate(CGL.GL_CLEAR_ALL, 0, 0, w, h);
    for (CGL.Material m in meshes.keys) {
      programPrep.Draw(meshes[m], [perspective, illumination, m]);
    }
    screen.Activate(CGL.GL_CLEAR_ALL, 0, 0, w, h);
    for (CGL.Material m in meshes.keys) {
      program.Draw(meshes[m], [perspective, illumination, m]);
    }
  }

  int w, h;
  CGL.Framebuffer fb;
  CGL.Illumination illumination;
  CGL.RenderProgram programPrep;
  CGL.Framebuffer screen;
  Map<CGL.Material, CGL.MeshData> meshes = {};
}

class SceneCityNight extends Scene {
  SceneCityNight(
      CGL.ChronosGL cgl,
      Math.Random rng,
      this.w,
      this.h,
      Floorplan floorplan,
      CGL.GeometryBuilder torus,
      TORUS.TorusKnotHelper tkhelper,
      int kWidth,
      int kHeigth) {
    screen = CGL.Framebuffer.Screen(cgl);

    program = CGL.RenderProgram(
        "final", cgl, pcTexturedVertexShader, pcTexturedFragmentShader);
    final THEME.Theme theme = THEME.allThemes[THEME.kModeNight];

    Shape shape = CITY.MakeBuildings(cgl, rng, 666.0, floorplan.GetBuildings(),
        tkhelper, kWidth, kHeigth, ["delta", "alpha"], theme);

    Map<String, CGL.Material> materials =
        FACADE.MakeMaterialsForTheme(cgl, theme, kLogos, rng, 0.0);

    Map<CGL.Material, CGL.GeometryBuilder> consolidator = {};

    final VM.Matrix4 id4 = VM.Matrix4.identity();
    final VM.Matrix3 id3 = VM.Matrix3.identity();

    for (String m in shape.builders.keys) {
      final CGL.Material mat = materials[m];
      final CGL.GeometryBuilder gb = shape.builders[m];
      if (consolidator.containsKey(mat)) {
        consolidator[mat].MergeAndTakeOwnership(gb, id4, id3);
      } else {
        consolidator[mat] = gb;
      }
    }
    for (CGL.Material mat in consolidator.keys) {
      mat..SetUniform(CGL.uModelMatrix, VM.Matrix4.identity());
      meshes[mat] =
          CGL.GeometryBuilderToMeshData("", program, consolidator[mat]);
    }
  }

  void Draw(CGL.ChronosGL cgl, CGL.Perspective perspective) {
    screen.Activate(CGL.GL_CLEAR_ALL, 0, 0, w, h);
    for (CGL.Material m in meshes.keys)
      program.Draw(meshes[m], [perspective, m]);
  }

  int w, h;
  Map<CGL.Material, CGL.MeshData> meshes = {};
  CGL.Framebuffer screen;
}

class SceneCityWireframe extends Scene {
  SceneCityWireframe(
      CGL.ChronosGL cgl,
      Math.Random rng,
      this.w,
      this.h,
      Floorplan floorplan,
      CGL.GeometryBuilder torus,
      TORUS.TorusKnotHelper tkhelper,
      int kWidth,
      int kHeight) {
    screen = CGL.Framebuffer.Screen(cgl);

    program = CGL.RenderProgram(
        "final", cgl, wireframeVertexShader, wireframeFragmentShader);

    programLogo = CGL.RenderProgram(
        "final", cgl, pcTexturedVertexShader, pcTexturedFragmentShader);
    final THEME.Theme theme = THEME.allThemes[THEME.kModeWireframe];

    Shape shape = CITY.MakeBuildings(cgl, rng, 666.0, floorplan.GetBuildings(),
        tkhelper, kWidth, kHeight, ["delta", "alpha"], theme);

    Map<String, CGL.Material> materials =
        FACADE.MakeMaterialsForTheme(cgl, theme, kLogos, rng, 0.0);

    Map<CGL.Material, CGL.GeometryBuilder> consolidator = {};

    final VM.Matrix4 id4 = VM.Matrix4.identity();
    final VM.Matrix3 id3 = VM.Matrix3.identity();

    for (String m in shape.builders.keys) {
      final CGL.Material mat = materials[m];
      final CGL.GeometryBuilder gb = shape.builders[m];
      if (consolidator.containsKey(mat)) {
        consolidator[mat].MergeAndTakeOwnership(gb, id4, id3);
      } else {
        consolidator[mat] = gb;
      }
    }
    for (CGL.Material mat in consolidator.keys) {
      mat
        ..SetUniform(CGL.uModelMatrix, VM.Matrix4.identity())
        ..SetUniform(uWidth, 1.5)
        ..SetUniform(CGL.uColor, VM.Vector3(1.0, 1.0, 0.0))
        ..SetUniform(CGL.uColorAlpha, VM.Vector4(1.0, 0.0, 0.0, 1.0))
        ..SetUniform(CGL.uColorAlpha2, VM.Vector4(0.1, 0.0, 0.0, 1.0));
      if (mat.name == CONFIG.kLogoMat) {
        meshes[mat] =
            CGL.GeometryBuilderToMeshData("", programLogo, consolidator[mat]);
      } else {
        meshes[mat] =
            CGL.GeometryBuilderToMeshData("", program, consolidator[mat]);
      }
    }
  }

  void Draw(CGL.ChronosGL cgl, CGL.Perspective perspective) {
    screen.Activate(CGL.GL_CLEAR_ALL, 0, 0, w, h);
    for (CGL.Material m in meshes.keys)
      if (m.name == CONFIG.kLogoMat) {
        programLogo.Draw(meshes[m], [perspective, m]);
      } else {
        program.Draw(meshes[m], [perspective, m]);
      }
  }

  int w, h;
  Map<CGL.Material, CGL.MeshData> meshes = {};
  CGL.Framebuffer screen;
  CGL.RenderProgram programLogo;
}

class AllScenes {
  AllScenes(CGL.ChronosGL cgl, Math.Random rng, int w, int h) {
    // Building Scenes

    LogInfo("creating building scenes");

    final TORUS.TorusKnotHelper tkhelper =
        TORUS.TorusKnotHelper(TORUS.kRadius, 2, 3, TORUS.kHeightScale);

    final Floorplan floorplan = Floorplan(TORUS.kHeight, TORUS.kWidth, 10, rng);
    //final CGL.GeometryBuilder torus = TorusKnot(kHeight, kWidth);
    final CGL.GeometryBuilder torusLowRez =
        TORUS.TorusKnot(TORUS.kHeight ~/ 4, TORUS.kWidth ~/ 4);

    final CGL.GeometryBuilder torusLowRezInside =
        TORUS.InsideTorusKTexture(TORUS.kHeight ~/ 4, TORUS.kWidth ~/ 4);

    outsideStreet = Scene.OutsideStreet(cgl, floorplan, torusLowRez);

    outsideNightBuildings = SceneCityNight(
        cgl, rng, w, h, floorplan, null, tkhelper, TORUS.kWidth, TORUS.kHeight);

    outsideWireframeBuildings = SceneCityWireframe(
        cgl, rng, w, h, floorplan, null, tkhelper, TORUS.kWidth, TORUS.kHeight);

    outsideSketch = SceneSketch(
        cgl, rng, w, h, floorplan, null, tkhelper, TORUS.kWidth, TORUS.kHeight);

    LogInfo("creating buildingcenes done");

    // Other Scenes
    insideGOL1 = SceneGOL.Variant1(cgl, w, h, torusLowRezInside, rng);
    insideGOL2 = SceneGOL.Variant2(cgl, w, h, torusLowRezInside, rng);

    sky = Scene.Sky(cgl, w, h);
    sky2 = Scene.Sky2(cgl, w, h);
    portal = Scene.Portal(cgl);
    finale = Scene.Finale(cgl);

    LogInfo("creating other scenes done");
    CGL.Framebuffer.Screen(cgl).Activate(CGL.GL_CLEAR_ALL, 0, 0, w, h);
  }

  Scene outsideStreet;

  Scene outsideWireframeBuildings;

  Scene outsideNightBuildings;

  Scene outsideSketch;

  Scene insideGOL1;
  Scene insideGOL2;

  Scene portal;
  Scene finale;
  Scene sky;
  Scene sky2;

  // Note: updates tkc as a side-effect
  void PlacePortal(double timeMs, double speed, double pos, double radius,
      TORUS.TorusKnotCamera tkc) {
    // print("portal ${timeMs}");
    tkc.SetTubeRadius(radius);
    tkc.animate(pos, speed, gCameraRoute.value);
    VM.Matrix4 mat = VM.Matrix4.identity()
      ..rotateZ(timeMs / 500.0)
      ..setTranslation(tkc.getPoint());
    portal.mat.ForceUniform(CGL.uModelMatrix, mat);
  }

  void UpdateCameras(
      String name,
      CGL.Perspective perspective,
      double timeMs,
      double speed,
      double radius,
      TORUS.TorusKnotCamera tkc,
      InitialApproachCamera iac,
      FinaleCamera fc,
      CGL.OrbitCamera oc) {
    switch (name) {
      case "wireframe-orbit":
        perspective.UpdateCamera(iac);
        iac.radius = TORUS.kRadius * 6.0;
        iac.animate(timeMs);
        break;
      case "night-orbit":
        perspective.UpdateCamera(iac);
        iac.radius = TORUS.kRadius * 6.0;
        iac.animate(timeMs);
        break;
      case "wireframe-outside":
      case "night-outside":
      case "sketch-outside":
        tkc.SetTubeRadius(TORUS.kTubeRadius + 50.0);
        perspective.UpdateCamera(tkc);
        tkc.animate(timeMs, speed, gCameraRoute.value);
        break;
      case "plasma-inside":
      case "wireframe-inside-hexagon":
      case "wireframe-inside":
      case "wireframe-inside-varying-width":
      case "gol-inside":
      case "gol2-inside":
      case "fractal-inside":
        tkc.SetTubeRadius(1.0);
        perspective.UpdateCamera(tkc);
        tkc.animate(timeMs, speed, gCameraRoute.value);
        break;
      case "finale":
        fc.animate(timeMs);
        perspective.UpdateCamera(fc);
        break;
      default:
        assert(false, "unexepected theme ${name}");
    }
  }

  void RenderScene(String name, CGL.ChronosGL cgl, CGL.Perspective perspective,
      double timeMs) {
    portal.mat.ForceUniform(CGL.uTime, timeMs);
    finale.mat.ForceUniform(CGL.uTime, timeMs / 1000.0);

    // TODO: switch this all to sky.Draw()
    switch (name) {
      case "wireframe-outside":
        outsideWireframeBuildings.Draw(cgl, perspective);
        outsideStreet.Draw(cgl, perspective);
        //sky2.Draw(cgl, perspective);
        sky.Draw(cgl, perspective);
        portal.Draw(cgl, perspective);
        break;
      case "wireframe-orbit":
        outsideWireframeBuildings.Draw(cgl, perspective);
        outsideStreet.Draw(cgl, perspective);
        break;
      case "gol-inside":
        insideGOL1.Draw(cgl, perspective);
        portal.Draw(cgl, perspective);
        break;
      case "gol2-inside":
        insideGOL2.Draw(cgl, perspective);
        portal.Draw(cgl, perspective);
        break;
      case "sketch-outside":
        outsideSketch.Draw(cgl, perspective);
        outsideStreet.Draw(cgl, perspective);
        //sky2.Draw(cgl, perspective);
        sky.Draw(cgl, perspective);
        portal.Draw(cgl, perspective);
        break;
      case "night-outside":
        outsideNightBuildings.Draw(cgl, perspective);
        outsideStreet.Draw(cgl, perspective);
        sky2.Draw(cgl, perspective);
        portal.Draw(cgl, perspective);
        break;
      case "night-orbit":
        outsideNightBuildings.Draw(cgl, perspective);
        outsideStreet.Draw(cgl, perspective);
        sky2.Draw(cgl, perspective);
        break;
      case "finale":
        finale.Draw(cgl, perspective);
        sky2.Draw(cgl, perspective);
        break;
      default:
        assert(false, "unexepected theme ${name}");
    }
  }
}

void main2() {
  final CGL.StatsFps fps =
      CGL.StatsFps(HTML.document.getElementById("stats"), "blue", "gray");
  final params = HashParameters();
  LogInfo("Params: ${params}");
  if (params.containsKey("develop")) {
    print("development mode");
    for (HTML.Element e in HTML.document.querySelectorAll(".control")) {
      print("disable control: ${e}");
      e.style.display = "block";
    }
  } else {
    gMode.value = "demo";
  }

  IntroduceShaderVars();
  GOL.RegisterShaderVars();
  SKY.RegisterShaderVars();

  final HTML.CanvasElement canvas =
      HTML.document.querySelector('#webgl-canvas');
  final CGL.ChronosGL cgl = CGL.ChronosGL(canvas)..enable(CGL.GL_CULL_FACE);

  var ext = cgl.GetGlExtensionAnisotropic();
  if (ext == null) {
    CGL.LogError("No anisotropic texture extension");
  } else {
    final int mafl = cgl.MaxAnisotropicFilterLevel();
    FACADE.defaultAnisoLevel = mafl > 4 ? 4 : mafl;
    print("setting AnisoLevel to ${FACADE.defaultAnisoLevel}");
  }

  // Cameras

  final TORUS.TorusKnotCamera tkc =
      TORUS.TorusKnotCamera(TORUS.kRadius, 2, 3, TORUS.kHeightScale);
  // manual
  final CGL.OrbitCamera mc =
      CGL.OrbitCamera(TORUS.kRadius * 1.5, 0.0, 0.0, canvas)
        ..mouseWheelFactor = -0.2;

  final CGL.OrbitCamera oc = CGL.OrbitCamera(100, 0.0, 0.0, canvas);
  final FinaleCamera fc = FinaleCamera();

  final InitialApproachCamera iac = InitialApproachCamera();

  // Misc
  final CGL.Perspective perspective =
      CGL.PerspectiveResizeAware(cgl, canvas, tkc, zNear, zFar)
        ..UpdateFov(cameraFov);

  final Math.Random rng = Math.Random(0);

  tkc.SetTubeRadius(TORUS.kTubeRadius + 50.0);
  tkc.animate(0, 1.0, "${gScript[1].route}");
  iac.ci.setDst(tkc.transform);
  iac.cameraFinalPos.setFrom(tkc.getPoint());

  AllScenes allScenes =
      AllScenes(cgl, rng, canvas.clientWidth, canvas.clientHeight);

  double zeroTimeMs = 0.0;
  double lastTimeMs = 0.0;

  String lastTheme;

  void animate(num timeMs) {
    double elapsed = timeMs - lastTimeMs;
    lastTimeMs = timeMs + 0.0;

    if (gTheme.value != lastTheme) {
      zeroTimeMs = timeMs;
      iac.azimuth = 0.0;
      lastTheme = gTheme.value;
    }

    gPaused.style.display = "none";
    double t = timeMs - zeroTimeMs;
    if (gMode.value == "manual-camera") {
      perspective.UpdateCamera(mc);
      // allow the camera to also reflect mouse movement.
      mc.animate(elapsed);
      allScenes.RenderScene(gTheme.value, cgl, perspective, t);
    } else if (gMode.value == "demo") {
      if (gSoundtrack.ended ||
          gSoundtrack.currentTime == 0.0 ||
          gSoundtrack.paused) {
        gPaused.style.display = "block";
      }
      if (gSoundtrack.ended || gSoundtrack.currentTime == 0.0) {
        print("Music started ${gSoundtrack.ended} ${gSoundtrack.currentTime}");
        gSoundtrack.play();
      } else {
        t = 1000.0 * gSoundtrack.currentTime;
        // also check gMusic.ended
        for (ScriptScene s in gScript) {
          if (t < s.durationMs) {
            gCameraRoute.selectedIndex = s.route ~/ 3;
            allScenes.PlacePortal(t, s.durationMs, s.speed, s.radius, tkc);
            allScenes.UpdateCameras(
                s.name, perspective, t, s.speed, s.radius, tkc, iac, fc, oc);
            allScenes.RenderScene(s.name, cgl, perspective, t);
            gTheme.value = s.name;
            break;
          }
          t -= s.durationMs;
        }
      }
    } else {
      double radius = TORUS.kTubeRadius + 50.0;
      if (gMode.value.contains("inside")) {
        radius = 1.0;
      }
      // place portal early so we can see it right aways
      allScenes.PlacePortal(t, 10000, 1.0, radius, tkc);
      allScenes.UpdateCameras(
          gTheme.value, perspective, t, 0.5, radius, tkc, iac, fc, oc);
      allScenes.RenderScene(gTheme.value, cgl, perspective, t);
    }

    gClock.text = DurationFormat(t);
    HTML.window.animationFrame.then(animate);
    fps.UpdateFrameCount(lastTimeMs);
  }

  HTML.document.body.onKeyDown.listen((HTML.KeyboardEvent e) {
    LogInfo("key pressed ${e.which} ${e.target.runtimeType}");
    if (e.target.runtimeType == HTML.InputElement) {
      return;
    }
    String cmd = new String.fromCharCodes([e.which]);
    if (cmd == " ") {
      if (gSoundtrack.paused || gSoundtrack.currentTime == 0.0) {
        gSoundtrack.play();
      } else {
        gSoundtrack.pause();
      }
    }
  });

  gPaused.onClick.listen((HTML.Event ev) {
    ev.preventDefault();
    ev.stopPropagation();
    gSoundtrack.play();
    return false;
  });

  gInitializing.style.display = "none";
  animate(0.0);
}

void main() {
  try {
    main2();
  } catch (e) {
    gInitializing.text = "Problem: ${e}";
  }
}
