# Traffic Control Revamp → Cross-Platform Mobile Game: Build Brief

*Prepared for Beck — August 13, 2026 (rev. 2: Flutter + Flame, Claude Code build)*

---

## Read this first: the premise is wrong, but the plan is salvageable

You said you checked the App Store and "nothing like it exists." That's not accurate, and building on that belief is the fastest way to waste months. There's an entire cluster of traffic-light-controller games already shipping, one with 1,700+ ratings at 4.2 stars. If your story to yourself (or an investor, or your own motivation) is "first mover in an empty category," it collapses the moment anyone searches "traffic control" in the store.

Here's the part that saves the idea: almost every competitor is playing a **different game than the one you loved.** They're single/few-intersection *collision-avoidance reflex* games — fail = a crash. Traffic Control 2 is a *whole-city throughput/flow* game — fail = **gridlock**, and your score is cars that complete their trip across the grid. That distinction is genuinely under-served. So the opportunity isn't "a category nobody has touched." It's "the good version of a mechanic everyone has touched badly, aimed at the flow/optimization variant the leaders skipped."

---

## Competitive landscape (Apple App Store, US)

| App | Developer | Model | Rating (count) | What it actually is |
|---|---|---|---|---|
| **Crazy Traffic Control** | BoomHits | Free + IAP ($2.99 no-ads, coin packs to $19.99) | **4.2 (1.7K)** | Market leader. Multi-intersection, tap-to-change lights, prevent collisions. Adds trains + pedestrians. Fail = crash. |
| **Crossroads: Traffic Light** | Dukhnich Dmitrii | Free | 5.0 (18) | Single busy intersection. Priority vehicles. 30+ levels. Fail = crash. Tiny install base. |
| **Traffic Light Control Madness** | Tahir Ali | Free | 1.0 (1) | Low-effort clone, effectively dead. The name is taken; the quality floor is very low. |
| **Street Light – Madness** | — | Free | — | Same collision-avoidance lane. |
| **Highway Traffic Control Game** | — | Free | — | Newer, same lane. |
| **Traffix** (traffic-flow puzzle) | — | Varies | — | Closest in spirit to "flow," but intersection-scale, not city-grid. |

**Takeaways:** the category is real and monetized (Crazy Traffic Control proves people pay); quality is bimodal (one strong leader, a long tail of 1-star throwaways); **nobody owns the city-grid / gridlock variant well**; and the obvious names are burned.

*[Guessing] on exact ranking/downloads — the store doesn't expose installs; rating volume is a proxy, not gospel.*

---

## 1. What the game actually is (mechanic spec, from playing it)

I played Traffic Control 2 directly. Stripped to its rules:

- **Board:** top-down city as a grid of blocks. Intersections ("junctions") sit at grid crossings — roughly 5×6 in the original.
- **Control:** tap a junction's light to toggle which axis gets green (N–S vs E–W). One tap, one junction, instant.
- **Agents:** cars spawn at the edges, each with a route across the city. They obey greens, stop at reds, queue behind each other.
- **Scoring:** every car that completes its trip and exits = **+1 point**. (I watched the score tick 16 → 17 live as cars cleared.)
- **Difficulty curve:** spawn rate rises with score. Longer survival = denser traffic.
- **Fail state:** **gridlock.** A "Queue" meter tracks backed-up cars. Too many piled up with nowhere to go and you're locked for good. No crash mechanic — the enemy is congestion.
- **Feel:** calm-to-frantic ramp. Trivial for 30 seconds, then you're triaging six junctions at once. "Trickier than it looks" is the whole hook.

Design DNA is closer to **Mini Metro / Flight Control** (network flow under rising pressure) than to the collision-avoidance clones. Lean into that.

---

## 2. Recommended tech stack — Flutter + Flame

You're building **iOS *and* Android**, and you're building it **with Claude Code.** Those two constraints together kill both obvious defaults:

- **Native (SpriteKit) is out** — it's iOS-only. Building the same game twice in two native toolchains doubles the work and defeats the point.
- **Unity is out too**, and this is the non-obvious call. Unity is editor-first: a large share of real work happens by dragging objects in a visual scene editor, wiring prefabs, setting inspector values. **Claude Code can't drive that GUI.** You'd be the manual bridge on every change, and that friction compounds forever.

