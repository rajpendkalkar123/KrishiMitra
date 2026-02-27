import 'package:hive_flutter/hive_flutter.dart';
import 'package:krishimitra/domain/models/farm_models.dart';
import 'package:latlong2/latlong.dart';

class FarmDatabaseService {
  static const String _farmBoxName = 'farms';
  static const String _sectorBoxName = 'sectors';

  static Box<Map>? _farmBox;
  static Box<Map>? _sectorBox;
  static Future<void> initialize() async {
    await Hive.initFlutter();
    _farmBox = await Hive.openBox<Map>(_farmBoxName);
    _sectorBox = await Hive.openBox<Map>(_sectorBoxName);
  }

  static Future<void> saveFarm(Farm farm) async {
    final farmMap = {
      'id': farm.id,
      'name': farm.name,
      'farmerId': farm.farmerId,
      'boundary':
          farm.boundary
              .map((point) => {'lat': point.latitude, 'lng': point.longitude})
              .toList(),
      'area': farm.area,
      'createdAt': farm.createdAt.toIso8601String(),
    };

    await _farmBox?.put(farm.id, farmMap);
    for (final sector in farm.sectors) {
      await saveSector(sector);
    }
  }

  static Future<void> saveSector(Sector sector) async {
    final sectorMap = {
      'id': sector.id,
      'farmId': sector.farmId,
      'name': sector.name,
      'boundary':
          sector.boundary
              .map((point) => {'lat': point.latitude, 'lng': point.longitude})
              .toList(),
      'area': sector.area,
      'cropType': sector.cropType,
      'plantingDate': sector.plantingDate?.toIso8601String(),
      'growthStage': sector.growthStage,
      'health': sector.health.toString(),
      'sensorIP': sector.sensorIP,
    };

    await _sectorBox?.put(sector.id, sectorMap);
  }

  static Future<List<Farm>> getAllFarms() async {
    if (_farmBox == null || _farmBox!.isEmpty) return [];

    final farms = <Farm>[];
    for (final farmMap in _farmBox!.values) {
      final farm = _mapToFarm(farmMap);
      if (farm != null) farms.add(farm);
    }

    return farms;
  }

  static Future<Farm?> getFarm(String farmId) async {
    final farmMap = _farmBox?.get(farmId);
    if (farmMap == null) return null;
    return _mapToFarm(farmMap);
  }

  static Future<List<Sector>> getSectorsByFarmId(String farmId) async {
    if (_sectorBox == null || _sectorBox!.isEmpty) return [];

    final sectors = <Sector>[];
    for (final sectorMap in _sectorBox!.values) {
      if (sectorMap['farmId'] == farmId) {
        final sector = _mapToSector(sectorMap);
        if (sector != null) sectors.add(sector);
      }
    }

    return sectors;
  }

  static Future<List<Sector>> getAllSectors() async {
    if (_sectorBox == null || _sectorBox!.isEmpty) return [];

    final sectors = <Sector>[];
    for (final sectorMap in _sectorBox!.values) {
      final sector = _mapToSector(sectorMap);
      if (sector != null) sectors.add(sector);
    }

    return sectors;
  }

  static Future<void> deleteFarm(String farmId) async {
    await _farmBox?.delete(farmId);
    final sectors = await getSectorsByFarmId(farmId);
    for (final sector in sectors) {
      await deleteSector(sector.id);
    }
  }

  static Future<void> deleteSector(String sectorId) async {
    await _sectorBox?.delete(sectorId);
  }

  static Future<void> updateSector(Sector sector) async {
    await saveSector(sector); // Hive overwrites by key
  }

  static Future<void> clearAll() async {
    await _farmBox?.clear();
    await _sectorBox?.clear();
  }

  static Farm? _mapToFarm(Map farmMap) {
    try {
      final boundaryList = farmMap['boundary'] as List;
      final boundary =
          boundaryList
              .map(
                (point) =>
                    LatLng(point['lat'] as double, point['lng'] as double),
              )
              .toList();

      return Farm(
        id: farmMap['id'] as String,
        name: farmMap['name'] as String,
        farmerId: farmMap['farmerId'] as String,
        boundary: boundary,
        area: farmMap['area'] as double,
        sectors: [],
        createdAt: DateTime.parse(farmMap['createdAt'] as String),
      );
    } catch (e) {
      print('Error converting map to Farm: $e');
      return null;
    }
  }

  static Sector? _mapToSector(Map sectorMap) {
    try {
      final boundaryList = sectorMap['boundary'] as List;
      final boundary =
          boundaryList
              .map(
                (point) =>
                    LatLng(point['lat'] as double, point['lng'] as double),
              )
              .toList();

      return Sector(
        id: sectorMap['id'] as String,
        farmId: sectorMap['farmId'] as String,
        name: sectorMap['name'] as String,
        boundary: boundary,
        area: sectorMap['area'] as double,
        cropType: sectorMap['cropType'] as String,
        plantingDate:
            sectorMap['plantingDate'] != null
                ? DateTime.parse(sectorMap['plantingDate'] as String)
                : null,
        growthStage: sectorMap['growthStage'] as String?,
        health: _parseHealth(sectorMap['health'] as String?),
        sensorIP: sectorMap['sensorIP'] as String?,
      );
    } catch (e) {
      print('Error converting map to Sector: $e');
      return null;
    }
  }

  static SectorHealth _parseHealth(String? healthString) {
    if (healthString == null) return SectorHealth.unknown;

    switch (healthString) {
      case 'SectorHealth.excellent':
        return SectorHealth.excellent;
      case 'SectorHealth.good':
        return SectorHealth.good;
      case 'SectorHealth.fair':
        return SectorHealth.fair;
      case 'SectorHealth.poor':
        return SectorHealth.poor;
      case 'SectorHealth.critical':
        return SectorHealth.critical;
      default:
        return SectorHealth.unknown;
    }
  }
}
