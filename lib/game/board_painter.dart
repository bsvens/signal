import 'dart:math' as math;
import 'dart:ui';

import '../simulation/axis.dart';
import '../simulation/car.dart';
import '../simulation/cell.dart';
import '../simulation/city_grid.dart';
import '../simulation/direction.dart';
import '../simulation/snapshot.dart';
import 'grid_layout.dart';

/// Draws a [SimSnapshot] as a top-down city — a fusion of the classic
/// traffic-light arcade look (signal circles, yellow box junctions, varied
/// city lots) with a modern, premium dark palette.
///
/// Pure presentation (Hard Rule #2): reads sim state and paints it, no game
/// logic. The sim's cell is the position of record; [alpha] only smooths motion
/// between ticks and [timeSeconds] only drives cosmetic animation. Scenery is
/// derived deterministically from coordinates so it never flickers.
class BoardPainter {
  // Void / sky + backdrop city.
  static const Color _voidTop = Color(0xFF10141D);
  static const Color _voidBottom = Color(0xFF0A0C12);
  static const Color _backdropCity = Color(0xFF141A24);
  static const Color _backdropWindow = Color(0x2EFFCF7A);

  // Ground.
  static const Color _asphalt = Color(0xFF272C37);
  static const Color _sidewalk = Color(0xFF3A414F);
  static const Color _lane = Color(0x66C9A94A); // classic yellow, moderate
  static const Color _boxJunction = Color(0x3EE0C24A);

  // Signals.
  static const Color _sigGreen = Color(0xFF37E08A);
  static const Color _sigRed = Color(0xFFF0524F);
  static const Color _sigHousing = Color(0xFF0E1116);

  // Lots.
  static const Color _grass = Color(0xFF2F6B3E);
  static const Color _water = Color(0xFF2F6E9E);
  static const Color _court = Color(0xFF2E7D57);
  static const List<Color> _offices = [
    Color(0xFF4A5468),
    Color(0xFF566175),
    Color(0xFF515C72),
    Color(0xFF5E6980),
  ];
  static const Color _brickRoof = Color(0xFFA9524A);
  static const Color _brickRoof2 = Color(0xFF8F4A45);

  static const List<Color> _carColors = [
    Color(0xFFE0605C),
    Color(0xFF4F9DDE),
    Color(0xFFF0C24A),
    Color(0xFFEDEFF2),
    Color(0xFF43B79E),
    Color(0xFF9B6DD6),
    Color(0xFFE08A3C),
  ];

  final Paint _p = Paint()..isAntiAlias = true;
  final Paint _glow = Paint()
    ..isAntiAlias = true
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

