/// Which axis of a junction currently has a green light.
///
/// See docs/SIMULATION_SPEC.md §2 (Junction). This lives in the pure
/// simulation layer and must never import Flame/Flutter/dart:ui.
enum RoadAxis {
  /// North–south (vertical) traffic has green.
  ns,

  /// East–west (horizontal) traffic has green.
  ew;

  RoadAxis get opposite => this == RoadAxis.ns ? RoadAxis.ew : RoadAxis.ns;
}
