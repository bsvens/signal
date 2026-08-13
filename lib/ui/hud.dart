import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/traffic_game.dart';
import '../simulation/snapshot.dart';

/// The in-game heads-up display: score, queue meter, and a pause toggle.
///
/// Reads the game's snapshot notifier and rebuilds on each tick. It renders
/// nothing that isn't in the snapshot — the sim stays authoritative.
class Hud extends StatelessWidget {
  const Hud({super.key, required this.game});

  final TrafficGame game;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // The board is a centered square of side shortestSide * 0.94 (see
    // GridLayout). Anchor the HUD to the band just above it so the instrument
    // panel and the board read as one machine instead of drifting apart.
    final board = mq.size.shortestSide * 0.94;
    final topBand = (mq.size.height - board) / 2;
    final topPad = math.max(mq.padding.top + 8, topBand - 64);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, topPad, 16, 0),
      child: Align(
        alignment: Alignment.topCenter,
        child: ValueListenableBuilder<SimSnapshot>(
          valueListenable: game.hud,
          builder: (context, snap, _) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Read-outs ignore pointers so taps fall through to the
                // board; only the pause button catches its own taps.
                IgnorePointer(
                  child: ValueListenableBuilder<int>(
                    valueListenable: game.bestScore,
                    builder: (context, best, _) =>
                        _ScorePill(score: snap.score, best: best),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: IgnorePointer(child: _QueueMeter(snapshot: snap)),
                ),
                const SizedBox(width: 14),
                _PauseButton(game: game),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill({required this.score, required this.best});

  final int score;
  final int best;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xCC1B2130),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'SCORE',
                style: TextStyle(
                  color: Color(0xFF8A93A6),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 8),
              // A quick scale pop each time the score ticks up — restarted by
              // keying the animation on the score value itself.
              TweenAnimationBuilder<double>(
                key: ValueKey<int>(score),
                tween: Tween(begin: 1.35, end: 1.0),
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutBack,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: Text(
                  '$score',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          Text(
            'BEST $best',
            style: const TextStyle(
              color: Color(0xFF6E7688),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// A horizontal fill bar showing `queueLength / queueLimit`, greening when calm
/// and reddening as gridlock approaches (SIMULATION_SPEC.md §6).
class _QueueMeter extends StatelessWidget {
  const _QueueMeter({required this.snapshot});

  final SimSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final fill = snapshot.queueFill;
    final color = Color.lerp(
      const Color(0xFF35D07F),
      const Color(0xFFFF5A5A),
      Curves.easeIn.transform(fill),
    )!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'QUEUE',
              style: TextStyle(
                color: Color(0xFF8A93A6),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            Text(
              '${snapshot.queueLength}/${snapshot.queueLimit}',
              style: const TextStyle(
                color: Color(0xFFB7C0D4),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 12,
          decoration: BoxDecoration(
            color: const Color(0xFF1B2130),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF2A3140)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 200),
                  widthFactor: fill,
                  child: Container(color: color),
                ),
                // Danger tick at the gridlock limit.
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(width: 2, color: const Color(0x99FF5A5A)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PauseButton extends StatefulWidget {
  const _PauseButton({required this.game});

  final TrafficGame game;

  @override
  State<_PauseButton> createState() => _PauseButtonState();
}

class _PauseButtonState extends State<_PauseButton> {
  @override
  Widget build(BuildContext context) {
    final paused = widget.game.isPaused;
    return Material(
      color: const Color(0xCC1B2130),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          widget.game.togglePause();
          setState(() {});
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }
}
