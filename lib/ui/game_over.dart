import 'package:flutter/material.dart';

import '../game/traffic_game.dart';
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
              ValueListenableBuilder<int>(
                valueListenable: game.bestScore,
                builder: (context, best, _) {
                  if (game.isNewBest) {
                    return Container(
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
                    );
                  }
                  return Text(
                    'BEST  $best',
                    style: const TextStyle(
                      color: Color(0xFF8A93A6),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
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
}
