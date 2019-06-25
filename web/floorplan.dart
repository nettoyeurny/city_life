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
This file contains code for laying out buildings in the world
and managing the cars.
*/

library pc_floorplan;

import 'dart:html' as HTML;
import 'dart:math';
import 'dart:typed_data';

import 'package:vector_math/vector_math.dart' as VM;

import 'geometry.dart' as GEOMETRY;
import 'logging.dart';

const double kMaxCarMovement = 0.5;

const int kMinBuildingSize = 12;
const int kMinRoadDistance = 3 * kMinBuildingSize;

const int kTileEmpty = 0;

// Order is important
const int kTileSidewalkLight = 1;
const int kTileSidewalk = 2;
const int kTileDivider = 3;
const int kTileLane = 4;

const int kTileBuildingBorder = 8;
const int kTileBuildingTower = 9;
const int kTileBuildingBlocky = 10;
const int kTileBuildingModern = 11;
const int kTileBuildingSimple = 12;

const int kDirEast = 16;
const int kDirWest = 32;
const int kDirNorth = 64;
const int kDirSouth = 128;

int FloorplanGetTileType(int t) {
  return t & 0xf;
}

int FloorplanGetTileDir(int t) {
  return t & 0xf0;
}

int CountBits(int i) {
  int n = 0;
  int b = i;
  while (true) {
    if (b == 0) break;
    n++;
    b &= b - 1;
  }
  return n;
}

bool OnlyOneBitSet(int b) {
  return b & (b - 1) == 0;
}

int RandomSetBit(Random rng, int bits, int n) {
  if (n == 1) return bits;
  int s = 1 + rng.nextInt(n - 1);
  int last;
  for (int i = 0; i < s; i++) {
    last = bits;
    bits &= bits - 1;
  }
  return last ^ bits;
}

class WorldMap {
  WorldMap(this._w, this._h, bool isTorus) {
    _tiles = Uint8List(_w * _h);
    for (int i = 0; i < _w * _h; i++) {
      _tiles[i] = kTileEmpty;
    }
  }

  final int _w;
  final int _h;
  Uint8List _tiles;

  //Uint8List _cars;
  int get width => _w;

  int get height => _h;

  int GetTile(int x, int y) {
    int index = x + y * _w;
    return _tiles[index];
  }

  int GetTilePos(final PosInt pos) {
    if (pos.x < 0 || pos.y < 0 || pos.x >= _w || pos.y >= _h) return kTileEmpty;
    return GetTile(pos.x, pos.y);
  }

  bool IsEmpty(int x, int y) {
    if (x >= _w) x -= _w;
    if (y >= _h) y -= _h;
    int index = x + y * _w;
    return _tiles[index] == kTileEmpty;
  }

  bool IsEmptyPlot(int x, int y, int w, int d) {
    for (int i = 0; i < w; i++) {
      if (!IsEmpty(x + i, y)) return false;
      if (!IsEmpty(x + i, y + d - 1)) return false;
    }

    for (int i = 0; i < d; i++) {
      if (!IsEmpty(x, y + i)) return false;
      if (!IsEmpty(x + w - 1, y + i)) return false;
    }

    return true;
  }

  // This relies on having streets all around - sentinels
  GEOMETRY.Rect MaxEmptyPlotContaining(int x, int y) {
    int x1 = x;
    int x2 = x;
    int y1 = y;
    int y2 = y;
    for (x1--; IsEmpty(x1, y); x1--);
    x1++;
    for (x2++; IsEmpty(x2, y); x2++);
    x2--;
    for (y1--; IsEmpty(x, y1); y1--);
    y1++;
    for (y2++; IsEmpty(x, y2); y2++);
    y2--;
    return GEOMETRY.Rect(x1 * 1.0, y1 * 1.0, x2 - x1 + 1.0, y2 - y1 + 1.0);
  }

  void MergeTile(int x, int y, int new_kind) {
    //LogInfo("merge");
    final int index = (x % _w) + (y % _h) * _w;
    final int old_kind = _tiles[index];
    final int old_type = FloorplanGetTileType(old_kind);
    final int new_type = FloorplanGetTileType(new_kind);
    if (new_type == old_type) {
      _tiles[index] = new_kind | old_kind;
      assert(CountBits(FloorplanGetTileDir(_tiles[index])) <= 2);
    } else if (old_type < new_type) {
      _tiles[index] = new_kind;
    }
  }

