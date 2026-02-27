import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

/// Dual-joystick flight controls.
///   Left  stick – Y = altitude (up/down),  X = yaw (rotate)
///   Right stick – Y = forward/back,        X = strafe left/right
// ignore_for_file: deprecated_member_use
class DroneFlightControls extends StatefulWidget {
  final ValueChanged<Vector2> onLeftStick;
  final ValueChanged<Vector2> onRightStick;
  final VoidCallback onTakeOff;
  final VoidCallback onLand;
  final VoidCallback onHover;
  final VoidCallback onAltUp;
  final VoidCallback onAltDown;
  final VoidCallback onClearWaypoints;
  final VoidCallback onStartMission;
  final VoidCallback onReset;
  final bool missionActive;

  const DroneFlightControls({
    super.key,
    required this.onLeftStick,
    required this.onRightStick,
    required this.onTakeOff,
    required this.onLand,
    required this.onHover,
    required this.onAltUp,
    required this.onAltDown,
    required this.onClearWaypoints,
    required this.onStartMission,
    required this.onReset,
    this.missionActive = false,
  });

  @override
  State<DroneFlightControls> createState() => _DroneFlightControlsState();
}

class _DroneFlightControlsState extends State<DroneFlightControls> {
  static const Color accent = Color(0xFFa6cf4f);
  static const double padSize = 95.0;
  static const double thumbR = 17.0;
  static const double deadZone = 6.0;
  static const double _maxR = padSize / 2 - thumbR;

  Offset _leftOffset = Offset.zero;
  Offset _rightOffset = Offset.zero;

  // Clamp an absolute finger-position (relative to pad centre) to the joystick
  // circle and return it. This replaces the old delta-accumulation approach
  // which caused the thumb to drift away from the actual finger position.
  static Offset _clampToCircle(Offset rel) {
    final dist = rel.distance;
    if (dist <= _maxR) return rel;
    return rel.scale(_maxR / dist, _maxR / dist);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Left joystick (Altitude / Yaw) ──────────────────────────
          _buildStick(
            label: '↑ ALT  ·  YAW ↻',
            offset: _leftOffset,
            onUpdate: (o) {
              setState(() => _leftOffset = o);
              widget.onLeftStick(_toVec(o));
            },
            onEnd: () {
              setState(() => _leftOffset = Offset.zero);
              widget.onLeftStick(Vector2.zero());
            },
          ),
          const SizedBox(width: 8),
          // ── Action buttons ──────────────────────────────────────────
          _buildActions(),
          const SizedBox(width: 8),
          // ── Right joystick (Forward / Strafe) ──────────────────────
          _buildStick(
            label: '↑ FWD  ·  STRAFE →',
            offset: _rightOffset,
            onUpdate: (o) {
              setState(() => _rightOffset = o);
              widget.onRightStick(_toVec(o));
            },
            onEnd: () {
              setState(() => _rightOffset = Offset.zero);
              widget.onRightStick(Vector2.zero());
            },
          ),
        ],
      ),
    );
  }

  // Converts the thumb's offset from pad centre into a normalised [-1, 1]
  // Vector2. The Y axis is kept in screen convention (down = positive) and
  // each engine handler interprets sign as needed.
  Vector2 _toVec(Offset o) {
    if (o.distance < deadZone) return Vector2.zero();
    return Vector2(
      (o.dx / _maxR).clamp(-1.0, 1.0),
      (o.dy / _maxR).clamp(-1.0, 1.0),
    );
  }

  Widget _buildStick({
    required String label,
    required Offset offset,
    required ValueChanged<Offset> onUpdate,
    required VoidCallback onEnd,
  }) {
    const half = padSize / 2;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9)),
        const SizedBox(height: 4),
        GestureDetector(
          // On first touch: snap thumb directly to finger position.
          onPanStart: (d) {
            final rel = d.localPosition - const Offset(half, half);
            onUpdate(_clampToCircle(rel));
          },
          // Track finger absolutely from pad centre – no drift.
          onPanUpdate: (d) {
            final rel = d.localPosition - const Offset(half, half);
            onUpdate(_clampToCircle(rel));
          },
          onPanEnd: (_) => onEnd(),
          onPanCancel: () => onEnd(),
          child: Container(
            width: padSize,
            height: padSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.shade900,
              border: Border.all(color: accent.withOpacity(0.45), width: 1.8),
            ),
            child: Stack(
              children: [
                // crosshair
                Center(
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withOpacity(0.35),
                    ),
                  ),
                ),
                // thumb
                Positioned(
                  left: half - thumbR + offset.dx,
                  top: half - thumbR + offset.dy,
                  child: Container(
                    width: thumbR * 2,
                    height: thumbR * 2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent,
                      boxShadow: [
                        BoxShadow(
                          color: accent.withOpacity(0.55),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Row 1: TakeOff | Land
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _iconBtn(
              Icons.flight_takeoff,
              'Take Off',
              widget.onTakeOff,
              accent,
            ),
            const SizedBox(width: 4),
            _iconBtn(Icons.flight_land, 'Land', widget.onLand, Colors.orange),
          ],
        ),
        const SizedBox(height: 3),
        // Row 2: Alt Up | Alt Down
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _iconBtn(
              Icons.keyboard_arrow_up,
              'Alt Up',
              widget.onAltUp,
              Colors.lightBlueAccent,
            ),
            const SizedBox(width: 4),
            _iconBtn(
              Icons.keyboard_arrow_down,
              'Alt Down',
              widget.onAltDown,
              Colors.lightBlueAccent,
            ),
          ],
        ),
        const SizedBox(height: 3),
        // Row 3: Hover | Mission / Abort
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _iconBtn(
              Icons.pause_circle_outline,
              'Hover',
              widget.onHover,
              Colors.cyanAccent,
            ),
            const SizedBox(width: 4),
            _iconBtn(
              widget.missionActive ? Icons.stop_circle : Icons.rocket_launch,
              widget.missionActive ? 'Abort' : 'Mission',
              widget.onStartMission,
              widget.missionActive ? Colors.red : Colors.greenAccent,
            ),
          ],
        ),
        const SizedBox(height: 3),
        // Row 4: Clear | Reset
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _iconBtn(
              Icons.delete_sweep,
              'Clear',
              widget.onClearWaypoints,
              Colors.white54,
            ),
            const SizedBox(width: 4),
            _iconBtn(Icons.refresh, 'Reset', widget.onReset, Colors.white38),
          ],
        ),
      ],
    );
  }

  Widget _iconBtn(IconData icon, String tip, VoidCallback cb, Color color) {
    return Tooltip(
      message: tip,
      child: InkWell(
        onTap: cb,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: color.withOpacity(0.45)),
          ),
          child: Icon(icon, color: color, size: 15),
        ),
      ),
    );
  }
}
