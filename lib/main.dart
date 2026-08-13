import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'game/traffic_game.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: GameWidget(game: _game)),
    );
  }
}
