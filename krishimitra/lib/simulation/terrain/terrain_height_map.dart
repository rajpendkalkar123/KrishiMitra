import 'dart:math' as math;
import 'dart:typed_data';

// ignore_for_file: deprecated_member_use

/// Fractal Brownian Motion terrain seeded by GPS coordinates.
/// Precomputes a 64×64 height grid for O(1) bilinear lookups at runtime.
class TerrainHeightMap {
  final int seed;

  // Grid dimensions & world span
  static const int gridSize = 96; // higher resolution – finer height detail
  static const double worldSpan = 320.0;
  static const double maxHeight = 14.0; // flatter, agricultural-plains scale
  static const double flatBase = 0.3; // near-zero base so crops sit at ground

  late final Float32List _heights;

  TerrainHeightMap({required this.seed}) {
    _heights = Float32List(gridSize * gridSize);
    _precompute();
  }

  void _precompute() {
    for (int z = 0; z < gridSize; z++) {
      for (int x = 0; x < gridSize; x++) {
        final wx = x / gridSize.toDouble() * worldSpan;
        final wz = z / gridSize.toDouble() * worldSpan;
        // 6-octave fBm — divide by worldSpan*0.25 to get ~4 noise cycles
        final h = _fbm(wx / (worldSpan * 0.25), wz / (worldSpan * 0.25));
        _heights[z * gridSize + x] = (h * maxHeight).clamp(0.0, maxHeight);
      }
    }
    // smooth the zero-borders so there are no hard edges
    _smoothBorder();
  }

  void _smoothBorder() {
    const margin = 4;
    for (int z = 0; z < gridSize; z++) {
      for (int x = 0; x < gridSize; x++) {
        final edgeDist = [
          x,
          z,
          gridSize - 1 - x,
          gridSize - 1 - z,
        ].reduce(math.min);
        if (edgeDist < margin) {
          final t = edgeDist / margin;
          _heights[z * gridSize + x] *= t * t;
        }
      }
    }
  }

  /// Bilinear-interpolated height at world (x, z).
  double heightAt(double x, double z) {
    final gx = (x / worldSpan * gridSize).clamp(0.0, gridSize - 1.001);
    final gz = (z / worldSpan * gridSize).clamp(0.0, gridSize - 1.001);
    final xi = gx.floor(), zi = gz.floor();
    final xi1 = math.min(xi + 1, gridSize - 1);
    final zi1 = math.min(zi + 1, gridSize - 1);
    final fx = gx - xi, fz = gz - zi;

    final h00 = _heights[zi * gridSize + xi];
    final h10 = _heights[zi * gridSize + xi1];
    final h01 = _heights[zi1 * gridSize + xi];
    final h11 = _heights[zi1 * gridSize + xi1];

    return flatBase +
        h00 +
        (h10 - h00) * fx +
        (h01 - h00) * fz +
        (h11 - h10 - h01 + h00) * fx * fz;
  }

  /// Height-based terrain color for rendering.
  /// Palette tuned for GPS-seeded agricultural land (typical Indian farmland).
  static int colorForHeight(double h) {
    if (h < 0.8) return 0xFF4a7c59; // low-lying / waterlogged / paddy field
    if (h < 2.2) return 0xFF5a9e3a; // wet paddy / rice cultivation
    if (h < 4.0) return 0xFF72b848; // irrigated flat farmland
    if (h < 6.0) return 0xFF8dc55a; // general cropland / field
    if (h < 8.0) return 0xFF9dc962; // elevated farm / dryland
    if (h < 10.0) return 0xFF7a9c40; // scrubland / seasonal fallow
    if (h < 11.5) return 0xFF8b7355; // rocky hillside / wasteland
    if (h < 13.0) return 0xFF7a6348; // rocky terrain / village paths
    return 0xFF6b5a45; // ridge / high ground
  }

  // ── Surface feature codes (deterministic, seeded) ───────────────────────
  static const int featurePlain = 0;
  static const int featureCropField = 1; // alternating crop-row strip
  static const int featureRoadH = 2; // east-west dirt track
  static const int featureRoadV = 3; // north-south dirt track
  static const int featureVillage = 4; // building cluster zone

