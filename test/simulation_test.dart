import 'package:flutter_test/flutter_test.dart';
import 'package:traffic_control/simulation/axis.dart';
import 'package:traffic_control/simulation/car.dart';
import 'package:traffic_control/simulation/cell.dart';
import 'package:traffic_control/simulation/routing.dart';
import 'package:traffic_control/simulation/sim_config.dart';
import 'package:traffic_control/simulation/traffic_simulation.dart';

/// Deterministic simulation tests — the Phase 1 contract from
/// docs/SIMULATION_SPEC.md §8. No rendering is involved.
void main() {
  group('CityGrid structure', () {
    test('4x4 junction lattice with straight cells between junctions', () {
      final sim = TrafficSimulation(seed: 1, autoSpawn: false);
      final grid = sim.grid;

      // 16 junctions at even coordinates 0,2,4,6.
      expect(grid.junctions.length, 16);
      expect(grid.isJunction(const Cell(0, 0)), isTrue);
      expect(grid.isJunction(const Cell(2, 0)), isTrue);
      expect(grid.isJunction(const Cell(6, 6)), isTrue);

      // A cell between two junctions on a road line is a straight road cell,
      // not a junction.
      expect(grid.isRoad(const Cell(1, 0)), isTrue);
      expect(grid.isJunction(const Cell(1, 0)), isFalse);

      // A cell off every road line is a building, not drivable.
      expect(grid.isRoad(const Cell(1, 1)), isFalse);

      // Junction cells connect both axes; straight cells connect one axis.
      expect(grid.neighbours(const Cell(2, 2)).length, 4);
      expect(grid.neighbours(const Cell(1, 0)).length, 2);
    });
  });

  group('Contract 1 — routing + scoring', () {
    test('a car routes edge-to-edge and scores exactly one point', () {
      final sim = TrafficSimulation(seed: 7, autoSpawn: false);

      // BFS a route straight across the top edge, west→east.
      final route = findRoute(sim.grid, const Cell(0, 0), const Cell(6, 0));
      expect(route, isNotNull);
      expect(route!.first, const Cell(0, 0));
      expect(route.last, const Cell(6, 0));
      expect(
        route.every((c) => c.row == 0),
        isTrue,
        reason: 'shortest path along row 0 stays on row 0',
      );

      // Give the eastbound car greens: set every junction on row 0 to E–W.
      for (final j in sim.junctions.where((j) => j.cell.row == 0)) {
        if (j.greenAxis != RoadAxis.ew) sim.toggleJunction(j.id);
      }

      final id = sim.spawnCarOnRoute(route);
      expect(id, isNonNegative);

      var ticks = 0;
      while (sim.cars.isNotEmpty && ticks < 100) {
        sim.tick();
        ticks++;
      }

      expect(sim.score, 1);
      expect(sim.cars, isEmpty, reason: 'exited car is reaped');
      // 6 moves (index 0→6) to exit, plus one linger tick before the reap.
      expect(sim.tickCount, inInclusiveRange(6, 7));
    });
  });

  group('Contract 2 — red light stops', () {
    test('car waits at an opposing red, then advances after a toggle', () {
      final sim = TrafficSimulation(seed: 11, autoSpawn: false);

      // Eastbound car sitting just before junction (2,0).
      final route = <Cell>[
        const Cell(1, 0),
        const Cell(2, 0),
        const Cell(3, 0),
      ];
      final junction = sim.grid.junctionAt(const Cell(2, 0))!;
      expect(
        junction.greenAxis,
        RoadAxis.ns,
        reason: 'ns is red for an eastbound (ew) car',
      );

      final id = sim.spawnCarOnRoute(route);
      expect(id, isNonNegative);

      sim.tick();
      expect(
        sim.cars.single.cell,
        const Cell(1, 0),
        reason: 'blocked by the red light — no advance',
      );
      expect(sim.cars.single.state, CarState.waiting);

      sim.toggleJunction(junction.id); // ns → ew, now green for eastbound.
      sim.tick();
      expect(
        sim.cars.single.cell,
        const Cell(2, 0),
        reason: 'advances onto the junction once green',
      );
      expect(sim.cars.single.state, CarState.moving);
    });
  });

  group('Contract 3 — reproducibility', () {
    test('same seed + same taps → byte-identical snapshots', () {
      final a = TrafficSimulation(seed: 12345);
      final b = TrafficSimulation(seed: 12345);

      for (var t = 0; t < 400; t++) {
        // Identical, deterministic tap schedule on both sims.
        if (t % 17 == 0) {
          final jid = (t ~/ 17) % 16;
          a.toggleJunction(jid);
          b.toggleJunction(jid);
        }
        a.tick();
        b.tick();
        expect(
          a.snapshot.serialize(),
          b.snapshot.serialize(),
          reason: 'diverged at tick $t',
        );
      }
      expect(a.score, b.score);
      expect(a.gameOver, b.gameOver);
    });

    test('different seeds diverge (RNG is actually seeded)', () {
      final a = TrafficSimulation(seed: 1);
      final b = TrafficSimulation(seed: 2);
      for (var t = 0; t < 200; t++) {
        a.tick();
        b.tick();
      }
      // Extremely unlikely to match across 200 ticks of spawning.
      expect(a.snapshot.serialize() == b.snapshot.serialize(), isFalse);
    });
  });

  group('Contract 4 — gridlock fires (Tier 1)', () {
    test('a forced jam reaches game over within the grace window', () {
      const config = SimConfig();
      final sim = TrafficSimulation(seed: 3, autoSpawn: false, config: config);

      // Place QUEUE_LIMIT eastbound cars, each on a horizontal straight cell
      // whose next cell is an ns-green (red-for-east) junction. All stay
      // blocked forever, so the queue is permanently full.
      var placed = 0;
      for (final row in const [0, 2, 4, 6]) {
        for (final col in const [1, 3, 5]) {
          final id = sim.spawnCarOnRoute(<Cell>[
            Cell(col, row),
            Cell(col + 1, row),
          ]);
          if (id >= 0) placed++;
        }
      }
      expect(placed, config.queueLimit, reason: 'exactly QUEUE_LIMIT cars');

      // Not yet over just before the grace window elapses.
      for (var t = 1; t < config.gridlockGrace; t++) {
        sim.tick();
        expect(sim.gameOver, isFalse, reason: 'still within grace at tick $t');
        expect(sim.queueLength, config.queueLimit);
      }

      // The tick that completes the grace window ends the game.
      sim.tick();
      expect(sim.gameOver, isTrue);
    });
  });

  group('Contract 5 — one car, one point', () {
    test('a car cannot score twice; further ticks do not inflate score', () {
      final sim = TrafficSimulation(seed: 9, autoSpawn: false);
      final route = findRoute(sim.grid, const Cell(0, 0), const Cell(6, 0))!;
      for (final j in sim.junctions.where((j) => j.cell.row == 0)) {
        if (j.greenAxis != RoadAxis.ew) sim.toggleJunction(j.id);
      }
      sim.spawnCarOnRoute(route);

      while (sim.cars.isNotEmpty) {
        sim.tick();
      }
      expect(sim.score, 1);

      // Keep ticking with an empty board — score must not move.
      for (var t = 0; t < 20; t++) {
        sim.tick();
      }
      expect(sim.score, 1);
      expect(sim.cars, isEmpty);
    });
  });

  group('Spawn curve (difficulty ramp)', () {
    const config = SimConfig();

    test('starts at BASE_INTERVAL and never speeds up below MIN_INTERVAL', () {
      expect(config.spawnEveryTicks(0), config.baseInterval);
      // A very high score is clamped to the fastest allowed interval.
      expect(config.spawnEveryTicks(100000), config.minInterval);
    });

    test('interval is monotonically non-increasing as score rises', () {
      var prev = config.spawnEveryTicks(0);
      for (var score = 1; score <= 500; score++) {
        final now = config.spawnEveryTicks(score);
        expect(now, lessThanOrEqualTo(prev), reason: 'at score $score');
        expect(now, greaterThanOrEqualTo(config.minInterval));
        prev = now;
      }
    });
  });
}
