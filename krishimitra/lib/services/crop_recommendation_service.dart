import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service for getting crop recommendations from the deployed API
class CropRecommendationService {
  static const String _baseUrl = 'https://krishimitra-crop-recommender.onrender.com';
  
  /// Get crop recommendation based on soil and environmental parameters
  /// 
  /// Parameters:
  /// - district: District name (Khartoum, ALfashir, Algazira, Shendi, Niyala)
  /// - soilColor: Soil color (Black, Red, Medium Brown, Dark Brown, Light Brown, Reddish Brown)
  /// - nitrogen: Nitrogen content (20-150)
  /// - phosphorus: Phosphorus content (10-90)
  /// - potassium: Potassium content (5-150)
  /// - ph: pH level (0.5-8.5)
  /// - rainfall: Rainfall in mm (300-1700)
  /// - temperature: Temperature in °C (10-40)
  /// 
  /// Returns a Map with:
  /// - crop: Recommended crop name
  /// - confidence: Confidence score (0-1)
  /// - error: Error message if request fails
  Future<Map<String, dynamic>> getCropRecommendation({
    required String district,
    required String soilColor,
    required double nitrogen,
    required double phosphorus,
    required double potassium,
    required double ph,
    required double rainfall,
    required double temperature,
  }) async {
    try {
      final requestBody = {
        'district': district,
        'soil_color': soilColor,
        'nitrogen': nitrogen,
        'phosphorus': phosphorus,
        'potassium': potassium,
        'ph': ph,
        'rainfall': rainfall,
        'temperature': temperature,
      };

      print('🌾 Requesting crop recommendation...');
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
        
        // Extract crop and confidence from response
        // API returns 'recommended_crop' and 'confidence'
        final crop = data['recommended_crop'] as String? ?? data['crop'] as String?;
        final confidence = data['confidence'] as num?;

        if (crop == null || confidence == null) {
          return {
            'error': 'Invalid response format from server',
          };
        }

        return {
          'crop': crop,
          'confidence': (confidence as double),
          'inputSummary': {
            'district': district,
            'soilColor': soilColor,
            'nitrogen': nitrogen,
            'phosphorus': phosphorus,
            'potassium': potassium,
            'ph': ph,
            'rainfall': rainfall,
            'temperature': temperature,
          },
        };
      } else {
        return {
          'error': 'Server error (${response.statusCode}): ${response.body}',
        };
      }
    } catch (e) {
      print('Error getting crop recommendation: $e');
      return {
        'error': 'Failed to get recommendation: $e',
      };
    }
  }

  /// Get list of available districts
  static List<String> getAvailableDistricts() {
    return [
      'Khartoum',
      'ALfashir',
      'Algazira',
      'Shendi',
      'Niyala',
    ];
  }

  /// Get list of available soil colors
  static List<String> getAvailableSoilColors() {
    return [
      'Black',
      'Red',
      'Medium Brown',
      'Dark Brown',
      'Light Brown',
      'Reddish Brown',
    ];
  }

  /// Get crop emoji based on crop name
  static String getCropEmoji(String crop) {
    final cropLower = crop.toLowerCase();
    if (cropLower.contains('wheat')) return '🌾';
    if (cropLower.contains('rice')) return '🌾';
    if (cropLower.contains('maize') || cropLower.contains('corn')) return '🌽';
    if (cropLower.contains('cotton')) return '🌱';
    if (cropLower.contains('sugarcane')) return '🎋';
    if (cropLower.contains('grape')) return '🍇';
    if (cropLower.contains('groundnut') || cropLower.contains('peanut')) return '🥜';
    if (cropLower.contains('soybean')) return '🌱';
    if (cropLower.contains('ginger')) return '🫚';
    if (cropLower.contains('turmeric')) return '🌱';
    if (cropLower.contains('gram') || cropLower.contains('chickpea')) return '🫘';
    if (cropLower.contains('moong') || cropLower.contains('mung')) return '🫘';
    if (cropLower.contains('masoor') || cropLower.contains('lentil')) return '🫘';
    if (cropLower.contains('tur') || cropLower.contains('pigeon pea')) return '🫘';
    if (cropLower.contains('urad') || cropLower.contains('black gram')) return '🫘';
    if (cropLower.contains('jowar') || cropLower.contains('sorghum')) return '🌾';
    return '🌱'; // Default
  }
}
