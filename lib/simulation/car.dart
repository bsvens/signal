import 'cell.dart';
import 'direction.dart';

/// Lifecycle state of a car (SIMULATION_SPEC.md §2).
enum CarState { moving, waiting, exited }

/// A single vehicle travelling a fixed route across the city.
///
/// See docs/SIMULATION_SPEC.md §2. A car occupies exactly one cell at a time,
/// and at most one car may occupy a cell — this is the sole source of
/// congestion. The route is fixed for the car's life; cars never re-route.
class Car {
  Car({required this.id, required this.route})
    : assert(route.isNotEmpty, 'a route needs at least one cell'),
      routeIndex = 0,
      state = CarState.moving,
      waitingTicks = 0,
      previousCell = route.first;

  final int id;

  /// Ordered cells from a spawn edge cell to an exit edge cell.
  final List<Cell> route;

  /// Index into [route] of the cell the car currently occupies.
  int routeIndex;

  /// The cell occupied on the previous tick. Rendering interpolates between
  /// [previousCell] and [cell]; the sim's [cell] is always the truth.
  Cell previousCell;

  CarState state;

  /// Consecutive ticks spent blocked. Feeds gridlock detection (§6).
  int waitingTicks;

  /// The tick on which this car exited, or null while still driving. Lets the
  /// sim keep an exited car for one extra tick so rendering can slide it off
  /// the board instead of popping it out of existence. Scoring still happens
  /// exactly once, at the moment of exit.
  int? exitTick;

  /// The cell currently occupied.
  Cell get cell => route[routeIndex];

  /// The next cell along the route, or null if already at the exit.
  Cell? get nextCell =>
      routeIndex + 1 < route.length ? route[routeIndex + 1] : null;

  /// Direction of travel toward [nextCell], or null at the exit.
  Direction? get heading {
    final next = nextCell;
    return next == null ? null : cell.directionTo(next);
  }

  bool get hasExited => state == CarState.exited;

  /// True when the car occupies the final cell of its route.
  bool get atRouteEnd => routeIndex == route.length - 1;
}
