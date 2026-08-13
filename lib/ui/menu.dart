import 'package:flutter/material.dart';

import '../game/traffic_game.dart';
import '../services/score_store.dart';

/// The title screen. Shown over a freshly-seeded, paused board so the player
/// sees the city before the first (losable) second of play.
class MenuOverlay extends StatelessWidget {
  const MenuOverlay({super.key, required this.game, required this.onPlay});

  final TrafficGame game;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xB80B0D13),
      child: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _SignalGlyph(),
                  const SizedBox(height: 22),
                  const Text(
                    'SIGNAL',
                    style: TextStyle(
                      color: Color(0xFFEDEFF2),
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'KEEP THE CITY MOVING',
                    style: TextStyle(
                      color: Color(0xFF8A93A6),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 44),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF35D07F),
                      foregroundColor: const Color(0xFF0A0C11),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 56,
                        vertical: 16,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                    onPressed: onPlay,
                    child: const Text('PLAY'),
                  ),
                  const SizedBox(height: 22),
                  ValueListenableBuilder<GameStats>(
                    valueListenable: game.stats,
                    builder: (context, s, _) {
                      if (s.gamesPlayed == 0 && s.best == 0) {
                        return const SizedBox(height: 20);
                      }
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _menuStat('BEST', '${s.best}'),
                          const SizedBox(width: 26),
                          _menuStat('GAMES', '${s.gamesPlayed}'),
                          const SizedBox(width: 26),
                          _menuStat('CLEARED', '${s.totalCleared}'),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: 24),
                child: Text(
                  'Tap a junction to switch its lights',
                  style: TextStyle(color: Color(0xFF6E7688), fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _menuStat(String label, String value) {
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

/// A small horizontal three-lens traffic head; only the green lens is lit — the
/// brand mark in one glyph.
class _SignalGlyph extends StatelessWidget {
  const _SignalGlyph();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF15181F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF262B36)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          _Lens(Color(0x59E5484D)),
          SizedBox(width: 10),
          _Lens(Color(0x59D8B24A)),
          SizedBox(width: 10),
          _Lens(Color(0xFF3BDB86), lit: true),
        ],
      ),
    );
  }
}

class _Lens extends StatelessWidget {
  const _Lens(this.color, {this.lit = false});

  final Color color;
  final bool lit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: lit
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.6),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );
  }
}
