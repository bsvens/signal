import 'sim_config.dart';

/// Tier 1 gridlock detection: queue-overflow threshold (SIMULATION_SPEC.md §6).
///
/// The fail state is congestion, not collision. Two triggers:
///  1. `queueLength >= QUEUE_LIMIT` sustained for `GRIDLOCK_GRACE`
///     consecutive ticks.
///  2. any single car stuck (`waitingTicks >= STUCK_LIMIT`) — the board is
///     unrecoverable.
///
/// Tier 2 (true deadlock via waiting-for cycle detection) is a later
/// enhancement; this class deliberately implements only Tier 1 for the MVP.
class GridlockDetector {
  int _ticksOverLimit = 0;

  /// Consecutive ticks the queue has been at or over the limit. Exposed for
  /// tests and diagnostics.
  int get ticksOverLimit => _ticksOverLimit;

  /// Returns true when the game should end this tick.
  bool check({
    required int queueLength,
    required int maxWaitingTicks,
    required SimConfig config,
  }) {
    if (queueLength >= config.queueLimit) {
      _ticksOverLimit++;
    } else {
      _ticksOverLimit = 0;
    }
    if (_ticksOverLimit >= config.gridlockGrace) return true;
    if (maxWaitingTicks >= config.stuckLimit) return true;
    return false;
  }
}
