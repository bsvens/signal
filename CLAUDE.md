# CLAUDE.md — Traffic Control Revamp

This file governs how you (Claude Code) build this project. Read it fully before writing any code. Re-read the "Hard rules" section at the start of every session.

## What we're building

A cross-platform mobile game: a top-down city grid where the player taps intersections to toggle traffic lights, keeping cars flowing. Score = cars that complete their trip and exit the city. Fail = **gridlock** (cars backed up with nowhere to go). It is a *flow/throughput* game, NOT a collision-avoidance game — cars never crash; they only jam. Design DNA is Mini Metro / Flight Control.

Full product context is in `docs/traffic-control-brief.md`. The exact simulation model is in `docs/SIMULATION_SPEC.md` — that spec is authoritative for all simulation behavior. When code and spec disagree, the spec wins; if you believe the spec is wrong, stop and flag it, do not silently deviate.

## Stack

- **Language:** Dart 3 (null-safe)
- **Engine:** Flame (2D) on top of Flutter
- **UI chrome:** Flutter widgets over the `GameWidget`
- **Targets:** iOS and Android from day one
- **Persistence:** `shared_preferences`; JSON for replays
- Do NOT add Unity, Godot, native Swift/Kotlin game code, or a backend. If you think a dependency is needed, propose it and wait.

## Hard rules (do not violate these)

1. **Pure simulation.** Everything under `lib/simulation/` is pure Dart. It MUST NOT import `package:flame/*`, `package:flutter/*`, `dart:ui`, or anything rendering-related. No pixels, no colors, no sprites, no `dt` in seconds. The sim thinks in grid cells and integer ticks only. If you catch yourself importing Flame into a simulation file, stop — the design is wrong.
2. **Rendering is downstream and dumb.** `lib/game/` (Flame) reads simulation state each frame and draws it. Rendering never contains game logic. A car's position, whether a light is green, whether the game is over — all decided in the sim, never in a component.
3. **Determinism.** The sim runs on a **fixed timestep** with a **seeded RNG**. Given the same seed and the same sequence of player taps, `tick()` must produce byte-identical results every run. No `DateTime.now()`, no unseeded `Random()`, no wall-clock anywhere in `lib/simulation/`.
4. **Fixed-timestep loop.** Flame's `update(dt)` accumulates real `dt` and steps the sim in fixed increments (see spec). Never pass raw frame `dt` into sim logic.
5. **Tests are part of "done."** Every simulation module ships with unit tests. A phase is not complete until `flutter test` passes. No exceptions, no "I'll add tests later."
6. **Small, reviewable commits.** One coherent change per commit. Do not refactor unrelated code inside a feature commit.

## Directory contract

```
lib/
  main.dart                 // Flutter entry, hosts GameWidget + Flutter UI
  simulation/               // PURE Dart, deterministic, unit-tested
  game/                     // Flame components; reads sim, draws it
  ui/                       // Flutter widgets: menu, HUD, game over
  services/                 // scores, leaderboards, IAP (stub until Phase 5)
docs/
  traffic-control-brief.md  // product/strategy context
  SIMULATION_SPEC.md        // authoritative sim model
test/
  simulation_test.dart      // deterministic sim tests
```

## Commands

- Install deps: `flutter pub get`
- Run (choose a device): `flutter run`
- Test (must pass before any phase is "done"): `flutter test`
- Analyze/lint (must be clean): `flutter analyze`
- Format: `dart format .`
- Build iOS: `flutter build ios` · Build Android: `flutter build apk`

## Conventions

- Prefer immutable data + explicit state transitions in the sim. The sim exposes a read-only snapshot for rendering; rendering never mutates sim state directly — it calls intent methods (e.g. `simulation.toggleJunction(id)`).
- Keep files focused; one primary class per file, named to match.
- Document any non-obvious algorithm (routing, gridlock detection) with a comment pointing to the relevant section of `SIMULATION_SPEC.md`.
- No premature abstraction. Build the 4×4 fixed grid first; generalize only when a second map actually exists.

## Build order (do phases in sequence; do not skip ahead)

**Phase 0 — Scaffold.** Create the Flutter project, add Flame, set up the directory contract, get a blank `GameWidget` rendering on iOS and Android. Commit. Confirm both platforms launch before continuing.

**Phase 1 — Pure simulation, headless.** Implement `lib/simulation/` per `SIMULATION_SPEC.md`: grid, junctions, road graph, cars, routing, `tick()`, scoring, spawner, gridlock detection. NO rendering. Write `test/simulation_test.dart` proving: a car routes edge-to-edge and scores; a red light stops a car; a seeded run is reproducible; a forced-jam scenario triggers gridlock. `flutter test` green before Phase 2.

**Phase 2 — Render the sim.** Build `lib/game/` Flame components that draw the current sim snapshot: grid, junction lights (color by green axis), cars moving cell-to-cell (interpolated for smoothness, but position of record is the sim's). Wire the fixed-timestep loop. No interaction yet.

**Phase 3 — Interaction + HUD.** Tap a junction → `toggleJunction`. Build the Flutter HUD (score, queue meter, pause). Game-over overlay on gridlock. This is the first playable build — playtest it on a real device.

**Phase 4 — Feel + difficulty.** Tune the spawn curve, add haptic feedback on toggle, smooth car motion, readable queue meter, minimalist art pass. Target a 2–5 minute session with a fair difficulty ramp.

**Phase 5 — Retention + services (only after core is fun).** Local high scores, then one cross-platform leaderboard (`games_services`). Stub IAP behind a flag; do not wire real purchases until there's retention data.

At the end of each phase, run `flutter analyze` and `flutter test`, then summarize what changed and what the next phase needs. Ask before starting a new phase.
