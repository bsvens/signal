import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';

import '../services/leaderboard_service.dart';
import '../services/score_store.dart';
import '../simulation/axis.dart';
import '../simulation/junction.dart';
import '../simulation/snapshot.dart';
import '../simulation/traffic_simulation.dart';
import 'board_painter.dart';
import 'grid_layout.dart';

/// Seconds of real time per simulation tick (SIMULATION_SPEC.md §7). This sets
/// game speed; the sim itself never sees seconds. 0.25 → 4 ticks/sec.
const double kTickSeconds = 0.25;

/// The Flame layer. It owns a [TrafficSimulation], advances it on a fixed
/// timestep, and draws each snapshot. All game logic lives in the sim; this
/// class only accumulates real time, forwards taps as intents, and renders.
class TrafficGame extends FlameGame {
  TrafficGame._(
    this._sim, {
    ScoreStore? scoreStore,
    LeaderboardService? leaderboard,
  }) : hud = ValueNotifier<SimSnapshot>(_sim.snapshot),
       _scores = scoreStore ?? ScoreStore(),
       _leaderboard = leaderboard ?? const NoopLeaderboardService() {
    _scores.loadStats().then((s) {
      bestScore.value = s.best;
      stats.value = s;
    });
  }

  factory TrafficGame({int? seed}) =>
      TrafficGame._(TrafficSimulation(seed: seed ?? _seedFromClock()));

  TrafficSimulation _sim;
  final BoardPainter _painter = BoardPainter();
  final ScoreStore _scores;
  final LeaderboardService _leaderboard;

  /// The latest snapshot, pushed once per tick. The Flutter HUD/overlays listen
  /// to this; the Flame render loop reads the sim directly for interpolation.
  final ValueNotifier<SimSnapshot> hud;

  /// Best score across sessions. Loaded async on construction, bumped live when
  /// a run beats it.
  final ValueNotifier<int> bestScore = ValueNotifier<int>(0);

  /// Lifetime stats (best, games played, total cleared) for the menu/game-over.
  final ValueNotifier<GameStats> stats = ValueNotifier<GameStats>(
    GameStats.empty,
  );

  double _accumulator = 0;
  double _elapsed =
      0; // wall time for cosmetic animation only (never sim input)
  bool _paused = false;
  bool _gameOverHandled = false;
  bool _newBest = false;

  bool get isPaused => _paused;
  bool get isGameOver => _sim.gameOver;

  /// True when the just-finished run set a new personal best.
  bool get isNewBest => _newBest;

  SimSnapshot get snapshot => _sim.snapshot;

  // The game layer is free to use the wall clock to seed a run; the seed then
  // flows into the pure sim, which stays deterministic for that seed.
  static int _seedFromClock() =>
      DateTime.now().microsecondsSinceEpoch & 0x7FFFFFFF;

  @override
  Color backgroundColor() => const Color(0xFF10131A);

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (_paused || _sim.gameOver) return;

    _accumulator += dt;
    var stepped = false;
    // Cap steps per frame to avoid a spiral of death after a hitch.
    var steps = 0;
    while (_accumulator >= kTickSeconds && steps < 8) {
      _sim.tick();
      _accumulator -= kTickSeconds;
      stepped = true;
      steps++;
      if (_sim.gameOver) break;
    }
    if (_accumulator > kTickSeconds) _accumulator = kTickSeconds;
    if (stepped) hud.value = _sim.snapshot;

    if (_sim.gameOver && !_gameOverHandled) _handleGameOver();
  }

  // Persist the run and submit to the leaderboard once, on the game-over edge.
  void _handleGameOver() {
    _gameOverHandled = true;
    final finalScore = _sim.score;
    _scores.recordRun(finalScore).then((result) {
      _newBest = result.isBest;
      bestScore.value = result.stats.best;
      stats.value = result.stats;
    });
    _leaderboard.submitScore(finalScore);
  }

  /// Interpolation fraction between the previous and current tick, for smooth
  /// motion. Frozen at 1.0 when paused or over so cars sit on their cells.
  double get _alpha => (_paused || _sim.gameOver)
      ? 1.0
      : (_accumulator / kTickSeconds).clamp(0.0, 1.0);

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final canvasSize = Size(size.x, size.y);
    final layout = _layout();
    _painter.paint(
      canvas,
      canvasSize,
      layout,
      _sim.grid,
      _sim.snapshot,
      _alpha,
      _elapsed,
    );
  }

  GridLayout _layout() =>
      GridLayout(size: Size(size.x, size.y), maxCoord: _sim.grid.maxCoord);

  /// The junction at a pixel — exact hit, else the nearest within a comfortable
  /// radius so panicked near-misses still count. Pure input mapping.
  Junction? _junctionNear(Offset p) {
    final layout = _layout();
    final cell = layout.cellAt(p);
    final exact = cell == null ? null : _sim.grid.junctionAt(cell);
    if (exact != null) return exact;
    final maxDist = layout.cellSize * 0.8;
    Junction? best;
    var bestD = double.infinity;
    for (final j in _sim.grid.junctions) {
      final d = (layout.cellCenter(j.cell.col, j.cell.row) - p).distance;
      if (d < bestD && d <= maxDist) {
        bestD = d;
        best = j;
      }
    }
    return best;
  }

  /// Id of the junction at [p], or null. Used by the swipe-to-group gesture.
  int? junctionIdAtPixel(Offset p) =>
      _sim.gameOver ? null : _junctionNear(p)?.id;

  /// Single-tap toggle (the classic one-junction flip). Returns true on a hit.
  bool handleTapAtPixel(Offset p) {
    if (_sim.gameOver) return false;
    final junction = _junctionNear(p);
    if (junction == null) return false;
    _sim.toggleJunction(junction.id);
    hud.value = _sim.snapshot;
    return true;
  }

  /// Force a junction onto [axis] (used by the green-wave swipe). Only acts —
  /// and only reports true — when it actually changes state, so a swipe fires
  /// one haptic per junction it flips. Still expressed as toggle intents, so
  /// runs stay deterministic.
  bool alignJunction(int id, RoadAxis axis) {
    if (_sim.gameOver) return false;
    if (_sim.grid.junctionById(id).greenAxis == axis) return false;
    _sim.toggleJunction(id);
    hud.value = _sim.snapshot;
    return true;
  }

  void togglePause() {
    if (_sim.gameOver) return;
    _paused = !_paused;
  }

  /// Hold the sim still while the title/menu is showing.
  void pauseForMenu() => _paused = true;

  /// Release from the menu into live play.
  void beginPlay() => _paused = false;

  /// Start a fresh run with a new seed.
  void restart() {
    _sim = TrafficSimulation(seed: _seedFromClock());
    _accumulator = 0;
    _paused = false;
    _gameOverHandled = false;
    _newBest = false;
    hud.value = _sim.snapshot;
  }

  @override
  void onRemove() {
    hud.dispose();
    bestScore.dispose();
    stats.dispose();
    super.onRemove();
  }
}
