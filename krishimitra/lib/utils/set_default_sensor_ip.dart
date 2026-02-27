import 'package:krishimitra/services/farm_database_service.dart';
import 'package:krishimitra/services/soil_moisture_service.dart';

/// Utility function to set default sensor IP for all sectors
/// Call this once to update existing sectors with the default IP
Future<void> setDefaultSensorIPForAllSectors() async {
  try {
    final sectors = await FarmDatabaseService.getAllSectors();

    for (final sector in sectors) {
      // Only update if sensor IP is not already set
      if (sector.sensorIP == null || sector.sensorIP!.isEmpty) {
        final updatedSector = sector.copyWith(
          sensorIP: SoilMoistureSensorService.defaultIP,
        );
        await FarmDatabaseService.updateSector(updatedSector);
      }
    }

    print('✅ Updated ${sectors.length} sectors with default sensor IP');
  } catch (e) {
    print('❌ Error setting default sensor IP: $e');
  }
}