**Recommendation: Flutter + Flame** (Flame is a 2D game engine on top of Flutter). One Dart codebase → both platforms. The deciding factor: it's *entirely code*, no visual editor in the loop, so Claude Code can own the whole thing end to end — game loop, sprites, layout, sim, UI — all as text it can read and rewrite.

**The honest tradeoff:** Flame has a smaller community and thinner Stack Overflow coverage than Unity, so obscure problems have less ground to stand on. For a 2D grid game of this complexity, that's a manageable risk — nothing here strains Flame. Runner-up is **Godot** (free, mature, exports to both) but it pulls you back toward the editor-in-the-loop problem, so it's a worse fit for a Claude Code build despite being a stronger engine in the abstract.

| Layer | Choice | Why |
|---|---|---|
| Language | **Dart 3** | One language, both platforms, all code |
| Rendering / game loop | **Flame** (`FlameGame`, `Component`, `update(dt)`) | 2D components + built-in loop |
| Pathfinding / AI | Hand-rolled grid routing over the sim graph (BFS/A* on the road grid) | Small grid; no heavy lib needed |
| UI chrome (menus, HUD) | **Flutter widgets** overlaying the `GameWidget` | Fast to build menus/settings/overlays |
| Persistence | `shared_preferences` (scores/settings) + JSON for replays | No backend for MVP |
| Leaderboards | `games_services` plugin → Game Center + Google Play Games | Cross-platform native leaderboards |
| Monetization | `in_app_purchase` plugin | Mirror the proven no-ads + cosmetics model |
| Analytics | Firebase or TelemetryDeck | Know the funnel before scaling |

---

## 3. Framework / architecture

**The one rule that matters most:** the **simulation** and the **rendering** are strictly separated. The sim is pure Dart — it imports nothing from Flame or Flutter, knows nothing about pixels, and is fully deterministic and unit-testable. Flame reads the sim each frame and draws it. This is what lets you test "does this light config cause gridlock" with zero rendering, and it's the discipline Claude Code will break unless the spec forbids it.

```
traffic_control/
├── lib/
│   ├── main.dart                        // Flutter app entry, hosts GameWidget
│   ├── simulation/                      // PURE Dart — NO flame/flutter imports
│   │   ├── city_grid.dart               // grid dims, blocks, road cells
│   │   ├── junction.dart                // greenAxis (ns/ew), toggle()
│   │   ├── road_graph.dart              // drivable cells + adjacency
│   │   ├── car.dart                     // route, cell position, state
│   │   ├── car_spawner.dart             // spawn-rate curve keyed to score
│   │   ├── traffic_simulation.dart      // tick(): advance cars, resolve stops
│   │   └── gridlock_detector.dart       // queue/deadlock -> game over
│   ├── game/                            // Flame layer, reads the sim
│   │   ├── traffic_game.dart            // FlameGame; update(dt) -> sim.tick()
│   │   ├── junction_component.dart      // tappable light sprite
│   │   └── car_component.dart
│   ├── ui/                              // Flutter widgets
│   │   ├── main_menu.dart
│   │   ├── hud.dart                     // score, queue meter, pause
│   │   └── game_over.dart
│   └── services/
│       ├── score_store.dart
│       ├── leaderboard_service.dart
│       └── store_service.dart
└── test/
    └── simulation_test.dart             // deterministic sim, no rendering
```

**Core loop:**

1. Flame's `update(dt)` calls `simulation.tick()` on a **fixed timestep** (accumulate `dt`, step the sim in fixed increments).
2. `tick` advances every car one cell along its route, respecting each junction's green axis and cars ahead.
3. `GridlockDetector` checks the queue/deadlock condition → game over.
4. Flame reconciles each `CarComponent`/`JunctionComponent` to the updated sim state.
5. Player taps a junction → `junction.toggle()` mutates only the model; rendering follows next frame.

**Two things that will bite you if skipped:**

