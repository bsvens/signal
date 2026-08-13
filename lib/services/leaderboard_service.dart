/// Cross-platform leaderboard integration point (Phase 5).
///
/// The brief calls for ONE cross-platform leaderboard (Game Center + Google
/// Play Games via the `games_services` plugin) — but that requires real store
/// configuration (a Game Center leaderboard id, a Play Games app id, signed
/// builds) that can't be set up or tested from here. So this is a deliberate
/// scaffold: a stable interface plus a safe no-op implementation, gated behind
/// [leaderboardEnabled]. Nothing calls the network until it's wired and turned
/// on, so it can never crash a build or a run.
///
/// To go live later: add `games_services`, implement [GamesServicesLeaderboard]
/// against it, flip [leaderboardEnabled] to true, and construct that instead of
/// [NoopLeaderboardService].
abstract class LeaderboardService {
  /// Submit a completed-run score. Implementations must swallow their own
  /// errors (offline, not signed in, not configured) — a leaderboard failure
  /// must never disrupt gameplay.
  Future<void> submitScore(int score);

  /// Show the platform leaderboard UI, if available.
  Future<void> showLeaderboard();
}

/// Master switch. Kept false until a real backend is wired and configured.
const bool leaderboardEnabled = false;

/// Does nothing, safely. The default until a real backend is configured.
class NoopLeaderboardService implements LeaderboardService {
  const NoopLeaderboardService();

  @override
  Future<void> submitScore(int score) async {
    // Intentionally empty — see class docs / leaderboardEnabled.
  }

  @override
  Future<void> showLeaderboard() async {
    // Intentionally empty.
  }
}
