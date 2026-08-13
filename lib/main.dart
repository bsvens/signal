import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/traffic_game.dart';
import 'ui/game_over.dart';
import 'ui/hud.dart';

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
          Positioned.fill(child: Hud(game: _game)),
          // Game-over overlay: transparent and non-blocking until gridlock.
          Positioned.fill(child: GameOverOverlay(game: _game)),
        ],
      ),
    );
  }
}