- **Determinism.** Fixed timestep + seeded RNG for spawns. Required for replays, tests, and a future daily-challenge mode.
- **Deadlock detection is the actual hard problem.** "Cars are queued" is easy. "This config can *never* resolve" is graph cycle-detection. Get it right or the fail state feels random and players churn. (MVP can approximate with a queue-overflow threshold — see the sim spec.)

---

## 4. MVP scope (~6–8 weeks of focused build)

Cut everything that isn't the core loop. The original proves one mechanic is enough.

**In:** one fixed grid (start ~4×4 junctions); tap-to-toggle lights; cars spawn/route/queue/score on exit; rising spawn-rate difficulty; gridlock → game over → score; local high score + one cross-platform leaderboard; minimal menu, HUD (score + queue meter), game-over screen; haptic tick on toggle (cheap, huge feel upgrade over the Flash original).

**Out (v1.1+):** multiple maps/campaign; pedestrians, trains, emergency-vehicle priority (this is where competitors live — add *after* your flow core is proven); IAP/no-ads (add once you have retention data); daily seeded challenge (strong retention lever, but later).

**Verification before you call MVP done:** deterministic sim unit tests (seed + tap sequence → assert score and whether gridlock occurs); playtest checklist — does difficulty ramp feel fair, does gridlock ever feel unfair/random, does a session run 2–5 minutes; and a real build launched on **both** an iOS and an Android device (cross-platform means you test both, every milestone).

---

## 5. How you actually win (differentiation)

Beating a 4.2-star, 1.7K-rating incumbent needs a wedge, not parity. Ranked by leverage:

1. **Own the flow/gridlock variant, not collision-avoidance.** Market as "keep the city moving," not "don't crash." The Mini Metro adjacency — calmer, more premium, more replayable than the frantic crash-clones.
2. **Feel and polish.** The long-tail bar is low. Smooth car motion, satisfying haptics, clean minimalist art, and a readable queue meter out-class 90% of the field immediately.
3. **Endless + daily seeded challenge.** The original is a high-score arcade loop. Deterministic daily boards + leaderboards is a proven retention engine (Wordle-style "same board for everyone today").
4. **Respect the player.** No forced-ad walls. One-time no-ads/premium unlock + cosmetic themes (city skins, car palettes). The incumbent already validated people pay $2.99 for exactly this.

---

## 6. Naming, positioning & IP

**Names are burned.** "Traffic Control," "Crazy Traffic Control," "Traffic Light Control Madness" are taken. Pick a searchable name that signals *flow* not *crash*, with App Store + domain availability. Directions: *Gridlock, Green Wave, Rush Hour Control, Keep It Moving, Flowtown, Signal.* Verify trademark + store-name collision before committing.

**IP — the part you didn't ask about but need.** [Certain] game *mechanics* aren't copyrightable; you can freely rebuild the traffic-flow-and-gridlock loop. What you *cannot* lift is the original's name, art, sound, or specific expression. Practical rules: build the mechanic, ship your own name and art, and don't market it as "the original game remade" or credit Geheee's title. That keeps a "revamp of an OG classic" clean — it's a mechanic homage, not a copy.

---

## 7. The build path (resolved)

Stack decided (Flutter + Flame), platforms decided (iOS + Android), tooling decided (Claude Code). The next artifacts turn this brief into something you type at tonight:

- **`CLAUDE.md`** — lives at the repo root. Tells Claude Code the hard rules (sim/render separation, determinism, fixed timestep), the stack, the directory contract, the build/test commands, and a phased task order so the agent builds in the right sequence instead of sprinting into a tangle.
- **`SIMULATION_SPEC.md`** — the precise, pure-Dart model: entities, data structures, the exact tick algorithm, scoring, spawn curve, and gridlock detection. This is the document that determines whether the game *works*; hand it to Claude Code before it writes a line of the sim.

Both ship alongside this brief. Start Claude Code in an empty Flutter project, drop these three files in, and point the agent at Phase 0 in `CLAUDE.md`.

---

*Sources: game played live on AddictingGames; competitor data from the Apple App Store (Crazy Traffic Control, Crossroads: Traffic Light, Traffic Light Control Madness, and related listings).*
