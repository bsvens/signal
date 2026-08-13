import 'car.dart';
import 'cell.dart';
import 'city_grid.dart';
import 'gridlock_detector.dart';
import 'junction.dart';
import 'routing.dart';
import 'rng.dart';
import 'sim_config.dart';
import 'snapshot.dart';

/// The authoritative, deterministic traffic simulation.
///
/// See docs/SIMULATION_SPEC.md. This class owns the grid, all cars, the seeded
/// RNG, the score and tick count, and the game-over flag. It is PURE Dart:
/// nothing here imports Flame/Flutter/dart:ui, and there is no wall-clock — the
/// sim advances only via [tick] and thinks only in cells and integer ticks.
///
/// Given the same [seed] and the same sequence of [toggleJunction] taps, [tick]
/// produces byte-identical results every run (Hard Rule #3).
class TrafficSimulation {
  TrafficSimulation({
    required int seed,
    this.config = const SimConfig(),
    this.autoSpawn = true,
  }) : grid = CityGrid.build(config),
       _rng = DeterministicRng(seed);

  final SimConfig config;
  final CityGrid grid;
  final DeterministicRng _rng;

  /// When false, [tick] never spawns cars. Tests use this to build exact
  /// scenarios; gameplay leaves it true.
  final bool autoSpawn;

  final GridlockDetector _gridlock = GridlockDetector();

  final List<Car> _cars = <Car>[];

  /// Occupancy index: at most one car per cell (SIMULATION_SPEC.md §2).
  final Map<Cell, Car> _occupant = <Cell, Car>{};

  int _tickCount = 0;
  int _score = 0;
  bool _gameOver = false;
  int _nextCarId = 0;
  int _ticksSinceLastSpawn = 0;

  int get tickCount => _tickCount;
  int get score => _score;
  bool get gameOver => _gameOver;

  /// Active cars, ordered by ascending id (read-only).
  List<Car> get cars => List.unmodifiable(_cars);

  /// All junctions (read-only), ordered by id.
  List<Junction> get junctions => grid.junctions;

  /// Number of cars currently blocked (SIMULATION_SPEC.md §6).
  int get queueLength {
    var n = 0;
    for (final c in _cars) {
      if (c.state == CarState.waiting) n++;
    }
    return n;
  }

  // --- Intent API (the UI's only levers) ---

  /// Flip a junction's green axis. The single player action.
  void toggleJunction(int id) {
    if (_gameOver) return;
    grid.junctionById(id).toggle();
  }

  /// Test/spawner seam: place a car on an explicit [route]. Returns the new
  /// car id, or -1 if the spawn cell is already occupied. Used by the internal
  /// spawner and by tests that need a known route.
  int spawnCarOnRoute(List<Cell> route) {
    if (route.isEmpty) return -1;
    if (_occupant[route.first] != null) return -1;
    return _addCar(route);
  }

  // --- The tick (SIMULATION_SPEC.md §4) ---

  void tick() {
    if (_gameOver) return;
    _tickCount += 1;

    // Record each car's pre-move cell so rendering can interpolate motion.
    // (A car that does not move ends the tick with previousCell == cell.)
    for (final car in _cars) {
      car.previousCell = car.cell;
    }

    // 1. Spawn (only onto an empty spawn cell).
    _maybeSpawnCars();

    // 2. Move cars in a STABLE order (ascending id) for determinism.
    for (final car in _cars) {
      if (car.state == CarState.exited) continue;
      final next = car.nextCell;
      if (next != null && _canAdvance(car, next)) {
        _occupant.remove(car.cell);
        car.routeIndex += 1;
        car.waitingTicks = 0;
        car.state = CarState.moving;
        if (car.atRouteEnd && grid.isEdge(car.cell)) {
          // Reached the final cell of the route (an exit edge): score once.
          car.state = CarState.exited;
          _score += 1;
          // Exited cars free their cell immediately.
        } else {
          _occupant[car.cell] = car;
        }
      } else {
        car.state = CarState.waiting;
        car.waitingTicks += 1;
      }
    }

    // 3. Remove exited cars from the active set.
    _reapExitedCars();

    // 4. Gridlock check.
    _checkGridlock();
  }

  /// A car may advance into [next] iff [next] is empty and — if [next] is a
  /// junction — the car's travel direction matches that junction's greenAxis.
  /// Greens gate ENTERING a junction, not leaving one, so only the next cell's
  /// junction is consulted (SIMULATION_SPEC.md §4).
  bool _canAdvance(Car car, Cell next) {
    if (_occupant[next] != null) return false;
    final junction = grid.junctionAt(next);
    if (junction != null) {
      final dir = car.cell.directionTo(next);
      if (dir == null) return false;
      if (dir.axis != junction.greenAxis) return false;
    }
    return true;
  }

  void _maybeSpawnCars() {
    if (!autoSpawn) return;
    _ticksSinceLastSpawn += 1;
    if (_ticksSinceLastSpawn < config.spawnEveryTicks(_score)) return;
    _ticksSinceLastSpawn = 0;
    _trySpawnOne();
  }

  /// Attempt to spawn one car at a random free spawn edge (SIMULATION_SPEC.md
  /// §5). A blocked spawn edge is itself a pressure signal — skip, don't queue.
  void _trySpawnOne() {
    final edges = grid.edgeCells;
    if (edges.isEmpty) return;
    final spawn = edges[_rng.nextInt(edges.length)];
    if (_occupant[spawn] != null) return; // occupied → skip this spawn.

    // Pick a random exit edge and route to it; re-roll on the rare no-path.
    for (var attempt = 0; attempt < 8; attempt++) {
      final exit = edges[_rng.nextInt(edges.length)];
      if (exit == spawn) continue;
      final route = findRoute(grid, spawn, exit);
      if (route != null && route.length > 1) {
        _addCar(route);
        return;
      }
    }
  }

  int _addCar(List<Cell> route) {
    final car = Car(id: _nextCarId++, route: route);
    _cars.add(car);
    _occupant[car.cell] = car;
    return car.id;
  }

  void _reapExitedCars() {
    _cars.removeWhere((c) => c.state == CarState.exited);
  }

  void _checkGridlock() {
    var maxWaiting = 0;
    var waiting = 0;
    for (final c in _cars) {
      if (c.state == CarState.waiting) {
        waiting++;
        if (c.waitingTicks > maxWaiting) maxWaiting = c.waitingTicks;
      }
    }
    if (_gridlock.check(
      queueLength: waiting,
      maxWaitingTicks: maxWaiting,
      config: config,
    )) {
      _gameOver = true;
    }
  }

  // --- Read model for rendering/HUD ---

  SimSnapshot get snapshot => SimSnapshot(
    tickCount: _tickCount,
    score: _score,
    queueLength: queueLength,
    queueLimit: config.queueLimit,
    gameOver: _gameOver,
    junctions: [
      for (final j in grid.junctions)
        JunctionSnapshot(id: j.id, cell: j.cell, greenAxis: j.greenAxis),
    ],
    cars: [
      for (final c in _cars)
        CarSnapshot(
          id: c.id,
          cell: c.cell,
          previousCell: c.previousCell,
          heading: c.heading,
          state: c.state,
          routeIndex: c.routeIndex,
          routeLength: c.route.length,
        ),
    ],
  );
}
