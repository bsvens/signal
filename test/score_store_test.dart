import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:traffic_control/services/score_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScoreStore', () {
    test('defaults to empty stats when nothing is stored', () async {
      SharedPreferences.setMockInitialValues({});
      final s = await ScoreStore().loadStats();
      expect(s.best, 0);
      expect(s.gamesPlayed, 0);
      expect(s.totalCleared, 0);
    });

    test('recordRun accumulates games + total and tracks best', () async {
      SharedPreferences.setMockInitialValues({});
      final store = ScoreStore();

      var r = await store.recordRun(10);
      expect(r.isBest, isTrue); // 0 -> 10
      expect(r.stats.best, 10);
      expect(r.stats.gamesPlayed, 1);
      expect(r.stats.totalCleared, 10);

      r = await store.recordRun(7); // not a best, but still counts
      expect(r.isBest, isFalse);
      expect(r.stats.best, 10);
      expect(r.stats.gamesPlayed, 2);
      expect(r.stats.totalCleared, 17);

      r = await store.recordRun(25); // new best
      expect(r.isBest, isTrue);
      expect(r.stats.best, 25);
      expect(r.stats.gamesPlayed, 3);
      expect(r.stats.totalCleared, 42);
    });

    test('persists across store instances', () async {
      SharedPreferences.setMockInitialValues({});
      await ScoreStore().recordRun(42);
      final s = await ScoreStore().loadStats();
      expect(s.best, 42);
      expect(s.gamesPlayed, 1);
      expect(s.totalCleared, 42);
    });
  });
}
