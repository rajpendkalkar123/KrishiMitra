import 'dart:convert';
import 'package:http/http.dart' as http;

/// Model for soil moisture data
class SoilMoistureData {
  final int rawValue;
  final int moisturePercent;
  final String status;
  final int timestamp;
  final String sensor;

  SoilMoistureData({
    required this.rawValue,
    required this.moisturePercent,
    required this.status,
    required this.timestamp,
    required this.sensor,
  });

  factory SoilMoistureData.fromJson(Map<String, dynamic> json) {
    return SoilMoistureData(
      rawValue: json['raw_value'] as int? ?? 0,
      moisturePercent: json['moisture_percent'] as int? ?? 0,
      status: json['status'] as String? ?? 'Unknown',
      timestamp: json['timestamp'] as int? ?? 0,
      sensor: json['sensor'] as String? ?? 'YL-69',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'raw_value': rawValue,
      'moisture_percent': moisturePercent,
      'status': status,
      'timestamp': timestamp,
      'sensor': sensor,
    };
  }

  String get statusEmoji {
    if (moisturePercent < 30) return '🔴';
    if (moisturePercent < 60) return '🟡';
    if (moisturePercent < 80) return '🟢';
    return '💧';
  }

  String get recommendation {
    if (moisturePercent < 30) {
      return 'Soil is dry. Water your plants immediately.';
    } else if (moisturePercent < 60) {
      return 'Soil moisture is moderate. Monitor regularly.';
    } else if (moisturePercent < 80) {
      return 'Soil moisture is good. Plants are healthy.';
    } else {
      return 'Soil is very wet. Reduce watering to prevent root rot.';
    }
  }
}

/// Model for sensor health data
class SensorHealthData {
  final String status;
  final int uptime;
  final int wifiStrength;

  SensorHealthData({
    required this.status,
    required this.uptime,
    required this.wifiStrength,
  });

  factory SensorHealthData.fromJson(Map<String, dynamic> json) {
    return SensorHealthData(
      status: json['status'] as String? ?? 'unknown',
      uptime: json['uptime'] as int? ?? 0,
      wifiStrength: json['wifi_strength'] as int? ?? 0,
    );
  }

  bool get isHealthy => status == 'healthy';

  String get wifiQuality {
    if (wifiStrength > -50) return 'Excellent';
    if (wifiStrength > -60) return 'Good';
    if (wifiStrength > -70) return 'Fair';
    return 'Poor';
  }

  String get uptimeFormatted {
    final seconds = uptime ~/ 1000;
    final minutes = seconds ~/ 60;
    final hours = minutes ~/ 60;
    final days = hours ~/ 24;

    if (days > 0) return '$days days';
    if (hours > 0) return '$hours hours';
    if (minutes > 0) return '$minutes minutes';
    return '$seconds seconds';
  }
}

/// Model for sensor information
class SensorInfo {
  final String device;
  final String sensor;
  final String firmware;
  final String ip;
  final String mac;
  final int rssi;

  SensorInfo({
    required this.device,
    required this.sensor,
    required this.firmware,
    required this.ip,
    required this.mac,
    required this.rssi,
  });

  factory SensorInfo.fromJson(Map<String, dynamic> json) {
    return SensorInfo(
      device: json['device'] as String? ?? 'Unknown',
      sensor: json['sensor'] as String? ?? 'Unknown',
      firmware: json['firmware'] as String? ?? 'Unknown',
      ip: json['ip'] as String? ?? '0.0.0.0',
      mac: json['mac'] as String? ?? '00:00:00:00:00:00',
      rssi: json['rssi'] as int? ?? 0,
    );
  }
}

/// Service for ESP8266 soil moisture sensor integration
class SoilMoistureSensorService {
  // Default IP address - Update this with your ESP8266 IP
  static const String defaultIP = '192.168.206.149';
  static const Duration timeout = Duration(seconds: 10);

  /// Get current soil moisture reading
  static Future<SoilMoistureData> getMoistureData(String ip) async {
    try {
      print('📡 Fetching moisture data from: http://$ip/moisture');

      final response = await http
          .get(Uri.parse('http://$ip/moisture'))
          .timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Moisture data received: ${data['moisture_percent']}%');
        return SoilMoistureData.fromJson(data);
      } else {
        throw Exception(
          'Failed to get moisture data. Status: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ Error getting moisture data: $e');
      rethrow;
    }
  }

  /// Check sensor health status
  static Future<SensorHealthData> getHealthStatus(String ip) async {
    try {
      print('📡 Checking sensor health: http://$ip/health');

      final response = await http
          .get(Uri.parse('http://$ip/health'))
          .timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Sensor is ${data['status']}');
        return SensorHealthData.fromJson(data);
      } else {
        throw Exception(
          'Failed to get health status. Status: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ Error getting health status: $e');
      rethrow;
    }
  }

  /// Get sensor information
  static Future<SensorInfo> getSensorInfo(String ip) async {
    try {
      print('📡 Fetching sensor info: http://$ip/info');

      final response = await http
          .get(Uri.parse('http://$ip/info'))
          .timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Sensor info received: ${data['device']}');
        return SensorInfo.fromJson(data);
      } else {
        throw Exception(
          'Failed to get sensor info. Status: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ Error getting sensor info: $e');
      rethrow;
    }
  }

  /// Test if sensor is reachable
  static Future<bool> testConnection(String ip) async {
    try {
      final response = await http
          .get(Uri.parse('http://$ip/health'))
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      print('Connection test failed: $e');
      return false;
    }
  }

  /// Validate IP address format
  static bool isValidIP(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;

    for (final part in parts) {
      final num = int.tryParse(part);
      if (num == null || num < 0 || num > 255) return false;
    }

    return true;
  }

  /// Get moisture status color
  static String getMoistureColor(int percent) {
    if (percent < 30) return '#EF4444'; // Red
    if (percent < 60) return '#F59E0B'; // Orange
    if (percent < 80) return '#10B981'; // Green
    return '#3B82F6'; // Blue
  }

  /// Get moisture icon
  static String getMoistureIcon(int percent) {
    if (percent < 30) return '🔴';
    if (percent < 60) return '🟡';
    if (percent < 80) return '🟢';
    return '💧';
  }
}
