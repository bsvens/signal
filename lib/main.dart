import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/traffic_game.dart';
import 'simulation/axis.dart';
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

  // --- Input: tap flips one junction (OG); drag syncs a run into a green wave
  // (the Mini-Metro bridge). We track pointers ourselves so a quick touch is a
  // tap and any drag becomes a wave, without gesture-arena ambiguity.
  Offset? _pointerStart;
  bool _dragging = false;
  RoadAxis _waveAxis = RoadAxis.ew;
  final Set<int> _wave = {};

  void _onPointerDown(PointerDownEvent e) {
    _pointerStart = e.localPosition;
    _dragging = false;
    _wave.clear();
  }

  void _onPointerMove(PointerMoveEvent e) {
    final start = _pointerStart;
    if (start == null) return;
    if (!_dragging && (e.localPosition - start).distance > 14) {
      _dragging = true;
    }
    if (!_dragging) return;
    // Swipe direction picks the axis: drag across a row → east-west green.
    if (e.delta.distance > 0.5) {
      _waveAxis = e.delta.dx.abs() >= e.delta.dy.abs()
          ? RoadAxis.ew
          : RoadAxis.ns;
    }
    final id = _game.junctionIdAtPixel(e.localPosition);
    if (id != null && _wave.add(id)) {
      if (_game.alignJunction(id, _waveAxis)) {
        HapticFeedback.selectionClick();
      }
    }
  }

  void _onPointerUp(PointerUpEvent e) {
    if (!_dragging && _pointerStart != null) {
      if (_game.handleTapAtPixel(_pointerStart!)) {
        HapticFeedback.selectionClick();
      }
    }
    _pointerStart = null;
    _dragging = false;
    _wave.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF10131A),
      body: Stack(
        children: [
          // The board. A transparent input layer over it turns a tap into a
          // single toggle and a drag into a synced green wave.
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerUp,
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
