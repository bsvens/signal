import 'axis.dart';
import 'cell.dart';

/// A traffic light at a grid crossing.
///
/// See docs/SIMULATION_SPEC.md §2. `toggle()` is the ONLY player action.
class Junction {
  Junction({
    required this.id,
    required this.cell,
    this.greenAxis = RoadAxis.ns,
  });

  /// Stable identifier, unique within a [CityGrid].
  final int id;

  /// The grid cell this junction occupies.
  final Cell cell;

  /// Which axis currently has green. Defaults to [RoadAxis.ns].
  RoadAxis greenAxis;

  /// Flips `ns <-> ew`. The single player intent, applied to the model only.
  void toggle() => greenAxis = greenAxis.opposite;
}