  // Renderer-local cosmetic memory (never sim state).
  final Map<int, RoadAxis> _lastAxis = {};
  final Map<int, double> _changeAt = {};
  final Map<int, double> _carAngle = {}; // smooth heading for turning

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
    _paintRoadStubs(canvas, canvasSize, layout, grid);
    _paintRoads(canvas, layout, grid);
    _paintJunctions(canvas, layout, grid, snapshot, timeSeconds);
    _paintCars(canvas, canvasSize, layout, grid, snapshot, alpha);
    _paintDanger(canvas, canvasSize, layout, snapshot);
  }

  double _rand(int a, int b, [int salt = 0]) {
    var h = a * 374761393 + b * 668265263 + salt * 2246822519;
    h = (h ^ (h >> 13)) * 1274126177;
    h ^= h >> 16;
    return (h & 0x7fffffff) / 0x7fffffff;
  }

  // ---- Backdrop: gradient + dim night-city filling the void ----

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

    // A dim city of small buildings fills the whole screen; the lit play-board
    // is drawn on top, so the district sits inside a larger city and edge
    // spawns read as traffic arriving from town rather than from empty void.
    final board = layout.boardRect.inflate(layout.cellSize * 0.2);
    final unit = layout.cellSize * 0.9;
    final cols = (size.width / unit).ceil() + 1;
    final rows = (size.height / unit).ceil() + 1;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final bx = c * unit + unit * 0.12 * _rand(c, r, 2);
        final by = r * unit + unit * 0.12 * _rand(c, r, 3);
        final bw = unit * (0.5 + 0.32 * _rand(c, r, 4));
        final bh = unit * (0.5 + 0.32 * _rand(c, r, 5));
        final b = Rect.fromLTWH(bx, by, bw, bh);
        if (board.overlaps(b)) continue; // board will cover the centre anyway
        _p.color = _backdropCity;
        canvas.drawRRect(
          RRect.fromRectAndRadius(b, Radius.circular(unit * 0.06)),
          _p,
        );
        if (_rand(c, r, 6) > 0.6) {
          _p.color = _backdropWindow;
          canvas.drawCircle(b.center, unit * 0.05, _p);
        }
      }
    }

    // Ambient vignette so the eye settles on the lit board.
    _p.shader = Gradient.radial(
      board.center,
      size.longestSide * 0.6,
      const [Color(0x00000000), Color(0x4D000000)],
      const [0.5, 1.0],
    );
    canvas.drawRect(rect, _p);
    _p.shader = null;
  }

  // ---- City lots (blocks) ----

  void _paintLots(Canvas canvas, GridLayout layout, CityGrid grid) {
    for (var row = 0; row <= grid.maxCoord; row++) {
      for (var col = 0; col <= grid.maxCoord; col++) {
        final cell = Cell(col, row);
        if (grid.isRoad(cell)) continue;
        final cs = layout.cellSize;
        final full = layout.cellRect(col, row).inflate(0.5);
        _p.color = _sidewalk;
        canvas.drawRRect(
          RRect.fromRectAndRadius(full, Radius.circular(cs * 0.08)),
          _p,
        );
        final lot = layout.cellRect(col, row).deflate(cs * 0.12);
        switch ((_rand(col, row, 7) * 6).floor()) {
          case 0:
          case 1:
            _paintOffice(canvas, lot, cs, col, row);
          case 2:
            _paintResidential(canvas, lot, cs, col, row);
          case 3:
            _paintPark(canvas, lot, cs, col, row);
          case 4:
            _paintPond(canvas, lot, cs, col, row);
          default:
            _paintCourt(canvas, lot, cs, col, row);
        }
      }
    }
  }

  void _lotShadow(Canvas canvas, Rect r, double cs) {
    _p.color = const Color(0x33000000);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        r.translate(cs * 0.02, cs * 0.03),
        Radius.circular(cs * 0.05),
      ),
      _p,
    );
  }

  void _paintOffice(Canvas canvas, Rect lot, double cs, int col, int row) {
    _lotShadow(canvas, lot, cs);
    final color =
        _offices[(_rand(col, row, 1) * _offices.length).floor() %
            _offices.length];
    _p.color = color;
    canvas.drawRRect(
      RRect.fromRectAndRadius(lot, Radius.circular(cs * 0.05)),
      _p,
    );
    // Rooftop inset + unit + occasional warm light.
    final roof = lot.deflate(cs * 0.06);
    _p.color = _darken(color, 0.16);
    canvas.drawRRect(
      RRect.fromRectAndRadius(roof, Radius.circular(cs * 0.03)),
      _p,
    );
    _p.color = _darken(color, 0.3);
    final u = cs * 0.09;
    canvas.drawRect(
      Rect.fromLTWH(roof.left + cs * 0.04, roof.top + cs * 0.04, u, u),
      _p,
    );
    if (_rand(col, row, 9) > 0.5) {
      final c = roof.center;
      _glow.color = const Color(0x66FFCF7A);
      canvas.drawCircle(c, cs * 0.05, _glow);
      _p.color = const Color(0xFFFFE0A3);
      canvas.drawCircle(c, cs * 0.02, _p);
    }
  }

  void _paintResidential(Canvas canvas, Rect lot, double cs, int col, int row) {
    _lotShadow(canvas, lot, cs);
    // Two brick-roofed buildings (nods to the OG's red blocks).
    final halves = _rand(col, row, 2) > 0.5;
    final rects = halves
        ? [
            Rect.fromLTWH(
              lot.left,
              lot.top,
              lot.width,
              lot.height / 2 - cs * 0.02,
            ),
            Rect.fromLTWH(
              lot.left,
              lot.center.dy + cs * 0.02,
              lot.width,
              lot.height / 2 - cs * 0.02,
            ),
          ]
        : [
            Rect.fromLTWH(
              lot.left,
              lot.top,
              lot.width / 2 - cs * 0.02,
              lot.height,
            ),
            Rect.fromLTWH(
              lot.center.dx + cs * 0.02,
              lot.top,
              lot.width / 2 - cs * 0.02,
              lot.height,
            ),
          ];
    for (var i = 0; i < rects.length; i++) {
      _p.color = i == 0 ? _brickRoof : _brickRoof2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rects[i], Radius.circular(cs * 0.04)),
        _p,
      );
      // Ridge line down the roof.
      _p
        ..color = const Color(0x33000000)
        ..strokeWidth = cs * 0.02
        ..style = PaintingStyle.stroke;
      final rr = rects[i];
      if (halves) {
        canvas.drawLine(
          Offset(rr.left + cs * 0.06, rr.center.dy),
          Offset(rr.right - cs * 0.06, rr.center.dy),
          _p,
        );
      } else {
        canvas.drawLine(
          Offset(rr.center.dx, rr.top + cs * 0.06),
          Offset(rr.center.dx, rr.bottom - cs * 0.06),
          _p,
        );
      }
      _p.style = PaintingStyle.fill;
    }
  }

  void _paintPark(Canvas canvas, Rect lot, double cs, int col, int row) {
    _p.color = _grass;
    canvas.drawRRect(
      RRect.fromRectAndRadius(lot, Radius.circular(cs * 0.06)),
      _p,
    );
    // A little path.
    _p.color = const Color(0x223A414F);
    canvas.drawRect(
      Rect.fromCenter(center: lot.center, width: lot.width, height: cs * 0.06),
      _p,
    );
    final trees = 3 + (_rand(col, row, 5) * 3).floor();
    for (var i = 0; i < trees; i++) {
      final tx = lot.left + lot.width * (0.18 + 0.64 * _rand(col, row, 10 + i));
      final ty = lot.top + lot.height * (0.18 + 0.64 * _rand(col, row, 40 + i));
      _paintTree(canvas, Offset(tx, ty), cs * 0.14);
    }
  }

  void _paintPond(Canvas canvas, Rect lot, double cs, int col, int row) {
    _p.color = _grass;
    canvas.drawRRect(
      RRect.fromRectAndRadius(lot, Radius.circular(cs * 0.06)),
      _p,
    );
    _p.color = _water;
    final pond = lot.deflate(cs * 0.09);
    canvas.drawOval(pond, _p);
    // Highlight.
    _p.color = const Color(0x40FFFFFF);
    canvas.drawOval(
      Rect.fromLTWH(
        pond.left + cs * 0.05,
        pond.top + cs * 0.05,
        pond.width * 0.4,
        pond.height * 0.22,
      ),
      _p,
    );
    if (_rand(col, row, 3) > 0.5) {
      _paintTree(
        canvas,
        Offset(lot.left + cs * 0.12, lot.bottom - cs * 0.12),
        cs * 0.12,
      );
    }
  }

  void _paintCourt(Canvas canvas, Rect lot, double cs, int col, int row) {
    _p.color = _court;
    canvas.drawRRect(
      RRect.fromRectAndRadius(lot, Radius.circular(cs * 0.05)),
      _p,
    );
    final court = lot.deflate(cs * 0.08);
    _p
      ..color = const Color(0xCCEFF3F5)
      ..strokeWidth = cs * 0.02
      ..style = PaintingStyle.stroke;
    canvas.drawRect(court, _p);
    // Net / mid line across the short axis.
    if (court.width >= court.height) {
      canvas.drawLine(
        Offset(court.center.dx, court.top),
        Offset(court.center.dx, court.bottom),
        _p,
      );
    } else {
      canvas.drawLine(
        Offset(court.left, court.center.dy),
        Offset(court.right, court.center.dy),
        _p,
      );
    }
    _p.style = PaintingStyle.fill;
  }

  void _paintTree(Canvas canvas, Offset c, double r) {
    _p.color = const Color(0x33000000);
    canvas.drawCircle(c.translate(r * 0.2, r * 0.25), r, _p);
    _p.color = const Color(0xFF2E6B3E);
    canvas.drawCircle(c, r, _p);
    _p.color = const Color(0xFF44975A);
    canvas.drawCircle(c.translate(-r * 0.22, -r * 0.22), r * 0.62, _p);
  }

  // ---- Roads ----

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
      ..strokeWidth = cs * 0.035
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

  // ---- Road stubs to the screen edge ----

  // Distance from [p] to the screen edge in the (cardinal) direction [out].
  static double _distToEdge(Offset p, Offset out, Size size) {
    if (out.dx > 0.5) return size.width - p.dx;
    if (out.dx < -0.5) return p.dx;
    if (out.dy > 0.5) return size.height - p.dy;
    return p.dy; // up
  }

  bool _isOffBoard(Cell c, CityGrid grid) =>
      c.col < 0 || c.row < 0 || c.col > grid.maxCoord || c.row > grid.maxCoord;

  // Extends every perimeter road all the way to the screen edge, so the city
  // continues off-screen and cars can enter/leave at the border rather than
  // popping in/out at the board's floating edge.
  void _paintRoadStubs(
    Canvas canvas,
    Size size,
    GridLayout layout,
    CityGrid grid,
  ) {
    final cs = layout.cellSize;
    final halfW = cs * 0.5;
    for (final cell in grid.edgeCells) {
      for (final dir in Direction.values) {
        if (!_isOffBoard(cell.step(dir), grid)) continue;
        final out = Offset(dir.dCol.toDouble(), dir.dRow.toDouble());
        final c = layout.cellCenter(cell.col, cell.row);
        final edgePt = c + out * halfW;
        final screenPt = edgePt + out * _distToEdge(edgePt, out, size);
        _p.color = _asphalt;
        if (out.dy != 0) {
          final y1 = math.min(edgePt.dy, screenPt.dy);
          final y2 = math.max(edgePt.dy, screenPt.dy);
          canvas.drawRect(
            Rect.fromLTRB(c.dx - halfW, y1, c.dx + halfW, y2),
            _p,
          );
          _dashedLine(
            canvas,
            Offset(c.dx, edgePt.dy),
            Offset(c.dx, screenPt.dy),
            layout,
          );
        } else {
          final x1 = math.min(edgePt.dx, screenPt.dx);
          final x2 = math.max(edgePt.dx, screenPt.dx);
          canvas.drawRect(
            Rect.fromLTRB(x1, c.dy - halfW, x2, c.dy + halfW),
            _p,
          );
          _dashedLine(
            canvas,
            Offset(edgePt.dx, c.dy),
            Offset(screenPt.dx, c.dy),
            layout,
          );
        }
      }
    }
  }

  // ---- Intersections: box junction + classic signal circles ----

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

      // Classic yellow "box junction" keep-clear marking + tap affordance.
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = cs * 0.03
        ..color = _boxJunction;
      final box = rect.deflate(cs * 0.14);
      canvas.drawRect(box, _p);
      canvas.drawLine(box.topLeft, box.bottomRight, _p);
      canvas.drawLine(box.topRight, box.bottomLeft, _p);
      _p.style = PaintingStyle.fill;

      // Track state change for the toggle ripple.
      if (!_lastAxis.containsKey(j.id)) {
        _lastAxis[j.id] = j.greenAxis;
      } else if (_lastAxis[j.id] != j.greenAxis) {
        _changeAt[j.id] = time;
        _lastAxis[j.id] = j.greenAxis;
      }

      // Faint green flow tint along the open axis (keeps the "green wave" read).
      final tint = nsGreen
          ? Rect.fromCenter(center: center, width: cs * 0.16, height: cs)
          : Rect.fromCenter(center: center, width: cs, height: cs * 0.16);
      _p.color = _sigGreen.withValues(alpha: 0.14);
      canvas.drawRRect(
        RRect.fromRectAndRadius(tint, Radius.circular(cs * 0.08)),
        _p,
      );

      // Four signal heads — the classic circles. Green on the go-axis
      // approaches, red on the stopped ones; green breathes and glows.
      final breathe = 0.75 + 0.25 * math.sin(time * 2 + j.id);
      _signal(
        canvas,
        Offset(center.dx, rect.top + cs * 0.17),
        nsGreen,
        cs,
        breathe,
      ); // north
      _signal(
        canvas,
        Offset(center.dx, rect.bottom - cs * 0.17),
        nsGreen,
        cs,
        breathe,
      ); // south
      _signal(
        canvas,
        Offset(rect.right - cs * 0.17, center.dy),
        !nsGreen,
        cs,
        breathe,
      ); // east
      _signal(
        canvas,
        Offset(rect.left + cs * 0.17, center.dy),
        !nsGreen,
        cs,
        breathe,
      ); // west

      // Toggle ripple.
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

  void _signal(Canvas canvas, Offset c, bool go, double cs, double breathe) {
    // Dark housing.
    _p.color = _sigHousing;
    canvas.drawCircle(c, cs * 0.115, _p);
    final color = go ? _sigGreen : _sigRed;
    if (go) {
      _glow.color = color.withValues(alpha: 0.55 * breathe);
      canvas.drawCircle(c, cs * 0.13, _glow);
    }
    _p.color = go ? color.withValues(alpha: 0.7 + 0.3 * breathe) : color;
    canvas.drawCircle(c, cs * 0.075, _p);
    // Little specular highlight for a glassy lens.
    _p.color = const Color(0x66FFFFFF);
    canvas.drawCircle(c.translate(-cs * 0.02, -cs * 0.02), cs * 0.022, _p);
  }

  // ---- Cars ----

  static double _angleOf(Offset v) => math.atan2(v.dy, v.dx);

  void _paintCars(
    Canvas canvas,
    Size size,
    GridLayout layout,
    CityGrid grid,
    SimSnapshot snapshot,
    double alpha,
  ) {
    final cs = layout.cellSize;
    for (final car in snapshot.cars) {
      final pc = layout.cellCenter(car.previousCell.col, car.previousCell.row);
      final cc = layout.cellCenter(car.cell.col, car.cell.row);
      final heading = car.heading;
      final moved = car.previousCell != car.cell;

      Offset pos;
      double angle;
      if (car.state == CarState.exited) {
        // Leaving: drive from the last cell out through the exit edge and off
        // the screen along the extended road.
        final dir = moved ? (cc - pc) : const Offset(1, 0);
        final out = dir / (dir.distance == 0 ? 1 : dir.distance);
        final screenPt = cc + out * _distToEdge(cc, out, size);
        pos = Offset.lerp(pc, screenPt, alpha)!;
        angle = _angleOf(out);
      } else if (!moved || heading == null) {
        // Stationary: sit at the cell centre — safely BELOW the stop line, not
        // poking into the intersection.
        pos = cc;
        angle = heading != null
            ? _angleOf(Offset(heading.dCol.toDouble(), heading.dRow.toDouble()))
            : (_carAngle[car.id] ?? 0);
      } else if (car.routeIndex == 1 && grid.isEdge(car.previousCell)) {
        // Entering: first move off the spawn edge — drive IN from the screen
        // edge along the extended road so it never pops in mid-map.
        final inDir = cc - pc;
        final out = -inDir / (inDir.distance == 0 ? 1 : inDir.distance);
        final screenPt = pc + out * _distToEdge(pc, out, size);
        pos = Offset.lerp(screenPt, cc, alpha)!;
        angle = _angleOf(inDir);
      } else {
        // Normal drive: straight, clean interpolation (exact on the cell at the
        // tick boundary, so stops are crisp and there is no jitter).
        pos = Offset.lerp(pc, cc, alpha)!;
        angle = _angleOf(cc - pc);
      }

      // Ease facing so turns rotate smoothly instead of snapping.
      final prevA = _carAngle[car.id] ?? angle;
      var d = angle - prevA;
      d = math.atan2(math.sin(d), math.cos(d));
      final ang = prevA + d * 0.3;
      _carAngle[car.id] = ang;

      // Right-hand lane offset, perpendicular to facing.
      final right = Offset(-math.sin(ang), math.cos(ang));
      final drawPos = pos + right * (cs * 0.16);

      canvas.save();
      canvas.translate(drawPos.dx, drawPos.dy);
      canvas.rotate(ang);
      _drawCarBody(canvas, car, cs);
      canvas.restore();
    }
  }

  // Car drawn in local space: it drives toward +x. The front (windshield +
  // bright headlights) is deliberately distinct from the red-tail rear.
  void _drawCarBody(Canvas canvas, CarSnapshot car, double cs) {
    final type = car.id % 4;
    double lenF, widF;
    var isTruck = false;
    switch (type) {
      case 0:
        lenF = 0.52;
        widF = 0.27;
      case 1:
        lenF = 0.44;
        widF = 0.26;
      case 2:
        lenF = 0.66;
        widF = 0.30;
        isTruck = true;
      default:
        lenF = 0.54;
        widF = 0.30;
    }
    final len = cs * lenF, wid = cs * widF;
    final radius = Radius.circular(wid * 0.3);
    final bodyColor = _carColors[car.id % _carColors.length];

    // Shadow.
    _p.color = const Color(0x55000000);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(0, wid * 0.14), width: len, height: wid),
        radius,
      ),
      _p,
    );

    // Body.
    _p.color = bodyColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: len, height: wid),
        radius,
      ),
      _p,
    );

    if (isTruck) {
      _p.color = _darken(bodyColor, 0.22);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(-len * 0.18, 0),
            width: len * 0.56,
            height: wid,
          ),
          Radius.circular(wid * 0.18),
        ),
        _p,
      );
    }

    // Dark cabin toward the rear-centre.
    _p.color = _darken(bodyColor, 0.24);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(-len * 0.06, 0),
          width: len * 0.46,
          height: wid * 0.74,
        ),
        Radius.circular(wid * 0.2),
      ),
      _p,
    );

    // Windshield at the FRONT of the cabin — a strong "this end is forward" cue.
    _p.color = const Color(0xD8BFE4FF);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(len * 0.14, 0),
          width: len * 0.15,
          height: wid * 0.6,
        ),
        Radius.circular(wid * 0.12),
      ),
      _p,
    );

    final waiting = car.state == CarState.waiting;
    final sy = wid * 0.3;
    // Bright twin headlights at the very front (+x).
    _p.color = const Color(0xFFFFF6D0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(len * 0.46, sy),
          width: len * 0.07,
          height: wid * 0.22,
        ),
        Radius.circular(wid * 0.06),
      ),
      _p,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(len * 0.46, -sy),
          width: len * 0.07,
          height: wid * 0.22,
        ),
        Radius.circular(wid * 0.06),
      ),
      _p,
    );
    // Red tail-lights at the rear (-x), brighter when braking.
    _p.color = _sigRed.withValues(alpha: waiting ? 1.0 : 0.7);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(-len * 0.46, sy),
          width: len * 0.05,
          height: wid * 0.2,
        ),
        Radius.circular(wid * 0.05),
      ),
      _p,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(-len * 0.46, -sy),
          width: len * 0.05,
          height: wid * 0.2,
        ),
        Radius.circular(wid * 0.05),
      ),
      _p,
    );
  }

  // ---- Danger vignette ----

  void _paintDanger(
    Canvas canvas,
    Size size,
    GridLayout layout,
    SimSnapshot snapshot,
  ) {
    final fill = snapshot.queueFill;
    if (fill < 0.7) return;
    final a = (0.12 * ((fill - 0.7) / 0.3)).clamp(0.0, 0.12);
    _p.shader = Gradient.radial(
      layout.boardRect.center,
      size.longestSide * 0.6,
      [const Color(0x00F0524F), _sigRed.withValues(alpha: a)],
      const [0.45, 1.0],
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
