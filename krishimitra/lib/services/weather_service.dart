import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:krishimitra/domain/models/models.dart';

class WeatherService {
  static const String baseUrl = 'https://api.open-meteo.com/v1/forecast';
  static const String geocodeUrl =
      'https://nominatim.openstreetmap.org/reverse';

  /// Get location name from coordinates using reverse geocoding
  static Future<String> getLocationName({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final uri = Uri.parse(
        '$geocodeUrl?lat=$latitude&lon=$longitude&format=json&accept-language=en',
      );

      final response = await http
          .get(uri, headers: {'User-Agent': 'KrishiMitra/1.0'})
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => http.Response('Timeout', 408),
          );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final address = data['address'] as Map<String, dynamic>?;

        // Try to get city, town, village, or state
        String? locationName =
            address?['city'] ??
            address?['town'] ??
            address?['village'] ??
            address?['state_district'] ??
            address?['state'];

        if (locationName != null) {
          print('✅ Location name: $locationName');
          return locationName;
        }
      }
    } catch (e) {
      print('❌ Geocoding error: $e');
    }

    // Fallback to coordinates
    return '${latitude.toStringAsFixed(2)}°N, ${longitude.toStringAsFixed(2)}°E';
  }

  /// Fetch real-time weather data from Open-Meteo API
  /// Includes: temperature, precipitation, weather condition, humidity, wind speed
  static Future<WeatherData> fetchWeather({
    required double latitude,
    required double longitude,
  }) async {
    try {
      // Fetch weather and location name in parallel
      final weatherFuture = http
          .get(
            Uri.parse(
              '$baseUrl?latitude=$latitude&longitude=$longitude&current=temperature_2m,precipitation,weather_code,relative_humidity_2m,wind_speed_10m',
            ),
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => http.Response('Timeout', 408),
          );

      final locationFuture = getLocationName(
        latitude: latitude,
        longitude: longitude,
      );

      final results = await Future.wait([weatherFuture, locationFuture]);
      final response = results[0] as http.Response;
      final locationName = results[1] as String;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Weather for $locationName: ${data['current']}');
        return WeatherData.fromJson(data, locationName: locationName);
      } else {
        print('❌ Weather API Error: ${response.statusCode}');
        throw Exception('Failed to fetch weather: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Weather API Exception: $e');
      // Fallback data in case of error
      return WeatherData(
        temperature: 28.5,
        precipitation: 0.0,
        condition: 'Unavailable',
        locationName: 'Unknown',
      );
    }
  }
}
