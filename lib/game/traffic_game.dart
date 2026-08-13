import 'package:flame/game.dart';
import 'package:flutter/material.dart';

/// Phase 0 placeholder game.
///
/// This is intentionally minimal: it proves the Flame [GameWidget] renders on
/// both platforms. Real rendering of the simulation snapshot arrives in Phase 2
/// (see docs/SIMULATION_SPEC.md §7 for the fixed-timestep integration contract).
class TrafficGame extends FlameGame {
  @override
  Color backgroundColor() => const Color(0xFF10131A);
}
