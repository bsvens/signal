import 'cell.dart';
import 'direction.dart';
import 'junction.dart';
import 'sim_config.dart';

/// The static city: road cells, adjacency graph, junctions, and the perimeter
/// cells where cars enter and exit.
///
/// See docs/SIMULATION_SPEC.md §1–2. The grid is a lattice of junctions joined
/// by straight road cells; the cells between road lines are buildings and are
/// not drivable. Everything here is immutable once built.
///
/// Layout: junction "lines" sit at column/row indices that are multiples of
/// [SimConfig.blockSize]. A cell is a road cell if it lies on any junction
/// line; it is a junction if it lies on both a column line and a row line.
/// With `blockSize == 2` there is exactly one straight road cell between
/// adjacent junctions.
class CityGrid {
  // Positional params so private fields can use initializing formals (Dart
  // forbids underscore-prefixed named parameters). Called once, by the factory.
  CityGrid._(
    this.config,
    this.maxCoord,
    this._roadCells,
    this._junctionByCell,
    this.junctions,
    this._adjacency,
    this.edgeCells,
  );

  factory CityGrid.build(SimConfig config) {
    final n = config.junctionsPerSide;
    final step = config.blockSize;
    final maxCoord = (n - 1) * step;

    bool onColumnLine(int col) => col % step == 0 && col <= maxCoord;
    bool onRowLine(int row) => row % step == 0 && row <= maxCoord;
    bool isRoad(int col, int row) =>
        col >= 0 &&
        row >= 0 &&
        col <= maxCoord &&
        row <= maxCoord &&
        (onColumnLine(col) || onRowLine(row));

    final roadCells = <Cell>{};
    final junctionByCell = <Cell, Junction>{};
    final junctions = <Junction>[];

    // Enumerate cells in row-major order for deterministic id assignment.
    for (var row = 0; row <= maxCoord; row++) {
      for (var col = 0; col <= maxCoord; col++) {
        if (!isRoad(col, row)) continue;
        final cell = Cell(col, row);
        roadCells.add(cell);
        if (onColumnLine(col) && onRowLine(row)) {
          final jc = col ~/ step;
          final jr = row ~/ step;
          final id = jr * n + jc;
          final junction = Junction(id: id, cell: cell);
          junctionByCell[cell] = junction;
          junctions.add(junction);
        }
      }
    }
    junctions.sort((a, b) => a.id.compareTo(b.id));

    // Build adjacency: connect each road cell to in-bounds road neighbours.
    // Neighbour order follows Direction.values for a stable, deterministic graph.
    final adjacency = <Cell, List<Cell>>{};
    for (final cell in roadCells) {
      final neighbours = <Cell>[];
      for (final dir in Direction.values) {
        final next = cell.step(dir);
        if (roadCells.contains(next)) neighbours.add(next);
      }
      adjacency[cell] = neighbours;
    }

    // Perimeter road cells are spawn/exit edges.
    final edgeCells = <Cell>[];
    for (final cell in roadCells) {
      final onEdge =
          cell.col == 0 ||
          cell.row == 0 ||
          cell.col == maxCoord ||
          cell.row == maxCoord;
      if (onEdge) edgeCells.add(cell);
    }
    edgeCells.sort((a, b) {
      final r = a.row.compareTo(b.row);
      return r != 0 ? r : a.col.compareTo(b.col);
    });

    return CityGrid._(
      config,
      maxCoord,
      roadCells,
      junctionByCell,
      junctions,
      adjacency,
      edgeCells,
    );
  }

  final SimConfig config;

  /// Largest valid column/row index. The grid spans `0..maxCoord` on both axes.
  final int maxCoord;

  final Set<Cell> _roadCells;
  final Map<Cell, Junction> _junctionByCell;
  final Map<Cell, List<Cell>> _adjacency;

  /// All junctions, ordered by ascending id.
  final List<Junction> junctions;

  /// Perimeter road cells: the set of legal spawn and exit cells. Sorted
  /// row-major for deterministic random selection.
  final List<Cell> edgeCells;

  bool isRoad(Cell cell) => _roadCells.contains(cell);

  bool isJunction(Cell cell) => _junctionByCell.containsKey(cell);

  Junction? junctionAt(Cell cell) => _junctionByCell[cell];

  Junction junctionById(int id) => junctions[id];

  bool isEdge(Cell cell) => edgeCells.contains(cell);

  /// Drivable neighbours of [cell] in a stable order. Empty if not a road cell.
  List<Cell> neighbours(Cell cell) => _adjacency[cell] ?? const <Cell>[];

  Iterable<Cell> get roadCells => _roadCells;
}
