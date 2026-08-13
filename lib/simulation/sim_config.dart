/// Tunable constants for the simulation.
///
/// Values come from docs/SIMULATION_SPEC.md §5–6 (suggested starting
/// constants, to be tuned in Phase 4). Keeping them in one place makes the
/// difficulty pass a single-file change and keeps the sim logic readable.
class SimConfig {
  const SimConfig({
    this.junctionsPerSide = 4,
    this.blockSize = 2,
    this.baseInterval = 24,
    this.ramp = 6,
    this.minInterval = 6,
    this.queueLimit = 12,
    this.gridlockGrace = 30,
    this.stuckLimit = 240,
  });

  /// Number of junctions along each side of the city (4×4 for the MVP).
  final int junctionsPerSide;

  /// Cells between adjacent junctions along a road line. A value of 2 places
  /// exactly one straight road cell between neighbouring junctions.
  final int blockSize;

  // --- Spawn curve (SIMULATION_SPEC.md §5) ---
  final int baseInterval;
  final int ramp;
  final int minInterval;

  // --- Gridlock detection, Tier 1 (SIMULATION_SPEC.md §6) ---
  final int queueLimit;
  final int gridlockGrace;
  final int stuckLimit;

  /// `spawnEveryTicks = max(MIN_INTERVAL, BASE_INTERVAL - floor(score / RAMP))`.
  int spawnEveryTicks(int score) {
    final interval = baseInterval - (score ~/ ramp);
    return interval < minInterval ? minInterval : interval;
  }
}
