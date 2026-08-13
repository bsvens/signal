import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/traffic_game.dart';
import 'ui/game_over.dart';
import 'ui/hud.dart';
import 'ui/menu.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TrafficControlApp());
}

class TrafficControlApp extends StatelessWidget {
  const TrafficControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Traffic Control',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final TrafficGame _game = TrafficGame();
  bool _wasGameOver = false;
  bool _showMenu = true;

  @override
  void initState() {
    super.initState();
    _game.pauseForMenu(); // hold the board still under the title screen
    _game.hud.addListener(_onSnapshot);
  }

  void _play() {
    setState(() => _showMenu = false);
    _game.beginPlay();
  }

  @override
  void dispose() {
    _game.hud.removeListener(_onSnapshot);
    super.dispose();
  }

  // Fire a heavier haptic once, on the transition into gridlock.
  void _onSnapshot() {
    final over = _game.hud.value.gameOver;
    if (over && !_wasGameOver) HapticFeedback.heavyImpact();
    _wasGameOver = over;
  }

  void _onTapDown(TapDownDetails details) {
    if (_game.handleTapAtPixel(details.localPosition)) {
      HapticFeedback.selectionClick();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF10131A),
      body: Stack(
        children: [
          // The board. A transparent tap layer sits directly over it and
          // converts pixels to a junction toggle.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: _onTapDown,
              child: GameWidget(game: _game),
            ),
          ),
          // Non-interactive HUD chrome ignores pointer so board taps pass
          // through; only its pause button (a Material InkWell) catches taps.
          // Hidden while the title screen is up.
          if (!_showMenu) Positioned.fill(child: Hud(game: _game)),
          // Game-over overlay: transparent and non-blocking until gridlock.
          Positioned.fill(child: GameOverOverlay(game: _game)),
          // Title screen over a paused board.
          if (_showMenu)
            Positioned.fill(
              child: MenuOverlay(game: _game, onPlay: _play),
            ),
        ],
      ),
    );
  }
}
