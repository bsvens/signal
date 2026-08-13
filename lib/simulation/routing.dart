import 'cell.dart';
import 'city_grid.dart';

/// Breadth-first pathfinding over the road adjacency graph.
///
/// See docs/SIMULATION_SPEC.md §3: routes are computed on the road graph
/// ignoring other cars and light states (those are resolved at move time).
/// The grid is small, so BFS is sufficient; A* is optional.
///
/// Because [CityGrid.neighbours] returns a stable neighbour order, BFS is
/// deterministic: the same (start, goal) always yields the same route.
List<Cell>? findRoute(CityGrid grid, Cell start, Cell goal) {
  if (start == goal) return <Cell>[start];
  if (!grid.isRoad(start) || !grid.isRoad(goal)) return null;

  final cameFrom = <Cell, Cell>{};
  final visited = <Cell>{start};
  final queue = <Cell>[start];
  var head = 0;

  while (head < queue.length) {
    final current = queue[head++];
    for (final next in grid.neighbours(current)) {
      if (visited.contains(next)) continue;
      visited.add(next);
      cameFrom[next] = current;
      if (next == goal) {
        return _reconstruct(cameFrom, start, goal);
      }
      queue.add(next);
    }
  }
  return null; // No path (should not happen on a connected grid).
}

List<Cell> _reconstruct(Map<Cell, Cell> cameFrom, Cell start, Cell goal) {
  final path = <Cell>[goal];
  var current = goal;
  while (current != start) {
    current = cameFrom[current]!;
    path.add(current);
  }
  return path.reversed.toList(growable: false);
}
