import 'dart:math' as math;
import 'dart:ui';

import '../simulation/axis.dart';
import '../simulation/car.dart';
import '../simulation/cell.dart';
import '../simulation/city_grid.dart';
import '../simulation/direction.dart';
import '../simulation/snapshot.dart';
import 'grid_layout.dart';

/// Draws a [SimSnapshot] as a top-down city. Pure presentation (Hard Rule #2):
/// it reads sim state and paints it, with no game logic. The sim's cell is the
/// position of record; [alpha] only smooths motion and [timeSeconds] only drives
/// cosmetic animation.
///
/// Visual hierarchy is deliberate (per the design pass): roads and the green
/// signal axis are the primary read; lane markings, scenery and skyline are
/// texture. Saturated color is spent only where it means something — green =
/// go/state, red = stop/danger, car bodies = the moving agents.
class BoardPainter {
  // Void / sky.
  static const Color _voidTop = Color(0xFF10141D);
  static const Color _voidBottom = Color(0xFF0B0D13);
  static const Color _skyline = Color(0xFF171C27);

  // Ground.
  static const Color _asphalt = Color(0xFF272C37);
  static const Color _sidewalk = Color(0xFF343A47);
  static const Color _lane = Color(0x478A93A6); // grey-blue, low alpha
  static const Color _grass = Color(0xFF2C4A36);
  static const Color _portal = Color(0x2E8A93A6);

  // Signals.
  static const Color _sigGreen = Color(0xFF3BDB86);
  static const Color _sigRed = Color(0xFFE5484D);

  static const List<Color> _buildings = [
    Color(0xFF3E4759),
    Color(0xFF464F63),
    Color(0xFF4E586E),
    Color(0xFF545E74),
    Color(0xFF58627A),
    Color(0xFF5E6980),
  ];

  static const List<Color> _carColors = [
    Color(0xFFE0605C),
    Color(0xFF4F9DDE),
    Color(0xFFE7C24A),
    Color(0xFFEDEFF2),
    Color(0xFF43B79E),
    Color(0xFF9B6DD6),
    Color(0xFFE08A3C),
  ];

  final Paint _p = Paint()..isAntiAlias = true;
  final Paint _glow = Paint()
    ..isAntiAlias = true
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

  // Renderer-local cosmetic memory (not sim state): last-seen green axis and the
  // time it last changed, for the toggle ripple. Presentation only.
  final Map<int, RoadAxis> _lastAxis = {};
  final Map<int, double> _changeAt = {};

  void paint(
    Canvas canvas,
    Size canvasSize,
    GridLayout layout,
    CityGrid grid,
    SimSnapshot snapshot,
    double alpha,
    double timeSeconds,
  ) {
    _paintBackdrop(canvas, canvasSize, layout);
    _paintLots(canvas, layout, grid);
    _paintRoads(canvas, layout, grid);
    _paintPortals(canvas, layout, grid);
    _paintJunctions(canvas, layout, grid, snapshot, timeSeconds);
    _paintCars(canvas, layout, snapshot, alpha, timeSeconds);
    _paintDanger(canvas, canvasSize, layout, snapshot);
  }

  // Deterministic per-key pseudo-random in [0,1): stable scenery, no flicker.
  double _rand(int a, int b, [int salt = 0]) {
    var h = a * 374761393 + b * 668265263 + salt * 2246822519;
    h = (h ^ (h >> 13)) * 1274126177;
    h ^= h >> 16;
    return (h & 0x7fffffff) / 0x7fffffff;
  }

  // ---- Backdrop: gradient, skyline, ambient vignette ----

