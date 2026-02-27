import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:krishimitra/services/irrigation_prediction_service.dart';
import 'package:krishimitra/utils/app_strings.dart';
import 'package:krishimitra/utils/app_theme.dart';

/// Screen for AI-powered irrigation prediction
class IrrigationPredictionScreen extends StatefulWidget {
  const IrrigationPredictionScreen({super.key});

  @override
  State<IrrigationPredictionScreen> createState() =>
      _IrrigationPredictionScreenState();
}

class _IrrigationPredictionScreenState
    extends State<IrrigationPredictionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = IrrigationPredictionService();

  // Soil parameters
  double _soilMoisture = 50.0;
  double _temperature = 30.0;
  double _soilHumidity = 40.0;
  double _ph = 6.5;

  // NPK parameters
  double _nitrogen = 80.0;
  double _phosphorus = 45.0;
  double _potassium = 40.0;

  // Weather parameters
  int _time = 12;
  double _airTemperature = 25.5;
  double _windSpeed = 5.2;
  double _airHumidity = 50.0;
  double _windGust = 10.5;
  double _pressure = 101.3;
  double _rainfall = 200.5;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkHealth();
  }

  Future<void> _checkHealth() async {
    final isHealthy = await _service.checkHealth();
    if (!isHealthy && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.isHindi
                ? '⚠️ सर्वर वेक अप हो रहा है। पहली भविष्यवाणी में समय लग सकता है।'
                : '⚠️ Server may be waking up. First prediction may take longer.',
          ),
          duration: const Duration(seconds: 5),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _predictIrrigation() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    await _service.predictIrrigation(
      soilMoisture: _soilMoisture,
      temperature: _temperature,
      soilHumidity: _soilHumidity,
      time: _time,
      airTemperature: _airTemperature,
      windSpeed: _windSpeed,
      airHumidity: _airHumidity,
      windGust: _windGust,
      pressure: _pressure,
      ph: _ph,
      rainfall: _rainfall,
      nitrogen: _nitrogen,
      phosphorus: _phosphorus,
      potassium: _potassium,
    );

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      body: CustomScrollView(
        slivers: [
          // Gradient header
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            backgroundColor: const Color(0xFF1565C0),
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF0D47A1),
                      Color(0xFF1565C0),
                      Color(0xFF1976D2),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.water_drop,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                AppStrings.isHindi
                                    ? 'सिंचाई भविष्यवाणी'
                                    : 'Irrigation Prediction',
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    AppStrings.isHindi
                                        ? 'AI-संचालित विश्लेषण'
                                        : 'AI-Powered Analysis',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.greenAccent.withOpacity(
                                        0.25,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '99.42% Accuracy',
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.greenAccent,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Form body
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Soil Parameters
                    _buildSectionHeader(
                      '🌱',
                      AppStrings.isHindi
                          ? 'मिट्टी की स्थिति'
                          : 'Soil Conditions',
                    ),
                    const SizedBox(height: 10),
                    _buildSliderCard(
                      label:
                          AppStrings.isHindi
                              ? 'मिट्टी की नमी (%)'
                              : 'Soil Moisture (%)',
                      value: _soilMoisture,
                      min: 0,
                      max: 100,
                      onChanged: (v) => setState(() => _soilMoisture = v),
                    ),
                    const SizedBox(height: 8),
                    _buildSliderCard(
                      label:
                          AppStrings.isHindi
                              ? 'मिट्टी का तापमान (°C)'
                              : 'Soil Temperature (°C)',
                      value: _temperature,
                      min: -10,
                      max: 60,
                      onChanged: (v) => setState(() => _temperature = v),
                    ),
                    const SizedBox(height: 8),
                    _buildSliderCard(
                      label:
                          AppStrings.isHindi
                              ? 'मिट्टी की आर्द्रता (%)'
                              : 'Soil Humidity (%)',
                      value: _soilHumidity,
                      min: 0,
                      max: 100,
                      onChanged: (v) => setState(() => _soilHumidity = v),
                    ),
                    const SizedBox(height: 8),
                    _buildSliderCard(
                      label: AppStrings.isHindi ? 'pH स्तर' : 'pH Level',
                      value: _ph,
                      min: 0,
                      max: 14,
                      divisions: 140,
                      onChanged: (v) => setState(() => _ph = v),
                    ),
                    const SizedBox(height: 16),

                    // NPK Parameters
                    _buildSectionHeader(
                      '🧪',
                      AppStrings.isHindi ? 'NPK स्तर' : 'NPK Levels',
                    ),
                    const SizedBox(height: 10),
                    _buildSliderCard(
                      label:
                          AppStrings.isHindi ? 'नाइट्रोजन (N)' : 'Nitrogen (N)',
                      value: _nitrogen,
                      min: 0,
                      max: 200,
                      color: const Color(0xFF2196F3),
                      onChanged: (v) => setState(() => _nitrogen = v),
                    ),
                    const SizedBox(height: 8),
                    _buildSliderCard(
                      label:
                          AppStrings.isHindi
                              ? 'फास्फोरस (P)'
                              : 'Phosphorus (P)',
                      value: _phosphorus,
                      min: 0,
                      max: 200,
                      color: const Color(0xFFFF9800),
                      onChanged: (v) => setState(() => _phosphorus = v),
                    ),
                    const SizedBox(height: 8),
                    _buildSliderCard(
                      label:
                          AppStrings.isHindi ? 'पोटैशियम (K)' : 'Potassium (K)',
                      value: _potassium,
                      min: 0,
                      max: 200,
                      color: const Color(0xFF9C27B0),
                      onChanged: (v) => setState(() => _potassium = v),
                    ),
                    const SizedBox(height: 16),

                    // Weather Parameters
                    _buildSectionHeader(
                      '🌤️',
                      AppStrings.isHindi
                          ? 'मौसम की स्थिति'
                          : 'Weather Conditions',
                    ),
                    const SizedBox(height: 10),
                    _buildSliderCard(
                      label: AppStrings.isHindi ? 'समय (घंटा)' : 'Time (Hour)',
                      value: _time.toDouble(),
                      min: 0,
                      max: 23,
                      divisions: 23,
                      onChanged: (v) => setState(() => _time = v.toInt()),
                    ),
                    const SizedBox(height: 8),
                    _buildSliderCard(
                      label:
                          AppStrings.isHindi
                              ? 'हवा का तापमान (°C)'
                              : 'Air Temperature (°C)',
                      value: _airTemperature,
                      min: -10,
                      max: 50,
                      onChanged: (v) => setState(() => _airTemperature = v),
                    ),
                    const SizedBox(height: 8),
                    _buildSliderCard(
                      label:
                          AppStrings.isHindi
                              ? 'हवा की आर्द्रता (%)'
                              : 'Air Humidity (%)',
                      value: _airHumidity,
                      min: 0,
                      max: 100,
                      onChanged: (v) => setState(() => _airHumidity = v),
                    ),
                    const SizedBox(height: 8),
                    _buildSliderCard(
                      label:
                          AppStrings.isHindi
                              ? 'हवा की गति (Km/h)'
                              : 'Wind Speed (Km/h)',
                      value: _windSpeed,
                      min: 0,
                      max: 50,
                      onChanged: (v) => setState(() => _windSpeed = v),
                    ),
                    const SizedBox(height: 8),
                    _buildSliderCard(
                      label:
                          AppStrings.isHindi
                              ? 'हवा का झोंका (Km/h)'
                              : 'Wind Gust (Km/h)',
                      value: _windGust,
                      min: 0,
                      max: 100,
                      onChanged: (v) => setState(() => _windGust = v),
                    ),
                    const SizedBox(height: 8),
                    _buildSliderCard(
                      label:
                          AppStrings.isHindi
                              ? 'वायुमंडलीय दबाव (KPa)'
                              : 'Atmospheric Pressure (KPa)',
                      value: _pressure,
                      min: 95,
                      max: 110,
                      divisions: 150,
                      onChanged: (v) => setState(() => _pressure = v),
                    ),
                    const SizedBox(height: 8),
                    _buildSliderCard(
                      label:
                          AppStrings.isHindi ? 'वर्षा (mm)' : 'Rainfall (mm)',
                      value: _rainfall,
                      min: 0,
                      max: 500,
                      onChanged: (v) => setState(() => _rainfall = v),
                    ),
                    const SizedBox(height: 24),

                    // Predict Button
                    GestureDetector(
                      onTap: _isLoading ? null : _predictIrrigation,
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1565C0).withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Center(
                          child:
                              _isLoading
                                  ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                  : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.analytics,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        AppStrings.isHindi
                                            ? 'सिंचाई की भविष्यवाणी करें'
                                            : 'Predict Irrigation',
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String emoji, String title) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppTheme.darkGreen,
          ),
        ),
      ],
    );
  }

  Widget _buildSliderCard({
    required String label,
    required double value,
    required double min,
    required double max,
    int? divisions,
    Color color = const Color(0xFF1976D2),
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  value.toStringAsFixed(value % 1 == 0 ? 0 : 1),
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: color,
              thumbColor: color,
              inactiveTrackColor: color.withOpacity(0.2),
              overlayColor: color.withOpacity(0.1),
              trackHeight: 4,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions ?? (max - min).toInt(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
