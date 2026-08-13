import 'package:shared_preferences/shared_preferences.dart';

/// Persisted lifetime stats — the retention/score-keeper layer (Phase 5).
class GameStats {
  const GameStats({
    required this.best,
    required this.gamesPlayed,
    required this.totalCleared,
  });

  static const empty = GameStats(best: 0, gamesPlayed: 0, totalCleared: 0);

  /// Best single-run score.
  final int best;

  /// How many runs have ended.
  final int gamesPlayed;

  /// Lifetime cars cleared across all runs.
  final int totalCleared;
}

/// The outcome of recording a finished run.
class RunResult {
  const RunResult({required this.isBest, required this.stats});
  final bool isBest;
  final GameStats stats;
}

/// Persists the local score-keeper across sessions via shared_preferences.
///
/// The simulation never touches this — scoring lives in the sim; persistence is
/// a service concern.
class ScoreStore {
  static const String _kBest = 'signal.best';
  static const String _kGames = 'signal.gamesPlayed';
  static const String _kTotal = 'signal.totalCleared';

  Future<GameStats> loadStats() async {
    final p = await SharedPreferences.getInstance();
    return GameStats(
      best: p.getInt(_kBest) ?? 0,
      gamesPlayed: p.getInt(_kGames) ?? 0,
      totalCleared: p.getInt(_kTotal) ?? 0,
    );
  }

  /// Records a finished run: bumps games played, adds [score] to the lifetime
  /// total, and updates the best if beaten. Returns whether it set a new best
  /// plus the updated stats.
  Future<RunResult> recordRun(int score) async {
    final p = await SharedPreferences.getInstance();
    final best = p.getInt(_kBest) ?? 0;
    final games = (p.getInt(_kGames) ?? 0) + 1;
    final total = (p.getInt(_kTotal) ?? 0) + score;
    final isBest = score > best;
    final newBest = isBest ? score : best;

    await p.setInt(_kGames, games);
    await p.setInt(_kTotal, total);
    if (isBest) await p.setInt(_kBest, newBest);

    return RunResult(
      isBest: isBest,
      stats: GameStats(best: newBest, gamesPlayed: games, totalCleared: total),
    );
  }
}
