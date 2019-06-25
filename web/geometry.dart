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
This file contains abstractions for Meshes and Materials that isolate us
from the underlying rendering system.
renderer.dart translates these abstractions to ChronosGL
*/

library geometry;

import 'package:chronosgl/chronosgl.dart'
    if (dart.library.io) "fake_chronos.dart" as CGL;
import 'package:vector_math/vector_math.dart' as VM;

class Rect {
  Rect(this.x, this.y, this.w, this.h) {
    assert(w >= 0);
    assert(h >= 0);
  }

  Rect.withOffset(double x, double y, double w, double h, double offset)
      : this(x - offset, y - offset, w + 2 * offset, h + 2 * offset);

  Rect Clone() {
    return Rect(x, y, w, h);
  }

  double x;
  double y;
  double w;
  double h;

  void IncreaseByOffset(double offset) {
    x -= offset;
    y -= offset;
    w += 2 * offset;
    h += 2 * offset;
  }

  @override
  String toString() {
    return "Rect($x, $y, $w, $h)";
  }

  bool Contains(Rect o) {
    return x <= o.x && o.x + o.w <= x + w && y <= o.y && o.y + o.h <= y + h;
  }

  VM.Vector2 center() {
    return VM.Vector2(x + w / 2.0, y + h / 2.0);
  }
}

final List<VM.Vector2> kNoUV3 = [
  VM.Vector2(0.0, 0.0),
  VM.Vector2(0.0, 0.0),
  VM.Vector2(0.0, 0.0)
];

class Triad {
  Triad(this.v, [List<VM.Vector2> uvs]) {
    t = (uvs == null) ? kNoUV3 : uvs;
  }

  List<VM.Vector3> v;
  List<VM.Vector2> t;
}

class Quad {
  Quad(this.v, Rect uv) {
    _PopulateUV(uv);
  }

  Quad.fromXZTop(Rect r, double y, Rect uv) {
    VM.Vector3 vec(double a, double b) {
      return VM.Vector3(a, y, b);
    }

    VM.Vector3 a = vec(r.x, r.y);
    VM.Vector3 b = vec(r.x, r.y + r.h);
    VM.Vector3 c = vec(r.x + r.w, r.y + r.h);
    VM.Vector3 d = vec(r.x + r.w, r.y);
    _PopulateVertices([a, b, c, d], true);
    _PopulateUV(uv);
  }

  Quad.fromXZBottom(Rect r, double y, Rect uv) {
    VM.Vector3 vec(double a, double b) {
      return VM.Vector3(a, y, b);
    }

    VM.Vector3 a = vec(r.x, r.y);
    VM.Vector3 b = vec(r.x, r.y + r.h);
    VM.Vector3 c = vec(r.x + r.w, r.y + r.h);
    VM.Vector3 d = vec(r.x + r.w, r.y);
    _PopulateVertices([a, b, c, d], false);
    _PopulateUV(uv);
  }

  Quad.fromXZflipped(Rect r, double y, bool front, Rect uv) {
    VM.Vector3 vec(double a, double b) {
      return VM.Vector3(a, y, b);
    }

    VM.Vector3 a = vec(r.x, r.y);
    VM.Vector3 b = vec(r.x, r.y + r.h);
    VM.Vector3 c = vec(r.x + r.w, r.y + r.h);
    VM.Vector3 d = vec(r.x + r.w, r.y);
    _PopulateVertices([a, b, c, d], front);
    _PopulateUVFlipped(uv);
  }

  Quad.fromXYFront(Rect r, double z, Rect uv) {
    VM.Vector3 vec(double a, double b) {
      return VM.Vector3(a, b, z);
    }

    VM.Vector3 a = vec(r.x, r.y);
    VM.Vector3 b = vec(r.x, r.y + r.h);
    VM.Vector3 c = vec(r.x + r.w, r.y + r.h);
    VM.Vector3 d = vec(r.x + r.w, r.y);
    _PopulateVertices([a, b, c, d], true);
    _PopulateUV(uv);
  }

  Quad.fromXYBack(Rect r, double z, Rect uv) {
    VM.Vector3 vec(double a, double b) {
      return VM.Vector3(a, b, z);
    }

    VM.Vector3 a = vec(r.x, r.y);
    VM.Vector3 b = vec(r.x, r.y + r.h);
    VM.Vector3 c = vec(r.x + r.w, r.y + r.h);
    VM.Vector3 d = vec(r.x + r.w, r.y);
    _PopulateVertices([a, b, c, d], false);
    _PopulateUV(uv);
  }

  Quad.fromZYRight(Rect r, double x, Rect uv) {
    VM.Vector3 vec(double a, double b) {
      return VM.Vector3(x, a, b);
    }

    VM.Vector3 a = vec(r.y, r.x);
    VM.Vector3 b = vec(r.y + r.h, r.x);
    VM.Vector3 c = vec(r.y + r.h, r.x + r.w);
    VM.Vector3 d = vec(r.y, r.x + r.w);
    _PopulateVertices([a, b, c, d], true);
    _PopulateUV(uv);
  }

  Quad.fromZYLeft(Rect r, double x, Rect uv) {
    VM.Vector3 vec(double a, double b) {
      return VM.Vector3(x, a, b);
    }

    VM.Vector3 a = vec(r.y, r.x);
    VM.Vector3 b = vec(r.y + r.h, r.x);
    VM.Vector3 c = vec(r.y + r.h, r.x + r.w);
    VM.Vector3 d = vec(r.y, r.x + r.w);
    _PopulateVertices([a, b, c, d], false);
    _PopulateUV(uv);
  }