  void ForceTile(int x, int y, int kind) {
    int index = x + y * _w;
    _tiles[index] = kind;
  }

  void ForceTilePos(PosInt p, int kind) {
    return ForceTile(p.x, p.y, kind);
  }

  void MarkPlot(GEOMETRY.Rect plot, int kind) {
    int x = plot.x.floor();
    int y = plot.y.floor();
    int w = plot.w.floor();
    int h = plot.h.floor();
    for (int i = 0; i < w; i++) {
      for (int j = 0; j < h; j++) {
        ForceTile(x + i, y + j, kind);
      }
    }
  }

  void MarkStrip(int y, int x1, int x2, int dir, int kind) {
    for (int x = x1; x < x2; x++) {
      if (dir & (kDirEast | kDirWest) != 0) {
        MergeTile(x, y, kind | dir);
      } else {
        MergeTile(y, x, kind | dir);
      }
    }
  }

  Map<int, int> TileHistogram() {
    List<int> counters = List<int>(256);
    for (int i = 0; i < counters.length; i++) counters[i] = 0;

    for (int i = 0; i < _w * _h; i++) {
      counters[FloorplanGetTileType(_tiles[i])]++;
    }
    Map<int, int> c = {};
    for (int i = 0; i < counters.length; i++) {
      if (counters[i] > 0) c[i] = counters[i];
    }
    return c;
  }
}

class Road {
  Road(this._pos, int dir1, int dir2, int width, int len, WorldMap map) {
    _width = width;
    _divider = 0;
    if (width % 2 == 1) {
      width--;
      _divider = 1;
    }
    _sidewalk = max(2, (width - 10)) ~/ 2;
    width -= 2 * _sidewalk;
    _lanes = width ~/ 2;

    LogDebug(
        "@@@ ROAD ${_pos} ${len} w:${_width} d:${_divider} l:${_lanes} ${dir1} ${dir2}");

    int x1 = 0;
    int x2 = len;
    int y = _pos;
    int t = y;
    t += _sidewalk - 1;
    for (; y < t; y++) map.MarkStrip(y, x1, x2, dir1, kTileSidewalk);
    t += 1;
    for (; y < t; y++) map.MarkStrip(y, x1, x2, dir1, kTileSidewalkLight);
    t += _lanes;
    for (; y < t; y++) map.MarkStrip(y, x1, x2, dir1, kTileLane);
    t += _divider;
    for (; y < t; y++) map.MarkStrip(y, x1, x2, dir1, kTileDivider);
    t += _lanes;
    for (; y < t; y++) map.MarkStrip(y, x1, x2, dir2, kTileLane);
    t += 1;
    for (; y < t; y++) map.MarkStrip(y, x1, x2, dir2, kTileSidewalkLight);
    t += _sidewalk - 1;
    for (; y < t; y++) map.MarkStrip(y, x1, x2, dir2, kTileSidewalk);
  }

  int _pos;
  int _width;
  int _divider;
  int _sidewalk;
  int _lanes;

  @override
  String toString() {
    return "${_pos}: ${_width}";
  }
}

class Building {
  Building(this.plot, this.offset, this.height, this.kind, WorldMap map) {
    base = GEOMETRY.Rect(plot.x + offset, plot.y + offset, plot.w - 2 * offset,
        plot.h - 2 * offset);
    if (map != null) {
      map.MarkPlot(plot, kTileBuildingBorder);
      map.MarkPlot(base, kind);
    }
  }

  GEOMETRY.Rect plot;
  GEOMETRY.Rect base;
  int offset;
  double height;
  int kind;

  String toString() {
    return "plot: ${plot} ${base}  ${offset} ${height} ${kind}";
  }
}

class PosInt {
  PosInt(this.x, this.y);

  PosInt.fromPosDouble(PosDouble p) {
    x = p.x.floor();
    y = p.y.floor();
  }

  PosInt.Clone(PosInt p) {
    x = p.x;
    y = p.y;
  }

  PosInt.CloneWithDir(PosInt p, int dir) {
    x = p.x;
    y = p.y;
    UpdatePos(dir, 1);
  }

  int x;
  int y;

