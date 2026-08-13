import 'dart:math' as math;
import 'dart:ui';

import '../simulation/axis.dart';
import '../simulation/car.dart';
import '../simulation/city_grid.dart';
import '../simulation/direction.dart';
import '../simulation/snapshot.dart';
import 'grid_layout.dart';

/// Draws a [SimSnapshot] onto a canvas. Pure presentation: it reads sim state
/// and paints it, and contains no game logic (Hard Rule #2). The sim's cell is
/// always the position of record; [alpha] only smooths motion between ticks and
/// [timeSeconds] only drives cosmetic pulsing.
class BoardPainter {
  // Palette — minimalist, Mini Metro adjacent (see brief §5).
  static const Color _bgTop = Color(0xFF161B26);
  static const Color _bgBottom = Color(0xFF0B0D13);
  static const Color _road = Color(0xFF262B36);
  static const Color _junctionBase = Color(0xFF333B4A);
  static const Color _green = Color(0xFF35D07F);
  static const Color _red = Color(0x4DFF6B6B);
  static const Color _carMoving = Color(0xFF57CBF5);
  static const Color _carWaiting = Color(0xFFFFB74D);
  static const Color _headlight = Color(0xFFEAF6FF);

  final Paint _fill = Paint()..isAntiAlias = true;
  final Paint _glow = Paint()
    ..isAntiAlias = true
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

  void paint(
    Canvas canvas,
    Size canvasSize,
    GridLayout layout,
    CityGrid grid,
    SimSnapshot snapshot,
    double alpha,
    double timeSeconds,
  ) {
    _paintBackground(canvas, canvasSize);
    _paintRoads(canvas, layout, grid);
    _paintJunctions(canvas, layout, snapshot);
    _paintCars(canvas, layout, snapshot, alpha, timeSeconds);
  }

  void _paintBackground(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    _fill
      ..shader = Gradient.linear(
        Offset(size.width / 2, 0),
        Offset(size.width / 2, size.height),
        const [_bgTop, _bgBottom],
      )
      ..color = const Color(0xFFFFFFFF);
    canvas.drawRect(rect, _fill);
    _fill.shader = null;
  }

  void _paintRoads(Canvas canvas, GridLayout layout, CityGrid grid) {
    final radius = Radius.circular(layout.cellSize * 0.18);
    for (final cell in grid.roadCells) {
      _fill.color = grid.isJunction(cell) ? _junctionBase : _road;
      // Slightly inflate so adjacent cells read as connected roads, not tiles.
      final rect = layout.cellRect(cell.col, cell.row).inflate(0.5);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), _fill);
    }
  }

  void _paintJunctions(Canvas canvas, GridLayout layout, SimSnapshot snapshot) {
    for (final j in snapshot.junctions) {
      final rect = layout.cellRect(j.cell.col, j.cell.row);
      final thickness = layout.cellSize * 0.34;

      final vertical = Rect.fromCenter(
        center: rect.center,
        width: thickness,
        height: rect.height,
      );
      final horizontal = Rect.fromCenter(
        center: rect.center,
        width: rect.width,
        height: thickness,
      );

      final nsGreen = j.greenAxis == RoadAxis.ns;
      final greenBar = nsGreen ? vertical : horizontal;
      final redBar = nsGreen ? horizontal : vertical;

      // Red (stopped) axis, dim and flat.
      _fill.color = _red;
      _drawBar(canvas, redBar, layout);

      // Green (go) axis with a soft glow underneath for a premium read.
      _glow.color = _green.withValues(alpha: 0.45);
      _drawBar(
        canvas,
        greenBar.inflate(layout.cellSize * 0.04),
        layout,
        paint: _glow,
      );
      _fill.color = _green;
      _drawBar(canvas, greenBar, layout);
    }
  }

  void _drawBar(Canvas canvas, Rect bar, GridLayout layout, {Paint? paint}) {
    final r = Radius.circular(layout.cellSize * 0.14);
    canvas.drawRRect(RRect.fromRectAndRadius(bar, r), paint ?? _fill);
  }

  void _paintCars(
    Canvas canvas,
    GridLayout layout,
    SimSnapshot snapshot,
    double alpha,
    double timeSeconds,
  ) {
    final cs = layout.cellSize;
    final along = cs * 0.54;
    final across = cs * 0.36;

    for (final car in snapshot.cars) {
      final center = layout.lerpCenter(car.previousCell, car.cell, alpha);
      final heading = car.heading;

      // Orient the body along the travel axis; square when idle/at exit.
      double w = cs * 0.42, h = cs * 0.42;
      if (heading == Direction.east || heading == Direction.west) {
        w = along;
        h = across;
      } else if (heading == Direction.north || heading == Direction.south) {
        w = across;
        h = along;
      }

      final waiting = car.state == CarState.waiting;
      var body = waiting ? _carWaiting : _carMoving;
      if (waiting) {
        // Gentle breathing pulse so a stuck queue reads as "alive but stuck".
        final pulse = 0.5 + 0.5 * math.sin(timeSeconds * 3.0 + car.id);
        body = Color.lerp(_carWaiting, const Color(0xFFFF8A3D), pulse * 0.5)!;
      }

      final rect = Rect.fromCenter(center: center, width: w, height: h);
      final rr = RRect.fromRectAndRadius(rect, Radius.circular(across * 0.4));

      // Soft drop shadow for a little depth.
      _fill.color = const Color(0x55000000);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect.translate(0, cs * 0.03),
          Radius.circular(across * 0.4),
        ),
        _fill,
      );

      _fill.color = body;
      canvas.drawRRect(rr, _fill);

      // A small "headlight" at the leading edge conveys direction at a glance.
      if (heading != null) {
        final lead = Offset(heading.dCol.toDouble(), heading.dRow.toDouble());
        final dot = center + lead * (along * 0.5 - across * 0.28);
        _fill.color = _headlight.withValues(alpha: 0.85);
        canvas.drawCircle(dot, across * 0.16, _fill);
      }
    }
  }
}
