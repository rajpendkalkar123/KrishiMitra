import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import '../../domain/entities/drone_state.dart';
import '../../domain/entities/costmap_3d.dart';
import '../../domain/models/farm_models.dart';
import '../../services/farm_database_service.dart';
import '../../simulation/core/drone_simulation_engine.dart';
import '../../simulation/terrain/terrain_height_map.dart';
import '../widgets/drone_telemetry_panel.dart';
import '../widgets/drone_flight_controls.dart';

// ignore_for_file: deprecated_member_use

enum _Mode { manual, plan, mission }

/// Full-screen aerial survey drone simulation.
/// - Farm-pick mode: choose a saved farm → auto lawnmower survey
/// - GPS-seeded procedural terrain
/// - Tap-to-place waypoints (Plan mode)
/// - Auto-flight along user waypoints (Mission mode)
/// - Dual joystick (Manual mode)
class DroneSimulationScreen extends StatefulWidget {
  /// Optionally pre-select a farm so the survey starts immediately.
  final Farm? initialFarm;
  const DroneSimulationScreen({super.key, this.initialFarm});
  @override
  State<DroneSimulationScreen> createState() => _DroneSimulationScreenState();
}

class _DroneSimulationScreenState extends State<DroneSimulationScreen>
    with TickerProviderStateMixin {
  late final DroneSimulationEngine _engine;
  late final AnimationController _loopCtrl;

  _Mode _mode = _Mode.manual;

  /// True once a farm survey has been loaded (disables manual joystick).
  bool _farmSurveyActive = false;

  /// Toggle between 3-D perspective view and top-down 2-D map.
  bool _is3D = true;

  // orbit camera offsets
  double _camYawOff = 0.0;
  double _camPitchOff = 0.35;
  double _panX0 = 0, _panY0 = 0;

  Size _sceneSize = Size.zero; // set by LayoutBuilder

  static const Color _accent = Color(0xFFa6cf4f);

  @override
  void initState() {
    super.initState();
    _engine = DroneSimulationEngine();
    _engine.addListener(_onUpdate);
    _loopCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showLaunchChooser();
    });
  }

  // ── Launch chooser (Connect vs Simulate) ───────────────────────────────

  Future<void> _showLaunchChooser() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0d1117),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _LaunchChooserSheet(),
    );

    if (!mounted) return;

    if (choice == 'connect') {
      // Show a placeholder connection info dialog.
      await showDialog<void>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF111b2a),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.blueAccent.withOpacity(0.4)),
              ),
              title: const Row(
                children: [
                  Icon(
                    Icons.settings_remote,
                    color: Colors.blueAccent,
                    size: 28,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Connect to Real Drone',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hardware setup required:',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...[
                    '1. Power on your drone and enable its WiFi hotspot.',
                    '2. Connect this device to the drone\'s WiFi network.',
                    '3. The app will communicate via MAVLink on UDP 14550.',
                    '4. Ensure the flight controller supports MAVLink v2.',
                    '',
                    'Note: Full hardware integration is coming in the next update.',
                  ].map(
                    (s) => Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Text(
                        s,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text(
                    'Continue in Simulation',
                    style: TextStyle(color: Color(0xFFa6cf4f)),
                  ),
                ),
              ],
            ),
      );
      if (!mounted) return;
    }

    // Whether 'connect' (fallback to sim) or 'simulate', proceed with farm pick.
    if (widget.initialFarm != null) {
      _startFarmSurvey(_SurveyTarget(farm: widget.initialFarm!));
    } else {
      _showFarmPicker();
    }
  }

  // ── Farm survey helpers ─────────────────────────────────────────────────

  /// Show a bottom sheet listing saved farms; on selection start survey.
  Future<void> _showFarmPicker() async {
    final farms = await FarmDatabaseService.getAllFarms();

    if (!mounted) return;

    if (farms.isEmpty) {
      // No farms saved yet – fall back to GPS manual mode.
      _engine.fetchLocation();
      return;
    }

    final chosen = await showModalBottomSheet<_SurveyTarget>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0d1117),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FarmPickerSheet(farms: farms),
    );

    if (chosen != null && mounted) {
      _startFarmSurvey(chosen);
    } else if (mounted) {
      // User dismissed – use GPS for manual flying.
      _engine.fetchLocation();
    }
  }

  /// Decide survey strategy and seed the engine accordingly.
  void _startFarmSurvey(_SurveyTarget target) {
    final farm = target.farm;

    // ── Case 1: Specific sector selected ───────────────────────────────
    if (target.sector != null) {
      final sector = target.sector!;
      if (sector.boundary.isEmpty) {
        _engine.fetchLocation();
        return;
      }
      double sLat = 0, sLon = 0;
      for (final p in sector.boundary) {
        sLat += p.latitude;
        sLon += p.longitude;
      }
      _engine.seedFromFarm(
        farmName: '${farm.name} › ${sector.name}',
        centerLat: sLat / sector.boundary.length,
        centerLon: sLon / sector.boundary.length,
        boundaryLat: sector.boundary.map((p) => p.latitude).toList(),
        boundaryLon: sector.boundary.map((p) => p.longitude).toList(),
      );
    }
    // ── Case 2: Farm WITH sectors → sequential sector-by-sector survey ──
    else if (farm.sectors.isNotEmpty &&
        farm.sectors.any((s) => s.boundary.isNotEmpty)) {
      // Use farm boundary centroid as reference; fall back to sector points.
      double sLat = 0, sLon = 0;
      int n = 0;
      final refPts =
          farm.boundary.isNotEmpty
              ? farm.boundary
              : farm.sectors
                  .where((s) => s.boundary.isNotEmpty)
                  .expand((s) => s.boundary)
                  .toList();
      for (final p in refPts) {
        sLat += p.latitude;
        sLon += p.longitude;
        n++;
      }
      if (n == 0) {
        _engine.fetchLocation();
        return;
      }
      _engine.seedMultiSectorSurvey(
        farmName: farm.name,
        centerLat: sLat / n,
        centerLon: sLon / n,
        sectors:
            farm.sectors
                .where((s) => s.boundary.isNotEmpty)
                .map(
                  (s) => SectorMissionData(
                    name: s.name,
                    boundaryLat: s.boundary.map((p) => p.latitude).toList(),
                    boundaryLon: s.boundary.map((p) => p.longitude).toList(),
                  ),
                )
                .toList(),
      );
    }
    // ── Case 3: Farm boundary only (no sectors) ──────────────────────
    else {
      if (farm.boundary.isEmpty) {
        _engine.fetchLocation();
        return;
      }
      double sLat = 0, sLon = 0;
      for (final p in farm.boundary) {
        sLat += p.latitude;
        sLon += p.longitude;
      }
      _engine.seedFromFarm(
        farmName: farm.name,
        centerLat: sLat / farm.boundary.length,
        centerLon: sLon / farm.boundary.length,
        boundaryLat: farm.boundary.map((p) => p.latitude).toList(),
        boundaryLon: farm.boundary.map((p) => p.longitude).toList(),
      );
    }

    setState(() {
      _farmSurveyActive = true;
      _mode = _Mode.mission;
    });
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _engine.removeListener(_onUpdate);
    _engine.dispose();
    _loopCtrl.dispose();
    super.dispose();
  }

  // ── tap-to-place waypoint in Plan mode ─────────────────────────────────
  void _onTapPlan(TapUpDetails d) {
    if (_sceneSize == Size.zero) return;
    final terrain = _engine.terrain;
    if (terrain == null) return;

    final wp = _raycastTerrain(d.localPosition, _sceneSize, terrain);
    if (wp != null) {
      _engine.addWaypoint(wp);
    }
  }

  Vector3? _raycastTerrain(Offset tapPos, Size size, TerrainHeightMap terrain) {
    final droneYaw = _engine.droneState.rotation.y + _camYawOff;
    const camDist = 60.0;
    final camH = _engine.droneState.position.y + 20 + _camPitchOff * 30;
    final camX =
        _engine.droneState.position.x -
        math.sin(droneYaw) * camDist * math.cos(_camPitchOff);
    final camZ =
        _engine.droneState.position.z -
        math.cos(droneYaw) * camDist * math.cos(_camPitchOff);
    final camPos = Vector3(camX, camH, camZ);
    final camTarget = _engine.droneState.position + Vector3(0, 2, 0);

    // build camera basis
    final forward = (camTarget - camPos).normalized();
    final right = forward.cross(Vector3(0, 1, 0)).normalized();
    final up = right.cross(forward).normalized();

    final aspect = size.width / size.height;
    final fovY = 0.9;
    final fH = math.tan(fovY / 2);

    // NDC of tap
    final ndcX = (tapPos.dx / size.width * 2 - 1) * fH * aspect;
    final ndcY = -(tapPos.dy / size.height * 2 - 1) * fH;

    final rayDir =
        (forward + right.scaled(ndcX) + up.scaled(ndcY)).normalized();

    // march ray
    var pt = camPos.clone();
    const step = 2.0;
    const maxSteps = 400;
    for (int i = 0; i < maxSteps; i++) {
      pt += rayDir.scaled(step);
      if (pt.x < 0 || pt.x > 320 || pt.z < 0 || pt.z > 320) break;
      final gh = terrain.heightAt(pt.x, pt.z);
      if (pt.y <= gh + 0.3) {
        return Vector3(pt.x, gh + 8.0, pt.z); // 8m above ground
      }
    }
    // fallback: flat ground at y=8 under cursor
    if (rayDir.y.abs() > 0.001) {
      final t = (8.0 - camPos.y) / rayDir.y;
      if (t > 0) {
        final hit = camPos + rayDir.scaled(t);
        if (hit.x >= 0 && hit.x <= 320 && hit.z >= 0 && hit.z <= 320) {
          return hit;
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final loading = _engine.gpsLoading;
    final terrain = _engine.terrain;

    return Scaffold(
      backgroundColor: const Color(0xFF0d1117),
      body: SafeArea(
        child: Stack(
          children: [
            // ── 3-D scene ────────────────────────────────────────────────
            Positioned.fill(
              child: GestureDetector(
                // Camera orbit works in ALL modes; plan mode additionally
                // supports tap-to-place waypoints via onTapUp.
                onPanStart: (d) {
                  _panX0 = d.localPosition.dx;
                  _panY0 = d.localPosition.dy;
                },
                onPanUpdate: (d) {
                  setState(() {
                    _camYawOff += (d.localPosition.dx - _panX0) * 0.008;
                    _camPitchOff -= (d.localPosition.dy - _panY0) * 0.006;
                    _camPitchOff = _camPitchOff.clamp(0.05, 1.1);
                    _panX0 = d.localPosition.dx;
                    _panY0 = d.localPosition.dy;
                  });
                },
                onTapUp: _mode == _Mode.plan ? _onTapPlan : null,
                child: LayoutBuilder(
                  builder: (_, constraints) {
                    final sz = Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    _sceneSize = sz; // cache for tap raycast
                    return AnimatedBuilder(
                      animation: _loopCtrl,
                      builder:
                          (_, __) => CustomPaint(
                            painter: _Scene3DPainter(
                              drone: _engine.droneState,
                              costmap: _engine.costmap,
                              path: _engine.currentPath,
                              goal: _engine.goalPosition,
                              waypoints: _engine.userWaypoints,
                              terrain: terrain,
                              animT: _loopCtrl.value,
                              camYawOff: _camYawOff,
                              camPitchOff: _camPitchOff,
                              mode: _mode,
                              screenSize: sz,
                              is3D: _is3D,
                              farmBoundary: _engine.farmBoundaryXZ,
                              sectorBoundaries: _engine.sectorBoundariesXZ,
                              positionTrail: _engine.positionTrail,
                            ),
                            size: sz,
                          ),
                    );
                  },
                ),
              ),
            ),

            // ── GPS loading overlay ─────────────────────────────────────
            if (loading)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.65),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: _accent),
                      const SizedBox(height: 16),
                      const Text(
                        'Fetching GPS & building terrain...',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      if (_engine.gpsLat != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Lat: ${_engine.gpsLat!.toStringAsFixed(4)}  '
                            'Lon: ${_engine.gpsLon!.toStringAsFixed(4)}',
                            style: const TextStyle(
                              color: _accent,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

            // ── GPS error snackbar-style bar (manual mode only) ─────────
            if (!loading && !_farmSurveyActive && _engine.gpsError != null)
              Positioned(
                top: 80,
                left: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_off,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'GPS unavailable – using simulated terrain',
                          style: TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ),
                      GestureDetector(
                        onTap: _engine.fetchLocation,
                        child: const Text(
                          'RETRY',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── mode hint (plan mode) ───────────────────────────────────
            if (!_farmSurveyActive && _mode == _Mode.plan)
              const Positioned(
                bottom: 215,
                right: 14,
                child: _HintBadge(
                  text: 'Tap=place waypoint  ·  Drag=orbit',
                  icon: Icons.touch_app,
                ),
              )
            else if (!_farmSurveyActive && _mode == _Mode.manual)
              const Positioned(
                bottom: 215,
                right: 14,
                child: _HintBadge(
                  text: 'Drag to orbit camera',
                  icon: Icons.open_with,
                ),
              ),

            // ── Top bar ─────────────────────────────────────────────────
            Positioned(top: 10, left: 10, right: 10, child: _buildTopBar()),

            // ── Mode tab bar (hidden during farm survey) ─────────────────
            if (!_farmSurveyActive)
              Positioned(top: 74, left: 10, right: 10, child: _buildModeTabs()),

            // ── Telemetry panel ─────────────────────────────────────────
            Positioned(
              left: 10,
              top: _farmSurveyActive ? 74 : 122,
              child: DroneTelemetryPanel(state: _engine.droneState),
            ),

            // ── GPS badge ───────────────────────────────────────────────
            if (_engine.gpsLat != null)
              Positioned(
                right: 10,
                top: _farmSurveyActive ? 74 : 122,
                child: _GpsBadge(lat: _engine.gpsLat!, lon: _engine.gpsLon!),
              ),

            // ── Farm survey status panel ─────────────────────────────────
            if (_farmSurveyActive)
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: _FarmSurveyStatus(
                  engine: _engine,
                  onAbort: () {
                    _engine.abortMission();
                    setState(() {
                      _farmSurveyActive = false;
                      _mode = _Mode.manual;
                    });
                  },
                  onChangeFarm: () async {
                    _engine.abortMission();
                    _engine.reset();
                    setState(() {
                      _farmSurveyActive = false;
                      _mode = _Mode.manual;
                    });
                    await _showFarmPicker();
                  },
                ),
              ),

            // ── Flight controls (manual – hidden during farm survey) ──────
            if (!_farmSurveyActive && _mode != _Mode.mission)
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: DroneFlightControls(
                  onLeftStick: _engine.setLeftStick,
                  onRightStick: _engine.setRightStick,
                  onTakeOff: _engine.takeOff,
                  onLand: _engine.land,
                  onHover: _engine.hover,
                  onAltUp: _engine.altUp,
                  onAltDown: _engine.altDown,
                  onClearWaypoints: _engine.clearWaypoints,
                  onStartMission: () {
                    _engine.startMission();
                    setState(() => _mode = _Mode.mission);
                  },
                  onReset: _engine.reset,
                  missionActive: _engine.missionState == MissionState.flying,
                ),
              ),

            // ── Mission status (manual mission mode) ─────────────────────
            if (!_farmSurveyActive && _mode == _Mode.mission)
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: _MissionStatus(
                  engine: _engine,
                  onAbort: () {
                    _engine.abortMission();
                    setState(() => _mode = _Mode.manual);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final bat = _engine.droneState.batteryLevel;
    final batColor =
        bat > 0.3
            ? _accent
            : bat > 0.1
            ? Colors.orange
            : Colors.red;

    final title =
        _farmSurveyActive && _engine.activeFarmName != null
            ? _engine.activeFarmName!
            : 'Drone Survey';
    final subtitle =
        _farmSurveyActive
            ? 'Farm Survey Active'
            : _engine.isRunning
            ? 'Flight Active'
            : 'Ready';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accent.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.flight, color: _accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: _accent.withOpacity(0.8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // Battery
          Container(
            width: 52,
            height: 22,
            decoration: BoxDecoration(
              border: Border.all(color: batColor, width: 2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 2,
                  top: 2,
                  bottom: 2,
                  child: Container(
                    width: (46 * bat).clamp(0.0, 46.0),
                    decoration: BoxDecoration(
                      color: batColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    '${(bat * 100).toInt()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // Quick farm survey button
          Tooltip(
            message: 'Survey a Farm',
            child: GestureDetector(
              onTap: () async {
                final farms = await FarmDatabaseService.getAllFarms();
                if (!mounted) return;
                if (farms.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'No farms saved yet – go to My Farms to add one',
                      ),
                      duration: Duration(seconds: 3),
                    ),
                  );
                  return;
                }
                final chosen = await showModalBottomSheet<_SurveyTarget>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: const Color(0xFF0d1117),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  builder: (_) => _FarmPickerSheet(farms: farms),
                );
                if (chosen != null && mounted) {
                  _startFarmSurvey(chosen);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _accent.withOpacity(0.5)),
                ),
                child: const Icon(Icons.agriculture, color: _accent, size: 18),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTabs() {
    return Row(
      children: [
        _tab(_Mode.manual, Icons.videogame_asset, 'Manual'),
        const SizedBox(width: 6),
        _tab(_Mode.plan, Icons.map, 'Plan Path'),
        const SizedBox(width: 6),
        _tab(_Mode.mission, Icons.rocket_launch, 'Mission'),
        const Spacer(),
        // ── 2D / 3D view toggle ─────────────────────────────────────
        GestureDetector(
          onTap: () => setState(() => _is3D = !_is3D),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _is3D ? _accent.withOpacity(0.18) : Colors.black45,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _is3D ? _accent : Colors.white30,
                width: _is3D ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _is3D ? Icons.view_in_ar : Icons.map_outlined,
                  size: 14,
                  color: _is3D ? _accent : Colors.white54,
                ),
                const SizedBox(width: 4),
                Text(
                  _is3D ? '3D' : '2D',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _is3D ? _accent : Colors.white54,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _tab(_Mode m, IconData icon, String label) {
    final active = _mode == m;
    return GestureDetector(
      onTap: () {
        if (m == _Mode.mission && _engine.userWaypoints.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Add waypoints in Plan mode first'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        setState(() => _mode = m);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? _accent.withOpacity(0.22) : Colors.black45,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? _accent : Colors.white24,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: active ? _accent : Colors.white54),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: active ? _accent : Colors.white54,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small widgets
// ─────────────────────────────────────────────────────────────────────────────
class _HintBadge extends StatelessWidget {
  final String text;
  final IconData icon;
  const _HintBadge({required this.text, required this.icon});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.white12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white38, size: 13),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: Colors.white38, fontSize: 10)),
      ],
    ),
  );
}

class _GpsBadge extends StatelessWidget {
  final double lat, lon;
  const _GpsBadge({required this.lat, required this.lon});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.white12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.gps_fixed, color: Color(0xFFa6cf4f), size: 12),
            const SizedBox(width: 4),
            const Text(
              'GPS',
              style: TextStyle(
                color: Color(0xFFa6cf4f),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Text(
          lat.toStringAsFixed(4),
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
        Text(
          lon.toStringAsFixed(4),
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ],
    ),
  );
}

class _MissionStatus extends StatelessWidget {
  final DroneSimulationEngine engine;
  final VoidCallback onAbort;
  const _MissionStatus({required this.engine, required this.onAbort});
  @override
  Widget build(BuildContext context) {
    final total = engine.userWaypoints.length;
    final done = engine.surveyStripsDone;
    final status =
        engine.missionState == MissionState.completed
            ? '✓ Mission complete!'
            : 'Waypoint $done / $total';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFa6cf4f).withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.rocket_launch, color: Color(0xFFa6cf4f)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  status,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: total == 0 ? 0 : done / total,
                  backgroundColor: Colors.white12,
                  color: const Color(0xFFa6cf4f),
                  minHeight: 5,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.withOpacity(0.75),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: onAbort,
            icon: const Icon(Icons.stop_circle, size: 16),
            label: const Text('Abort', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Farm survey status bar
// ─────────────────────────────────────────────────────────────────────────────
class _FarmSurveyStatus extends StatelessWidget {
  final DroneSimulationEngine engine;
  final VoidCallback onAbort;
  final VoidCallback onChangeFarm;
  const _FarmSurveyStatus({
    required this.engine,
    required this.onAbort,
    required this.onChangeFarm,
  });

  @override
  Widget build(BuildContext context) {
    final completed = engine.missionState == MissionState.completed;
    final totalWps = engine.surveyTotalStrips;
    final doneWps = engine.surveyStripsDone;
    final progress = totalWps == 0 ? 0.0 : (doneWps / totalWps).clamp(0.0, 1.0);
    final nSectors = engine.totalSectorCount;
    final doneSectors = engine.completedSectorCount;
    final sectorName = engine.currentSectorName;

    final String statusLine;
    if (completed) {
      statusLine = '✓ Survey complete – ${engine.activeFarmName ?? 'Farm'}';
    } else if (nSectors > 1 && sectorName != null) {
      statusLine =
          '${engine.activeFarmName ?? 'Farm'} › $sectorName '
          '(${doneSectors + 1}/$nSectors)';
    } else {
      statusLine = 'Surveying ${engine.activeFarmName ?? 'Farm'}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.78),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFa6cf4f).withOpacity(0.45)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.satellite_alt,
                color: Color(0xFFa6cf4f),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusLine,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              // Change farm button
              GestureDetector(
                onTap: onChangeFarm,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Text(
                    'Change',
                    style: TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Abort
              GestureDetector(
                onTap: onAbort,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Abort',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white12,
              color: completed ? Colors.greenAccent : const Color(0xFFa6cf4f),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            completed
                ? 'All ${nSectors > 1 ? '$nSectors sectors' : 'strips'} covered'
                : '${(progress * 100).toInt()}%  •  '
                    'Alt ${engine.droneState.position.y.toStringAsFixed(1)}m  •  '
                    '${engine.droneState.velocity.length.toStringAsFixed(1)} m/s',
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Launch chooser – "Connect to Real Drone" vs "Simulate Drone"
// ─────────────────────────────────────────────────────────────────────────────
class _LaunchChooserSheet extends StatelessWidget {
  const _LaunchChooserSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 22),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.flight, color: Color(0xFFa6cf4f), size: 28),
              SizedBox(width: 10),
              Text(
                'KrishiMitra Drone',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'How would you like to fly?',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 26),
          _LaunchOption(
            icon: Icons.settings_remote,
            title: 'Connect to Real Drone',
            subtitle: 'Fly an actual drone via WiFi / MAVLink',
            color: Colors.blueAccent,
            onTap: () => Navigator.of(context).pop('connect'),
          ),
          const SizedBox(height: 14),
          _LaunchOption(
            icon: Icons.flight_takeoff,
            title: 'Simulate Drone',
            subtitle: 'Test the drone in a virtual 3-D environment',
            color: const Color(0xFFa6cf4f),
            onTap: () => Navigator.of(context).pop('simulate'),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _LaunchOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _LaunchOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.4), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withOpacity(0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios,
              color: color.withOpacity(0.7),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Farm picker bottom sheet
/// Represents either a full-farm survey or a single-sector survey.
class _SurveyTarget {
  final Farm farm;
  final Sector? sector; // null = survey the whole farm
  const _SurveyTarget({required this.farm, this.sector});
}

// ─────────────────────────────────────────────────────────────────────────────
// Farm / Sector picker bottom sheet
// ─────────────────────────────────────────────────────────────────────────────
class _FarmPickerSheet extends StatelessWidget {
  final List<Farm> farms;
  const _FarmPickerSheet({required this.farms});

  Color _healthColor(SectorHealth h) {
    switch (h) {
      case SectorHealth.excellent:
        return Colors.greenAccent;
      case SectorHealth.good:
        return const Color(0xFFa6cf4f);
      case SectorHealth.fair:
        return Colors.yellow;
      case SectorHealth.poor:
        return Colors.orange;
      case SectorHealth.critical:
        return Colors.red;
      case SectorHealth.unknown:
        return Colors.white38;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder:
          (_, controller) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: const [
                    Icon(Icons.agriculture, color: Color(0xFFa6cf4f), size: 22),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Select Farm or Sector to Survey',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Tap “Farm” to scan the full farm, or expand to pick a sector.',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    itemCount: farms.length,
                    itemBuilder: (_, i) {
                      final farm = farms[i];
                      final hasBoundary = farm.boundary.isNotEmpty;
                      final hasSectors = farm.sectors.isNotEmpty;

                      if (!hasSectors) {
                        // Simple tile – no sectors
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFa6cf4f,
                                ).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.grass,
                                color: Color(0xFFa6cf4f),
                                size: 18,
                              ),
                            ),
                            title: Text(
                              farm.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              hasBoundary
                                  ? '${farm.area.toStringAsFixed(1)} ac  •  No sectors'
                                  : 'No boundary saved',
                              style: TextStyle(
                                color:
                                    hasBoundary
                                        ? Colors.white54
                                        : Colors.orange,
                                fontSize: 10,
                              ),
                            ),
                            trailing:
                                hasBoundary
                                    ? _SurveyButton(
                                      label: 'Farm',
                                      onTap:
                                          () => Navigator.of(
                                            context,
                                          ).pop(_SurveyTarget(farm: farm)),
                                    )
                                    : const Icon(
                                      Icons.warning_amber,
                                      color: Colors.orange,
                                      size: 16,
                                    ),
                          ),
                        );
                      }

                      // Farm WITH sectors – expandable
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Theme(
                          data: Theme.of(
                            context,
                          ).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                            childrenPadding: EdgeInsets.zero,
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFa6cf4f,
                                ).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.grass,
                                color: Color(0xFFa6cf4f),
                                size: 18,
                              ),
                            ),
                            title: Text(
                              farm.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              '${farm.sectors.length} sector​(s)  •  '
                              '${farm.area.toStringAsFixed(1)} ac',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 10,
                              ),
                            ),
                            trailing:
                                hasBoundary
                                    ? _SurveyButton(
                                      label: 'Farm',
                                      onTap:
                                          () => Navigator.of(
                                            context,
                                          ).pop(_SurveyTarget(farm: farm)),
                                    )
                                    : null,
                            children:
                                farm.sectors.map((sector) {
                                  final hasSectorBoundary =
                                      sector.boundary.isNotEmpty;
                                  return Container(
                                    margin: const EdgeInsets.fromLTRB(
                                      12,
                                      0,
                                      12,
                                      6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.04),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.white10),
                                    ),
                                    child: ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 2,
                                          ),
                                      dense: true,
                                      leading: Icon(
                                        Icons.crop_square,
                                        color: _healthColor(sector.health),
                                        size: 18,
                                      ),
                                      title: Text(
                                        sector.name,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                      subtitle:
                                          sector.cropType.isNotEmpty
                                              ? Text(
                                                sector.cropType,
                                                style: const TextStyle(
                                                  color: Colors.white38,
                                                  fontSize: 10,
                                                ),
                                              )
                                              : null,
                                      trailing:
                                          hasSectorBoundary
                                              ? _SurveyButton(
                                                label: 'Sector',
                                                onTap:
                                                    () => Navigator.of(
                                                      context,
                                                    ).pop(
                                                      _SurveyTarget(
                                                        farm: farm,
                                                        sector: sector,
                                                      ),
                                                    ),
                                              )
                                              : const Text(
                                                'No boundary',
                                                style: TextStyle(
                                                  color: Colors.orange,
                                                  fontSize: 9,
                                                ),
                                              ),
                                    ),
                                  );
                                }).toList(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: TextButton.icon(
                    onPressed: () => Navigator.of(context).pop(null),
                    icon: const Icon(
                      Icons.videogame_asset,
                      color: Colors.white54,
                      size: 16,
                    ),
                    label: const Text(
                      'Skip – fly manually',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}

/// Small survey-launch chip used inside [_FarmPickerSheet].
class _SurveyButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SurveyButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFa6cf4f).withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFa6cf4f).withOpacity(0.55)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFFa6cf4f),
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Perspective camera
// ─────────────────────────────────────────────────────────────────────────────
class _Camera {
  final Vector3 pos;
  final Vector3 target;
  final double fovY;
  final double aspect;

  late final Matrix4 _view;
  late final Vector3 _fwd, _right, _up;

  _Camera({
    required this.pos,
    required this.target,
    required this.fovY,
    required this.aspect,
  }) {
    _fwd = (target - pos).normalized();
    _right = _fwd.cross(Vector3(0, 1, 0)).normalized();
    _up = _right.cross(_fwd).normalized();
    _view = Matrix4(
      _right.x,
      _up.x,
      -_fwd.x,
      0,
      _right.y,
      _up.y,
      -_fwd.y,
      0,
      _right.z,
      _up.z,
      -_fwd.z,
      0,
      -_right.dot(pos),
      -_up.dot(pos),
      _fwd.dot(pos),
      1,
    );
  }

  Matrix4 get viewMatrix => _view;

  Vector3? project(Vector3 world, Matrix4 view) {
    final v4 = view.transform(Vector4(world.x, world.y, world.z, 1.0));
    if (v4.z >= -0.1) return null;
    final fH = math.tan(fovY / 2);
    return Vector3(v4.x / (-v4.z) / (fH * aspect), -v4.y / (-v4.z) / fH, -v4.z);
  }

  Offset ndcToScreen(Vector3 ndc, Size size) =>
      Offset((ndc.x + 1) / 2 * size.width, (ndc.y + 1) / 2 * size.height);
}

class _Poly {
  final List<Offset> pts;
  final Color fill;
  final Color? stroke;
  final double strokeW;
  final double depth;
  _Poly(this.pts, this.fill, this.depth, {this.stroke, this.strokeW = 0.5});
}

// ─────────────────────────────────────────────────────────────────────────────
// 3-D scene painter
// ─────────────────────────────────────────────────────────────────────────────
class _Scene3DPainter extends CustomPainter {
  final DroneState drone;
  final Costmap3D costmap;
  final List<Vector3> path;
  final Vector3 goal;
  final List<Vector3> waypoints;
  final TerrainHeightMap? terrain;
  final double animT;
  final double camYawOff;
  final double camPitchOff;
  final _Mode mode;
  final Size screenSize;
  final bool is3D;
  final List<Vector3> farmBoundary;
  final List<(String, List<Vector3>)> sectorBoundaries;
  final List<Vector3> positionTrail;

  static const double worldSize = 320.0;
  static const Color accent = Color(0xFFa6cf4f);
  // Daytime sky – bright blue top to warm hazy horizon
  static const Color skyTop = Color(0xFF1565C0);
  static const Color skyBot = Color(0xFF90CAF9);
  static const Color horizonHaze = Color(0xFFB3E5FC);
  // Sun direction (normalized) – high noon, slightly south
  static final Vector3 _sun = Vector3(0.30, 0.95, 0.10).normalized();

  const _Scene3DPainter({
    required this.drone,
    required this.costmap,
    required this.path,
    required this.goal,
    required this.waypoints,
    required this.terrain,
    required this.animT,
    required this.camYawOff,
    required this.camPitchOff,
    required this.mode,
    required this.screenSize,
    required this.is3D,
    required this.farmBoundary,
    required this.sectorBoundaries,
    required this.positionTrail,
  });

  double _th(double x, double z) =>
      terrain?.heightAt(x, z) ??
      (math.sin(x * 0.04) * math.cos(z * 0.04) * 2.5 + 0.5);

  Color _applyLighting(Color base, Vector3 normal) {
    final diffuse = math.max(0.0, normal.dot(_sun));
    final light = 0.35 + diffuse * 0.65;
    return Color.fromARGB(
      base.alpha,
      (base.red * light).round().clamp(0, 255),
      (base.green * light).round().clamp(0, 255),
      (base.blue * light).round().clamp(0, 255),
    );
  }

  Color _fogBlend(Color c, double depth) {
    final t = (depth / 260).clamp(0.0, 1.0);
    // Blend toward the hazy horizon colour for a daytime aerial look
    return Color.lerp(c, horizonHaze, t * 0.55)!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // ── 2-D top-down map mode ─────────────────────────────────────────────
    if (!is3D) {
      _paint2D(canvas, size);
      return;
    }

    // sky – three-stop gradient: deep blue → sky blue → hazy horizon
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.55, 1.0],
          colors: [skyTop, skyBot, horizonHaze],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    final droneYaw = drone.rotation.y + camYawOff;
    const camDist = 60.0;
    final camH = drone.position.y + 20 + camPitchOff * 30;
    final camX =
        drone.position.x - math.sin(droneYaw) * camDist * math.cos(camPitchOff);
    final camZ =
        drone.position.z - math.cos(droneYaw) * camDist * math.cos(camPitchOff);
    final cam = _Camera(
      pos: Vector3(camX, camH, camZ),
      target: drone.position + Vector3(0, 2, 0),
      fovY: 0.9,
      aspect: size.width / size.height,
    );
    final view = cam.viewMatrix;

    final polys = <_Poly>[];
    _buildTerrain(polys, cam, view, size);
    _buildBuildings(polys, cam, view, size);
    _buildRoads(polys, cam, view, size);
    _buildFarmBoundaries(polys, cam, view, size);
    _buildGoalMarker(polys, cam, view, size);
    _buildWaypointPins(polys, cam, view, size);
    _buildDroneShadow(polys, cam, view, size);
    _buildDrone(polys, cam, view, size);

    polys.sort((a, b) => b.depth.compareTo(a.depth));

    for (final p in polys) {
      if (p.pts.length < 3) continue;
      final path2d = Path()..moveTo(p.pts.first.dx, p.pts.first.dy);
      for (final pt in p.pts.skip(1)) path2d.lineTo(pt.dx, pt.dy);
      path2d.close();
      canvas.drawPath(path2d, Paint()..color = p.fill);
      if (p.stroke != null) {
        canvas.drawPath(
          path2d,
          Paint()
            ..color = p.stroke!
            ..style = PaintingStyle.stroke
            ..strokeWidth = p.strokeW,
        );
      }
    }

    _drawPath3D(canvas, cam, view, size);
    _drawTrail3D(canvas, cam, view, size);
    _drawWaypointLines(canvas, cam, view, size);
    _drawRotors(canvas, cam, view, size);
    _drawWaypointLabels(canvas, cam, view, size);

    // Atmospheric haze at horizon – blends to warm horizon color
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          stops: const [0, 0.28],
          colors: [horizonHaze.withOpacity(0.0), horizonHaze.withOpacity(0.35)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
  }

  // ── terrain ─────────────────────────────────────────────────────────────
  void _buildTerrain(List<_Poly> out, _Camera cam, Matrix4 view, Size size) {
    // 30×30 = 900 quads, step 16 → 480-unit coverage centred on drone.
    // Keep well under the original 32×32 at step 20 to avoid GC-pressure crashes.
    const step = 16.0;
    const count = 30;
    const halfSpan = count / 2.0 * step; // 240 units
    const cullDistSq = 290.0 * 290.0; // skip tiles beyond ~290 units from cam

    final cx = drone.position.x;
    final cz = drone.position.z;
    final camX = cam.pos.x;
    final camZ = cam.pos.z;

    // Pre-allocate reusable corners to cut Vector3 allocations
    final c00 = Vector3.zero();
    final c10 = Vector3.zero();
    final c11 = Vector3.zero();
    final c01 = Vector3.zero();

    for (int zi = 0; zi < count; zi++) {
      for (int xi = 0; xi < count; xi++) {
        final wx0 = cx - halfSpan + xi * step;
        final wz0 = cz - halfSpan + zi * step;
        final wx1 = wx0 + step;
        final wz1 = wz0 + step;

        // Fast centre-of-tile distance cull (avoids projecting tiles the
        // camera cannot possibly see, which was the main perf bottleneck).
        final tileCX = wx0 + step * 0.5 - camX;
        final tileCZ = wz0 + step * 0.5 - camZ;
        if (tileCX * tileCX + tileCZ * tileCZ > cullDistSq) continue;

        final h00 = _th(wx0, wz0);
        final h10 = _th(wx1, wz0);
        final h01 = _th(wx0, wz1);
        final h11 = _th(wx1, wz1);

        // Reuse pre-allocated Vector3 objects
        c00.setValues(wx0, h00, wz0);
        c10.setValues(wx1, h10, wz0);
        c11.setValues(wx1, h11, wz1);
        c01.setValues(wx0, h01, wz1);

        final ndc0 = cam.project(c00, view);
        if (ndc0 == null) continue;
        final ndc1 = cam.project(c10, view);
        if (ndc1 == null) continue;
        final ndc2 = cam.project(c11, view);
        if (ndc2 == null) continue;
        final ndc3 = cam.project(c01, view);
        if (ndc3 == null) continue;

        final depth = (ndc0.z + ndc1.z + ndc2.z + ndc3.z) / 4;

        // Face normal for lighting (approximate – no per-frame Vector3 alloc)
        final e1x = c10.x - c00.x;
        final e1y = c10.y - c00.y;
        final e1z = c10.z - c00.z;
        final e2x = c01.x - c00.x;
        final e2y = c01.y - c00.y;
        final e2z = c01.z - c00.z;
        final nx = e1y * e2z - e1z * e2y;
        final ny = e1z * e2x - e1x * e2z;
        final nz = e1x * e2y - e1y * e2x;
        final nLen = math.sqrt(nx * nx + ny * ny + nz * nz);
        final normal =
            nLen > 0
                ? Vector3(nx / nLen, ny / nLen, nz / nLen)
                : Vector3(0, 1, 0);

        final double avgH = (h00 + h10 + h01 + h11) / 4;
        final double tileMidX = wx0 + step * 0.5;
        final double tileMidZ = wz0 + step * 0.5;
        final int feature =
            terrain?.featureAt(tileMidX, tileMidZ) ??
            TerrainHeightMap.featurePlain;
        // Crop rows: alternate brightness between adjacent sub-strips
        int rawArgb;
        if (feature == TerrainHeightMap.featureCropField) {
          final int stripParity =
              ((tileMidX / 9.0).floor() + (tileMidZ / 9.0).floor()) % 2;
          rawArgb = stripParity == 0 ? 0xFF72b848 : 0xFF5a9e3a;
        } else {
          rawArgb = TerrainHeightMap.colorForFeature(feature, avgH);
        }
        final rawC = Color(rawArgb);
        final lit = _applyLighting(rawC, normal);
        final fogged = _fogBlend(lit, depth);

        out.add(
          _Poly(
            [
              cam.ndcToScreen(ndc0, size),
              cam.ndcToScreen(ndc1, size),
              cam.ndcToScreen(ndc2, size),
              cam.ndcToScreen(ndc3, size),
            ],
            fogged,
            depth,
          ),
        );
      }
    }
  }

  // ── village buildings ────────────────────────────────────────────────────
  /// Draws deterministic extruded building boxes at village cluster zones.
  /// Each 64×64 world-unit cell that qualifies gets up to 6 buildings placed
  /// by seeded hash, so the layout is stable across frames.
  void _buildBuildings(List<_Poly> out, _Camera cam, Matrix4 view, Size size) {
    if (terrain == null) return;
    const double camCullSq = 250.0 * 250.0;
    const double cellSize = 64.0;
    // scan a 5×5 cell window around the drone
    final int baseCX = (drone.position.x / cellSize).floor();
    final int baseCZ = (drone.position.z / cellSize).floor();
    for (int dcx = -2; dcx <= 2; dcx++) {
      for (int dcz = -2; dcz <= 2; dcz++) {
        final int cellX = baseCX + dcx;
        final int cellZ = baseCZ + dcz;
        if (cellX < 0 || cellZ < 0) continue;
        final double clX = cellX * cellSize + cellSize / 2;
        final double clZ = cellZ * cellSize + cellSize / 2;
        // cull cells too far from drone
        final double ddx = clX - drone.position.x;
        final double ddz = clZ - drone.position.z;
        if (ddx * ddx + ddz * ddz > camCullSq) continue;
        // check if this cell is a village
        if (terrain!.featureAt(clX, clZ) != TerrainHeightMap.featureVillage) {
          continue;
        }
        // place up to 7 buildings deterministically inside a 20-unit radius
        for (int b = 0; b < 7; b++) {
          final double hb = terrain!.hashBuilding(cellX * 31 + b, cellZ * 17);
          final double hb2 = terrain!.hashBuilding(
            cellX * 13 + b,
            cellZ * 41 + 3,
          );
          final double hb3 = terrain!.hashBuilding(
            cellX * 7 + b,
            cellZ * 29 + 7,
          );
          final double ang = hb * math.pi * 2;
          final double rad = hb2 * 16.0 + 2.0;
          final double bx = clX + math.cos(ang) * rad;
          final double bz = clZ + math.sin(ang) * rad;
          if (bx < 0 || bx > worldSize || bz < 0 || bz > worldSize) continue;
          // Skip buildings that fall inside the mapped farm area.
          if (_isInsideFarmArea(bx, bz)) continue;
          final double gh = _th(bx, bz);
          final double bw = 3.5 + hb3 * 4.0; // 3.5 – 7.5 m wide
          final double bh = 3.0 + hb * 5.0; // 3 – 8 m tall
          final double bd = 3.5 + hb2 * 4.0;
          _box(
            out,
            cam,
            view,
            size,
            Vector3(bx, gh, bz),
            bw,
            bh,
            bd,
            const Color(0xFF9E8C78), // sandstone wall
            const Color(0xFFB5A085), // lighter roof
          );
        }
      }
    }
  }

  // ── road overlays ────────────────────────────────────────────────────────
  /// Draws flat dirt-road quads over road tiles to give a visible road network.
  void _buildRoads(List<_Poly> out, _Camera cam, Matrix4 view, Size size) {
    if (terrain == null) return;
    const double step = 16.0;
    const int count = 30;
    const double halfSpan = count / 2.0 * step;
    const double cullDistSq = 290.0 * 290.0;
    const Color roadCol = Color(0xFFD4B896);
    const Color roadEdge = Color(0xFFC4A87E);

    final double cx = drone.position.x, cz = drone.position.z;
    final double camX = cam.pos.x, camZ = cam.pos.z;

    for (int zi = 0; zi < count; zi++) {
      for (int xi = 0; xi < count; xi++) {
        final double wx0 = cx - halfSpan + xi * step;
        final double wz0 = cz - halfSpan + zi * step;
        final double wx1 = wx0 + step;
        final double wz1 = wz0 + step;
        final double tcx = wx0 + step * 0.5 - camX;
        final double tcz = wz0 + step * 0.5 - camZ;
        if (tcx * tcx + tcz * tcz > cullDistSq) continue;
        final double tileCX = wx0 + step * 0.5;
        final double tileCZ = wz0 + step * 0.5;
        final int feat = terrain!.featureAt(tileCX, tileCZ);
        if (feat != TerrainHeightMap.featureRoadH &&
            feat != TerrainHeightMap.featureRoadV)
          continue;
        // Raise road surface slightly above terrain to avoid Z-fighting
        final double raisedH = _th(tileCX, tileCZ) + 0.12;
        final n0 = cam.project(Vector3(wx0, raisedH, wz0), view);
        if (n0 == null) continue;
        final n1 = cam.project(Vector3(wx1, raisedH, wz0), view);
        if (n1 == null) continue;
        final n2 = cam.project(Vector3(wx1, raisedH, wz1), view);
        if (n2 == null) continue;
        final n3 = cam.project(Vector3(wx0, raisedH, wz1), view);
        if (n3 == null) continue;
        final double depth = (n0.z + n1.z + n2.z + n3.z) / 4 - 0.01;
        out.add(
          _Poly(
            [
              cam.ndcToScreen(n0, size),
              cam.ndcToScreen(n1, size),
              cam.ndcToScreen(n2, size),
              cam.ndcToScreen(n3, size),
            ],
            _fogBlend(roadCol, depth),
            depth,
            stroke: roadEdge,
            strokeW: 0.4,
          ),
        );
      }
    }
  }

  // ── farm / sector boundary rendering ──────────────────────────────────
  /// Draws the actual mapped farm/sector polygons as bright ground-level
  /// outlines with translucent coloured fill so the shape is clearly visible.
  void _buildFarmBoundaries(
    List<_Poly> out,
    _Camera cam,
    Matrix4 view,
    Size size,
  ) {
    // Draw per-sector boundaries with unique colours.
    const sectorColors = [
      Color(0xFF26A69A), // teal
      Color(0xFFEF5350), // red
      Color(0xFF42A5F5), // blue
      Color(0xFFAB47BC), // purple
      Color(0xFFFFCA28), // amber
      Color(0xFF66BB6A), // green
    ];
    for (int si = 0; si < sectorBoundaries.length; si++) {
      final (_, poly) = sectorBoundaries[si];
      if (poly.length < 3) continue;
      final col = sectorColors[si % sectorColors.length];
      _drawBoundaryEdges(out, cam, view, size, poly, col);
      _drawBoundaryGround(out, cam, view, size, poly, col.withOpacity(0.22));
    }

    // Draw farm outline (only if we have a farm-wide boundary and
    // it's separate from sector boundaries).
    if (farmBoundary.isNotEmpty &&
        sectorBoundaries.isEmpty &&
        farmBoundary.length >= 3) {
      const farmCol = Color(0xFFFFD600);
      _drawBoundaryEdges(out, cam, view, size, farmBoundary, farmCol);
      _drawBoundaryGround(
        out,
        cam,
        view,
        size,
        farmBoundary,
        farmCol.withOpacity(0.18),
      );
    }
  }

  /// Draws thick 3D edge strips along the polygon boundary on the ground.
  /// Each edge is a flat quad strip 2m wide at terrain height, giving a
  /// bright painted-line effect that follows the actual farm shape.
  void _drawBoundaryEdges(
    List<_Poly> out,
    _Camera cam,
    Matrix4 view,
    Size size,
    List<Vector3> poly,
    Color col,
  ) {
    const edgeW = 2.0; // half-width of the ground stripe
    const liftY = 0.20; // raise slightly above terrain to avoid z-fight

    for (int i = 0; i < poly.length; i++) {
      final p0 = poly[i];
      final p1 = poly[(i + 1) % poly.length];

      // Direction along the edge (in XZ plane).
      final dx = p1.x - p0.x;
      final dz = p1.z - p0.z;
      final len = math.sqrt(dx * dx + dz * dz);
      if (len < 0.1) continue;
      // Perpendicular (right-hand normal in XZ).
      final nx = -dz / len * edgeW;
      final nz = dx / len * edgeW;

      final h0 = _th(p0.x, p0.z) + liftY;
      final h1 = _th(p1.x, p1.z) + liftY;

      final corners = [
        Vector3(p0.x - nx, h0, p0.z - nz),
        Vector3(p0.x + nx, h0, p0.z + nz),
        Vector3(p1.x + nx, h1, p1.z + nz),
        Vector3(p1.x - nx, h1, p1.z - nz),
      ];

      final pts = <Offset>[];
      double depth = 0;
      bool ok = true;
      for (final c in corners) {
        final ndc = cam.project(c, view);
        if (ndc == null) {
          ok = false;
          break;
        }
        pts.add(cam.ndcToScreen(ndc, size));
        depth += ndc.z;
      }
      if (ok && pts.length == 4) {
        out.add(
          _Poly(
            pts,
            col.withOpacity(0.85),
            depth / 4 - 0.003,
            stroke: col,
            strokeW: 1.5,
          ),
        );
      }

      // Corner marker (small bright dot box) at each vertex.
      if (i == 0 || i == poly.length - 1) continue; // first/last handled
    }

    // Corner dots at each vertex.
    for (final p in poly) {
      final h = _th(p.x, p.z) + liftY;
      _box(out, cam, view, size, Vector3(p.x, h, p.z), 1.8, 0.5, 1.8, col, col);
    }
  }

  /// Draws a translucent ground fill for a boundary polygon.
  void _drawBoundaryGround(
    List<_Poly> out,
    _Camera cam,
    Matrix4 view,
    Size size,
    List<Vector3> poly,
    Color fillCol,
  ) {
    if (poly.length < 3) return;
    // Fan triangulation from first vertex.
    for (int i = 1; i < poly.length - 1; i++) {
      final tri = [poly[0], poly[i], poly[i + 1]];
      final pts = <Offset>[];
      double depth = 0;
      bool ok = true;
      for (final v in tri) {
        final raised = Vector3(v.x, v.y + 0.15, v.z);
        final ndc = cam.project(raised, view);
        if (ndc == null) {
          ok = false;
          break;
        }
        pts.add(cam.ndcToScreen(ndc, size));
        depth += ndc.z;
      }
      if (ok && pts.length == 3) {
        out.add(_Poly(pts, fillCol, depth / 3 - 0.005));
      }
    }
  }

  /// Point-in-polygon test (XZ plane) for suppressing buildings inside farm.
  bool _isInsidePoly(double px, double pz, List<Vector3> poly) {
    bool inside = false;
    final n = poly.length;
    for (int i = 0, j = n - 1; i < n; j = i++) {
      final zi = poly[i].z, zj = poly[j].z;
      final xi = poly[i].x, xj = poly[j].x;
      if (((zi > pz) != (zj > pz)) &&
          (px < (xj - xi) * (pz - zi) / (zj - zi) + xi)) {
        inside = !inside;
      }
    }
    return inside;
  }

  /// Check if world point is inside any rendered farm/sector polygon.
  bool _isInsideFarmArea(double wx, double wz) {
    for (final (_, poly) in sectorBoundaries) {
      if (poly.length >= 3 && _isInsidePoly(wx, wz, poly)) return true;
    }
    if (farmBoundary.length >= 3 && _isInsidePoly(wx, wz, farmBoundary)) {
      return true;
    }
    return false;
  }

  // ── drone shadow ─────────────────────────────────────────────────────────
  /// Projects a dark ellipse directly below the drone on the terrain to
  /// convey altitude and motion.
  void _buildDroneShadow(
    List<_Poly> out,
    _Camera cam,
    Matrix4 view,
    Size size,
  ) {
    final pos = drone.position;
    final groundH = _th(pos.x, pos.z);
    final altitude = (pos.y - groundH).clamp(0.0, 60.0);
    // Shadow size grows and fades with altitude.
    final r = 4.0 + altitude * 0.15;
    final alpha = (0.40 - altitude * 0.005).clamp(0.08, 0.40);
    const segs = 12;
    final pts = <Offset>[];
    double depth = 0;
    bool ok = true;
    for (int i = 0; i < segs; i++) {
      final a = i / segs * 2 * math.pi;
      final ndc = cam.project(
        Vector3(
          pos.x + math.cos(a) * r,
          groundH + 0.10,
          pos.z + math.sin(a) * r * 0.7,
        ),
        view,
      );
      if (ndc == null) {
        ok = false;
        break;
      }
      pts.add(cam.ndcToScreen(ndc, size));
      depth += ndc.z;
    }
    if (ok && pts.length == segs) {
      out.add(
        _Poly(
          pts,
          Colors.black.withOpacity(alpha),
          depth / segs - 0.002, // just above terrain
        ),
      );
    }
  }

  void _box(
    List<_Poly> out,
    _Camera cam,
    Matrix4 view,
    Size size,
    Vector3 c,
    double w,
    double h,
    double d,
    Color side,
    Color top,
  ) {
    final hw = w / 2, hd = d / 2;
    final by = c.y, ty = c.y + h, cx = c.x, cz = c.z;
    final faces = [
      (
        [
          Vector3(cx - hw, ty, cz - hd),
          Vector3(cx + hw, ty, cz - hd),
          Vector3(cx + hw, ty, cz + hd),
          Vector3(cx - hw, ty, cz + hd),
        ],
        top,
        Vector3(0, 1, 0),
      ),
      (
        [
          Vector3(cx - hw, by, cz - hd),
          Vector3(cx + hw, by, cz - hd),
          Vector3(cx + hw, ty, cz - hd),
          Vector3(cx - hw, ty, cz - hd),
        ],
        side,
        Vector3(0, 0, -1),
      ),
      (
        [
          Vector3(cx - hw, by, cz + hd),
          Vector3(cx + hw, by, cz + hd),
          Vector3(cx + hw, ty, cz + hd),
          Vector3(cx - hw, ty, cz + hd),
        ],
        side,
        Vector3(0, 0, 1),
      ),
      (
        [
          Vector3(cx - hw, by, cz - hd),
          Vector3(cx - hw, by, cz + hd),
          Vector3(cx - hw, ty, cz + hd),
          Vector3(cx - hw, ty, cz - hd),
        ],
        side,
        Vector3(-1, 0, 0),
      ),
      (
        [
          Vector3(cx + hw, by, cz - hd),
          Vector3(cx + hw, by, cz + hd),
          Vector3(cx + hw, ty, cz + hd),
          Vector3(cx + hw, ty, cz - hd),
        ],
        side,
        Vector3(1, 0, 0),
      ),
    ];
    for (final entry in faces) {
      final corners = entry.$1;
      final col = _applyLighting(entry.$2, entry.$3);
      final pts = <Offset>[];
      double depth = 0;
      bool ok = true;
      for (final cc in corners) {
        final ndc = cam.project(cc, view);
        if (ndc == null) {
          ok = false;
          break;
        }
        pts.add(cam.ndcToScreen(ndc, size));
        depth += ndc.z;
      }
      if (ok && pts.length >= 3)
        out.add(
          _Poly(
            pts,
            col,
            depth / corners.length,
            stroke: Colors.black38,
            strokeW: 0.5,
          ),
        );
    }
  }

  // ── goal ring ─────────────────────────────────────────────────────────────
  void _buildGoalMarker(List<_Poly> out, _Camera cam, Matrix4 view, Size size) {
    const r = 6.0;
    const segs = 16;
    final gy = _th(goal.x, goal.z) + 0.3;
    final pulse = 1.0 + 0.3 * math.sin(animT * 2 * math.pi);
    final pts = <Offset>[];
    double depth = 0;
    bool ok = true;
    for (int i = 0; i < segs; i++) {
      final a = i / segs * 2 * math.pi;
      final ndc = cam.project(
        Vector3(
          goal.x + math.cos(a) * r * pulse,
          gy,
          goal.z + math.sin(a) * r * pulse,
        ),
        view,
      );
      if (ndc == null) {
        ok = false;
        break;
      }
      pts.add(cam.ndcToScreen(ndc, size));
      depth += ndc.z;
    }
    if (ok && pts.length == segs)
      out.add(
        _Poly(
          pts,
          Colors.redAccent.withOpacity(0.55),
          depth / segs,
          stroke: Colors.red,
          strokeW: 1.5,
        ),
      );
  }

  // ── waypoint pins (small cylinders) ─────────────────────────────────────
  void _buildWaypointPins(
    List<_Poly> out,
    _Camera cam,
    Matrix4 view,
    Size size,
  ) {
    for (int i = 0; i < waypoints.length; i++) {
      final wp = waypoints[i];
      final base = _th(wp.x, wp.z);
      // vertical pole
      final segs = 8;
      const r = 2.0;
      for (int s = 0; s < segs; s++) {
        final a0 = s / segs * 2 * math.pi;
        final a1 = (s + 1) / segs * 2 * math.pi;
        final corners = [
          Vector3(wp.x + math.cos(a0) * r, base, wp.z + math.sin(a0) * r),
          Vector3(wp.x + math.cos(a1) * r, base, wp.z + math.sin(a1) * r),
          Vector3(wp.x + math.cos(a1) * r, wp.y, wp.z + math.sin(a1) * r),
          Vector3(wp.x + math.cos(a0) * r, wp.y, wp.z + math.sin(a0) * r),
        ];
        final pts = <Offset>[];
        double depth = 0;
        bool ok = true;
        for (final cc in corners) {
          final ndc = cam.project(cc, view);
          if (ndc == null) {
            ok = false;
            break;
          }
          pts.add(cam.ndcToScreen(ndc, size));
          depth += ndc.z;
        }
        if (ok && pts.length == 4) {
          final col =
              Color.lerp(
                Colors.orange,
                Colors.red,
                i / math.max(1, waypoints.length - 1),
              )!;
          out.add(_Poly(pts, col.withOpacity(0.85), depth / 4));
        }
      }
    }
  }

  // ── drone ─────────────────────────────────────────────────────────────────
  void _buildDrone(List<_Poly> out, _Camera cam, Matrix4 view, Size size) {
    final pos = drone.position;
    final yaw = drone.rotation.y;
    final pitch = drone.rotation.x;
    final roll = drone.rotation.z;

    // Forward direction in world space (nose).
    final fwd = Vector3(math.sin(yaw), 0, math.cos(yaw));
    // Right direction.
    final right = Vector3(math.cos(yaw), 0, -math.sin(yaw));

    // Compute a "tilted centre" offset: shift body slightly in the
    // tilt direction so the viewer can SEE the drone leaning.
    final tiltOff = Vector3(
      right.x * roll * 2.0 + fwd.x * pitch * 2.0,
      -(roll.abs() + pitch.abs()) * 1.2, // lower when tilted
      right.z * roll * 2.0 + fwd.z * pitch * 2.0,
    );

    final bodyPos = pos + tiltOff;

    // Speed-based colour: idle=orange, fast=deep red.
    final speed = drone.velocity.length;
    final speedT = (speed / 9.0).clamp(0.0, 1.0);
    final bodyCol =
        Color.lerp(
          const Color(0xFFFF7043), // idle orange
          const Color(0xFFC62828), // fast red
          speedT,
        )!;
    final bodyTop =
        Color.lerp(
          const Color(0xFFFFAB91), // idle light orange
          const Color(0xFFEF5350), // fast red
          speedT,
        )!;

    // ── Main body ────────────────────────────────────────────────────────
    _box(
      out,
      cam,
      view,
      size,
      bodyPos - Vector3(0, 2.0, 0),
      7.0,
      3.0,
      7.0,
      bodyCol,
      bodyTop,
    );

    // ── Forward marker (red nose) ────────────────────────────────────────
    // A small red box protruding forward from the body so heading is clear.
    final nosePos = bodyPos + fwd * 4.5;
    _box(
      out,
      cam,
      view,
      size,
      nosePos - Vector3(0, 1.5, 0),
      2.0,
      2.0,
      2.0,
      const Color(0xFFD32F2F), // red
      const Color(0xFFFF5252), // bright red top
    );

    // ── Tail marker (blue) ───────────────────────────────────────────────
    final tailPos = bodyPos - fwd * 4.5;
    _box(
      out,
      cam,
      view,
      size,
      tailPos - Vector3(0, 1.5, 0),
      2.0,
      1.5,
      2.0,
      const Color(0xFF1565C0), // blue
      const Color(0xFF42A5F5), // light blue top
    );

    // ── Arms: bright yellow with tilt-awareness ────────────────────────────
    const armAngles = [
      -math.pi / 4,
      math.pi / 4,
      3 * math.pi / 4,
      -3 * math.pi / 4,
    ];

    // Arm tip heights vary with tilt to show the drone leaning.
    for (int ai = 0; ai < armAngles.length; ai++) {
      final ang = armAngles[ai];
      const len = 10.0;
      final tx = bodyPos.x + math.cos(yaw + ang) * len;
      final tz = bodyPos.z + math.sin(yaw + ang) * len;
      // Arm tips tilt based on pitch & roll.
      final tipDx = math.cos(yaw + ang);
      final tipDz = math.sin(yaw + ang);
      final tipTilt =
          (tipDx * right.x + tipDz * right.z) * roll * 3.0 +
          (tipDx * fwd.x + tipDz * fwd.z) * pitch * 3.0;
      final tipY = bodyPos.y + tipTilt;

      final tip = Vector3(tx, tipY, tz);
      final perp = Vector3(
        math.cos(yaw + ang + math.pi / 2) * 1.2,
        0,
        math.sin(yaw + ang + math.pi / 2) * 1.2,
      );
      final corners = [
        bodyPos + perp - Vector3(0, 0.7, 0),
        bodyPos - perp - Vector3(0, 0.7, 0),
        tip - perp - Vector3(0, 0.7, 0),
        tip + perp - Vector3(0, 0.7, 0),
      ];
      final pts = <Offset>[];
      double depth = 0;
      bool ok = true;
      for (final cc in corners) {
        final ndc = cam.project(cc, view);
        if (ndc == null) {
          ok = false;
          break;
        }
        pts.add(cam.ndcToScreen(ndc, size));
        depth += ndc.z;
      }
      if (ok && pts.length == 4) {
        // Front arms slightly different colour than rear.
        final isRear = (ai >= 2);
        out.add(
          _Poly(
            pts,
            isRear ? const Color(0xFFE0E0E0) : const Color(0xFFFFD600),
            depth / 4,
            stroke: const Color(0xFFE65100),
            strokeW: 0.8,
          ),
        );
      }
    }
  }

  // ── A* path line ──────────────────────────────────────────────────────────
  void _drawPath3D(Canvas canvas, _Camera cam, Matrix4 view, Size size) {
    if (path.length < 2) return;
    final paint =
        Paint()
          ..color = accent.withOpacity(0.85)
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke;
    Offset? prev;
    for (final wp in path) {
      final ndc = cam.project(wp + Vector3(0, 0.5, 0), view);
      if (ndc == null) {
        prev = null;
        continue;
      }
      final scr = cam.ndcToScreen(ndc, size);
      if (prev != null) canvas.drawLine(prev, scr, paint);
      prev = scr;
    }
  }

  // ── drone motion trail ──────────────────────────────────────────────────
  /// Draws a fading colour trail behind the drone so the user can see
  /// the flight path and easily distinguish motion direction.
  void _drawTrail3D(Canvas canvas, _Camera cam, Matrix4 view, Size size) {
    if (positionTrail.length < 2) return;
    Offset? prev;
    for (int i = 0; i < positionTrail.length; i++) {
      final t = i / positionTrail.length; // 0 → 1 (old → new)
      final ndc = cam.project(positionTrail[i], view);
      if (ndc == null) {
        prev = null;
        continue;
      }
      final scr = cam.ndcToScreen(ndc, size);
      if (prev != null) {
        // Fade from faint cyan to bright cyan, getting thicker near head.
        final paint =
            Paint()
              ..color =
                  Color.lerp(
                    const Color(0xFF00BCD4).withOpacity(0.05),
                    const Color(0xFF00E5FF).withOpacity(0.85),
                    t,
                  )!
              ..strokeWidth = 1.0 + t * 2.5
              ..style = PaintingStyle.stroke
              ..strokeCap = StrokeCap.round;
        canvas.drawLine(prev, scr, paint);
      }
      prev = scr;
    }
  }

  // ── user waypoint connection lines ────────────────────────────────────────
  void _drawWaypointLines(Canvas canvas, _Camera cam, Matrix4 view, Size size) {
    if (waypoints.length < 2) return;
    final paint =
        Paint()
          ..color = Colors.orange.withOpacity(0.7)
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke;
    Offset? prev;
    // start from drone
    final dn = cam.project(drone.position, view);
    if (dn != null) prev = cam.ndcToScreen(dn, size);
    for (final wp in waypoints) {
      final ndc = cam.project(wp, view);
      if (ndc == null) {
        prev = null;
        continue;
      }
      final scr = cam.ndcToScreen(ndc, size);
      if (prev != null) canvas.drawLine(prev, scr, paint);
      prev = scr;
    }
  }

  // ── waypoint number labels ────────────────────────────────────────────────
  void _drawWaypointLabels(
    Canvas canvas,
    _Camera cam,
    Matrix4 view,
    Size size,
  ) {
    for (int i = 0; i < waypoints.length; i++) {
      final ndc = cam.project(waypoints[i] + Vector3(0, 3, 0), view);
      if (ndc == null) continue;
      final scr = cam.ndcToScreen(ndc, size);
      final tp = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black, blurRadius: 4)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.drawCircle(
        scr,
        10,
        Paint()..color = Colors.orange.withOpacity(0.8),
      );
      tp.paint(canvas, scr.translate(-tp.width / 2, -tp.height / 2));
    }
  }

  // ── animated rotor discs ──────────────────────────────────────────────────
  void _drawRotors(Canvas canvas, _Camera cam, Matrix4 view, Size size) {
    final pos = drone.position;
    final yaw = drone.rotation.y;
    final pitch = drone.rotation.x;
    final roll = drone.rotation.z;
    final fwd = Vector3(math.sin(yaw), 0, math.cos(yaw));
    final right = Vector3(math.cos(yaw), 0, -math.sin(yaw));

    const armAngles = [
      -math.pi / 4,
      math.pi / 4,
      3 * math.pi / 4,
      -3 * math.pi / 4,
    ];
    const segs = 28;
    const rotorR = 5.8;
    const armLen = 10.0;

    // Speed-based spin: faster spin when the drone is moving fast.
    final speed = drone.velocity.length;
    final spinRate = 4.0 + (speed / 9.0).clamp(0.0, 1.0) * 12.0; // 4..16
    final spin = animT * spinRate * math.pi;

    // Rotor disc opacity increases with speed.
    final discAlpha = 0.08 + (speed / 9.0).clamp(0.0, 1.0) * 0.15;
    // Ring colour shifts: green on idle, cyan on fast.
    final ringCol =
        Color.lerp(
          const Color(0xFF76FF03),
          const Color(0xFF00E5FF),
          (speed / 9.0).clamp(0.0, 1.0),
        )!;

    for (final ang in armAngles) {
      // Arm tip matches tilt from _buildDrone.
      final tipDx = math.cos(yaw + ang);
      final tipDz = math.sin(yaw + ang);
      final tipTilt =
          (tipDx * right.x + tipDz * right.z) * roll * 3.0 +
          (tipDx * fwd.x + tipDz * fwd.z) * pitch * 3.0;
      final cx = pos.x + tipDx * armLen;
      final cz = pos.z + tipDz * armLen;
      final cy = pos.y + tipTilt;

      final rPath = Path();
      bool first = true, skip = false;
      for (int s = 0; s <= segs; s++) {
        final a = s / segs * 2 * math.pi + spin;
        final ndc = cam.project(
          Vector3(
            cx + math.cos(a) * rotorR,
            cy + 0.3,
            cz + math.sin(a) * rotorR * 0.35,
          ),
          view,
        );
        if (ndc == null) {
          skip = true;
          break;
        }
        final scr = cam.ndcToScreen(ndc, size);
        if (first) {
          rPath.moveTo(scr.dx, scr.dy);
          first = false;
        } else {
          rPath.lineTo(scr.dx, scr.dy);
        }
      }
      if (skip) continue;
      rPath.close();
      // Rotor disc with speed-reactive colour.
      canvas.drawPath(
        rPath,
        Paint()..color = Colors.white.withOpacity(discAlpha),
      );
      canvas.drawPath(
        rPath,
        Paint()
          ..color = ringCol.withOpacity(0.90)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  // ── Top-down 2-D map painter ───────────────────────────────────────────
  void _paint2D(Canvas canvas, Size size) {
    // Show ~200 world-units across the smaller screen dimension.
    final double zoom = math.min(size.width, size.height) / 200.0;
    // Centre view on drone, with camera yaw pan as optional X offset.
    final double originX = size.width / 2 - drone.position.x * zoom;
    final double originZ = size.height / 2 - drone.position.z * zoom;

    // ── background ──────────────────────────────────────────────────────
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0a1f0a),
    );

    // ── terrain tiles ─────────────────────────────────────────────────────
    if (terrain != null) {
      const double tStep = 8.0;
      // Only draw tiles that can be visible
      final int x0 = (drone.position.x - 120.0).clamp(0, 320).round();
      final int x1 = (drone.position.x + 120.0).clamp(0, 320).round();
      final int z0 = (drone.position.z - 120.0).clamp(0, 320).round();
      final int z1 = (drone.position.z + 120.0).clamp(0, 320).round();
      final tileSz = tStep * zoom + 0.8;
      for (double wz = z0.toDouble(); wz < z1; wz += tStep) {
        for (double wx = x0.toDouble(); wx < x1; wx += tStep) {
          final double mx = wx + tStep / 2, mz = wz + tStep / 2;
          final int feat = terrain!.featureAt(mx, mz);
          final double avgH = terrain!.heightAt(mx, mz);
          int rawArgb;
          if (feat == TerrainHeightMap.featureCropField) {
            final int p = ((mx / 9.0).floor() + (mz / 9.0).floor()) % 2;
            rawArgb = p == 0 ? 0xFF72b848 : 0xFF5a9e3a;
          } else {
            rawArgb = TerrainHeightMap.colorForFeature(feat, avgH);
          }
          canvas.drawRect(
            Rect.fromLTWH(
              wx * zoom + originX,
              wz * zoom + originZ,
              tileSz,
              tileSz,
            ),
            Paint()..color = Color(rawArgb),
          );
        }
      }
    } else {
      // No terrain yet – simple grid
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = const Color(0xFF1a2e1a),
      );
    }

    // ── farm / sector boundary outlines (2D) ────────────────────────────
    const sectorColors2D = [
      Color(0xFF26A69A),
      Color(0xFFEF5350),
      Color(0xFF42A5F5),
      Color(0xFFAB47BC),
      Color(0xFFFFCA28),
      Color(0xFF66BB6A),
    ];
    void _drawPoly2D(List<Vector3> poly, Color col, {double w = 2.0}) {
      if (poly.length < 3) return;
      final p = Path();
      p.moveTo(poly.first.x * zoom + originX, poly.first.z * zoom + originZ);
      for (final v in poly.skip(1)) {
        p.lineTo(v.x * zoom + originX, v.z * zoom + originZ);
      }
      p.close();
      // Filled tint.
      canvas.drawPath(p, Paint()..color = col.withOpacity(0.12));
      // Stroke.
      canvas.drawPath(
        p,
        Paint()
          ..color = col.withOpacity(0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = w,
      );
    }

    for (int si = 0; si < sectorBoundaries.length; si++) {
      _drawPoly2D(
        sectorBoundaries[si].$2,
        sectorColors2D[si % sectorColors2D.length],
      );
    }
    if (farmBoundary.isNotEmpty && sectorBoundaries.isEmpty) {
      _drawPoly2D(farmBoundary, const Color(0xFFFFD600), w: 2.5);
    }

    // ── motion trail (2D) ──────────────────────────────────────────────
    if (positionTrail.length >= 2) {
      for (int i = 1; i < positionTrail.length; i++) {
        final t = i / positionTrail.length;
        final p0 = positionTrail[i - 1];
        final p1 = positionTrail[i];
        canvas.drawLine(
          Offset(p0.x * zoom + originX, p0.z * zoom + originZ),
          Offset(p1.x * zoom + originX, p1.z * zoom + originZ),
          Paint()
            ..color =
                Color.lerp(
                  const Color(0xFF00BCD4).withOpacity(0.05),
                  const Color(0xFF00E5FF).withOpacity(0.70),
                  t,
                )!
            ..strokeWidth = 1.0 + t * 1.5
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    // ── drone's A* path ──────────────────────────────────────────────────
    if (path.length >= 2) {
      final pathPaint =
          Paint()
            ..color = accent.withOpacity(0.75)
            ..strokeWidth = 2.5
            ..style = PaintingStyle.stroke;
      final p2d = Path();
      p2d.moveTo(path.first.x * zoom + originX, path.first.z * zoom + originZ);
      for (final pt in path.skip(1)) {
        p2d.lineTo(pt.x * zoom + originX, pt.z * zoom + originZ);
      }
      canvas.drawPath(p2d, pathPaint);
    }

    // ── waypoint connecting lines ────────────────────────────────────────
    if (waypoints.length >= 1) {
      final linePaint =
          Paint()
            ..color = Colors.orange.withOpacity(0.65)
            ..strokeWidth = 2.0
            ..style = PaintingStyle.stroke;
      final lp = Path();
      lp.moveTo(
        drone.position.x * zoom + originX,
        drone.position.z * zoom + originZ,
      );
      for (final wp in waypoints) {
        lp.lineTo(wp.x * zoom + originX, wp.z * zoom + originZ);
      }
      canvas.drawPath(lp, linePaint);
    }

    // ── waypoint pins ────────────────────────────────────────────────────
    for (int i = 0; i < waypoints.length; i++) {
      final wp = waypoints[i];
      final double sx = wp.x * zoom + originX;
      final double sz = wp.z * zoom + originZ;
      final Color col =
          Color.lerp(
            Colors.orange,
            Colors.red,
            i / math.max(1, waypoints.length - 1),
          )!;
      canvas.drawCircle(
        Offset(sx, sz),
        9.0,
        Paint()..color = col.withOpacity(0.85),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(sx - tp.width / 2, sz - tp.height / 2));
    }

    // ── drone top-down icon ───────────────────────────────────────────────
    final double dx = drone.position.x * zoom + originX;
    final double dz = drone.position.z * zoom + originZ;
    final double yaw = drone.rotation.y;
    const double armLen = 14.0;
    const List<double> armAngles = [
      -math.pi / 4,
      math.pi / 4,
      3 * math.pi / 4,
      -3 * math.pi / 4,
    ];
    canvas.save();
    canvas.translate(dx, dz);
    canvas.rotate(yaw);
    // arms
    for (final ang in armAngles) {
      canvas.drawLine(
        Offset.zero,
        Offset(math.cos(ang) * armLen, math.sin(ang) * armLen),
        Paint()
          ..color = const Color(0xFF2B2B3D)
          ..strokeWidth = 4
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
      // rotor disc
      canvas.drawCircle(
        Offset(math.cos(ang) * armLen, math.sin(ang) * armLen),
        5.5,
        Paint()..color = accent.withOpacity(0.30),
      );
      canvas.drawCircle(
        Offset(math.cos(ang) * armLen, math.sin(ang) * armLen),
        5.5,
        Paint()
          ..color = accent.withOpacity(0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
    // body
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: 10, height: 10),
      Paint()..color = const Color(0xFF1C1C2E),
    );
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: 10, height: 10),
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    // forward indicator
    canvas.drawLine(
      Offset.zero,
      const Offset(0, -8),
      Paint()
        ..color = Colors.red
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();

    // ── north arrow ───────────────────────────────────────────────────────
    const double arrowX = 24.0, arrowY = 36.0;
    canvas.drawLine(
      Offset(arrowX, arrowY),
      Offset(arrowX, arrowY - 18),
      Paint()
        ..color = Colors.white70
        ..strokeWidth = 2,
    );
    final nTp = TextPainter(
      text: const TextSpan(
        text: 'N',
        style: TextStyle(
          color: Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    nTp.paint(canvas, Offset(arrowX - nTp.width / 2, arrowY - 32));

    // ── scale bar ─────────────────────────────────────────────────────────
    final double scaleWorld = 50.0; // 50 world units
    final double barPx = scaleWorld * zoom;
    final double barY = size.height - 18;
    canvas.drawLine(
      Offset(12, barY),
      Offset(12 + barPx, barY),
      Paint()
        ..color = Colors.white70
        ..strokeWidth = 2,
    );
    canvas.drawLine(
      Offset(12, barY - 4),
      Offset(12, barY + 4),
      Paint()
        ..color = Colors.white70
        ..strokeWidth = 2,
    );
    canvas.drawLine(
      Offset(12 + barPx, barY - 4),
      Offset(12 + barPx, barY + 4),
      Paint()
        ..color = Colors.white70
        ..strokeWidth = 2,
    );
    final scaleTp = TextPainter(
      text: const TextSpan(
        text: '50 m',
        style: TextStyle(color: Colors.white70, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    scaleTp.paint(
      canvas,
      Offset(12 + barPx / 2 - scaleTp.width / 2, barY - 14),
    );
  }

  @override
  bool shouldRepaint(covariant _Scene3DPainter old) =>
      old.animT != animT ||
      old.drone != drone ||
      old.camYawOff != camYawOff ||
      old.camPitchOff != camPitchOff ||
      old.waypoints.length != waypoints.length ||
      old.terrain != terrain ||
      old.mode != mode ||
      old.is3D != is3D;
}