  void UpdatePos(int dir, int dist) {
    switch (dir) {
      case kDirNorth:
        y -= dist;
        break;
      case kDirSouth:
        y += dist;
        break;
      case kDirEast:
        x += dist;
        break;
      case kDirWest:
        x -= dist;
        break;
    }
  }

  @override
  String toString() {
    return "($x, $y)";
  }

  @override
  bool operator ==(dynamic o) => o.x == x && o.y == y;

  @override
  int get hashCode => y * 16 * 1024 + x;
}

int ManhattanDiststance(PosInt a, PosInt b) {
  int dx = a.x - b.x;
  if (dx < 0) dx = -dx;
  int dy = a.y - b.y;
  if (dy < 0) dy = -dy;
  return max(dx, dy);
}

class PosDouble {
  PosDouble(this.x, this.y);

  PosDouble.fromClone(PosDouble p) {
    x = p.x;
    y = p.y;
  }

  PosDouble.fromPosInt(PosInt p) {
    x = p.x * 1.0;
    y = p.y * 1.0;
  }

  double x;
  double y;

  bool InSameCell(PosDouble p) {
    return x.floor() == p.x.floor() && y.floor() == p.y.floor();
  }

  void UpdatePos(int dir, double speed) {
    switch (dir) {
      case kDirNorth:
        y -= speed;
        break;
      case kDirSouth:
        y += speed;
        break;
      case kDirEast:
        x += speed;
        break;
      case kDirWest:
        x -= speed;
        break;
    }
  }
}

List<int> CreateRoadIntervals(Random rng, int start, int end) {
  List<int> out = [];
  for (int x = start;
      x < end;
      x += kMinRoadDistance + rng.nextInt(kMinRoadDistance)) {
    out.add(x);
    out.add(6 + rng.nextInt(6));
  }
  return out;
}

class Floorplan {
  Floorplan(this._w, this._h, int nSkyscrapers, Random rng)
      : _map = WorldMap(_w, _h, true) {
    LogInfo("Creating world ${_w} x ${_h}");

    LogInfo("Creating Roads");
    // Short ring roads
    InitRoads(rng, kDirSouth, kDirNorth, _w, _h);
    // Long torus roads
    InitRoadsSemiRandom(rng, kDirWest, kDirEast, _h, _w);
    LogInfo("Creating Skyscrapers");
    // InitSkyscrapers(rng, nSkyscrapers);
    LogInfo("Creating Regular Buildings");
    InitBuildings(rng);
    LogInfo("world done");
  }

  final List<Building> _buildings = [];
  final List<Road> _roads = [];
  final int _w;
  final int _h;
  final WorldMap _map;

  WorldMap get world_map => _map;

  List<GEOMETRY.Rect> GetTileStrips(int kind) {
    List<GEOMETRY.Rect> out = [];
    for (int x = 0; x < _w; x++) {
      int count = 0;
      for (int y = 0; y <= _h; y++) {
        final int tile =
            (y < _h) ? FloorplanGetTileType(_map.GetTile(x, y)) : kind + 1;
        if (tile == kind) {
          count++;
        } else {
          if (count > 1) {
            out.add(
                GEOMETRY.Rect(x * 1.0, (y - count) * 1.0, 1.0, count * 1.0));
          }
          count = 0;
        }
      }
    }
    for (int y = 0; y < _h; y++) {
      int count = 0;
      for (int x = 0; x <= _w; x++) {
        final int tile =
            (x < _w) ? FloorplanGetTileType(_map.GetTile(x, y)) : kind + 1;
        if (tile == kind) {
          count++;
        } else {
          if (count > 1) {
            out.add(
                GEOMETRY.Rect((x - count) * 1.0, y * 1.0, count * 1.0, 1.0));
          }
          count = 0;
        }
      }
    }

    return out;
  }

  List<Building> GetBuildings() {
    return _buildings;
  }

  void InitRoads(Random rng, int dir1, int dir2, int w, int len) {
    int outerW = 11;
    List<int> intervals = CreateRoadIntervals(
        rng, kMinRoadDistance, w - kMinRoadDistance - outerW ~/ 2);

    for (int i = 0; i < intervals.length; i += 2) {
      _roads.add(Road(intervals[i], dir1, dir2, intervals[i + 1], len, _map));
    }
    // TODO
    // _roads.add(Road(kWorldBorder, dir1, dir2, outerW, _map));
    // _roads.add(Road(_w - kWorldBorder - outerW, dir1, dir2, outerW, _map));

    LogInfo("road count: ${_roads.length}");
  }

