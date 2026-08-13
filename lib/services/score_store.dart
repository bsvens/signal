import 'package:shared_preferences/shared_preferences.dart';

/// Persists the local best score across sessions (Phase 5).
///
/// Deliberately tiny and dependency-light: one integer keyed in
/// shared_preferences. The simulation never touches this — scoring lives in the
/// sim; persistence is a service concern.
class ScoreStore {
  static const String _key = 'signal.highScore';

  /// The current best score, or 0 if none has been recorded.
  Future<int> loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_key) ?? 0;
  }

  /// Records [score] if it beats the stored best. Returns true when it set a
  /// new record.
  Future<bool> recordScore(int score) async {
    final prefs = await SharedPreferences.getInstance();
    final best = prefs.getInt(_key) ?? 0;
    if (score > best) {
      await prefs.setInt(_key, score);
      return true;
    }
    return false;
  }
}
