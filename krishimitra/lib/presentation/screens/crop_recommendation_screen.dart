import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:krishimitra/services/crop_recommendation_service.dart';
import 'package:krishimitra/utils/app_strings.dart';
import 'package:krishimitra/utils/app_theme.dart';

/// Screen for getting AI-powered crop recommendations
class CropRecommendationScreen extends StatefulWidget {
  const CropRecommendationScreen({super.key});

  @override
  State<CropRecommendationScreen> createState() =>
      _CropRecommendationScreenState();
}

class _CropRecommendationScreenState extends State<CropRecommendationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = CropRecommendationService();

  // Form controllers
  String _selectedDistrict = 'Khartoum';
  String _selectedSoilColor = 'Black';
  double _nitrogen = 75.0;
  double _phosphorus = 50.0;
  double _potassium = 100.0;
  double _ph = 6.5;
  double _rainfall = 1000.0;
  double _temperature = 20.0;

  bool _isLoading = false;
  Map<String, dynamic>? _result;

  Future<void> _getCropRecommendation() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _result = null;
    });

    final result = await _service.getCropRecommendation(
      district: _selectedDistrict,
      soilColor: _selectedSoilColor,
      nitrogen: _nitrogen,
      phosphorus: _phosphorus,
      potassium: _potassium,
      ph: _ph,
      rainfall: _rainfall,
      temperature: _temperature,
    );

    setState(() {
      _isLoading = false;
      _result = result;
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
            backgroundColor: AppTheme.darkGreen,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.darkGreen,
                      AppTheme.primaryGreen,
                      AppTheme.mediumGreen,
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
                            Icons.agriculture,
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
                                    ? 'फसल सिफारिश'
                                    : 'Crop Recommendation',
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                AppStrings.isHindi
                                    ? 'AI-संचालित फसल विश्लेषण'
                                    : 'AI-Powered Crop Analysis',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.white70,
                                ),
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
                    // Location Section
                    _buildSectionHeader(
                      '📍',
                      AppStrings.isHindi ? 'स्थान' : 'Location',
                    ),
                    const SizedBox(height: 10),
                    _buildDropdownCard(
                      label: AppStrings.isHindi ? 'जिला' : 'District',
                      icon: Icons.location_city,
                      value: _selectedDistrict,
                      items: CropRecommendationService.getAvailableDistricts(),
                      onChanged: (value) {
                        if (value != null)
                          setState(() => _selectedDistrict = value);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Soil Section
                    _buildSectionHeader(
                      '🟤',
                      AppStrings.isHindi
                          ? 'मिट्टी की जानकारी'
                          : 'Soil Information',
                    ),
                    const SizedBox(height: 10),
                    _buildDropdownCard(
                      label:
                          AppStrings.isHindi ? 'मिट्टी का रंग' : 'Soil Color',
                      icon: Icons.palette,
                      value: _selectedSoilColor,
                      items: CropRecommendationService.getAvailableSoilColors(),
                      onChanged: (value) {
                        if (value != null)
                          setState(() => _selectedSoilColor = value);
                      },
                    ),
                    const SizedBox(height: 16),

                    // NPK Section
                    _buildSectionHeader(
                      '🧪',
                      AppStrings.isHindi ? 'NPK स्तर' : 'NPK Levels',
                    ),
                    const SizedBox(height: 10),
                    _buildSliderCard(
                      label:
                          AppStrings.isHindi ? 'नाइट्रोजन (N)' : 'Nitrogen (N)',
                      value: _nitrogen,
                      min: 20,
                      max: 150,
                      color: const Color(0xFF2196F3),
                      onChanged: (value) => setState(() => _nitrogen = value),
                    ),
                    const SizedBox(height: 8),
                    _buildSliderCard(
                      label:
                          AppStrings.isHindi
                              ? 'फास्फोरस (P)'
                              : 'Phosphorus (P)',
                      value: _phosphorus,
                      min: 10,
                      max: 90,
                      color: const Color(0xFFFF9800),
                      onChanged: (value) => setState(() => _phosphorus = value),
                    ),
                    const SizedBox(height: 8),
                    _buildSliderCard(
                      label:
                          AppStrings.isHindi ? 'पोटैशियम (K)' : 'Potassium (K)',
                      value: _potassium,
                      min: 5,
                      max: 150,
                      color: const Color(0xFF9C27B0),
                      onChanged: (value) => setState(() => _potassium = value),
                    ),
                    const SizedBox(height: 16),

                    // pH and Environment Section
                    _buildSectionHeader(
                      '⚗️',
                      AppStrings.isHindi ? 'पर्यावरण' : 'Environment',
                    ),
                    const SizedBox(height: 10),
                    _buildSliderCard(
                      label: AppStrings.isHindi ? 'pH स्तर' : 'pH Level',
                      value: _ph,
                      min: 0.5,
                      max: 8.5,
                      divisions: 80,
                      color: const Color(0xFF00BCD4),
                      onChanged: (value) => setState(() => _ph = value),
                    ),
                    const SizedBox(height: 8),
                    _buildSliderCard(
                      label:
                          AppStrings.isHindi ? 'वर्षा (mm)' : 'Rainfall (mm)',
                      value: _rainfall,
                      min: 300,
                      max: 1700,
                      color: const Color(0xFF3F51B5),
                      onChanged: (value) => setState(() => _rainfall = value),
                    ),
                    const SizedBox(height: 8),
                    _buildSliderCard(
                      label:
                          AppStrings.isHindi
                              ? 'तापमान (°C)'
                              : 'Temperature (°C)',
                      value: _temperature,
                      min: 10,
                      max: 40,
                      color: const Color(0xFFE91E63),
                      onChanged:
                          (value) => setState(() => _temperature = value),
                    ),
                    const SizedBox(height: 24),

                    // Submit Button
                    GestureDetector(
                      onTap: _isLoading ? null : _getCropRecommendation,
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppTheme.primaryGreen,
                              AppTheme.mediumGreen,
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryGreen.withOpacity(0.4),
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
                                        Icons.auto_awesome,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        AppStrings.isHindi
                                            ? 'फसल सिफारिश प्राप्त करें'
                                            : 'Get Crop Recommendation',
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

                    // Result Display
                    if (_result != null) _buildResultCard(),
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

  Widget _buildDropdownCard({
    required String label,
    required IconData icon,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppTheme.primaryGreen),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        dropdownColor: Colors.white,
        items:
            items
                .map(
                  (item) => DropdownMenuItem(
                    value: item,
                    child: Text(item, style: GoogleFonts.poppins(fontSize: 14)),
                  ),
                )
                .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildSliderCard({
    required String label,
    required double value,
    required double min,
    required double max,
    int? divisions,
    required Color color,
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
                  value.toStringAsFixed(1),
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

  Widget _buildResultCard() {
    if (_result!.containsKey('error')) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.alertRed.withOpacity(0.4)),
        ),
        child: Column(
          children: [
            Icon(Icons.error_outline, size: 48, color: AppTheme.alertRed),
            const SizedBox(height: 8),
            Text(
              AppStrings.isHindi ? 'त्रुटि' : 'Error',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.alertRed,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _result!['error'].toString(),
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.alertRed),
            ),
          ],
        ),
      );
    }

    final crop = _result!['crop'] as String;
    final confidence = (_result!['confidence'] as double) * 100;
    final emoji = CropRecommendationService.getCropEmoji(crop);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Hero result card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primaryGreen, AppTheme.mediumGreen],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryGreen.withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 64)),
              const SizedBox(height: 12),
              Text(
                AppStrings.isHindi ? 'सिफारिश की गई फसल' : 'Recommended Crop',
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.white70),
              ),
              const SizedBox(height: 4),
              Text(
                crop,
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    AppStrings.isHindi ? 'विश्वास:' : 'Confidence:',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: confidence / 100,
                        backgroundColor: Colors.white24,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getConfidenceColor(confidence),
                        ),
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _getConfidenceColor(confidence).withOpacity(0.25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${confidence.toStringAsFixed(1)}%',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Input summary card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('📋', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(
                    AppStrings.isHindi ? 'इनपुट सारांश' : 'Input Summary',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.darkGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildInputSummaryRow(
                AppStrings.isHindi ? 'जिला' : 'District',
                _selectedDistrict,
              ),
              _buildInputSummaryRow(
                AppStrings.isHindi ? 'मिट्टी का रंग' : 'Soil Color',
                _selectedSoilColor,
              ),
              _buildInputSummaryRow(
                'NPK',
                'N=${_nitrogen.toStringAsFixed(0)}, P=${_phosphorus.toStringAsFixed(0)}, K=${_potassium.toStringAsFixed(0)}',
              ),
              _buildInputSummaryRow('pH', _ph.toStringAsFixed(1)),
              _buildInputSummaryRow(
                AppStrings.isHindi ? 'वर्षा' : 'Rainfall',
                '${_rainfall.toStringAsFixed(0)} mm',
              ),
              _buildInputSummaryRow(
                AppStrings.isHindi ? 'तापमान' : 'Temperature',
                '${_temperature.toStringAsFixed(1)}°C',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInputSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
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
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryGreen,
            ),
          ),
        ],
      ),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 80) return Colors.greenAccent;
    if (confidence >= 60) return Colors.orange;
    return AppTheme.alertRed;
  }
}
