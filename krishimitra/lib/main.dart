import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:krishimitra/presentation/screens/splash_screen.dart';
import 'package:krishimitra/presentation/screens/crop_recommendation_screen.dart';
import 'package:krishimitra/presentation/screens/irrigation_prediction_screen.dart';
import 'package:krishimitra/presentation/screens/soil_moisture_screen.dart';
import 'package:krishimitra/presentation/screens/task_calendar_screen.dart';
import 'package:krishimitra/presentation/screens/mandi_prices_screen.dart';
import 'package:krishimitra/presentation/screens/equipment_rental_screen.dart';
import 'package:krishimitra/services/farm_database_service.dart';
import 'package:krishimitra/services/esp32_camera_service.dart';
import 'package:krishimitra/services/marathi_tts_service.dart';
import 'package:krishimitra/utils/app_strings.dart';
import 'package:krishimitra/utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Let system UI overlay blend with the app
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );

  await FarmDatabaseService.initialize();
  await ESP32CameraService.initialize();
  MarathiTtsService.initialize(); // Fire and forget TTS init

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: AppStrings.appTitle,
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        home: const SplashScreen(),
        routes: {
          '/crop-recommendation': (context) => const CropRecommendationScreen(),
          '/irrigation-prediction':
              (context) => const IrrigationPredictionScreen(),
          '/soil-moisture': (context) => const SoilMoistureScreen(),
          '/task-calendar': (context) => const TaskCalendarScreen(),
          '/mandi-prices': (context) => const MandiPricesScreen(),
          '/equipment-rental': (context) => const EquipmentRentalScreen(),
        },
      ),
    );
  }
}
