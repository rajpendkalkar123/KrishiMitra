import 'package:vector_math/vector_math_64.dart';

/// Immutable drone state for agricultural survey simulation.
/// Axes: x = east, y = altitude (up), z = south.
class DroneState {
  /// World position in metres
  final Vector3 position;

  /// Rotation (Euler angles in radians): x = pitch, y = yaw, z = roll
  final Vector3 rotation;

  /// Linear velocity (m/s)
  final Vector3 velocity;

  /// Angular velocity (rad/s)
  final Vector3 angularVelocity;

  // ── physics constants ──
  final double mass; // kg
  final double maxThrust; // Newtons
  final double drag; // air-resistance coefficient

  // ── status ──
  final double thrust; // current thrust force
  final bool isFlying;
  final bool isHovering;
  final double batteryLevel; // 0.0 → 1.0

  /// Current autonomous target (null = manual control)
  final Vector3? targetPosition;

  const DroneState._({
    required this.position,
    required this.rotation,
    required this.velocity,
    required this.angularVelocity,
    required this.mass,
    required this.maxThrust,
    required this.drag,
    required this.thrust,
    required this.isFlying,
    required this.isHovering,
    required this.batteryLevel,
    this.targetPosition,
  });

  /// Start drone at centre of [worldSize] at 12 m altitude.
  factory DroneState.initial({double worldSize = 320.0}) {
    return DroneState._(
      position: Vector3(worldSize / 2, 12.0, worldSize / 2),
      rotation: Vector3.zero(),
      velocity: Vector3.zero(),
      angularVelocity: Vector3.zero(),
      mass: 1.5,
      maxThrust: 30.0,
      drag: 0.15, // increased from 0.12 – reduces floaty over-shoot
      thrust: 0.0,
      isFlying: false,
      isHovering: false,
      batteryLevel: 1.0,
      targetPosition: null,
    );
  }

  DroneState copyWith({
    Vector3? position,
    Vector3? rotation,
    Vector3? velocity,
    Vector3? angularVelocity,
    double? mass,
    double? maxThrust,
    double? drag,
    double? thrust,
    bool? isFlying,
    bool? isHovering,
    double? batteryLevel,
    Vector3? targetPosition,
    bool clearTarget = false,
  }) {
    return DroneState._(
      position: position ?? this.position.clone(),
      rotation: rotation ?? this.rotation.clone(),
      velocity: velocity ?? this.velocity.clone(),
      angularVelocity: angularVelocity ?? this.angularVelocity.clone(),
      mass: mass ?? this.mass,
      maxThrust: maxThrust ?? this.maxThrust,
      drag: drag ?? this.drag,
      thrust: thrust ?? this.thrust,
      isFlying: isFlying ?? this.isFlying,
      isHovering: isHovering ?? this.isHovering,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      targetPosition:
          clearTarget ? null : (targetPosition ?? this.targetPosition?.clone()),
    );
  }

  // ── computed helpers ──
  double get speedKmh => velocity.length * 3.6;
  double get altitudeM => position.y;
  double get headingDeg => (rotation.y * 180 / 3.14159265) % 360;
}
