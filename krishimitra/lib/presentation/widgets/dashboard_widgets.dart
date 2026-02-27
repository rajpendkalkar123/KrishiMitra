import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:krishimitra/domain/models/models.dart';
import 'package:krishimitra/utils/app_strings.dart';
import 'package:krishimitra/utils/app_theme.dart';

class WeatherCard extends StatelessWidget {
  final WeatherData weather;

  const WeatherCard({super.key, required this.weather});

  @override
  Widget build(BuildContext context) {
    final isHeatWave = weather.temperature > 35;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.darkGreen, AppTheme.mediumGreen],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.weatherCard,
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${weather.temperature.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '°C',
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    weather.condition,
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              Text(weather.emoji, style: const TextStyle(fontSize: 52)),
            ],
          ),

          if (isHeatWave) ...[
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.alertRed.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.alertRed.withOpacity(0.5)),
              ),
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_rounded,
                    color: AppTheme.alertRed,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppStrings.heatWaveMessage,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatChip(
                icon: Icons.water_drop_rounded,
                value: '${weather.humidity.toStringAsFixed(0)}%',
                label: AppStrings.isHindi ? 'नमी' : 'Humidity',
              ),
              _StatChip(
                icon: Icons.air_rounded,
                value: '${weather.windSpeed.toStringAsFixed(0)} m/s',
                label: AppStrings.isHindi ? 'हवा' : 'Wind',
              ),
              _StatChip(
                icon: Icons.grain_rounded,
                value: '${weather.precipitation.toStringAsFixed(1)}mm',
                label: AppStrings.isHindi ? 'वर्षा' : 'Precip',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(color: Colors.white60, fontSize: 10),
        ),
      ],
    );
  }
}

class WaterSavingsCard extends StatelessWidget {
  final double percentage;

  const WaterSavingsCard({super.key, this.percentage = 25.0});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.waterSaved,
                style: GoogleFonts.poppins(
                  color: Colors.grey[600],
                  fontSize: 13,
                ),
              ),
              Text(
                '$percentage%',
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.successGreen,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.paleGreen,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.water_drop_rounded,
              color: AppTheme.primaryGreen,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }
}

class LocationCard extends StatelessWidget {
  final String title;
  final double latitude;
  final double longitude;

  const LocationCard({
    super.key,
    required this.title,
    required this.latitude,
    required this.longitude,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.paleGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: AppTheme.primaryGreen,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.darkBrown,
                ),
              ),
              Text(
                'Lat: ${latitude.toStringAsFixed(4)}  Lon: ${longitude.toStringAsFixed(4)}',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class FarmHealthScore extends StatelessWidget {
  final double score; // 0.0 - 1.0

  const FarmHealthScore({super.key, required this.score});

  Color _getScoreColor() {
    if (score >= 0.8) return AppTheme.successGreen;
    if (score >= 0.6) return AppTheme.mediumGreen;
    if (score >= 0.4) return AppTheme.warningOrange;
    return AppTheme.alertRed;
  }

  String _getScoreText() {
    if (score >= 0.8) return 'Excellent';
    if (score >= 0.6) return 'Good';
    if (score >= 0.4) return 'Fair';
    return 'Poor';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                AppStrings.farmHealth,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkBrown,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _getScoreColor().withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _getScoreText(),
                  style: GoogleFonts.poppins(
                    color: _getScoreColor(),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: score,
              minHeight: 10,
              backgroundColor: Colors.grey[100],
              valueColor: AlwaysStoppedAnimation<Color>(_getScoreColor()),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(score * 100).toStringAsFixed(0)}% Farm Health',
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

class CropRecommendationCard extends StatelessWidget {
  const CropRecommendationCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryGreen, AppTheme.lightGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withOpacity(0.28),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, '/crop-recommendation'),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.agriculture_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.isHindi
                          ? 'फसल सिफारिश'
                          : 'Crop Recommendation',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppStrings.isHindi
                          ? 'AI द्वारा सर्वोत्तम फसल खोजें'
                          : 'Find the best crop with AI',
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white60,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class IrrigationPredictionCard extends StatelessWidget {
  const IrrigationPredictionCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withOpacity(0.28),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, '/irrigation-prediction'),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.water_drop_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.isHindi
                          ? 'सिंचाई भविष्यवाणी'
                          : 'Irrigation Prediction',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppStrings.isHindi
                          ? '99.42% सटीकता के साथ AI भविष्यवाणी'
                          : 'AI prediction with 99.42% accuracy',
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white60,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SoilMoistureSensorCard extends StatelessWidget {
  const SoilMoistureSensorCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.brown.shade500, Colors.brown.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.brown.withOpacity(0.28),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, '/soil-moisture'),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.sensors_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.isHindi
                          ? 'मिट्टी की नमी सेंसर'
                          : 'Soil Moisture Sensor',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppStrings.isHindi
                          ? 'ESP8266 से तत्काल डेटा'
                          : 'Live data from ESP8266',
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.sensors_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'ESP8266',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
