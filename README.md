# Signal

A top-down city traffic-flow game. You tap intersections to toggle their green
axis and keep cars moving across the grid. **Score** is cars that complete their
trip and exit the city; **you lose to gridlock**, not to crashes. Design DNA is
Mini Metro / Flight Control — network flow under rising pressure.

Built with **Flutter + Flame**, one Dart codebase targeting **iOS and Android**.

## Architecture

The one rule that matters: the **simulation** and the **rendering** are strictly
separated.

- `lib/simulation/` — **pure Dart.** No Flame/Flutter/`dart:ui` imports, no
  pixels, no seconds. The sim thinks in grid cells and integer ticks and is fully
  deterministic (seeded RNG + fixed timestep), so a given seed and tap sequence
  replays byte-for-byte. This is where all game logic lives.
- `lib/game/` — the **Flame layer.** Reads the sim snapshot each frame and draws
  it (grid, junction lights, interpolated cars). Contains no game logic.
- `lib/ui/` — Flutter widgets over the game: HUD (score, queue meter, pause) and
  the game-over overlay.
- `docs/` — `SIMULATION_SPEC.md` is the authoritative model; `CLAUDE.md` holds
  the build rules and phase order; `traffic-control-brief.md` is product context.

## Status

- **Phase 0** — Scaffold (Flutter + Flame, directory contract). ✅
- **Phase 1** — Pure simulation + tests (routing, tick, scoring, spawner,
  Tier-1 gridlock). ✅ All spec §8 contracts covered.
- **Phase 2** — Render the sim on a fixed-timestep loop. ✅
- **Phase 3** — Tap interaction, HUD, game-over/restart. ✅ First playable.
- **Phase 4** — Feel + difficulty tuning. _next_
- **Phase 5** — Retention + services (high scores, leaderboard). _later_

## Develop

```bash
flutter pub get
flutter run           # choose an iOS or Android device
flutter test          # deterministic simulation tests must pass
flutter analyze       # must be clean
dart format .
```

Build: `flutter build ios` · `flutter build apk`.
