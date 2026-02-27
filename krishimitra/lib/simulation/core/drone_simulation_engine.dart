import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vector_math/vector_math_64.dart';
import '../../domain/entities/drone_state.dart';
import '../../domain/entities/costmap_3d.dart';
import '../physics/drone_physics_engine.dart';
import '../navigation/astar_3d.dart';
import '../terrain/terrain_height_map.dart';

enum MissionState { idle, flying, completed }

/// Data for one sector in a multi-sector survey mission.
class SectorMissionData {
  final String name;
  final List<double> boundaryLat;
  final List<double> boundaryLon;
  const SectorMissionData({
    required this.name,
    required this.boundaryLat,
    required this.boundaryLon,
  });
}

/// Internal tracker for sector segment boundaries in the waypoint list.
class _SectorSegment {
  final String name;
  final int wpStart; // inclusive
  final int wpEnd; // exclusive
  const _SectorSegment(this.name, this.wpStart, this.wpEnd);
}

/// Main simulation loop – 60 Hz, mixes physics, A* navigation, GPS terrain.
class DroneSimulationEngine extends ChangeNotifier {
  // ── public state ───────────────────────────────────────────────────────
  DroneState droneState = DroneState.initial();
  List<Vector3> currentPath = [];
  Vector3 goalPosition = Vector3(160, 15, 160);
  late Costmap3D costmap;

  TerrainHeightMap? terrain;
  double? gpsLat, gpsLon;
  bool gpsLoading = false;
  String? gpsError;

  List<Vector3> userWaypoints = [];
  MissionState missionState = MissionState.idle;
  int _wpIndex = 0;

  bool isRunning = false;

  /// Set when a farm survey is active.
  String? activeFarmName;
  int surveyTotalStrips = 0;
  int get surveyStripsDone =>
      missionState == MissionState.completed
          ? surveyTotalStrips
          : _wpIndex.clamp(0, surveyTotalStrips);

  // ── Sector tracking ─────────────────────────────────────────────────
  List<_SectorSegment> _sectorSegments = [];

  // ── Farm / sector boundary polygons in sim-space (for rendering) ────
  /// Farm outline polygon in simulation XZ coordinates.
  List<Vector3> farmBoundaryXZ = [];

  /// Per-sector outline polygons in simulation XZ coordinates.
  /// Each entry is (name, polygon).
  List<(String, List<Vector3>)> sectorBoundariesXZ = [];

  /// Raw farm boundary X/Z arrays for point-in-polygon tests.
  List<double> _farmPolyX = [];
  List<double> _farmPolyZ = [];

  // ── Drone motion trail (ring buffer of recent positions) ────────────
  static const int _trailMax = 120; // ~2 seconds at 60 Hz
  final List<Vector3> positionTrail = [];

  /// Name of the sector currently being surveyed (null if no segments).
  String? get currentSectorName {
    for (final seg in _sectorSegments) {
      if (_wpIndex < seg.wpEnd) return seg.name;
    }
    return _sectorSegments.isNotEmpty ? _sectorSegments.last.name : null;
  }

  /// Total number of sector segments in the mission.
  int get totalSectorCount => _sectorSegments.length;

  /// Number of fully completed sector segments.
  int get completedSectorCount {
    if (missionState == MissionState.completed) return _sectorSegments.length;
    int count = 0;
    for (final seg in _sectorSegments) {
      if (_wpIndex >= seg.wpEnd) count++;
    }
    return count;
  }

  /// Progress within the currently-active sector (0.0 → 1.0).
  double get currentSectorProgress {
    for (final seg in _sectorSegments) {
      if (_wpIndex < seg.wpEnd) {
        final total = seg.wpEnd - seg.wpStart;
        if (total <= 0) return 0;
        return ((_wpIndex - seg.wpStart) / total).clamp(0.0, 1.0);
      }
    }
    return missionState == MissionState.completed ? 1.0 : 0.0;
  }

  // ── control inputs (dual joystick) ────────────────────────────────────
  double _thrustInput = 0.0;
  double _yawInput = 0.0;
  Vector2 _tiltInput = Vector2.zero();

  // ── internals ──────────────────────────────────────────────────────────
  bool _autoNavEnabled = false;
  final DronePhysicsEngine _physics = DronePhysicsEngine();
  Timer? _updateTimer;
  DateTime _lastUpdate = DateTime.now();