  void InitRoadsSemiRandom(Random rng, int dir1, int dir2, int w, int len) {
    int width;

    width = 7 + rng.nextInt(6);
    List<int> intervals = [
      w - width ~/ 2,
      width,
      w ~/ 2 - width ~/ 2,
      width,
      w ~/ 4 - width ~/ 2,
      width,
      w * 3 ~/ 4 - width ~/ 2,
      width,
    ];

    for (int i = 0; i < intervals.length; i += 2) {
      _roads.add(Road(intervals[i], dir1, dir2, intervals[i + 1], len, _map));
    }
  }

  void InitSkyscrapers(Random rng, int n) {
    int numTower = 0;
    int numBlocky = 0;
    int numModern = 0;
    double height = 45.0 + rng.nextInt(10);
    while (n > 0) {
      int x = rng.nextInt(_w);
      int y = rng.nextInt(_h);
      if (!_map.IsEmpty(x, y)) continue;
      GEOMETRY.Rect plot = _map.MaxEmptyPlotContaining(x, y);
      // TODO
      //if (!_wc.IsWithinCenter(plot)) continue;

      if (plot.w < 15 || plot.h < 15) continue;
      while (plot.w * plot.h > 800) {
        if (plot.w > plot.h) {
          double half = (plot.w / 2).floor() * 1.0;
          if (rng.nextBool()) {
            plot.x += plot.w - half;
          }
          plot.w = half;
        } else {
          double half = (plot.h / 2).floor() * 1.0;
          if (rng.nextBool()) {
            plot.y += plot.h - half;
          }
          plot.h = half;
        }
      }
      assert(plot.h >= 10);
      assert(plot.w >= 10);
      int kind = 0;
      // For Skyscrapers we want a base whose sides are multiples of two.
      plot.w = 2.0 * (plot.w / 2.0).floor();
      plot.h = 2.0 * (plot.h / 2.0).floor();
      if ((plot.w - plot.h).abs() < 10 && plot.w + plot.h > 35) {
        numModern++;
        kind = kTileBuildingModern;
      } else if (numModern <= numBlocky && numModern <= numTower) {
        numModern++;
        kind = kTileBuildingModern;
      } else if (numBlocky <= numModern && numBlocky <= numTower) {
        numBlocky++;
        kind = kTileBuildingBlocky;
      } else if (numTower <= numBlocky && numTower <= numModern) {
        numTower++;
        kind = kTileBuildingTower;
      }
      _buildings.add(Building(plot, 1, height, kind, _map));
      n--;
    }
  }

  // Fill rest of m
  void InitBuildings(Random rng) {
    for (int x = 0; x < _w - kMinBuildingSize; x++) {
      for (int y = 0; y < _h - kMinBuildingSize; y++) {
        if (!_map.IsEmpty(x, y)) continue;

        // target building size
        // we may lower this to kMinBuildingSize in each dimension
        // but we must lower the target equally in reach dimension.
        int w = kMinBuildingSize + rng.nextInt(20);
        int h = kMinBuildingSize + rng.nextInt(20);
        //int m = min(w, h);

        int yy;
        for (yy = y; yy < y + h; yy++) {
          if (!_map.IsEmpty(x, yy)) break;
        }

        if (yy - y < kMinBuildingSize) {
          // y += kMinBuildingSize - 1;
          continue;
        }

        int xx;
        for (xx = x; xx < x + w; xx++) {
          if (!_map.IsEmpty(xx, y)) break;
        }

        if (xx - x < kMinBuildingSize) continue;

        int delta = max(y + h - yy, x + w - xx);
        w -= delta;
        h -= delta;

        if (h < kMinBuildingSize) continue;
        if (w < kMinBuildingSize) continue;

        double altitude = 10.0 + rng.nextInt(15);
        int offset = 1;
        int kind = kTileBuildingSimple;
        GEOMETRY.Rect plot = GEOMETRY.Rect(x + 0.0, y + 0.0, w + 0.0, h + 0.0);
        // TODO

        /*
        if (y < _h * 0.1 || y > _h * 0.7) {
          if (0 == rng.nextInt(4)) {
            altitude = 20.0 + rng.nextInt(15) * 4;
          }
        }
        */
        if (rng.nextInt(4) == 1) {
          altitude = 25.0 + rng.nextInt(10) + rng.nextInt(10);
          switch (rng.nextInt(3)) {
            case 0:
              kind = kTileBuildingTower;
              break;
            case 1:
              kind = kTileBuildingBlocky;
              break;
            case 2:
              kind = kTileBuildingModern;
              break;
          }
        }

        /*
        if (_wc.IsWithinCenter(plot)) {
          altitude = 15.0 + rng.nextInt(15);

          kind = rng.nextBool() ? kTileBuildingTower : kTileBuildingBlocky;
        } else if (_wc.IsAtBorder(plot)) {
          altitude = (m).floor() * 1.0 + rng.nextInt(5);
          kind = kTileBuildingSimple;
        } else {
          altitude = (m / 2).floor() * 1.0 + rng.nextInt(5);
          kind = kTileBuildingSimple;
        }
        */
        _buildings.add(Building(plot, offset, altitude, kind, _map));
      }
    }
  }

