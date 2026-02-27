import 'package:flutter/material.dart';
import '../../domain/entities/drone_state.dart';

/// Semi-transparent telemetry panel showing altitude, speed, heading, etc.
class DroneTelemetryPanel extends StatelessWidget {
  final DroneState state;

  const DroneTelemetryPanel({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.65),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFa6cf4f).withOpacity(0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: 10),
          _metric('Altitude', '${state.altitudeM.toStringAsFixed(1)} m'),
          _metric('Speed', '${state.speedKmh.toStringAsFixed(1)} km/h'),
          _metric('Heading', '${state.headingDeg.toStringAsFixed(0)}°'),
          _metric('Pitch', '${_rad2deg(state.rotation.x)}°'),
          _metric('Roll', '${_rad2deg(state.rotation.z)}°'),
          const SizedBox(height: 8),
          _statusChip(),
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        const Icon(Icons.sensors, color: Color(0xFFa6cf4f), size: 18),
        const SizedBox(width: 6),
        const Text(
          'Telemetry',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _metric(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFa6cf4f),
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip() {
    final label = state.isHovering
        ? 'Hovering'
        : state.isFlying
            ? 'Flying'
            : 'Landed';
    final col = state.isFlying ? const Color(0xFFa6cf4f) : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: col.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: col.withOpacity(0.6)),
      ),
      child: Text(
        label,
        style: TextStyle(color: col, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  int _rad2deg(double r) => (r * 180 / 3.14159265).round();
}
