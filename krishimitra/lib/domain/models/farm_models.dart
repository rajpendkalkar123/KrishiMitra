import 'package:latlong2/latlong.dart';

class Farm {
  final String id;
  final String name;
  final String farmerId;
  final List<LatLng> boundary;
  final double area; // in acres
  final List<Sector> sectors;
  final DateTime createdAt;

  Farm({
    required this.id,
    required this.name,
    required this.farmerId,
    required this.boundary,
    required this.area,
    required this.sectors,
    required this.createdAt,
  });

  Farm copyWith({
    String? id,
    String? name,
    String? farmerId,
    List<LatLng>? boundary,
    double? area,
    List<Sector>? sectors,
    DateTime? createdAt,
  }) {
    return Farm(
      id: id ?? this.id,
      name: name ?? this.name,
      farmerId: farmerId ?? this.farmerId,
      boundary: boundary ?? this.boundary,
      area: area ?? this.area,
      sectors: sectors ?? this.sectors,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class Sector {
  final String id;
  final String farmId;
  final String name;
  final List<LatLng> boundary;
  final double area; // in acres
  final String cropType;
  final DateTime? plantingDate;
  final String? growthStage;
  final SectorHealth health;
  final String? sensorIP; // ESP8266 sensor IP address

  Sector({
    required this.id,
    required this.farmId,
    required this.name,
    required this.boundary,
    required this.area,
    required this.cropType,
    this.plantingDate,
    this.growthStage,
    this.health = SectorHealth.unknown,
    this.sensorIP,
  });

  Sector copyWith({
    String? id,
    String? farmId,
    String? name,
    List<LatLng>? boundary,
    double? area,
    String? cropType,
    DateTime? plantingDate,
    String? growthStage,
    SectorHealth? health,
    String? sensorIP,
  }) {
    return Sector(
      id: id ?? this.id,
      farmId: farmId ?? this.farmId,
      name: name ?? this.name,
      boundary: boundary ?? this.boundary,
      area: area ?? this.area,
      cropType: cropType ?? this.cropType,
      plantingDate: plantingDate ?? this.plantingDate,
      growthStage: growthStage ?? this.growthStage,
      health: health ?? this.health,
      sensorIP: sensorIP ?? this.sensorIP,
    );
  }
}

enum SectorHealth { excellent, good, fair, poor, critical, unknown }
