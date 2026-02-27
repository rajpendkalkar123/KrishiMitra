import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:krishimitra/domain/models/models.dart';
import 'package:krishimitra/services/weather_service.dart';
import 'package:krishimitra/services/location_service.dart';

final languageProvider = StateProvider<bool>((ref) => false);

// Real-time weather provider using Open-Meteo API with GPS location
final weatherProvider = FutureProvider.autoDispose<WeatherData>((ref) async {
  // Try to get user's actual GPS location
  print('🌤️ Starting weather fetch...');
  final position = await LocationService.getCurrentLocation();

  double latitude;
  double longitude;
  String source;

  if (position != null) {
    // Use actual GPS location
    latitude = position.latitude;
    longitude = position.longitude;
    source = 'GPS';
    print('🌍 Using GPS location: $latitude, $longitude');
  } else {
    // Fallback to last known location
    final lastPosition = await LocationService.getLastKnownLocation();
    if (lastPosition != null) {
      latitude = lastPosition.latitude;
      longitude = lastPosition.longitude;
      source = 'Cached';
      print('📍 Using last known location: $latitude, $longitude');
    } else {
      // Final fallback to center of India
      latitude = 20.5937;
      longitude = 78.9629;
      source = 'Default';
      print(
        '⚠️ Using default location (Center of India): $latitude, $longitude',
      );
    }
  }

  print('🔄 Fetching weather from $source location...');
  final weatherData = await WeatherService.fetchWeather(
    latitude: latitude,
    longitude: longitude,
  );

  print('✅ Weather fetched successfully for ${weatherData.locationName}');
  return weatherData;
});

final soilMoistureProvider = StateProvider<double>((ref) => 50.0);

final irrigationStatusProvider = Provider<IrrigationStatus>((ref) {
  final moisture = ref.watch(soilMoistureProvider);
  final weather = ref.watch(weatherProvider);
  return weather.when(
    data: (data) {
      if (moisture < 30 && data.precipitation < 1) {
        return IrrigationStatus(
          status: 'START',
          message: 'Soil is dry. Start irrigation pump.',
          isAlert: true,
        );
      } else if (moisture > 80) {
        return IrrigationStatus(
          status: 'STOP',
          message: 'Soil is over-watered. Stop irrigation.',
          isAlert: true,
        );
      } else {
        return IrrigationStatus(
          status: 'RUNNING',
          message: 'Soil moisture is optimal.',
          isAlert: false,
        );
      }
    },
    loading:
        () => IrrigationStatus(
          status: 'LOADING',
          message: 'Fetching weather data...',
          isAlert: false,
        ),
    error:
        (error, stack) => IrrigationStatus(
          status: 'ERROR',
          message: 'Error fetching data',
          isAlert: false,
        ),
  );
});

final nitrogenProvider = StateProvider<double>((ref) => 50.0);
final phosphorusProvider = StateProvider<double>((ref) => 20.0);
final potassiumProvider = StateProvider<double>((ref) => 20.0);
final fertilizerRecommendationProvider = Provider<FertilizerRecommendation?>((
  ref,
) {
  final n = ref.watch(nitrogenProvider);
  final p = ref.watch(phosphorusProvider);
  final k = ref.watch(potassiumProvider);
  if (n > 40 && p < 30 && k < 30) {
    return FertilizerRecommendation(
      name: 'DAP (Diammonium Phosphate)',
      quantity: 10.0,
      type: 'Chemical Fertilizer',
      similarity: 0.95,
    );
  } else if (n < 30 && p > 30 && k > 30) {
    return FertilizerRecommendation(
      name: 'Urea + MOP',
      quantity: 8.0,
      type: 'Chemical Fertilizer',
      similarity: 0.88,
    );
  }
  return null;
});
final diseaseDetectionProvider = FutureProvider.autoDispose<DiseaseResult?>((
  ref,
) async {
  return null;
});
final farmerProfileProvider = StateProvider<FarmerProfile?>((ref) {
  return FarmerProfile(
    name: 'Demo Farmer',
    district: 'Kolhapur',
    farmArea: 2.5,
    primaryCrop: 'Sugarcane',
    latitude: 20.5937,
    longitude: 78.9629,
  );
});
final farmHealthScoreProvider = Provider<double>((ref) {
  final moisture = ref.watch(soilMoistureProvider);
  final weather = ref.watch(weatherProvider);
  double score = 50.0;
  score += (50.0 - (moisture - 50).abs()); // Optimal moisture = 50%

  return weather.maybeWhen(
    data: (data) {
      if (data.temperature < 35) {
        score += 20;
      }
      return score / 100.0;
    },
    orElse: () => score / 100.0,
  );
});
