import 'package:flutter/material.dart';

import '../game/traffic_game.dart';
import '../services/score_store.dart';
import '../simulation/snapshot.dart';

/// Full-screen overlay shown when the city gridlocks. Offers the final score
/// and a restart. Invisible (and non-blocking) while the game is live.
class GameOverOverlay extends StatelessWidget {
  const GameOverOverlay({super.key, required this.game});

  final TrafficGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SimSnapshot>(
      valueListenable: game.hud,
      builder: (context, snap, _) {
        if (!snap.gameOver) return const SizedBox.shrink();
        return Container(
          color: const Color(0xCC0A0C11),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'GRIDLOCK',
                style: TextStyle(
                  color: Color(0xFFFF5A5A),
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'The city seized up.',
                style: TextStyle(color: Color(0xFF8A93A6), fontSize: 15),
              ),
              const SizedBox(height: 28),
              Text(
                '${snap.score}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 64,
                  fontWeight: FontWeight.w800,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const Text(
                'CARS CLEARED',
                style: TextStyle(
                  color: Color(0xFF8A93A6),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 18),
              ValueListenableBuilder<GameStats>(
                valueListenable: game.stats,
                builder: (context, s, _) {
                  final survived = Duration(
                    milliseconds: (snap.tickCount * kTickSeconds * 1000)
                        .round(),
                  );
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (game.isNewBest)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF35D07F),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'NEW BEST!',
                            style: TextStyle(
                              color: Color(0xFF0A0C11),
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                        )
                      else
                        _stat('BEST', '${s.best}'),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _stat('SURVIVED', _fmt(survived)),
                          const SizedBox(width: 28),
                          _stat('GAMES', '${s.gamesPlayed}'),
                          const SizedBox(width: 28),
                          _stat('TOTAL', '${s.totalCleared}'),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 30),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF35D07F),
                  foregroundColor: const Color(0xFF0A0C11),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                onPressed: game.restart,
                child: const Text('PLAY AGAIN'),
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _stat(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFFEDEFF2),
            fontSize: 18,
            fontWeight: FontWeight.w800,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF6E7688),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return "$m:${s.toString().padLeft(2, '0')}";
  }
}
