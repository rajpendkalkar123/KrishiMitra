import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service for predicting irrigation status using ML model
class IrrigationPredictionService {
  static const String _baseUrl = 'https://irrigation-os8x.onrender.com';
  
  /// Predict whether irrigation should be ON or OFF
  /// 
  /// Parameters (14 total):
  /// - soilMoisture: Soil moisture percentage (0-100)
  /// - temperature: Soil temperature in Celsius (-10 to 60)
  /// - soilHumidity: Soil humidity percentage (0-100)
  /// - time: Hour of the day (0-23)
  /// - airTemperature: Air temperature in Celsius (-10 to 50)
  /// - windSpeed: Wind speed in Km/h (0-50)
  /// - airHumidity: Air humidity percentage (0-100)
  /// - windGust: Wind gust speed in Km/h (0-100)
  /// - pressure: Atmospheric pressure in KPa (95-110)
  /// - ph: Soil pH level (0-14)
  /// - rainfall: Rainfall in mm (0-500)
  /// - nitrogen: Nitrogen content (0-200)
  /// - phosphorus: Phosphorus content (0-200)
  /// - potassium: Potassium content (0-200)
  /// 
  /// Returns a Map with:
  /// - status: "ON" or "OFF"
  /// - confidence: Confidence score (0-1)
  /// - probabilities: {OFF: x, ON: y}
  /// - recommendation: Human-readable recommendation
  /// - error: Error message if request fails
  Future<Map<String, dynamic>> predictIrrigation({
    required double soilMoisture,
    required double temperature,
    required double soilHumidity,
    required int time,
    required double airTemperature,
    required double windSpeed,
    required double airHumidity,
    required double windGust,
    required double pressure,
    required double ph,
    required double rainfall,
    required double nitrogen,
    required double phosphorus,
    required double potassium,
  }) async {
    try {
      final requestBody = {
        'soil_moisture': soilMoisture,
        'temperature': temperature,
        'soil_humidity': soilHumidity,
        'time': time,
        'air_temperature': airTemperature,
        'wind_speed': windSpeed,
        'air_humidity': airHumidity,
        'wind_gust': windGust,
        'pressure': pressure,
        'ph': ph,
        'rainfall': rainfall,
        'nitrogen': nitrogen,
        'phosphorus': phosphorus,
        'potassium': potassium,
      };

      print('💧 Requesting irrigation prediction...');
      print('Request body: ${jsonEncode(requestBody)}');

      final response = await http.post(
        Uri.parse('$_baseUrl/predict'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(
        const Duration(seconds: 90),
        onTimeout: () {
          throw Exception('Request timeout. The server may be waking up (cold start on free tier). Please try again in a moment.');
        },
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        
        // Extract prediction results from response
        final status = data['status'] as String?;
        final confidence = data['confidence'] as num?;
        final probabilities = data['probabilities'] as Map<String, dynamic>?;
        final recommendation = data['recommendation'] as String?;

        if (status == null || confidence == null) {
          return {
            'error': 'Invalid response format from server',
          };
        }

        return {
          'status': status,
          'confidence': (confidence as double),
          'probabilities': {
            'OFF': (probabilities?['OFF'] as num?)?.toDouble() ?? 0.0,
            'ON': (probabilities?['ON'] as num?)?.toDouble() ?? 0.0,
          },
          'recommendation': recommendation ?? _getDefaultRecommendation(status),
          'inputSummary': {
            'soilMoisture': soilMoisture,
            'temperature': temperature,
            'soilHumidity': soilHumidity,
            'time': time,
            'airTemperature': airTemperature,
            'windSpeed': windSpeed,
            'airHumidity': airHumidity,
            'windGust': windGust,
            'pressure': pressure,
            'ph': ph,
            'rainfall': rainfall,
            'nitrogen': nitrogen,
            'phosphorus': phosphorus,
            'potassium': potassium,
          },
        };
      } else {
        return {
          'error': 'Server error (${response.statusCode}): ${response.body}',
        };
      }
    } catch (e) {
      print('Error predicting irrigation: $e');
      return {
        'error': 'Failed to get prediction: $e',
      };
    }
  }

  /// Get default recommendation based on status
  String _getDefaultRecommendation(String status) {
    if (status == 'ON') {
      return 'Your crops need water. It is recommended to turn ON the irrigation system.';
    } else {
      return 'Irrigation is not needed at this time. Keep the irrigation system OFF.';
    }
  }

  /// Get model information
  Future<Map<String, dynamic>> getModelInfo() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/model-info'),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        return {
          'error': 'Failed to fetch model info: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'error': 'Failed to fetch model info: $e',
      };
    }
  }

  /// Check if irrigation API is healthy
  Future<bool> checkHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/health'),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['status'] == 'healthy';
      }
      return false;
    } catch (e) {
      print('Health check failed: $e');
      return false;
    }
  }
}
