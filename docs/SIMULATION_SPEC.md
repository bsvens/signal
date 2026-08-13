# SIMULATION_SPEC.md — Traffic Control Sim (authoritative)

This document defines the **pure-Dart simulation model**. It is authoritative: rendering and UI conform to it, not the other way around. Everything here lives under `lib/simulation/` and imports nothing from Flame/Flutter/`dart:ui`. The sim thinks in **grid cells** and **integer ticks**, never pixels or seconds.

If a rule here is ambiguous or seems wrong, stop and flag it before coding around it.

---

## 1. Coordinate model

- The city is a grid of **cells**, addressed `(col, row)` with integer coordinates, origin top-left, `col` increasing right, `row` increasing down.
- Grid size for MVP: a road network with **4×4 junctions**. Roads run along every junction row and column; blocks (buildings) fill the space between. Only **road cells** are drivable.
- A **direction** is one of `north, south, east, west`. Moving `east` increases `col`; `south` increases `row`.
- Each road cell knows its drivable neighbors (the adjacency graph). Junction cells connect both axes; straight road cells connect along one axis.

## 2. Entities

### Junction
- `id` (stable int), `cell` (col,row).
- `greenAxis`: enum `{ ns, ew }` — which axis currently has green. Default `ns`.
- `toggle()`: flips `ns <-> ew`. This is the ONLY player action.
- A car may enter/cross a junction cell only if its direction of travel matches `greenAxis`:
  - moving north/south → allowed when `greenAxis == ns`
  - moving east/west → allowed when `greenAxis == ew`

### Car
- `id`, `route`: an ordered list of cells from a spawn edge cell to an exit edge cell.
- `routeIndex`: index of the cell the car currently occupies.
- `state`: `{ moving, waiting, exited }`.
- `waitingTicks`: consecutive ticks the car has been blocked (for gridlock detection).
- A car occupies exactly one cell at a time. **At most one car per cell** (this is the whole source of congestion).

### CityGrid
- Holds cells, adjacency, junctions, and the set of spawn edges and exit edges (perimeter road cells).

### TrafficSimulation
- Owns the grid, all cars, the RNG (seeded), `score` (int), `tickCount` (int), `gameOver` (bool).
- Exposes an immutable **snapshot** for rendering: junction states + car positions/route progress + score + queue length + gameOver.
- Intent API for the UI: `toggleJunction(int id)`.

## 3. Routing

