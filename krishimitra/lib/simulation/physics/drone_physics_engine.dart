import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart';
import '../../domain/entities/drone_state.dart';

/// Simulates quadcopter flight dynamics.
/// Uses simplified Newtonian mechanics suitable for real-time 60 Hz updates.
class DronePhysicsEngine {
  static const double gravity = 9.81; // m/s²
  // Balanced hover thrust: mass(1.5) × g(9.81) / maxThrust(30) ≈ 0.4905
  static const double hoverThrust = 0.49;

  // ── Altitude hold (D-gain rate controller) ──────────────────────────────
  // Activated when the vertical stick is within _altHoldDeadzone of hover.
  // The controller damps vertical drift so the drone stays at one altitude.
  static const double _altHoldDeadzone = 0.07;
  static const double _kD_alt = 0.40; // damp vertical velocity
  static const double _kP_alt = 0.12; // resist persistent drift

  // ── Lateral auto-brake ──────────────────────────────────────────────────
  // When horizontal stick is centred, extra drag bleeds off lateral speed.
  static const double _latBrakeDrag = 2.0;

  // ── Horizontal speed cap ─────────────────────────────────────────────────
  static const double _maxHorizSpeed = 14.0; // m/s

  /// Advance drone state by [dt] seconds.
  ///
  /// [thrustInput]  0.0 (off) → 1.0 (full)
  /// [tiltInput]    x = left/right,  y = forward/backward, range −1..1
  /// [yawInput]     −1 = spin left, +1 = spin right
  /// [terrainHeight] ground altitude at current x/z position
  DroneState update({
    required DroneState drone,
    required double dt,
    required double thrustInput,
    required Vector2 tiltInput,
    double yawInput = 0.0,
    required double terrainHeight,
  }) {
    // ── Altitude hold ────────────────────────────────────────────────────
    // When stick is near neutral, auto-correct thrust to cancel vertical drift.
    double effectiveThrust = thrustInput;
    if (drone.isFlying &&
        (thrustInput - hoverThrust).abs() < _altHoldDeadzone) {
      final vY = drone.velocity.y;
      final correction = -_kD_alt * vY; // dampen vertical speed
      effectiveThrust = (hoverThrust + correction).clamp(0.10, 0.96);
    }

    // ── thrust direction ─────────────────────────────────────────────────
    final thrustN = effectiveThrust * drone.maxThrust;
    final thrustDir = _thrustDir(drone.rotation, tiltInput);
    final thrustVec = thrustDir.scaled(thrustN);

    // ── lateral auto-brake when stick centred ────────────────────────────
    final latBrake =
        tiltInput.length < 0.08 && drone.isFlying ? _latBrakeDrag : 0.0;

    // ── forces ──────────────────────────────────────────────────────────
    final forces =
        Vector3(0, -drone.mass * gravity, 0) // gravity
          ..add(thrustVec) // thrust
          ..add(drone.velocity.scaled(-(drone.drag + latBrake))); // drag

    // ── integrate ────────────────────────────────────────────────────────
    final acc = forces.scaled(1.0 / drone.mass);
    final newVel = drone.velocity.clone()..add(acc.scaled(dt));
    final newPos = drone.position.clone()..add(newVel.scaled(dt));

    // ── horizontal speed cap ─────────────────────────────────────────────
    final hx = newVel.x, hz = newVel.z;
    final horizSpd = math.sqrt(hx * hx + hz * hz);
    if (horizSpd > _maxHorizSpeed) {
      final scale = _maxHorizSpeed / horizSpd;
      newVel.x *= scale;
      newVel.z *= scale;
    }

    // ── ground clamp ─────────────────────────────────────────────────────
    final minY = terrainHeight + 0.5;
    bool flying = true;
    if (newPos.y < minY) {
      newPos.y = minY;
      newVel.y = math.max(0, newVel.y);
      if (thrustInput < 0.3) flying = false;
    }

    // ── rotation – snappier tilt response ────────────────────────────────
    final newRot = drone.rotation.clone();
    const smoothing = 12.0; // increased from 8 for snappier feel
    final targetPitch = tiltInput.y * 0.42;
    final targetRoll = tiltInput.x * 0.42;
    newRot.x += (targetPitch - newRot.x) * smoothing * dt;
    newRot.z += (targetRoll - newRot.z) * smoothing * dt;
    newRot.x = newRot.x.clamp(-0.60, 0.60);
    newRot.z = newRot.z.clamp(-0.60, 0.60);
    // faster yaw for easier manoeuvring
    newRot.y += yawInput * 3.5 * dt;

    // ── battery drain ────────────────────────────────────────────────────
    final drain = (thrustInput * 0.006 + 0.0005) * dt;
    final bat = math.max(0.0, drone.batteryLevel - drain);

    return drone.copyWith(
      position: newPos,
      rotation: newRot,
      velocity: newVel,
      thrust: thrustN,
      isFlying: flying,
      isHovering: flying && newVel.length < 0.6,
      batteryLevel: bat,
    );
  }

  Vector3 _thrustDir(Vector3 rot, Vector2 tilt) {
    final base = Vector3(0, 1, 0);

    // Yaw matrix
    final yaw =
        Matrix3.identity()..setValues(
          math.cos(rot.y),
          0,
          math.sin(rot.y),
          0,
          1,
          0,
          -math.sin(rot.y),
          0,
          math.cos(rot.y),
        );

    // Pitch matrix (x-axis rotation)
    final pitch = rot.x + tilt.y * 0.28;
    final pm =
        Matrix3.identity()..setValues(
          1,
          0,
          0,
          0,
          math.cos(pitch),
          -math.sin(pitch),
          0,
          math.sin(pitch),
          math.cos(pitch),
        );

    // Roll matrix (z-axis rotation)
    final roll = rot.z + tilt.x * 0.28;
    final rm =
        Matrix3.identity()..setValues(
          math.cos(roll),
          -math.sin(roll),
          0,
          math.sin(roll),
          math.cos(roll),
          0,
          0,
          0,
          1,
        );

    return yaw.multiplied(pm).multiplied(rm).transform(base).normalized();
  }

  /// Simple sine-wave terrain height (matches visual terrain in renderer).
  double terrainHeightAt(double x, double z) {
    return math.sin(x * 0.04) * math.cos(z * 0.04) * 2.5 + 0.5;
  }
}
