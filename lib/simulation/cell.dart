import 'direction.dart';

/// An immutable grid coordinate `(col, row)`.
///
/// See docs/SIMULATION_SPEC.md §1. Integer coordinates only — the sim never
/// thinks in pixels. `col` increases to the right (east), `row` increases
/// downward (south).
class Cell {
  const Cell(this.col, this.row);

  final int col;
  final int row;

  /// The neighbouring cell one step in [dir].
  Cell step(Direction dir) => Cell(col + dir.dCol, row + dir.dRow);

  /// The direction that moves from this cell to [other], which must be an
  /// orthogonal neighbour exactly one cell away. Returns null otherwise.
  Direction? directionTo(Cell other) {
    final dc = other.col - col;
    final dr = other.row - row;
    for (final d in Direction.values) {
      if (d.dCol == dc && d.dRow == dr) return d;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is Cell && other.col == col && other.row == row;

  @override
  int get hashCode => col * 73856093 ^ row * 19349663;

  @override
  String toString() => '($col,$row)';
}