  void _paintBackdrop(Canvas canvas, Size size, GridLayout layout) {
    final rect = Offset.zero & size;
    _p
      ..shader = Gradient.linear(
        Offset(size.width / 2, 0),
        Offset(size.width / 2, size.height),
        const [_voidTop, _voidBottom],
      )
      ..color = const Color(0xFFFFFFFF);
    canvas.drawRect(rect, _p);
    _p.shader = null;

    // A city horizon rising from the bottom of the screen, below the board.
    final board = layout.boardRect;
    final bandTop = board.bottom;
    final maxH = math.min(size.height * 0.10, (size.height - bandTop) * 0.85);
    if (maxH > 8) {
      const n = 18;
      final w = size.width / n;
      for (var i = 0; i < n; i++) {
        final h = maxH * (0.35 + 0.65 * _rand(i, 0, 3));
        final bx = i * w;
        _p.color = _skyline;
        canvas.drawRect(Rect.fromLTWH(bx, size.height - h, w + 1, h), _p);
        if (_rand(i, 0, 4) > 0.5) {
          _p.color = const Color(0x3DFFCF7A);
          canvas.drawCircle(
            Offset(bx + w * 0.5, size.height - h + maxH * 0.18),
            1.6,
            _p,
          );
        }
      }
    }

    // Ambient vignette: darken the corners so the eye settles on the board.
    _p.shader = Gradient.radial(
      board.center,
      size.longestSide * 0.62,
      const [Color(0x00000000), Color(0x38000000)],
      const [0.55, 1.0],
    );
    canvas.drawRect(rect, _p);
    _p.shader = null;
  }

  // ---- Blocks: sidewalk + building or park ----

