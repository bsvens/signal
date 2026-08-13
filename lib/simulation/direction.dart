import 'axis.dart';

/// A cardinal direction of travel on the grid.
///
/// See docs/SIMULATION_SPEC.md §1: moving `east` increases `col`, moving
/// `south` increases `row`. Origin is top-left.
enum Direction {
  north(0, -1),
  south(0, 1),
  east(1, 0),
  west(-1, 0);

  const Direction(this.dCol, this.dRow);

  /// Column delta applied when moving one cell in this direction.
  final int dCol;

  /// Row delta applied when moving one cell in this direction.
  final int dRow;

  /// The axis this direction travels along. North/south → [RoadAxis.ns];
  /// east/west → [RoadAxis.ew]. Used to gate junction entry against
  /// `greenAxis` (SIMULATION_SPEC.md §2).
  RoadAxis get axis => (this == Direction.north || this == Direction.south)
      ? RoadAxis.ns
      : RoadAxis.ew;
}