  /// True after [seedFromFarm] is called. Prevents [fetchLocation] from
  /// overwriting the farm-derived terrain/position.
  bool _farmSeeded = false;

  static const double worldSize = 320.0;

  DroneSimulationEngine() {
    // Empty costmap – no hardcoded obstacles. Farm boundaries are rendered
    // directly from the mapped polygon data.
    costmap = Costmap3D.empty();
    _startLoop();
    // Do NOT call fetchLocation here. The screen calls it only when the
    // user skips the farm picker (manual GPS mode).
  }

  void _startLoop() {
    const interval = Duration(microseconds: 16667);
    _updateTimer = Timer.periodic(interval, (_) => _tick());
  }

  // ── GPS & Terrain ──────────────────────────────────────────────────────

  Future<void> fetchLocation() async {
    // If a farm has already been seeded, don't overwrite it with device GPS.
    if (_farmSeeded) return;
    gpsLoading = true;
    gpsError = null;
    notifyListeners();
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        throw Exception('Location permission denied forever');
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(const Duration(seconds: 12));

      gpsLat = pos.latitude;
      gpsLon = pos.longitude;
      final seed =
          ((pos.latitude * 1000).truncate() ^ (pos.longitude * 1000).truncate())
              .abs();
      // Only set terrain if no farm has been seeded in the meantime.
      if (!_farmSeeded) {
        terrain = TerrainHeightMap(seed: seed);
      }
      gpsError = null;
    } catch (e) {
      terrain ??= TerrainHeightMap(seed: 42);
      gpsError = e.toString();
    } finally {
      gpsLoading = false;
      notifyListeners();
    }
  }

  // ── Farm-seeded survey ─────────────────────────────────────────────────

  /// Seed the simulation from a real farm boundary.
  ///
  /// [centerLat] / [centerLon] – centroid of the farm; used to build the
  /// GPS-seeded terrain height map.
  ///
  /// [boundaryLat] / [boundaryLon] – parallel lists of the farm polygon
  /// corners in WGS-84 degrees.
  ///
  /// After calling this the engine is ready: terrain is built, automated
  /// coverage waypoints are filled in and the mission is started so the
  /// drone takes off and flies the full lawnmower survey automatically.
  void seedFromFarm({
    required String farmName,
    required double centerLat,
    required double centerLon,
    required List<double> boundaryLat,
    required List<double> boundaryLon,
  }) {
    // Reset first so any previous state is clean.
    reset();
    _farmSeeded = true; // guard against any in-flight fetchLocation

    activeFarmName = farmName;
    gpsLat = centerLat;
    gpsLon = centerLon;
    gpsLoading = false;
    gpsError = null;

    // Build terrain from farm GPS seed.
    final seed =
        ((centerLat * 1000).truncate() ^ (centerLon * 1000).truncate()).abs();
    terrain = TerrainHeightMap(seed: seed);

    // Convert boundary to simulation XZ coordinates.
    // Farm centroid maps to world centre (worldSize/2, worldSize/2).
    // Scale: 1 metre real ≈ 1 simulation unit (world is 320 m wide).
    const metersPerDegLat = 111000.0;
    final metersPerDegLon =
        metersPerDegLat * math.cos(centerLat * math.pi / 180);
    final cx = worldSize / 2;
    final cz = worldSize / 2;

    final simX = <double>[];
    final simZ = <double>[];
    for (int i = 0; i < boundaryLat.length; i++) {
      final dx = (boundaryLon[i] - centerLon) * metersPerDegLon;
      final dz = (boundaryLat[i] - centerLat) * metersPerDegLat;
      simX.add((cx + dx).clamp(10.0, worldSize - 10.0));
      simZ.add((cz + dz).clamp(10.0, worldSize - 10.0));
    }

    // Store boundary for 3D rendering.
    farmBoundaryXZ = _toGroundPoly(simX, simZ);
    sectorBoundariesXZ = [];
    _farmPolyX = List.of(simX);
    _farmPolyZ = List.of(simZ);

    // Build a lawnmower (boustrophedon) path over the farm bounding box.
    userWaypoints = _lawnmowerPath(simX, simZ);
    _sectorSegments = [_SectorSegment(farmName, 0, userWaypoints.length)];
    surveyTotalStrips = userWaypoints.length;

    // Position drone at the start of the survey path so it doesn't have
    // to fly from an arbitrary default position to the farm.
    if (userWaypoints.isNotEmpty) {
      final wp0 = userWaypoints.first;
      final h0 = terrain?.heightAt(wp0.x, wp0.z) ?? 0.0;
      droneState = droneState.copyWith(
        position: Vector3(wp0.x, h0 + 1.0, wp0.z),
        velocity: Vector3.zero(),
        rotation: Vector3.zero(),
        isFlying: false,
      );
    }

    // Auto-start mission.
    _wpIndex = 0;
    _autoNavEnabled = true;
    missionState = MissionState.flying;
    isRunning = true;
    _thrustInput = 0.60;
    notifyListeners();
  }

  // ── Multi-sector survey ──────────────────────────────────────────────

  /// Seed a multi-sector survey mission.
  ///
  /// The drone will fly a lawnmower path over each sector in sequence,
  /// transitioning automatically between sectors without stopping.
  /// All sector coordinates are mapped relative to [centerLat]/[centerLon]
  /// so their spatial relationship is preserved in the simulation.
  void seedMultiSectorSurvey({
    required String farmName,
    required double centerLat,
    required double centerLon,
    required List<SectorMissionData> sectors,
  }) {
    reset();
    _farmSeeded = true;
    activeFarmName = farmName;
    gpsLat = centerLat;
    gpsLon = centerLon;
    gpsLoading = false;
    gpsError = null;

    final seed =
        ((centerLat * 1000).truncate() ^ (centerLon * 1000).truncate()).abs();
    terrain = TerrainHeightMap(seed: seed);

    const metersPerDegLat = 111000.0;
    final metersPerDegLon =
        metersPerDegLat * math.cos(centerLat * math.pi / 180);
    final cx = worldSize / 2;
    final cz = worldSize / 2;

    userWaypoints = [];
    _sectorSegments = [];
    farmBoundaryXZ = [];
    sectorBoundariesXZ = [];
    _farmPolyX = [];
    _farmPolyZ = [];

    for (final sector in sectors) {
      final simX = <double>[];
      final simZ = <double>[];
      for (int i = 0; i < sector.boundaryLat.length; i++) {
        final dx = (sector.boundaryLon[i] - centerLon) * metersPerDegLon;
        final dz = (sector.boundaryLat[i] - centerLat) * metersPerDegLat;
        simX.add((cx + dx).clamp(10.0, worldSize - 10.0));
        simZ.add((cz + dz).clamp(10.0, worldSize - 10.0));
      }

      // Store sector boundary for 3D rendering.
      sectorBoundariesXZ.add((sector.name, _toGroundPoly(simX, simZ)));
      // Accumulate all points for farm-wide polygon.
      _farmPolyX.addAll(simX);
      _farmPolyZ.addAll(simZ);
      farmBoundaryXZ.addAll(_toGroundPoly(simX, simZ));

      final startIdx = userWaypoints.length;
      final sectorWps = _lawnmowerPath(simX, simZ);
      userWaypoints.addAll(sectorWps);
      if (sectorWps.isNotEmpty) {
        _sectorSegments.add(
          _SectorSegment(sector.name, startIdx, userWaypoints.length),
        );
      }
    }

    surveyTotalStrips = userWaypoints.length;

    // Position drone at the start of the first sector's survey path.
    if (userWaypoints.isNotEmpty) {
      final wp0 = userWaypoints.first;
      final h0 = terrain?.heightAt(wp0.x, wp0.z) ?? 0.0;
      droneState = droneState.copyWith(
        position: Vector3(wp0.x, h0 + 1.0, wp0.z),
        velocity: Vector3.zero(),
        rotation: Vector3.zero(),
        isFlying: false,
      );
    }

    _wpIndex = 0;
    _autoNavEnabled = true;
    missionState = MissionState.flying;
    isRunning = true;
    _thrustInput = 0.60;
    notifyListeners();
  }

  /// Convert parallel simX / simZ arrays to a polygon of ground-level
  /// Vector3s (y = terrain height) for boundary rendering.
  List<Vector3> _toGroundPoly(List<double> simX, List<double> simZ) {
    final poly = <Vector3>[];
    for (int i = 0; i < simX.length; i++) {
      final h = terrain?.heightAt(simX[i], simZ[i]) ?? 0.0;
      poly.add(Vector3(simX[i], h, simZ[i]));
    }
    return poly;
  }

  /// Generate a boustrophedon coverage path **clipped to the actual polygon**.
  ///
  /// Each horizontal scan-line at a given Z intersects the polygon edges to
  /// find the valid X spans.  Waypoints are placed only inside the polygon,
  /// so the drone covers the real farm/sector shape — not the bounding box.
  List<Vector3> _lawnmowerPath(List<double> simX, List<double> simZ) {
    if (simX.length < 3) return [];

    final minX = simX.reduce(math.min);
    final maxX = simX.reduce(math.max);
    var minZ = simZ.reduce(math.min);
    var maxZ = simZ.reduce(math.max);

    // Pad very small polygons.
    const minSpan = 20.0;
    if (maxZ - minZ < minSpan) {
      final pad = (minSpan - (maxZ - minZ)) / 2;
      minZ -= pad;
      maxZ += pad;
    }

    const stripSpacing = 12.0; // metres between parallel passes
    const surveyAlt = 15.0; // metres above ground
    const margin = 2.0; // inset from polygon edges

    final n = simX.length;
    final wps = <Vector3>[];
    int strip = 0;
    double z = minZ + margin;

    while (z <= maxZ - margin + 1.0) {
      // Find X intersections of the scan-line at this Z with polygon edges.
      final xHits = <double>[];
      for (int i = 0; i < n; i++) {
        final j = (i + 1) % n;
        final z0 = simZ[i], z1 = simZ[j];
        if ((z0 <= z && z1 > z) || (z1 <= z && z0 > z)) {
          final t = (z - z0) / (z1 - z0);
          xHits.add(simX[i] + t * (simX[j] - simX[i]));
        }
      }
      xHits.sort();

      // Take pairs of intersections as inside-spans.
      for (int p = 0; p + 1 < xHits.length; p += 2) {
        var x0 = (xHits[p] + margin).clamp(8.0, worldSize - 8.0);
        var x1 = (xHits[p + 1] - margin).clamp(8.0, worldSize - 8.0);
        if (x1 - x0 < 3.0) continue; // skip tiny slivers
        final sz = z.clamp(8.0, worldSize - 8.0);
        final h0 = terrain?.heightAt(x0, sz) ?? 0.0;
        final h1 = terrain?.heightAt(x1, sz) ?? 0.0;
        if (strip.isEven) {
          wps.add(Vector3(x0, h0 + surveyAlt, sz));
          wps.add(Vector3(x1, h1 + surveyAlt, sz));
        } else {
          wps.add(Vector3(x1, h1 + surveyAlt, sz));
          wps.add(Vector3(x0, h0 + surveyAlt, sz));
        }
      }

      z += stripSpacing;
      strip++;
    }

    // If polygon is too small or oddly shaped and no waypoints were
    // generated, fall back to a simple bounding-box path.
    if (wps.isEmpty) {
      final cx = (minX + maxX) / 2;
      final cz = (minZ + maxZ) / 2;
      final h = terrain?.heightAt(cx, cz) ?? 0.0;
      wps.add(
        Vector3(
          minX.clamp(8.0, worldSize - 8.0),
          h + surveyAlt,
          minZ.clamp(8.0, worldSize - 8.0),
        ),
      );
      wps.add(
        Vector3(
          maxX.clamp(8.0, worldSize - 8.0),
          h + surveyAlt,
          maxZ.clamp(8.0, worldSize - 8.0),
        ),
      );
    }

    return wps;
  }

  /// Test whether point (px, pz) is inside the polygon defined by
  /// [polyX] / [polyZ] using the ray-casting algorithm.
  static bool _pointInPolygon(
    double px,
    double pz,
    List<double> polyX,
    List<double> polyZ,
  ) {
    bool inside = false;
    final n = polyX.length;
    for (int i = 0, j = n - 1; i < n; j = i++) {
      if (((polyZ[i] > pz) != (polyZ[j] > pz)) &&
          (px <
              (polyX[j] - polyX[i]) * (pz - polyZ[i]) / (polyZ[j] - polyZ[i]) +
                  polyX[i])) {
        inside = !inside;
      }
    }
    return inside;
  }

  /// Check if a world XZ point is inside any farm/sector boundary.
  /// Used by the renderer to suppress procedural buildings inside the farm.
  bool isInsideFarm(double wx, double wz) {
    if (_farmPolyX.length < 3) return false;
    // Check each individual sector polygon first.
    for (final (_, poly) in sectorBoundariesXZ) {
      if (poly.length < 3) continue;
      final px = poly.map((v) => v.x).toList();
      final pz = poly.map((v) => v.z).toList();
      if (_pointInPolygon(wx, wz, px, pz)) return true;
    }
    // Fallback: check the farm polygon itself.
    return _pointInPolygon(wx, wz, _farmPolyX, _farmPolyZ);
  }

  double _terrainH(double x, double z) =>
      terrain?.heightAt(x, z) ??
      (math.sin(x * 0.04) * math.cos(z * 0.04) * 2.5 + 0.5);

  // ── Timer tick ─────────────────────────────────────────────────────────

  void _tick() {
    final now = DateTime.now();
    final dt = (now.difference(_lastUpdate).inMicroseconds / 1e6).clamp(
      0.001,
      0.05,
    );
    _lastUpdate = now;
    if (!isRunning) return;

    final terrainH = _terrainH(droneState.position.x, droneState.position.z);
    if (_autoNavEnabled) _followMission(dt);

    droneState = _physics.update(
      drone: droneState,
      dt: dt,
      thrustInput: _thrustInput,
      tiltInput: _tiltInput,
      yawInput: _yawInput,
      terrainHeight: terrainH,
    );

    // Record position trail for rendering.
    if (droneState.isFlying) {
      positionTrail.add(droneState.position.clone());
      if (positionTrail.length > _trailMax) positionTrail.removeAt(0);
    }

    notifyListeners();
  }

  // ── Path following ─────────────────────────────────────────────────────

  void _followMission(double dt) {
    if (_wpIndex >= userWaypoints.length) {
      _autoNavEnabled = false;
      missionState = MissionState.completed;
      _thrustInput = DronePhysicsEngine.hoverThrust;
      _tiltInput = Vector2.zero();
      _yawInput = 0;
      notifyListeners();
      return;
    }

    final target = userWaypoints[_wpIndex];
    final pos = droneState.position;

    // Horizontal displacement to target.
    final dx = target.x - pos.x;
    final dz = target.z - pos.z;
    final horizDist = math.sqrt(dx * dx + dz * dz);
    final altErr = target.y - pos.y;

    // ── waypoint arrival ───────────────────────────────────────────────
    if (horizDist < 5.0 && altErr.abs() < 5.0) {
      _wpIndex++;
      return;
    }

    // ── altitude control (PD controller) ───────────────────────────────
    final vertVel = droneState.velocity.y;
    _thrustInput = (DronePhysicsEngine.hoverThrust +
            altErr * 0.14 -
            vertVel * 0.10)
        .clamp(0.15, 0.92);

    // ── horizontal navigation ──────────────────────────────────────────
    if (horizDist > 0.5) {
      // Unit horizontal direction.
      final hx = dx / horizDist;
      final hz = dz / horizDist;

      // Approach scaling: ease off near waypoints to prevent overshoot.
      final approachFactor = (horizDist / 15.0).clamp(0.0, 1.0);
      final tiltStrength = 0.20 + 0.60 * approachFactor;

      // ── body-frame tilt decomposition (CORRECTED) ────────────────────
      // Matrix3.setValues() fills column-major, so the physics _thrustDir
      // matrices are transposed relative to the code comments.  The actual
      // small-angle thrust direction is:
      //   thrust.x ≈  roll·cos(yaw) + pitch·sin(yaw)
      //   thrust.z ≈  roll·sin(yaw) − pitch·cos(yaw)
      // Inverting that 2×2 system (det = −1) gives:
      final yaw = droneState.rotation.y;
      final roll = (hx * math.cos(yaw) + hz * math.sin(yaw)) * tiltStrength;
      final pitch = (hx * math.sin(yaw) - hz * math.cos(yaw)) * tiltStrength;

      // Smooth tilt toward target (mild low-pass to avoid jerk).
      const smooth = 0.12;
      _tiltInput = Vector2(
        (_tiltInput.x +
            (roll.clamp(-0.80, 0.80) - _tiltInput.x) * (1 - smooth)),
        (_tiltInput.y +
            (pitch.clamp(-0.80, 0.80) - _tiltInput.y) * (1 - smooth)),
      );

      // ── yaw toward travel direction ──────────────────────────────────
      final targetYaw = math.atan2(hx, hz);
      var yawErr = targetYaw - droneState.rotation.y;
      while (yawErr > math.pi) yawErr -= 2 * math.pi;
      while (yawErr < -math.pi) yawErr += 2 * math.pi;
      _yawInput = (yawErr * 1.5).clamp(-0.8, 0.8);
    } else {
      // Very close horizontally – bleed off tilt and yaw.
      _tiltInput = Vector2(_tiltInput.x * 0.85, _tiltInput.y * 0.85);
      _yawInput *= 0.8;
    }
  }

  // ── Public API ─────────────────────────────────────────────────────────

  /// Left stick: Y = thrust (−down / +up), X = yaw
  void setLeftStick(Vector2 v) {
    if (_autoNavEnabled) return;
    // Screen-space Y: push thumb UP → v.y is negative (screen-down = positive).
    // Negate so climbing maps to positive thrust delta.
    _thrustInput = (DronePhysicsEngine.hoverThrust - v.y * 0.5).clamp(0.0, 1.0);
    _yawInput = v.x.clamp(-1.0, 1.0);
  }

  /// Right stick: Y = pitch/forward, X = roll/strafe
  void setRightStick(Vector2 v) {
    if (_autoNavEnabled) return;
    _tiltInput = Vector2(v.x.clamp(-1, 1), v.y.clamp(-1, 1));
  }

  void takeOff() {
    isRunning = true;
    _thrustInput = 0.58;
    notifyListeners();
  }

  /// Immediately engage altitude hold at the current height.
  void hover() {
    if (_autoNavEnabled) return;
    _thrustInput = DronePhysicsEngine.hoverThrust;
    _tiltInput = Vector2.zero();
    _yawInput = 0;
    notifyListeners();
  }

  /// Nudge altitude up by a fixed step (for button presses).
  void altUp() {
    if (_autoNavEnabled) return;
    _thrustInput = (_thrustInput + 0.08).clamp(0.0, 1.0);
    notifyListeners();
  }

  /// Nudge altitude down by a fixed step (for button presses).
  void altDown() {
    if (_autoNavEnabled) return;
    _thrustInput = (_thrustInput - 0.08).clamp(0.0, 1.0);
    notifyListeners();
  }

  void land() {
    _autoNavEnabled = false;
    _thrustInput = 0.18;
    _tiltInput = Vector2.zero();
    _yawInput = 0;
  }

  void addWaypoint(Vector3 wp) {
    userWaypoints.add(wp);
    notifyListeners();
  }

  void removeLastWaypoint() {
    if (userWaypoints.isNotEmpty) {
      userWaypoints.removeLast();
      notifyListeners();
    }
  }

  void clearWaypoints() {
    userWaypoints.clear();
    notifyListeners();
  }

  void startMission() {
    if (userWaypoints.isEmpty) return;
    surveyTotalStrips = userWaypoints.length;
    _sectorSegments = [];
    _wpIndex = 0;
    _autoNavEnabled = true;
    missionState = MissionState.flying;
    isRunning = true;
    _thrustInput = 0.58;
    notifyListeners();
  }

  void abortMission() {
    _autoNavEnabled = false;
    missionState = MissionState.idle;
    _tiltInput = Vector2.zero();
    _yawInput = 0;
    notifyListeners();
  }

  void setRandomGoal() {
    final rng = math.Random();
    goalPosition = Vector3(
      30 + rng.nextDouble() * (worldSize - 60),
      10 + rng.nextDouble() * 18,
      30 + rng.nextDouble() * (worldSize - 60),
    );
    currentPath = AStar3D.findPath(
      costmap: costmap,
      start: droneState.position,
      goal: goalPosition,
    );
    _autoNavEnabled = true;
    isRunning = true;
    notifyListeners();
  }

  void reset() {
    droneState = DroneState.initial();
    currentPath = [];
    userWaypoints = [];
    missionState = MissionState.idle;
    _wpIndex = 0;
    _autoNavEnabled = false;
    isRunning = false;
    _thrustInput = 0;
    _tiltInput = Vector2.zero();
    _yawInput = 0;
    activeFarmName = null;
    surveyTotalStrips = 0;
    _sectorSegments = [];
    farmBoundaryXZ = [];
    sectorBoundariesXZ = [];
    _farmPolyX = [];
    _farmPolyZ = [];
    positionTrail.clear();
    _farmSeeded = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }
}