- On spawn, pick a random spawn edge cell and a random exit edge cell (seeded RNG), then compute a path with **BFS** (grid is small; A* is optional). The route is fixed for the car's life — cars do not re-route.
- Routes are computed on the road adjacency graph ignoring other cars and light states (those are resolved at move time, not route time).
- If no path exists (shouldn't on a connected grid), discard and re-roll the spawn.

## 4. The tick algorithm

`tick()` advances the sim exactly one fixed step. It is deterministic. Order matters — follow it exactly:

```
tick():
  if gameOver: return
  tickCount += 1

  # 1. Spawn (see spawn curve). Only spawn onto an empty spawn cell.
  maybeSpawnCars()

  # 2. Move cars. Process in a STABLE order (ascending car id) for determinism.
  #    A car advances to its next route cell iff:
  #      a. it is not already exited, AND
  #      b. the next cell is currently empty (no other car), AND
  #      c. if the next cell is a junction, the car's travel direction
  #         matches that junction's greenAxis, AND
  #      d. if the car is currently ON a junction cell leaving it, that's always allowed
  #         (greens gate ENTERING a junction, not leaving).
  for car in carsSortedById where state != exited:
      next = car.route[car.routeIndex + 1]  # null if at exit
      if canAdvance(car, next):
          move car to next; car.waitingTicks = 0; car.state = moving
          if next is an exit edge cell and is last in route:
              car.state = exited; score += 1   # SCORING happens here
      else:
          car.state = waiting; car.waitingTicks += 1

  # 3. Remove exited cars from the active set.
  reapExitedCars()

  # 4. Gridlock check (see below). If triggered: gameOver = true.
  checkGridlock()
```

**Important scoring rule:** a point is scored the instant a car reaches the final cell of its route (an exit edge). One car = exactly one point, once.

**Occupancy resolution:** because cars move one at a time in id order and only into an *empty* cell, two cars can never occupy the same cell. A car directly behind another that just moved will find the cell empty on its own turn within the same tick — this produces smooth single-file flow. (This is intentional; do not batch-move.)

## 5. Spawn curve (difficulty)

- Spawning is driven by `score`, matching the original ("as your score increases the amount of cars entering the city will increase").
- Define spawn interval in ticks: `spawnEveryTicks = max(MIN_INTERVAL, BASE_INTERVAL - floor(score / RAMP))`.
  - Suggested starting constants (tune in Phase 4): `BASE_INTERVAL = 45`, `RAMP = 5`, `MIN_INTERVAL = 8`.
- On a spawn opportunity, attempt to spawn 1 car at a random free spawn edge. If that edge cell is occupied, skip this spawn (do not queue infinitely) — a blocked spawn edge is itself a pressure signal feeding gridlock.
- All randomness uses the sim's seeded RNG so runs are reproducible.

## 6. Gridlock detection (the hard part)

The fail state is congestion, not collision. Two-tier approach — implement Tier 1 for MVP, Tier 2 as an enhancement.

**Tier 1 — queue-overflow threshold (MVP, matches the original's "Queue" meter):**
- `queueLength` = number of cars currently in `waiting` state.
- If `queueLength >= QUEUE_LIMIT` for `GRIDLOCK_GRACE` consecutive ticks → `gameOver`.
  - Suggested: `QUEUE_LIMIT = 12`, `GRIDLOCK_GRACE = 30` (tune in Phase 4).
- Also trigger if any single car's `waitingTicks >= STUCK_LIMIT` (e.g. `STUCK_LIMIT = 240`) — a permanently stuck car means the board is unrecoverable.
- Expose `queueLength` and `QUEUE_LIMIT` in the snapshot so the HUD can draw the queue meter as a fill ratio.

**Tier 2 — true deadlock (enhancement, better feel):**
- Build a "waiting-for" directed graph: each waiting car points to whatever occupies the cell it wants to enter.
- A **cycle** in this graph (car A waits on B, B on C, C on A) that also has no light-toggle that could break it is an unrecoverable deadlock → `gameOver` immediately, without waiting out the grace period.
- Tier 2 makes losses feel earned ("I created a loop") instead of arbitrary ("the meter filled"). Add it only after Tier 1 works and is tested.

## 7. Fixed-timestep integration (rendering side, for reference)

The sim exposes `tick()`. The Flame layer converts real time to ticks:

```
accumulator += dt            // dt in seconds from Flame
while accumulator >= TICK_SECONDS:   // e.g. TICK_SECONDS = 0.25 (4 ticks/sec)
    simulation.tick()
    accumulator -= TICK_SECONDS
// render interpolates car positions between last and current cell using
// (accumulator / TICK_SECONDS) for smoothness — but the sim's cell is truth.
```

`TICK_SECONDS` sets game speed; tune for feel in Phase 4. The sim itself never sees seconds.

## 8. Determinism test contract (Phase 1 must prove)

`test/simulation_test.dart` must include at minimum:

1. **Routing + scoring:** seed a sim, place one car with a known route, tick until it exits, assert `score == 1` and the car reached the exit cell.
2. **Red light stops:** a car facing a junction whose `greenAxis` opposes its direction does not advance; after `toggleJunction`, it advances.
3. **Reproducibility:** two sims constructed with the same seed and given the same tap sequence over N ticks produce identical snapshots (score, car positions, gameOver).
4. **Gridlock fires:** a constructed jam scenario reaches `gameOver` via Tier 1 within the expected tick window.
5. **One car, one point:** a car cannot score twice; `score` increments exactly once per exit.

All five green (`flutter test`) before rendering work begins.
