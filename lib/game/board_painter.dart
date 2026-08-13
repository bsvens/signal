import 'dart:math' as math;
import 'dart:ui';

import '../simulation/axis.dart';
import '../simulation/car.dart';
import '../simulation/cell.dart';
import '../simulation/city_grid.dart';
import '../simulation/direction.dart';
import '../simulation/snapshot.dart';
import 'grid_layout.dart';

/// Draws a [SimSnapshot] as a top-down city: asphalt roads with lane markings,
/// intersections with crosswalks and traffic-signal heads, little top-down cars,
/// and buildings / parks / trees filling the blocks.
///
/// Pure presentation (Hard Rule #2): it reads sim state and paints it, with no
/// game logic. The sim's cell is the position of record; [alpha] only smooths
/// motion between ticks and [timeSeconds] only drives cosmetic animation. Static
/// scenery (buildings, trees) is derived deterministically from cell coordinates
/// so it never flickers between frames.
class BoardPainter {
  // Void / sky behind the city.
  static const Color _voidTop = Color(0xFF151A24);
  static const Color _voidBottom = Color(0xFF0B0D13);

  // Ground.
  static const Color _asphalt = Color(0xFF23272F);
  static const Color _asphaltEdge = Color(0xFF2B303A);
  static const Color _sidewalk = Color(0xFF3C4250);
  static const Color _laneYellow = Color(0xFFD8B24A);
  static const Color _crosswalk = Color(0xCCE9EDF5);
  static const Color _grass = Color(0xFF2F5138);

  // Signals.
  static const Color _sigGreen = Color(0xFF3BDB86);
  static const Color _sigRed = Color(0xFFE5484D);
  static const Color _sigHousing = Color(0xFF15181F);

