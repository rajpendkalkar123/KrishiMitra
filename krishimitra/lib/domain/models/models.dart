library;

import 'package:flutter/material.dart';

// Export new model files (TODO: create these files)
// export 'task_models.dart';
// export 'marketplace_models.dart';

class WeatherData {
  final double temperature;
  final double precipitation;
  final String condition;
  final double humidity;
  final double windSpeed;
  final String? locationName;

  WeatherData({
    required this.temperature,
    required this.precipitation,
    required this.condition,
    this.humidity = 60.0,
    this.windSpeed = 6.0,
    this.locationName,
  });

  factory WeatherData.fromJson(
    Map<String, dynamic> json, {
    String? locationName,
  }) {
    final weatherCode = json['current']?['weather_code'] ?? 0;
    return WeatherData(
      temperature: (json['current']?['temperature_2m'] ?? 0).toDouble(),
      precipitation: (json['current']?['precipitation'] ?? 0).toDouble(),
      humidity: (json['current']?['relative_humidity_2m'] ?? 60).toDouble(),
      windSpeed: (json['current']?['wind_speed_10m'] ?? 6).toDouble(),
      condition: _getWeatherCondition(weatherCode),
      locationName: locationName,
    );
  }

  // Convert WMO weather code to readable condition
  static String _getWeatherCondition(int code) {
    switch (code) {
      case 0:
        return 'Clear';
      case 1:
      case 2:
      case 3:
        return 'Partly Cloudy';
      case 45:
      case 48:
        return 'Foggy';
      case 51:
      case 53:
      case 55:
        return 'Drizzle';
      case 61:
      case 63:
      case 65:
        return 'Rain';
      case 71:
      case 73:
      case 75:
        return 'Snow';
      case 80:
      case 81:
      case 82:
        return 'Rain Showers';
      case 95:
        return 'Thunderstorm';
      case 96:
      case 99:
        return 'Thunderstorm with Hail';
      default:
        return 'Unknown';
    }
  }

  // Get weather emoji icon
  String get emoji {
    switch (condition) {
      case 'Clear':
        return '☀️';
      case 'Partly Cloudy':
        return '⛅';
      case 'Foggy':
        return '🌫️';
      case 'Drizzle':
        return '🌦️';
      case 'Rain':
      case 'Rain Showers':
        return '🌧️';
      case 'Snow':
        return '❄️';
      case 'Thunderstorm':
      case 'Thunderstorm with Hail':
        return '⛈️';
      default:
        return '🌤️';
    }
  }
}

class SoilData {
  final double latitude;
  final double longitude;
  final double moisture;
  final double nitrogen;
  final double phosphorus;
  final double potassium;
  final double pH;
  final String soilType;

  SoilData({
    required this.latitude,
    required this.longitude,
    required this.moisture,
    required this.nitrogen,
    required this.phosphorus,
    required this.potassium,
    required this.pH,
    this.soilType = 'Black Soil',
  });
}

class IrrigationStatus {
  final String status; // 'START', 'STOP', 'RUNNING'
  final String message;
  final bool isAlert;

  IrrigationStatus({
    required this.status,
    required this.message,
    required this.isAlert,
  });
}

class FertilizerRecommendation {
  final String name;
  final double quantity;
  final String type; // DAP, Urea, MOP, etc.
  final double similarity; // KNN similarity score

  FertilizerRecommendation({
    required this.name,
    required this.quantity,
    required this.type,
    required this.similarity,
  });
}

class DiseaseResult {
  final String label;
  final String? plant;
  final double confidence;
  final String remedy;
  final String? rawPrediction;
  final String? geminiExplanation;

  DiseaseResult({
    required this.label,
    this.plant,
    required this.confidence,
    required this.remedy,
    this.rawPrediction,
    this.geminiExplanation,
  });
}

class FarmerProfile {
  final String name;
  final String district;
  final double farmArea;
  final String primaryCrop;
  final double latitude;
  final double longitude;

  FarmerProfile({
    required this.name,
    required this.district,
    required this.farmArea,
    required this.primaryCrop,
    required this.latitude,
    required this.longitude,
  });
}

class CropRecommendation {
  final String crop;
  final double confidence;
  final Map<String, dynamic> inputParameters;

  CropRecommendation({
    required this.crop,
    required this.confidence,
    required this.inputParameters,
  });

  factory CropRecommendation.fromJson(Map<String, dynamic> json) {
    return CropRecommendation(
      crop: json['crop'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      inputParameters: json['inputSummary'] as Map<String, dynamic>? ?? {},
    );
  }
}

class IrrigationPrediction {
  final String status; // "ON" or "OFF"
  final double confidence;
  final Map<String, double> probabilities; // {OFF: x, ON: y}
  final String recommendation;
  final Map<String, dynamic> inputParameters;

  IrrigationPrediction({
    required this.status,
    required this.confidence,
    required this.probabilities,
    required this.recommendation,
    required this.inputParameters,
  });

  factory IrrigationPrediction.fromJson(Map<String, dynamic> json) {
    final probs = json['probabilities'] as Map<String, dynamic>? ?? {};
    return IrrigationPrediction(
      status: json['status'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      probabilities: {
        'OFF': (probs['OFF'] as num?)?.toDouble() ?? 0.0,
        'ON': (probs['ON'] as num?)?.toDouble() ?? 0.0,
      },
      recommendation: json['recommendation'] as String,
      inputParameters: json['inputSummary'] as Map<String, dynamic>? ?? {},
    );
  }

  bool get shouldIrrigate => status == 'ON';

  Color get statusColor {
    if (status == 'ON') {
      return const Color(0xFF2196F3); // Blue for ON
    } else {
      return const Color(0xFF4CAF50); // Green for OFF
    }
  }
}
