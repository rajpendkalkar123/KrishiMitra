import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart';
import '../../domain/entities/costmap_3d.dart';

/// 3-D A* path-finder on the [Costmap3D] voxel grid.
class AStar3D {
  /// Returns a list of world-space waypoints from [start] to [goal].
  /// Returns an empty list if no path is found within [maxIterations].
  static List<Vector3> findPath({
    required Costmap3D costmap,
    required Vector3 start,
    required Vector3 goal,
    int maxIterations = 3000,
  }) {
    final s = _toGrid(costmap, start);
    final g = _toGrid(costmap, goal);

    if (_isBlocked(costmap, g.$1, g.$2, g.$3) ||
        _isBlocked(costmap, s.$1, s.$2, s.$3)) {
      return [];
    }

    final open = <_Node>[];
    final closed = <String, bool>{};

    open.add(_Node(s.$1, s.$2, s.$3, g: 0, h: _heuristic(s, g)));

    int iterations = 0;
    while (open.isNotEmpty && iterations < maxIterations) {
      iterations++;
      open.sort((a, b) => a.f.compareTo(b.f));
      final current = open.removeAt(0);

      final key = _key(current.x, current.y, current.z);
      if (closed[key] == true) continue;
      closed[key] = true;

      if (current.x == g.$1 && current.y == g.$2 && current.z == g.$3) {
        return _reconstruct(costmap, current);
      }

      for (final nb in _neighbours(costmap, current, g)) {
        final nk = _key(nb.x, nb.y, nb.z);
        if (closed[nk] == true) continue;
        open.add(nb);
      }
    }
    return []; // no path found
  }

  // ── helpers ────────────────────────────────────────────────────────────

  static (int, int, int) _toGrid(Costmap3D c, Vector3 world) {
    final x = (world.x / c.altitudeStep).round().clamp(0, c.cols - 1);
    final y = (world.z / c.altitudeStep).round().clamp(0, c.rows - 1);
    final z = (world.y / c.altitudeStep).round().clamp(0, c.layers - 1);
    return (x, y, z);
  }

  static Vector3 _toWorld(Costmap3D c, int x, int y, int z) =>
      Vector3(x * c.altitudeStep, z * c.altitudeStep, y * c.altitudeStep);

  static bool _isBlocked(Costmap3D c, int x, int y, int z) =>
      c.getCost(x, y, z) >= 10;

  static String _key(int x, int y, int z) => '$x,$y,$z';

  static double _heuristic((int, int, int) a, (int, int, int) b) {
    final dx = (a.$1 - b.$1).abs().toDouble();
    final dy = (a.$2 - b.$2).abs().toDouble();
    final dz = (a.$3 - b.$3).abs().toDouble();
    return math.sqrt(dx * dx + dy * dy + dz * dz);
  }

  static List<_Node> _neighbours(Costmap3D c, _Node n, (int, int, int) goal) {
    final result = <_Node>[];
    for (int dx = -1; dx <= 1; dx++) {
      for (int dy = -1; dy <= 1; dy++) {
        for (int dz = -1; dz <= 1; dz++) {
          if (dx == 0 && dy == 0 && dz == 0) continue;
          final nx = n.x + dx;
          final ny = n.y + dy;
          final nz = n.z + dz;
          if (nx < 0 || nx >= c.cols) continue;
          if (ny < 0 || ny >= c.rows) continue;
          if (nz < 0 || nz >= c.layers) continue;

          final cost = c.getCost(nx, ny, nz);
          if (cost >= 10) continue;

          // movement cost
          final steps = (dx.abs() + dy.abs() + dz.abs()).toDouble();
          final moveCost =
              (steps > 1 ? math.sqrt(2.0) : 1.0) +
              cost * 0.5 +
              (3 - nz).clamp(0, 3) * 0.1; // prefer higher layers

          result.add(
            _Node(
              nx,
              ny,
              nz,
              g: n.g + moveCost,
              h: _heuristic((nx, ny, nz), goal),
              parent: n,
            ),
          );
        }
      }
    }
    return result;
  }

  static List<Vector3> _reconstruct(Costmap3D c, _Node node) {
    final path = <Vector3>[];
    _Node? cur = node;
    while (cur != null) {
      path.add(_toWorld(c, cur.x, cur.y, cur.z));
      cur = cur.parent;
    }
    return path.reversed.toList();
  }
}

class _Node {
  final int x, y, z;
  final double g, h;
  final _Node? parent;

  _Node(
    this.x,
    this.y,
    this.z, {
    required this.g,
    required this.h,
    this.parent,
  });

  double get f => g + h;
}