  static const List<Color> _buildings = [
    Color(0xFF4A5468),
    Color(0xFF566175),
    Color(0xFF46506A),
    Color(0xFF5B5566),
    Color(0xFF4E5A66),
    Color(0xFF614F58),
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

  void paint(
    Canvas canvas,
    Size canvasSize,
    GridLayout layout,
    CityGrid grid,
    SimSnapshot snapshot,
    double alpha,
    double timeSeconds,
  ) {
    _paintVoid(canvas, canvasSize);
    _paintLots(canvas, layout, grid); // buildings, parks, trees (blocks)
    _paintRoads(canvas, layout, grid); // asphalt + lane markings
    _paintIntersections(canvas, layout, grid, snapshot); // crosswalks + signals
    _paintCars(canvas, layout, snapshot, alpha, timeSeconds);
  }

  // Deterministic per-cell pseudo-random in [0,1): stable scenery, no flicker.
  double _rand(int a, int b, [int salt = 0]) {
    var h = a * 374761393 + b * 668265263 + salt * 2246822519;
    h = (h ^ (h >> 13)) * 1274126177;
    h ^= h >> 16;
    return (h & 0x7fffffff) / 0x7fffffff;
  }

  void _paintVoid(Canvas canvas, Size size) {
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
  }

  // ---- Blocks: sidewalk + building or park ----

  void _paintLots(Canvas canvas, GridLayout layout, CityGrid grid) {
    for (var row = 0; row <= grid.maxCoord; row++) {
      for (var col = 0; col <= grid.maxCoord; col++) {
        final cell = Cell(col, row);
        if (grid.isRoad(cell)) continue;
        final rect = layout.cellRect(col, row).inflate(0.5);

        // Sidewalk pad under everything on the block.
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

    // Footprint with a soft drop shadow to suggest height.
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

    // Rooftop inset (darker) + a couple of rooftop units.
    final roof = foot.deflate(cs * 0.06);
    _p.color = _darken(color, 0.14);
    canvas.drawRRect(
      RRect.fromRectAndRadius(roof, Radius.circular(cs * 0.03)),
      _p,
    );
    _p.color = _darken(color, 0.28);
    final unit = cs * 0.09;
    canvas.drawRect(
      Rect.fromLTWH(roof.left + cs * 0.04, roof.top + cs * 0.04, unit, unit),
      _p,
    );
    if (_rand(col, row, 3) > 0.5) {
      canvas.drawRect(
        Rect.fromLTWH(
          roof.right - cs * 0.04 - unit,
          roof.bottom - cs * 0.04 - unit,
          unit,
          unit,
        ),
        _p,
      );
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
    canvas.drawCircle(c.translate(r * 0.2, r * 0.25), r, _p); // shadow
    _p.color = const Color(0xFF2E6B3E);
    canvas.drawCircle(c, r, _p);
    _p.color = const Color(0xFF3E8A50);
    canvas.drawCircle(c.translate(-r * 0.22, -r * 0.22), r * 0.62, _p);
  }

  // ---- Roads ----

  void _paintRoads(Canvas canvas, GridLayout layout, CityGrid grid) {
    // Asphalt first (full cells so roads merge into continuous strips).
    for (final cell in grid.roadCells) {
      final rect = layout.cellRect(cell.col, cell.row).inflate(0.6);
      _p.color = _asphalt;
      canvas.drawRect(rect, _p);
    }
    // Lane markings on straight segments (not through intersections).
    for (final cell in grid.roadCells) {
      if (grid.isJunction(cell)) continue;
      final hasH =
          grid.isRoad(cell.step(Direction.east)) ||
          grid.isRoad(cell.step(Direction.west));
      final rect = layout.cellRect(cell.col, cell.row);
      if (hasH) {
        _dashedLine(
          canvas,
          Offset(rect.left, rect.center.dy),
          Offset(rect.right, rect.center.dy),
          layout,
        );
        _edgeLine(
          canvas,
          Offset(rect.left, rect.top),
          Offset(rect.right, rect.top),
          layout,
        );
        _edgeLine(
          canvas,
          Offset(rect.left, rect.bottom),
          Offset(rect.right, rect.bottom),
          layout,
        );
      } else {
        _dashedLine(
          canvas,
          Offset(rect.center.dx, rect.top),
          Offset(rect.center.dx, rect.bottom),
          layout,
        );
        _edgeLine(
          canvas,
          Offset(rect.left, rect.top),
          Offset(rect.left, rect.bottom),
          layout,
        );
        _edgeLine(
          canvas,
          Offset(rect.right, rect.top),
          Offset(rect.right, rect.bottom),
          layout,
        );
      }
    }
  }

  void _dashedLine(Canvas canvas, Offset a, Offset b, GridLayout layout) {
    final cs = layout.cellSize;
    _p.color = _laneYellow;
    final total = (b - a).distance;
    final dir = (b - a) / total;
    final dash = cs * 0.16, gap = cs * 0.12, thick = cs * 0.035;
    for (var d = cs * 0.08; d < total; d += dash + gap) {
      final s = a + dir * d;
      final e = a + dir * math.min(d + dash, total);
      canvas.drawLine(
        s,
        e,
        _p
          ..strokeWidth = thick
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _edgeLine(Canvas canvas, Offset a, Offset b, GridLayout layout) {
    _p
      ..color = _asphaltEdge
      ..strokeWidth = layout.cellSize * 0.05
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(a, b, _p);
  }

  // ---- Intersections: crosswalks + signal heads ----

  void _paintIntersections(
    Canvas canvas,
    GridLayout layout,
    CityGrid grid,
    SimSnapshot snapshot,
  ) {
    final cs = layout.cellSize;
    for (final j in snapshot.junctions) {
      final rect = layout.cellRect(j.cell.col, j.cell.row);
      final nsGreen = j.greenAxis == RoadAxis.ns;

      // Crosswalk ladders on each approach that has a road.
      for (final dir in Direction.values) {
        if (!grid.isRoad(j.cell.step(dir))) continue;
        _paintCrosswalk(canvas, rect, dir, cs);
      }

      // Signal heads: green on the go-axis approaches, red on the others.
      _paintSignal(
        canvas,
        Offset(rect.center.dx, rect.top + cs * 0.16),
        nsGreen ? _sigGreen : _sigRed,
        cs,
      ); // north
      _paintSignal(
        canvas,
        Offset(rect.center.dx, rect.bottom - cs * 0.16),
        nsGreen ? _sigGreen : _sigRed,
        cs,
      ); // south
      _paintSignal(
        canvas,
        Offset(rect.right - cs * 0.16, rect.center.dy),
        nsGreen ? _sigRed : _sigGreen,
        cs,
      ); // east
      _paintSignal(
        canvas,
        Offset(rect.left + cs * 0.16, rect.center.dy),
        nsGreen ? _sigRed : _sigGreen,
        cs,
      ); // west
    }
  }

  void _paintCrosswalk(Canvas canvas, Rect rect, Direction dir, double cs) {
    _p.color = _crosswalk;
    final horizontal = dir == Direction.north || dir == Direction.south;
    const stripes = 4;
    for (var i = 0; i < stripes; i++) {
      final t = (i + 0.5) / stripes;
      if (horizontal) {
        final x = rect.left + rect.width * (0.28 + 0.44 * t);
        final y = dir == Direction.north
            ? rect.top + cs * 0.05
            : rect.bottom - cs * 0.11;
        canvas.drawRect(Rect.fromLTWH(x, y, cs * 0.05, cs * 0.06), _p);
      } else {
        final y = rect.top + rect.height * (0.28 + 0.44 * t);
        final x = dir == Direction.west
            ? rect.left + cs * 0.05
            : rect.right - cs * 0.11;
        canvas.drawRect(Rect.fromLTWH(x, y, cs * 0.06, cs * 0.05), _p);
      }
    }
  }

  void _paintSignal(Canvas canvas, Offset c, Color color, double cs) {
    final housing = cs * 0.15;
    _p.color = _sigHousing;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: c, width: housing, height: housing),
        Radius.circular(housing * 0.3),
      ),
      _p,
    );
    if (color == _sigGreen) {
      _glow.color = color.withValues(alpha: 0.6);
      canvas.drawCircle(c, cs * 0.09, _glow);
    }
    _p.color = color;
    canvas.drawCircle(c, cs * 0.05, _p);
  }

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

      // Length along travel, width across; keep to the right-hand lane.
      double len = cs * 0.46, wid = cs * 0.26;
      Offset fwd = Offset.zero;
      if (heading != null) {
        fwd = Offset(heading.dCol.toDouble(), heading.dRow.toDouble());
        final right = Offset(-fwd.dy, fwd.dx); // right-hand side of travel
        center = center + right * (cs * 0.16);
      } else {
        len = wid = cs * 0.34;
      }

      final horizontal = heading == Direction.east || heading == Direction.west;
      final w = heading == null ? len : (horizontal ? len : wid);
      final h = heading == null ? len : (horizontal ? wid : len);

      final rect = Rect.fromCenter(center: center, width: w, height: h);
      final radius = Radius.circular(wid * 0.34);

      // Shadow.
      _p.color = const Color(0x55000000);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.translate(cs * 0.02, cs * 0.03), radius),
        _p,
      );

      // Body (stable per-car colour).
      _p.color = _carColors[car.id % _carColors.length];
      canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), _p);

      // Windshield toward the front.
      if (heading != null) {
        final wsCenter = center + fwd * (len * 0.16);
        final wsW = horizontal ? len * 0.26 : wid * 0.66;
        final wsH = horizontal ? wid * 0.66 : len * 0.26;
        _p.color = const Color(0xB3121820);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: wsCenter, width: wsW, height: wsH),
            Radius.circular(wid * 0.16),
          ),
          _p,
        );

        // Lights: white headlights up front; red brake lights when waiting.
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

  Color _darken(Color c, double amount) {
    return Color.fromARGB(
      (c.a * 255).round(),
      ((c.r * 255) * (1 - amount)).round(),
      ((c.g * 255) * (1 - amount)).round(),
      ((c.b * 255) * (1 - amount)).round(),
    );
  }
}
