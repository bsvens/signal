import 'dart:ui';

import '../simulation/cell.dart';

/// Maps simulation grid cells `(col, row)` to on-screen pixels and back.
///
/// This is the single place the render/input layers convert between the sim's
/// integer cell space and screen coordinates. The board is a square, centred in
/// the available space with a small margin. Recomputed cheaply per frame from
/// the current [size], so it always tracks rotation/resize.
class GridLayout {
  GridLayout({
    required this.size,
    required this.maxCoord,
    this.marginFraction = 0.03,
  });

  /// Current drawing surface size, in logical pixels.
  final Size size;

  /// Largest valid cell index on each axis (grid spans `0..maxCoord`).
  final int maxCoord;

  /// Fraction of the shorter side reserved as an outer margin.
  final double marginFraction;

  int get _cellCount => maxCoord + 1;

  double get cellSize =>
      (size.shortestSide * (1 - marginFraction * 2)) / _cellCount;

  double get _boardPixels => cellSize * _cellCount;

  double get _originX => (size.width - _boardPixels) / 2;
  double get _originY => (size.height - _boardPixels) / 2;

  /// The square pixel region the whole board occupies.
  Rect get boardRect =>
      Rect.fromLTWH(_originX, _originY, _boardPixels, _boardPixels);

  /// Pixel centre of cell `(col, row)`.
  Offset cellCenter(int col, int row) => Offset(
    _originX + (col + 0.5) * cellSize,
    _originY + (row + 0.5) * cellSize,
  );

  /// Interpolated pixel centre between two cells (for smooth car motion).
  Offset lerpCenter(Cell from, Cell to, double t) => Offset.lerp(
    cellCenter(from.col, from.row),
    cellCenter(to.col, to.row),
    t,
  )!;

  /// The square occupied by cell `(col, row)`.
  Rect cellRect(int col, int row) {
    final c = cellCenter(col, row);
    final half = cellSize / 2;
    return Rect.fromLTRB(c.dx - half, c.dy - half, c.dx + half, c.dy + half);
  }

  /// The cell under a pixel position, or null if outside the grid bounds.
  Cell? cellAt(Offset p) {
    final col = ((p.dx - _originX) / cellSize).floor();
    final row = ((p.dy - _originY) / cellSize).floor();
    if (col < 0 || row < 0 || col > maxCoord || row > maxCoord) return null;
    return Cell(col, row);
  }
}
