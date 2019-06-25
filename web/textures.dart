library textures;

import 'dart:html' as HTML;
import 'dart:math' as Math;

import 'package:chronosgl/chronosgl.dart' as CGL;

CGL.Texture MakeNoiseTexture(CGL.ChronosGL cgl, Math.Random rand) {
  HTML.CanvasElement canvas = new HTML.CanvasElement();
  canvas.width = 512 * 2;
  canvas.height = 512 * 2;
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

  return CGL.ImageTexture(cgl, "noise", canvas, CGL.TexturePropertiesMipmap);
}