  @override
  String toString() {
    return "Floorplan buildings[${_buildings.length}]";
  }
}

final Map<int, VM.Vector3> kTileToColorsExtreme = {
  kTileEmpty: VM.Vector3(0.1, 0.1, 0.1),
  kTileLane: VM.Vector3(1.0, 0.0, 0.0),
  kTileSidewalk: VM.Vector3(0.5, 0.5, 0.5),
  kTileSidewalkLight: VM.Vector3(1.0, 1.0, 1.0),
  kTileDivider: VM.Vector3(1.0, 1.0, 0.0),
  kTileBuildingSimple: VM.Vector3(1.0, 0.0, 1.0),
  kTileBuildingTower: VM.Vector3(0.0, 0.0, 1.0),
  kTileBuildingModern: VM.Vector3(0.0, 0.0, 1.0),
  kTileBuildingBlocky: VM.Vector3(0.0, 0.0, 1.0),
  kTileBuildingBorder: VM.Vector3(1.0, 1.0, 1.0),
};

final kDarkGray = VM.Vector3(0.05, 0.05, 0.05);

final Map<int, VM.Vector3> kTileToColorsStandard = {
  kTileEmpty: kDarkGray,
  kTileLane: VM.Vector3(0.1, 0.1, 0.1),
  kTileSidewalk: kDarkGray,
  kTileSidewalkLight: kDarkGray,
  kTileDivider: kDarkGray,
  kTileBuildingSimple: kDarkGray,
  kTileBuildingTower: kDarkGray,
  kTileBuildingModern: kDarkGray,
  kTileBuildingBlocky: kDarkGray,
  kTileBuildingBorder: kDarkGray,
};

HTML.CanvasElement RenderCanvasWorldMap(WorldMap wm,
    [Map<int, VM.Vector3> tileMap]) {
  tileMap = tileMap ?? kTileToColorsExtreme;
  final int w = wm.width;
  final int h = wm.height;
  final HTML.CanvasElement canvas = HTML.CanvasElement()
    ..width = w
    ..height = h;
  final HTML.CanvasRenderingContext2D c = canvas.context2D;
  final HTML.ImageData id = c.createImageData(w, h);
  Uint8ClampedList data = id.data;

  for (int x = 0; x < w; x++) {
    for (int y = 0; y < h; y++) {
      int tile = FloorplanGetTileType(wm.GetTile(x, y));
      //if (tile == kTileEmpty) continue;

      VM.Vector3 color = tileMap[tile];
      final int ix = w - x - 1;
      final int iy = h - y - 1;
      final int i = 4 * (iy * w + ix);
      data[i + 0] = (color.r * 255.0).floor();
      data[i + 1] = (color.g * 255.0).floor();
      data[i + 2] = (color.b * 255.0).floor();
      data[i + 3] = 255;
    }
  }
  c.putImageData(id, 0, 0);

  return canvas;

  // reduce canvas by 2 in w dimensions
  /*
  return HTML.CanvasElement()
    ..width = w
    ..height = h
    ..context2D.drawImageScaled(canvas, 0, 0, w, h);
    */
}