  List<VM.Vector3> v = [];
  List<VM.Vector2> t = [];

  void _PopulateVertices(List<VM.Vector3> vertices, bool front) {
    if (front) {
      // 23
      // 14
      v.addAll(vertices);
    } else {
      // 32
      // 41
      v.addAll(vertices.reversed);
    }
  }

  void _PopulateUV(Rect uv) {
    t.add(VM.Vector2(uv.x + uv.w, uv.y));
    t.add(VM.Vector2(uv.x + uv.w, uv.y + uv.h));
    t.add(VM.Vector2(uv.x, uv.y + uv.h));
    t.add(VM.Vector2(uv.x, uv.y));
  }

  void _PopulateUVFlipped(Rect uv) {
    t.add(VM.Vector2(uv.x, uv.y + uv.h));
    t.add(VM.Vector2(uv.x + uv.w, uv.y + uv.h));
    t.add(VM.Vector2(uv.x + uv.w, uv.y));
    t.add(VM.Vector2(uv.x, uv.y));
  }
}

final _epsilon = 0.05;
final Rect kFullUV = Rect(0.0, 0.0, 1.0, 1.0);
final Rect kAlmostFullUV =
    Rect(_epsilon, _epsilon, 1.0 - 2 * _epsilon, 1.0 - 2 * _epsilon);

class ColorMat {
  ColorMat(this.mat, this.color);

  String mat;
  VM.Vector3 color;
}

class Shape {
  Shape(this._attributes, this._pointAttributes);

  Map<String, CGL.GeometryBuilder> builders = {};
  List<String> _attributes;
  List<String> _pointAttributes;

  List<VM.Vector4> centers3 = [
    VM.Vector4(1.0, 0.0, 0.0, 0.0),
    VM.Vector4(0.0, 1.0, 0.0, 0.0),
    VM.Vector4(0.0, 0.0, 1.0, 0.0)
  ];

  List<VM.Vector4> centers4 = [
    VM.Vector4(1.0, 0.0, 0.0, 1.0),
    VM.Vector4(1.0, 1.0, 0.0, 1.0),
    VM.Vector4(0.0, 1.0, 0.0, 1.0),
    VM.Vector4(0.0, 0.0, 0.0, 1.0)
  ];

  VM.Vector3 temp = VM.Vector3.zero();
  VM.Vector3 norm = VM.Vector3.zero();

  CGL.GeometryBuilder Get(String m) {
    return builders.putIfAbsent(m, initialBuilder);
  }

  void AddPoint(VM.Vector3 pos, double size, ColorMat m) {
    assert(false, "no points");
    final CGL.GeometryBuilder gb =
        builders.putIfAbsent(m.mat, initialBuilderPoints);

    gb.AddVertex(pos);
    gb.AddAttributeVector3(CGL.aColor, m.color);
    gb.AddAttributeDouble(CGL.aPointSize, size);
  }

  void AddManyPoints(List<VM.Vector3> pos, double size, ColorMat m) {
    assert(false, "no points");
    final CGL.GeometryBuilder gb =
        builders.putIfAbsent(m.mat, initialBuilderPoints);

    for (VM.Vector3 p in pos) {
      gb.AddVertex(p);
      gb.AddAttributeVector3(CGL.aColor, m.color);
      gb.AddAttributeDouble(CGL.aPointSize, size);
    }
  }

  void AddQuad(Quad q, ColorMat m) {
    final CGL.GeometryBuilder gb = builders.putIfAbsent(m.mat, initialBuilder);

    gb.AddVerticesFace4TakeOwnership(q.v);
    gb.AddAttributesVector2TakeOwnership(CGL.aTexUV, q.t);
    gb.AddAttributesVector3TakeOwnership(
        CGL.aColor, [m.color, m.color, m.color, m.color]);
    gb.AddAttributesVector4TakeOwnership(CGL.aCenter, centers4);
    CGL.NormalFromPoints(q.v[0], q.v[1], q.v[2], temp, norm);
    gb.AddAttributesVector3(CGL.aNormal, [norm, norm, norm, norm]);
  }

  void AddTriad(Triad t, ColorMat m) {
    final CGL.GeometryBuilder gb = builders.putIfAbsent(m.mat, initialBuilder);

    gb.AddVerticesFace3TakeOwnership(t.v);

    gb.AddAttributesVector2TakeOwnership(CGL.aTexUV, t.t);
    gb.AddAttributesVector3TakeOwnership(
        CGL.aColor, [m.color, m.color, m.color]);
    gb.AddAttributesVector4TakeOwnership(CGL.aCenter, centers3);
    CGL.NormalFromPoints(t.v[0], t.v[1], t.v[2], temp, norm);
    gb.AddAttributesVector3(CGL.aNormal, [norm, norm, norm]);
  }

  CGL.GeometryBuilder initialBuilder() {
    CGL.GeometryBuilder gb = CGL.GeometryBuilder(false);
    for (String a in _attributes) {
      gb.EnableAttribute(a);
    }
    return gb;
  }

  CGL.GeometryBuilder initialBuilderPoints() {
    CGL.GeometryBuilder gb = CGL.GeometryBuilder(true);
    for (String a in _pointAttributes) {
      gb.EnableAttribute(a);
    }
    return gb;
  }

  @override
  String toString() {
    List<String> out = [];
    for (CGL.GeometryBuilder gb in builders.values) {
      out.add(gb.toString());
      out.add("manifold: ${gb.IsOrientableManifoldWithBoundaries()}");
    }
    return out.join("\n");
  }
}
