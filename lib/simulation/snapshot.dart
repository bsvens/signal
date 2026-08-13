import 'axis.dart';
import 'car.dart';
import 'cell.dart';
import 'direction.dart';

/// Immutable read-model of a single junction, for rendering/HUD.
class JunctionSnapshot {
  const JunctionSnapshot({
    required this.id,
    required this.cell,
    required this.greenAxis,
  });

  final int id;
  final Cell cell;
  final RoadAxis greenAxis;
}

/// Immutable read-model of a single car, for rendering/HUD.
///
/// [previousCell] and [cell] let the renderer interpolate motion between ticks
/// (SIMULATION_SPEC.md §7) while the sim's [cell] remains the position of record.
class CarSnapshot {
  const CarSnapshot({
    required this.id,
    required this.cell,
    required this.previousCell,
    required this.heading,
    required this.state,
    required this.routeIndex,
    required this.routeLength,
  });

  final int id;
  final Cell cell;
  final Cell previousCell;
  final Direction? heading;
  final CarState state;
  final int routeIndex;
  final int routeLength;
}

/// An immutable snapshot of the whole simulation at one tick.
///
/// This is the ONLY thing rendering reads (SIMULATION_SPEC.md §2). It carries
/// everything the game/HUD needs and nothing rendering could mutate.
class SimSnapshot {
  const SimSnapshot({
    required this.tickCount,
    required this.score,
    required this.queueLength,
    required this.queueLimit,
    required this.gameOver,
    required this.junctions,
    required this.cars,
  });

  final int tickCount;
  final int score;

  /// Number of cars currently waiting (blocked). Drives the HUD queue meter.
  final int queueLength;

  /// The queue limit; the HUD draws the meter as `queueLength / queueLimit`.
  final int queueLimit;

  final bool gameOver;
  final List<JunctionSnapshot> junctions;
  final List<CarSnapshot> cars;

  /// The queue meter fill, clamped to `[0, 1]`.
  double get queueFill =>
      queueLimit == 0 ? 0 : (queueLength / queueLimit).clamp(0.0, 1.0);

  /// A canonical, stable string form used by determinism tests to compare two
  /// runs. Cars are already ordered by id in [cars]; junctions by id.
  String serialize() {
    final b = StringBuffer();
    b.write('t=$tickCount;score=$score;q=$queueLength;over=$gameOver;');
    b.write('J[');
    for (final j in junctions) {
      b.write('${j.id}:${j.cell.col},${j.cell.row}:${j.greenAxis.name};');
    }
    b.write(']C[');
    for (final c in cars) {
      b.write(
        '${c.id}:${c.cell.col},${c.cell.row}:${c.state.name}:${c.routeIndex}/${c.routeLength};',
      );
    }
    b.write(']');
    return b.toString();
  }
}
