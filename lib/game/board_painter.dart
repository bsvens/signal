import 'dart:ui';

import '../simulation/axis.dart';
import '../simulation/car.dart';
import '../simulation/city_grid.dart';
import '../simulation/snapshot.dart';
import 'grid_layout.dart';

/// Draws a [SimSnapshot] onto a canvas. Pure presentation: it reads sim state
/// and paints it, and contains no game logic (Hard Rule #2). The sim's cell is
/// always the position of record; [alpha] only smooths motion between ticks.
class BoardPainter {
  // Palette — minimalist, Mini Metro adjacent (see brief §5).
  static const Color _road = Color(0xFF2A2F3A);
  static const Color _junctionBase = Color(0xFF3A4150);
  static const Color _green = Color(0xFF35D07F);
  static const Color _red = Color(0x55FF6B6B);
  static const Color _carMoving = Color(0xFF4FC3F7);
  static const Color _carWaiting = Color(0xFFFFB74D);

  final Paint _fill = Paint()..isAntiAlias = true;

  void paint(
    Canvas canvas,
    GridLayout layout,
    CityGrid grid,
    SimSnapshot snapshot,
    double alpha,
  ) {
    _paintRoads(canvas, layout, grid);
    _paintJunctions(canvas, layout, snapshot);
    _paintCars(canvas, layout, snapshot, alpha);
  }

  void _paintRoads(Canvas canvas, GridLayout layout, CityGrid grid) {
    final radius = Radius.circular(layout.cellSize * 0.18);
    for (final cell in grid.roadCells) {
      _fill.color = grid.isJunction(cell) ? _junctionBase : _road;
      // Slightly inset so adjacent cells read as connected roads, not tiles.
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
      // Draw the red (stopped) axis first, then the green axis on top.
      _fill.color = _red;
      _drawBar(canvas, nsGreen ? horizontal : vertical, layout);
      _fill.color = _green;
      _drawBar(canvas, nsGreen ? vertical : horizontal, layout);
    }
  }

  void _drawBar(Canvas canvas, Rect bar, GridLayout layout) {
    final r = Radius.circular(layout.cellSize * 0.14);
    canvas.drawRRect(RRect.fromRectAndRadius(bar, r), _fill);
  }

  void _paintCars(
    Canvas canvas,
    GridLayout layout,
    SimSnapshot snapshot,
    double alpha,
  ) {
    final size = layout.cellSize * 0.46;
    final radius = Radius.circular(size * 0.32);
    for (final car in snapshot.cars) {
      final center = layout.lerpCenter(car.previousCell, car.cell, alpha);
      _fill.color = car.state == CarState.waiting ? _carWaiting : _carMoving;
      final rect = Rect.fromCenter(center: center, width: size, height: size);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), _fill);
    }
  }
}