  /// Returns the surface-feature code for world position ([wx], [wz]).
  /// Pure O(1) deterministic calculation – no allocation.
  int featureAt(double wx, double wz) {
    // ── Dirt-road grid every ~80 world units, 7-unit wide strips ──────────
    const double roadSpacing = 80.0;
    const double roadHalfW = 3.5;
    final double modX = wx % roadSpacing;
    final double modZ = wz % roadSpacing;
    if (modX >= 0 && modX < roadHalfW * 2) return featureRoadV;
    if (modZ >= 0 && modZ < roadHalfW * 2) return featureRoadH;

    // ── Village cluster: one per 64×64 grid cell when hash ≥ 0.78 ─────────
    final int cellX = (wx / 64.0).floor();
    final int cellZ = (wz / 64.0).floor();
    if (_hash2(cellX, cellZ) > 0.78) {
      final double clX = cellX * 64.0 + 32.0;
      final double clZ = cellZ * 64.0 + 32.0;
      final double dx = wx - clX, dz = wz - clZ;
      if (dx * dx + dz * dz < 20.0 * 20.0) return featureVillage;
    }

    // ── Crop rows: alternating 18-unit wide strips ─────────────────────────
    if (((wx / 18.0).floor() + (wz / 18.0).floor()) % 2 == 0) {
      return featureCropField;
    }

    return featurePlain;
  }

  /// Colours for surface features, indexed by feature code.
  static int colorForFeature(int feature, double h) {
    switch (feature) {
      case featureRoadH:
      case featureRoadV:
        return 0xFFD4B896; // dirt track – warm sandy tan
      case featureVillage:
        return 0xFFB0A090; // village ground – stone/mud
      case featureCropField:
        // alternate light/dark green based on coarse sub-strip group
        return 0xFF72b848; // bright irrigated green
      default:
        return colorForHeight(h);
    }
  }

  /// Second hash for village placement (separate from height hash).
  double _hash2(int cx, int cz) {
    int n = cx * 1619 + cz * 31337 + seed;
    n = ((n << 13) ^ n) & 0x7fffffff;
    n = (n * (n * n * 15731 + 789221) + 1376312589) & 0x7fffffff;
    return n / 2147483648.0;
  }

  /// Seeded hash for individual building placement within a village cell.
  double hashBuilding(int bx, int bz) => _hash2(bx * 7 + seed, bz * 13 + seed);

  // ── Fractal Brownian Motion ─────────────────────────────────────────────
  double _fbm(double x, double y) {
    double val = 0, amp = 0.52, freq = 1.0;
    // 5 octaves: enough detail without high-frequency jaggies on flat plains
    for (int i = 0; i < 5; i++) {
      val += _valueNoise(x * freq, y * freq) * amp;
      amp *= 0.44;
      freq *= 2.05;
    }
    val = val.clamp(0.0, 1.0);
    // Apply bias: squash values toward the lower-mid range to create mostly
    // flat agricultural plains with occasional gentle hills.
    // smoothstep² keeps most terrain in the 0.2–0.55 range.
    final t = val * val * (3 - 2 * val);
    return t * 0.75 + val * 0.25; // blend for subtle ridge detail
  }

  double _valueNoise(double x, double y) {
    final xi = x.floor();
    final yi = y.floor();
    final fx = x - xi;
    final fy = y - yi;
    final ux = fx * fx * (3 - 2 * fx); // smoothstep
    final uy = fy * fy * (3 - 2 * fy);

    final a = _hash(xi, yi);
    final b = _hash(xi + 1, yi);
    final c = _hash(xi, yi + 1);
    final d = _hash(xi + 1, yi + 1);

    return _lerp(_lerp(a, b, ux), _lerp(c, d, ux), uy);
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  /// Deterministic hash in 0..1, influenced by [seed].
  double _hash(int x, int y) {
    int n = x + y * 57 + seed;
    n = ((n << 13) ^ n) & 0x7fffffff;
    n = (n * (n * n * 15731 + 789221) + 1376312589) & 0x7fffffff;
    return n / 2147483648.0;
  }
}
