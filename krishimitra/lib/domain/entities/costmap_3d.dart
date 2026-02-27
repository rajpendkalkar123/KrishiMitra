/// 3-D voxel costmap for drone path planning.
/// Axes: x = cols (east), y = rows (south), z = altitude layers.
/// Cost values: 0 = free, 1–9 = caution, ≥10 = blocked.
class Costmap3D {
  final int cols;
  final int rows;
  final int layers;

  /// metres per altitude layer
  final double altitudeStep;

  /// data[z][y][x]
  final List<List<List<int>>> data;

  Costmap3D._({
    required this.cols,
    required this.rows,
    required this.layers,
    required this.data,
    this.altitudeStep = 5.0,
  });

  /// Empty costmap with no obstacles.
  factory Costmap3D.empty() {
    return Costmap3D._(
      cols: 1,
      rows: 1,
      layers: 1,
      data: [
        [
          [0],
        ],
      ],
    );
  }

  int getCost(int x, int y, int z) {
    if (x < 0 || x >= cols || y < 0 || y >= rows || z < 0 || z >= layers) {
      return 10; // out-of-bounds = blocked
    }
    return data[z][y][x];
  }

  void setCost(int x, int y, int z, int cost) {
    if (x >= 0 && x < cols && y >= 0 && y < rows && z >= 0 && z < layers) {
      data[z][y][x] = cost;
    }
  }

  /// Build 3-D costmap from a 2-D ground grid (from inference).
  /// Higher altitude layers progressively clear obstacles.
  factory Costmap3D.fromGround({
    required List<List<int>> ground,
    int layers = 5,
    double altitudeStep = 5.0,
  }) {
    final rows = ground.length;
    final cols = ground.isNotEmpty ? ground[0].length : 0;

    final data = List.generate(layers, (z) {
      return List.generate(rows, (y) {
        return List.generate(cols, (x) {
          final g = ground[y][x];
          if (z == 0) return g; // ground layer
          if (z == 1) return g >= 10 ? 7 : g; // low altitude
          if (z == 2) return g >= 10 ? 3 : 0; // medium
          return 0; // high → clear
        });
      });
    });

    return Costmap3D._(
      cols: cols,
      rows: rows,
      layers: layers,
      data: data,
      altitudeStep: altitudeStep,
    );
  }

  /// Procedural farm costmap for demo / fallback.
  factory Costmap3D.proceduralFarm({
    int cols = 12,
    int rows = 8,
    int layers = 5,
  }) {
    final data = List.generate(layers, (_) {
      return List.generate(rows, (_) => List.filled(cols, 0));
    });

    // boundary walls (all altitudes blocked at z=0)
    for (int x = 0; x < cols; x++) {
      data[0][0][x] = 10;
      data[0][rows - 1][x] = 10;
    }
    for (int y = 0; y < rows; y++) {
      data[0][y][0] = 10;
      data[0][y][cols - 1] = 10;
    }

    // trees at certain (x,y)
    const trees = [(3, 2), (8, 2), (3, 5), (8, 5)];
    for (final t in trees) {
      for (int z = 0; z < 3; z++) {
        data[z][t.$2][t.$1] = 10;
      }
    }

    // crop caution zones
    for (int y = 2; y < 6; y++) {
      for (int x = 4; x < 8; x++) {
        data[0][y][x] = 3; // light caution
      }
    }

    return Costmap3D._(cols: cols, rows: rows, layers: layers, data: data);
  }
}
