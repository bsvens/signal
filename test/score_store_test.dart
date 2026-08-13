import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:traffic_control/services/score_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScoreStore', () {
    test('defaults to 0 when nothing is stored', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await ScoreStore().loadHighScore(), 0);
    });

    test('records only scores that beat the stored best', () async {
      SharedPreferences.setMockInitialValues({});
      final store = ScoreStore();

      expect(await store.recordScore(10), isTrue); // 0 -> 10 (new best)
      expect(await store.loadHighScore(), 10);

      expect(await store.recordScore(7), isFalse); // not a best
      expect(await store.loadHighScore(), 10);

      expect(await store.recordScore(25), isTrue); // 10 -> 25 (new best)
      expect(await store.loadHighScore(), 25);
    });

    test('persists across store instances', () async {
      SharedPreferences.setMockInitialValues({});
      await ScoreStore().recordScore(42);
      // A fresh instance reads the same underlying prefs.
      expect(await ScoreStore().loadHighScore(), 42);
    });
  });
}
