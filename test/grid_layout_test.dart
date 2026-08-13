import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:traffic_control/game/grid_layout.dart';
import 'package:traffic_control/simulation/cell.dart';

/// The render layer is visual, but the cell↔pixel mapping carries real logic
/// (it decides which junction a tap hits), so it is worth pinning down.
void main() {
  group('GridLayout', () {
    final layout = GridLayout(size: const Size(400, 800), maxCoord: 6);

    test('the centre of a cell maps back to that cell', () {
      for (var col = 0; col <= 6; col++) {
        for (var row = 0; row <= 6; row++) {
          final center = layout.cellCenter(col, row);
          expect(
            layout.cellAt(center),
            Cell(col, row),
            reason: 'round-trip for ($col,$row)',
          );
        }
      }
    });

    test('taps outside the board return null', () {
      expect(layout.cellAt(const Offset(-100, -100)), isNull);
      expect(layout.cellAt(const Offset(10000, 10000)), isNull);
    });

    test('interpolation lands on endpoints at t=0 and t=1', () {
      const a = Cell(1, 0);
      const b = Cell(2, 0);
      expect(layout.lerpCenter(a, b, 0), layout.cellCenter(1, 0));
      expect(layout.lerpCenter(a, b, 1), layout.cellCenter(2, 0));
      // Midpoint sits between the two cell centres.
      final mid = layout.lerpCenter(a, b, 0.5);
      expect(
        mid.dx,
        closeTo(
          (layout.cellCenter(1, 0).dx + layout.cellCenter(2, 0).dx) / 2,
          0.001,
        ),
      );
    });
  });
}