  void _paintLots(Canvas canvas, GridLayout layout, CityGrid grid) {
    for (var row = 0; row <= grid.maxCoord; row++) {
      for (var col = 0; col <= grid.maxCoord; col++) {
        final cell = Cell(col, row);
        if (grid.isRoad(cell)) continue;
        final rect = layout.cellRect(col, row).inflate(0.5);
        _p.color = _sidewalk;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            rect,
            Radius.circular(layout.cellSize * 0.08),
          ),
          _p,
        );
        if (_rand(col, row, 7) < 0.28) {
          _paintPark(canvas, layout, col, row);
        } else {
          _paintBuilding(canvas, layout, col, row);
        }
      }
    }
  }

  void _paintBuilding(Canvas canvas, GridLayout layout, int col, int row) {
    final cs = layout.cellSize;
    final foot = layout.cellRect(col, row).deflate(cs * 0.15);
    final color =
        _buildings[(_rand(col, row) * _buildings.length).floor() %
            _buildings.length];

    _p.color = const Color(0x33000000);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        foot.translate(cs * 0.02, cs * 0.03),
        Radius.circular(cs * 0.05),
      ),
      _p,
    );
    _p.color = color;
    canvas.drawRRect(
      RRect.fromRectAndRadius(foot, Radius.circular(cs * 0.05)),
      _p,
    );

    // A single rooftop unit (kept minimal — see design cut list).
    final roof = foot.deflate(cs * 0.06);
    _p.color = _darken(color, 0.2);
    final unit = cs * 0.1;
    canvas.drawRect(
      Rect.fromLTWH(roof.left + cs * 0.04, roof.top + cs * 0.04, unit, unit),
      _p,
    );

    // Warm rooftop light on some buildings (ambiance).
    if (_rand(col, row, 9) > 0.55) {
      final c = Offset(
        roof.left + roof.width * (0.35 + 0.3 * _rand(col, row, 11)),
        roof.top + roof.height * (0.35 + 0.3 * _rand(col, row, 12)),
      );
      _glow.color = const Color(0x66FFCF7A);
      canvas.drawCircle(c, cs * 0.05, _glow);
      _p.color = const Color(0xFFFFE0A3);
      canvas.drawCircle(c, cs * 0.022, _p);
    }
  }

  void _paintPark(Canvas canvas, GridLayout layout, int col, int row) {
    final cs = layout.cellSize;
    final area = layout.cellRect(col, row).deflate(cs * 0.13);
    _p.color = _grass;
    canvas.drawRRect(
      RRect.fromRectAndRadius(area, Radius.circular(cs * 0.06)),
      _p,
    );
    final trees = 2 + (_rand(col, row, 5) * 2).floor();
    for (var i = 0; i < trees; i++) {
      final tx =
          area.left + area.width * (0.25 + 0.5 * _rand(col, row, 10 + i));
      final ty =
          area.top + area.height * (0.25 + 0.5 * _rand(col, row, 40 + i));
      _paintTree(canvas, Offset(tx, ty), cs * 0.16);
    }
  }

  void _paintTree(Canvas canvas, Offset c, double r) {
    _p.color = const Color(0x33000000);
    canvas.drawCircle(c.translate(r * 0.2, r * 0.25), r, _p);
    _p.color = const Color(0xFF2E6B3E);
    canvas.drawCircle(c, r, _p);
    _p.color = const Color(0xFF3E8A50);
    canvas.drawCircle(c.translate(-r * 0.22, -r * 0.22), r * 0.62, _p);
  }

  // ---- Roads: asphalt + demoted lane markings ----

  void _paintRoads(Canvas canvas, GridLayout layout, CityGrid grid) {
    for (final cell in grid.roadCells) {
      final rect = layout.cellRect(cell.col, cell.row).inflate(0.6);
      _p.color = _asphalt;
      canvas.drawRect(rect, _p);
    }
    for (final cell in grid.roadCells) {
      if (grid.isJunction(cell)) continue;
      final rect = layout.cellRect(cell.col, cell.row);
      final hasH =
          grid.isRoad(cell.step(Direction.east)) ||
          grid.isRoad(cell.step(Direction.west));
      if (hasH) {
        _dashedLine(
          canvas,
          Offset(rect.left, rect.center.dy),
          Offset(rect.right, rect.center.dy),
          layout,
        );
      } else {
        _dashedLine(
          canvas,
          Offset(rect.center.dx, rect.top),
          Offset(rect.center.dx, rect.bottom),
          layout,
        );
      }
    }
  }

  void _dashedLine(Canvas canvas, Offset a, Offset b, GridLayout layout) {
    final cs = layout.cellSize;
    _p
      ..color = _lane
      ..strokeWidth = cs * 0.03
      ..strokeCap = StrokeCap.round;
    final total = (b - a).distance;
    final dir = (b - a) / total;
    final dash = cs * 0.16, gap = cs * 0.12;
    for (var d = cs * 0.08; d < total; d += dash + gap) {
      final s = a + dir * d;
      final e = a + dir * math.min(d + dash, total);
      canvas.drawLine(s, e, _p);
    }
  }

  // ---- Spawn / exit portals at the board perimeter ----

  void _paintPortals(Canvas canvas, GridLayout layout, CityGrid grid) {
    final cs = layout.cellSize;
    for (final cell in grid.edgeCells) {
      if (grid.isJunction(cell)) continue; // mark straight road mouths only
      for (final dir in Direction.values) {
        final n = cell.step(dir);
        final offBoard =
            n.col < 0 ||
            n.row < 0 ||
            n.col > grid.maxCoord ||
            n.row > grid.maxCoord;
        if (!offBoard) continue;
        final center = layout
            .cellCenter(cell.col, cell.row)
            .translate(dir.dCol * cs * 0.52, dir.dRow * cs * 0.52);
        final horizontal = dir == Direction.north || dir == Direction.south;
        final w = horizontal ? cs * 0.5 : cs * 0.2;
        final h = horizontal ? cs * 0.2 : cs * 0.5;
        _p.color = _portal;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: center, width: w, height: h),
            Radius.circular(cs * 0.1),
          ),
          _p,
        );
      }
    }
  }

  // ---- Intersections: tap disc, green corridor bar, red stop lines ----

  void _paintJunctions(
    Canvas canvas,
    GridLayout layout,
    CityGrid grid,
    SimSnapshot snapshot,
    double time,
  ) {
    final cs = layout.cellSize;
    for (final j in snapshot.junctions) {
      final rect = layout.cellRect(j.cell.col, j.cell.row);
      final center = rect.center;
      final nsGreen = j.greenAxis == RoadAxis.ns;

      // Tap affordance: a faint disc says "this is a button".
      _p.color = const Color(0x0DFFFFFF);
      canvas.drawCircle(center, cs * 0.46, _p);
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x1AFFFFFF);
      canvas.drawCircle(center, cs * 0.46, _p);
      _p.style = PaintingStyle.fill;

      // Track state change for the toggle ripple (cosmetic memory only).
      if (!_lastAxis.containsKey(j.id)) {
        _lastAxis[j.id] = j.greenAxis;
      } else if (_lastAxis[j.id] != j.greenAxis) {
        _changeAt[j.id] = time;
        _lastAxis[j.id] = j.greenAxis;
      }

      // Green "go corridor": a glowing bar along the open axis. Orientation
      // encodes the state (colour-blind safe by geometry).
      final greenRect = nsGreen
          ? Rect.fromCenter(center: center, width: cs * 0.30, height: cs * 0.94)
          : Rect.fromCenter(
              center: center,
              width: cs * 0.94,
              height: cs * 0.30,
            );
      _p.color = _sigGreen.withValues(alpha: 0.22);
      canvas.drawRRect(
        RRect.fromRectAndRadius(greenRect, Radius.circular(cs * 0.15)),
        _p,
      );
      final coreRect = nsGreen
          ? Rect.fromCenter(center: center, width: cs * 0.08, height: cs * 0.94)
          : Rect.fromCenter(
              center: center,
              width: cs * 0.94,
              height: cs * 0.08,
            );
      final breathe = 0.4 + 0.15 * math.sin(time * 2 + j.id);
      _glow.color = _sigGreen.withValues(alpha: breathe);
      canvas.drawRRect(
        RRect.fromRectAndRadius(coreRect, Radius.circular(cs * 0.06)),
        _glow,
      );
      _p.color = _sigGreen;
      canvas.drawRRect(
        RRect.fromRectAndRadius(coreRect, Radius.circular(cs * 0.06)),
        _p,
      );

      // Red stop lines across the blocked approaches (only where a road exists).
      _p.color = _sigRed;
      if (nsGreen) {
        // E–W blocked: vertical stop bars at the west/east entrances.
        if (grid.isRoad(j.cell.step(Direction.west))) {
          canvas.drawRRect(
            _stopBar(
              rect.left + cs * 0.12,
              center.dy,
              cs * 0.06,
              cs * 0.32,
              cs,
            ),
            _p,
          );
        }
        if (grid.isRoad(j.cell.step(Direction.east))) {
          canvas.drawRRect(
            _stopBar(
              rect.right - cs * 0.12,
              center.dy,
              cs * 0.06,
              cs * 0.32,
              cs,
            ),
            _p,
          );
        }
      } else {
        // N–S blocked: horizontal stop bars at the north/south entrances.
        if (grid.isRoad(j.cell.step(Direction.north))) {
          canvas.drawRRect(
            _stopBar(center.dx, rect.top + cs * 0.12, cs * 0.32, cs * 0.06, cs),
            _p,
          );
        }
        if (grid.isRoad(j.cell.step(Direction.south))) {
          canvas.drawRRect(
            _stopBar(
              center.dx,
              rect.bottom - cs * 0.12,
              cs * 0.32,
              cs * 0.06,
              cs,
            ),
            _p,
          );
        }
      }

      // Toggle ripple: an expanding white ring for 0.25s after a change.
      final t0 = _changeAt[j.id];
      if (t0 != null && time - t0 < 0.25) {
        final k = (time - t0) / 0.25;
        _p
          ..style = PaintingStyle.stroke
          ..strokeWidth = cs * 0.04
          ..color = Color.lerp(
            const Color(0x80FFFFFF),
            const Color(0x00FFFFFF),
            k,
          )!;
        canvas.drawCircle(center, cs * (0.3 + 0.3 * k), _p);
        _p.style = PaintingStyle.fill;
      }
    }
  }

  RRect _stopBar(double cx, double cy, double w, double h, double cs) =>
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy), width: w, height: h),
        Radius.circular(cs * 0.03),
      );

  // ---- Cars ----

  void _paintCars(
    Canvas canvas,
    GridLayout layout,
    SimSnapshot snapshot,
    double alpha,
    double timeSeconds,
  ) {
    final cs = layout.cellSize;
    for (final car in snapshot.cars) {
      var center = layout.lerpCenter(car.previousCell, car.cell, alpha);
      final heading = car.heading;

      final type = car.id % 4;
      double lenF, widF;
      var isTruck = false;
      switch (type) {
        case 0:
          lenF = 0.48;
          widF = 0.26;
        case 1:
          lenF = 0.40;
          widF = 0.25;
        case 2:
          lenF = 0.62;
          widF = 0.30;
          isTruck = true;
        default:
          lenF = 0.50;
          widF = 0.29;
      }
      double len = cs * lenF, wid = cs * widF;

      Offset fwd = Offset.zero;
      if (heading != null) {
        fwd = Offset(heading.dCol.toDouble(), heading.dRow.toDouble());
        final right = Offset(-fwd.dy, fwd.dx);
        center = center + right * (cs * 0.16);
      } else {
        len = wid = cs * 0.34;
      }

      final horizontal = heading == Direction.east || heading == Direction.west;
      final w = heading == null ? len : (horizontal ? len : wid);
      final h = heading == null ? len : (horizontal ? wid : len);
      final rect = Rect.fromCenter(center: center, width: w, height: h);
      final radius = Radius.circular(wid * 0.34);

      _p.color = const Color(0x55000000);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.translate(cs * 0.02, cs * 0.03), radius),
        _p,
      );

      final bodyColor = _carColors[car.id % _carColors.length];
      _p.color = bodyColor;
      canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), _p);

      if (isTruck && heading != null) {
        final boxCenter = center - fwd * (len * 0.20);
        final bw = horizontal ? len * 0.54 : wid;
        final bh = horizontal ? wid : len * 0.54;
        _p.color = _darken(bodyColor, 0.22);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: boxCenter, width: bw, height: bh),
            Radius.circular(wid * 0.2),
          ),
          _p,
        );
      }

      if (heading != null) {
        final wsCenter = center + fwd * (len * 0.20);
        final wsW = horizontal ? len * 0.22 : wid * 0.66;
        final wsH = horizontal ? wid * 0.66 : len * 0.22;
        _p.color = const Color(0xB3121820);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: wsCenter, width: wsW, height: wsH),
            Radius.circular(wid * 0.16),
          ),
          _p,
        );

        final rear = center - fwd * (len * 0.42);
        final front = center + fwd * (len * 0.42);
        final side = Offset(-fwd.dy, fwd.dx) * (wid * 0.28);
        if (car.state == CarState.waiting) {
          final pulse = 0.6 + 0.4 * math.sin(timeSeconds * 6 + car.id);
          _p.color = Color.lerp(
            const Color(0xFF7A1414),
            const Color(0xFFFF5A5A),
            pulse,
          )!;
          canvas.drawCircle(rear + side, wid * 0.1, _p);
          canvas.drawCircle(rear - side, wid * 0.1, _p);
        } else {
          _p.color = const Color(0xFFFFF6D6);
          canvas.drawCircle(front + side, wid * 0.09, _p);
          canvas.drawCircle(front - side, wid * 0.09, _p);
        }
      }
    }
  }

  // ---- Danger vignette (rising congestion) ----

  void _paintDanger(
    Canvas canvas,
    Size size,
    GridLayout layout,
    SimSnapshot snapshot,
  ) {
    final fill = snapshot.queueFill;
    if (fill < 0.7) return;
    final a = (0.1 * ((fill - 0.7) / 0.3)).clamp(0.0, 0.1);
    _p.shader = Gradient.radial(
      layout.boardRect.center,
      size.longestSide * 0.6,
      [const Color(0x00E5484D), _sigRed.withValues(alpha: a)],
      const [0.5, 1.0],
    );
    canvas.drawRect(Offset.zero & size, _p);
    _p.shader = null;
  }

  Color _darken(Color c, double amount) {
    return Color.fromARGB(
      (c.a * 255).round(),
      ((c.r * 255) * (1 - amount)).round(),
      ((c.g * 255) * (1 - amount)).round(),
      ((c.b * 255) * (1 - amount)).round(),
    );
  }
}
