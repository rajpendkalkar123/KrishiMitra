import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:krishimitra/services/gemini_service.dart';
import 'package:krishimitra/services/farm_database_service.dart';
import 'package:krishimitra/domain/models/farm_models.dart';
import 'package:krishimitra/utils/app_strings.dart';
import 'package:krishimitra/utils/app_theme.dart';
import 'package:krishimitra/presentation/providers/app_providers.dart';

class AIAdvisorScreen extends ConsumerStatefulWidget {
  const AIAdvisorScreen({super.key});

  @override
  ConsumerState<AIAdvisorScreen> createState() => _AIAdvisorScreenState();
}

class _AIAdvisorScreenState extends ConsumerState<AIAdvisorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Farm/Sector selection
  List<Sector> _savedSectors = [];
  Sector? _selectedSector;

  // Input values
  String _selectedCrop = 'Wheat';
  String _selectedGrowthStage = 'Vegetative';
  final String _selectedSoilType = 'Black Soil';
  double _soilMoisture = 45.0;
  double _nitrogen = 40.0;
  double _phosphorus = 30.0;
  double _potassium = 25.0;
  double _pH = 6.5;
  double _temperature = 28.0;
  double _rainfall = 15.0;
  double _farmArea = 2.5;

  bool _isLoading = false;
  FarmingRecommendation? _recommendation;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSavedFarms();
  }

  Future<void> _loadSavedFarms() async {
    try {
      final sectors = await FarmDatabaseService.getAllSectors();
      setState(() {
        _savedSectors = sectors;
      });
    } catch (e) {
      print('Error loading sectors: $e');
    }
  }

  void _loadFarmData(Sector sector) {
    setState(() {
      _selectedSector = sector;
      _selectedCrop = sector.cropType;
      _selectedGrowthStage = sector.growthStage ?? 'Vegetative';
      _farmArea = sector.area;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _getRecommendation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final recommendation = await GeminiService.getFarmingRecommendation(
        cropType: _selectedCrop,
        soilMoisture: _soilMoisture,
        nitrogen: _nitrogen,
        phosphorus: _phosphorus,
        potassium: _potassium,
        pH: _pH,
        temperature: _temperature,
        rainfall: _rainfall,
        farmArea: _farmArea,
        growthStage: _selectedGrowthStage,
        soilType: _selectedSoilType,
      );

      setState(() {
        _recommendation = recommendation;
        _isLoading = false;
      });

      // Switch to results tab
      _tabController.animateTo(1);
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to get recommendation: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch language changes to rebuild UI
    final isHindi = ref.watch(languageProvider);

    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      body: NestedScrollView(
        headerSliverBuilder:
            (context, innerBoxIsScrolled) => [
              SliverAppBar(
                expandedHeight: 160,
                pinned: true,
                backgroundColor: AppTheme.lightBg,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back, color: AppTheme.darkGreen),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF7E57C2),
                          const Color(0xFFAB47BC),
                        ],
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(60, 48, 20, 16),
                        child: Row(
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.psychology,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    isHindi
                                        ? '🤖 AI कृषि सलाहकार'
                                        : '🤖 AI Farm Advisor',
                                    style: GoogleFonts.poppins(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    isHindi
                                        ? 'AI-संचालित सिफारिशें'
                                        : 'AI-Powered Insights',
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
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(60),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF7E57C2).withOpacity(0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicator: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7E57C2), Color(0xFFAB47BC)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        labelStyle: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        unselectedLabelStyle: GoogleFonts.poppins(fontSize: 13),
                        labelColor: Colors.white,
                        unselectedLabelColor: const Color(0xFF7E57C2),
                        tabs: [
                          Tab(
                            text: AppStrings.isHindi ? '📝 डेटा' : '📝 Input',
                            height: 44,
                          ),
                          Tab(
                            text:
                                AppStrings.isHindi
                                    ? '🎯 AI परिणाम'
                                    : '🎯 Results',
                            height: 44,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
        body: TabBarView(
          controller: _tabController,
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.only(top: 20, bottom: 100),
              child: _buildInputTab(),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.only(top: 20, bottom: 100),
              child: _buildResultsTab(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderCard(),
          const SizedBox(height: 16),

          // Farm Selector
          _buildFarmSelector(),
          const SizedBox(height: 16),

          _buildFarmAreaCard(),
          const SizedBox(height: 16),

          _buildSoilConditionsCard(),
          const SizedBox(height: 16),
          _buildNPKCard(),
          const SizedBox(height: 16),
          _buildEnvironmentCard(),
          const SizedBox(height: 24),
          _buildAnalyzeButton(),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  // NEW: Farm Selector Widget
  Widget _buildFarmSelector() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: AppTheme.primaryGreen, size: 24),
                const SizedBox(width: 8),
                Text(
                  AppStrings.isHindi
                      ? '🏠 अपना खेत चुनें'
                      : '🏠 Select Your Farm',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Farm/Sector Dropdown
            const Divider(),
            const SizedBox(height: 8),
            if (_savedSectors.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        AppStrings.isHindi
                            ? 'कोई सहेजा गया खेत नहीं मिला। कृपया पहले एक खेत बनाएं।'
                            : 'No saved farms found. Please create a farm first.',
                        style: TextStyle(color: Colors.orange[900]),
                      ),
                    ),
                  ],
                ),
              )
            else
              DropdownButtonFormField<Sector>(
                value: _selectedSector,
                decoration: InputDecoration(
                  labelText:
                      AppStrings.isHindi ? 'सेक्टर चुनें' : 'Select Sector',
                  prefixIcon: const Icon(Icons.map),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items:
                    _savedSectors.map((sector) {
                      return DropdownMenuItem(
                        value: sector,
                        child: Text(
                          '${sector.name} - ${sector.cropType} (${sector.area.toStringAsFixed(1)} acres)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                onChanged: (sector) {
                  if (sector != null) {
                    _loadFarmData(sector);
                  }
                },
              ),

            if (_selectedSector != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: AppTheme.primaryGreen,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          AppStrings.isHindi ? 'लोड किया गया:' : 'Loaded:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('📍 ${_selectedSector!.name}'),
                    Text('🌾 ${_selectedSector!.cropType}'),
                    Text(
                      '📏 ${_selectedSector!.area.toStringAsFixed(2)} acres',
                    ),
                    Text('🌱 ${_selectedSector!.growthStage}'),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryGreen,
            AppTheme.primaryGreen.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.psychology, color: Colors.white, size: 40),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.isHindi
                      ? 'Gemini AI द्वारा संचालित'
                      : 'Powered by Gemini AI',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppStrings.isHindi
                      ? 'अपनी फसल का डेटा दर्ज करें और AI से व्यक्तिगत सिफारिशें प्राप्त करें'
                      : 'Enter your crop data and get personalized AI recommendations',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFarmAreaCard() {
    return _buildCard(
      title: AppStrings.isHindi ? '📏 खेत का क्षेत्रफल' : '📏 Farm Area',
      children: [
        _buildSliderWithInput(
          label:
              AppStrings.isHindi
                  ? 'खेत का क्षेत्रफल (एकड़)'
                  : 'Farm Area (acres)',
          value: _farmArea,
          min: 0.5,
          max: 50.0,
          divisions: 99,
          unit: AppStrings.isHindi ? 'एकड़' : 'acres',
          onChanged: (value) => setState(() => _farmArea = value),
          icon: Icons.square_foot,
        ),
      ],
    );
  }

  Widget _buildSoilConditionsCard() {
    return _buildCard(
      title: AppStrings.isHindi ? '💧 मिट्टी की स्थिति' : '💧 Soil Conditions',
      children: [
        _buildSliderWithInput(
          label: AppStrings.isHindi ? 'मिट्टी की नमी' : 'Soil Moisture',
          value: _soilMoisture,
          min: 0,
          max: 100,
          divisions: 100,
          unit: '%',
          onChanged: (value) => setState(() => _soilMoisture = value),
          icon: Icons.water_drop,
          color: _getMoistureColor(_soilMoisture),
        ),
        const SizedBox(height: 16),
        _buildSliderWithInput(
          label: AppStrings.isHindi ? 'मिट्टी का pH' : 'Soil pH',
          value: _pH,
          min: 4.0,
          max: 9.0,
          divisions: 50,
          unit: 'pH',
          onChanged: (value) => setState(() => _pH = value),
          icon: Icons.science,
          color: _getPhColor(_pH),
        ),
      ],
    );
  }

  Widget _buildNPKCard() {
    return _buildCard(
      title:
          AppStrings.isHindi ? '🧪 NPK स्तर (kg/ha)' : '🧪 NPK Levels (kg/ha)',
      children: [
        _buildSliderWithInput(
          label: AppStrings.isHindi ? 'नाइट्रोजन (N)' : 'Nitrogen (N)',
          value: _nitrogen,
          min: 0,
          max: 150,
          divisions: 150,
          unit: 'kg/ha',
          onChanged: (value) => setState(() => _nitrogen = value),
          icon: Icons.grass,
          color: Colors.green,
        ),
        const SizedBox(height: 16),
        _buildSliderWithInput(
          label: AppStrings.isHindi ? 'फॉस्फोरस (P)' : 'Phosphorus (P)',
          value: _phosphorus,
          min: 0,
          max: 100,
          divisions: 100,
          unit: 'kg/ha',
          onChanged: (value) => setState(() => _phosphorus = value),
          icon: Icons.eco,
          color: Colors.orange,
        ),
        const SizedBox(height: 16),
        _buildSliderWithInput(
          label: AppStrings.isHindi ? 'पोटेशियम (K)' : 'Potassium (K)',
          value: _potassium,
          min: 0,
          max: 150,
          divisions: 150,
          unit: 'kg/ha',
          onChanged: (value) => setState(() => _potassium = value),
          icon: Icons.spa,
          color: Colors.purple,
        ),
      ],
    );
  }

  Widget _buildEnvironmentCard() {
    return _buildCard(
      title: AppStrings.isHindi ? '🌤️ पर्यावरण' : '🌤️ Environment',
      children: [
        _buildSliderWithInput(
          label: AppStrings.isHindi ? 'तापमान' : 'Temperature',
          value: _temperature,
          min: 10,
          max: 50,
          divisions: 40,
          unit: '°C',
          onChanged: (value) => setState(() => _temperature = value),
          icon: Icons.thermostat,
          color: _getTemperatureColor(_temperature),
        ),
        const SizedBox(height: 16),
        _buildSliderWithInput(
          label: AppStrings.isHindi ? 'साप्ताहिक वर्षा' : 'Weekly Rainfall',
          value: _rainfall,
          min: 0,
          max: 200,
          divisions: 200,
          unit: 'mm',
          onChanged: (value) => setState(() => _rainfall = value),
          icon: Icons.cloudy_snowing,
          color: Colors.blue,
        ),
      ],
    );
  }

  Widget _buildCard({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkBrown,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSliderWithInput({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String unit,
    required ValueChanged<double> onChanged,
    required IconData icon,
    Color? color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: color ?? AppTheme.primaryGreen, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: (color ?? AppTheme.primaryGreen).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${value.toStringAsFixed(1)} $unit',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color ?? AppTheme.primaryGreen,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color ?? AppTheme.primaryGreen,
            inactiveTrackColor: (color ?? AppTheme.primaryGreen).withOpacity(
              0.2,
            ),
            thumbColor: color ?? AppTheme.primaryGreen,
            overlayColor: (color ?? AppTheme.primaryGreen).withOpacity(0.2),
            valueIndicatorColor: color ?? AppTheme.primaryGreen,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: '${value.toStringAsFixed(1)} $unit',
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyzeButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _getRecommendation,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryGreen,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
        child:
            _isLoading
                ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'AI is analyzing...',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ],
                )
                : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.auto_awesome, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      AppStrings.isHindi
                          ? '🚀 AI सिफारिशें प्राप्त करें'
                          : '🚀 Get AI Recommendations',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
      ),
    );
  }

  Widget _buildResultsTab() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryGreen),
            SizedBox(height: 16),
            Text('AI is analyzing your farm data...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _getRecommendation,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_recommendation == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.agriculture, size: 100, color: Colors.grey[300]),
            const SizedBox(height: 24),
            Text(
              AppStrings.isHindi
                  ? 'पहले अपना डेटा दर्ज करें'
                  : 'Enter your farm data first',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _tabController.animateTo(0),
              child: Text(
                AppStrings.isHindi ? 'डेटा दर्ज करें →' : 'Enter Data →',
                style: const TextStyle(color: AppTheme.primaryGreen),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildAISourceIndicator(_recommendation!),
          const SizedBox(height: 16),
          _buildProfitComparisonCard(_recommendation!),
          const SizedBox(height: 16),
          _buildIrrigationCard(_recommendation!),
          const SizedBox(height: 16),
          _buildFertilizerCard(_recommendation!),
          const SizedBox(height: 16),
          _buildCostSavingsCard(_recommendation!),
          const SizedBox(height: 16),
          _buildWeeklyPlanCard(_recommendation!),
          const SizedBox(height: 16),
          _buildMarketTimingCard(_recommendation!),
          const SizedBox(height: 16),
          _buildHealthTipsCard(_recommendation!),
          const SizedBox(height: 16),
          _buildRiskAlertsCard(_recommendation!),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildAISourceIndicator(FarmingRecommendation rec) {
    final isFromAI = rec.isFromGeminiAI;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            isFromAI
                ? Colors.green.withOpacity(0.1)
                : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFromAI ? Colors.green : Colors.orange,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isFromAI ? Icons.cloud_done : Icons.offline_bolt,
            color: isFromAI ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isFromAI
                      ? (AppStrings.isHindi
                          ? '✨ Gemini AI से लाइव विश्लेषण'
                          : '✨ Live Analysis from Gemini AI')
                      : (AppStrings.isHindi
                          ? '📊 स्मार्ट फॉलबैक विश्लेषण'
                          : '📊 Smart Fallback Analysis'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isFromAI ? Colors.green[700] : Colors.orange[700],
                  ),
                ),
                Text(
                  isFromAI
                      ? (AppStrings.isHindi
                          ? 'आपके डेटा के आधार पर व्यक्तिगत AI सिफारिशें'
                          : 'Personalized AI recommendations based on your data')
                      : (AppStrings.isHindi
                          ? 'आपके इनपुट के आधार पर गणना की गई सिफारिशें'
                          : 'Calculated recommendations based on your inputs'),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfitComparisonCard(FarmingRecommendation rec) {
    final profit = rec.profitAnalysis;
    final yield = rec.expectedYield;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[700]!, Colors.green[500]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.trending_up, color: Colors.white, size: 28),
              const SizedBox(width: 8),
              Text(
                AppStrings.isHindi
                    ? '📈 AI से मुनाफा बढ़ोतरी'
                    : '📈 AI Profit Boost',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildComparisonColumn(
                  AppStrings.isHindi ? 'बिना AI' : 'Without AI',
                  '₹${profit.estimatedRevenueWithoutAI.toStringAsFixed(0)}',
                  '${yield.withoutAI} qt/acre',
                  Colors.white.withOpacity(0.7),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.arrow_forward, color: Colors.green),
                    Text(
                      '+${yield.improvementPercent.toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _buildComparisonColumn(
                  AppStrings.isHindi ? 'AI के साथ' : 'With AI',
                  '₹${profit.estimatedRevenueWithAI.toStringAsFixed(0)}',
                  '${yield.withAI} qt/acre',
                  Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  AppStrings.isHindi ? 'अतिरिक्त मुनाफा' : 'Additional Profit',
                  style: TextStyle(color: Colors.white.withOpacity(0.9)),
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${profit.additionalProfitWithAI.toStringAsFixed(0)}/acre',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  AppStrings.isHindi
                      ? 'कुल: ₹${(profit.additionalProfitWithAI * _farmArea).toStringAsFixed(0)} (${_farmArea.toStringAsFixed(1)} एकड़)'
                      : 'Total: ₹${(profit.additionalProfitWithAI * _farmArea).toStringAsFixed(0)} (${_farmArea.toStringAsFixed(1)} acres)',
                  style: TextStyle(color: Colors.white.withOpacity(0.9)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonColumn(
    String title,
    String value,
    String subtitle,
    Color color,
  ) {
    return Column(
      children: [
        Text(title, style: TextStyle(color: color, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          subtitle,
          style: TextStyle(color: color.withOpacity(0.8), fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildIrrigationCard(FarmingRecommendation rec) {
    final irrigation = rec.irrigationRecommendation;
    final actionColor =
        irrigation.action == 'START'
            ? Colors.blue
            : (irrigation.action == 'STOP' ? Colors.red : Colors.orange);

    return _buildResultCard(
      icon: Icons.water_drop,
      iconColor: Colors.blue,
      title:
          AppStrings.isHindi
              ? '💧 सिंचाई सिफारिश'
              : '💧 Irrigation Recommendation',
      children: [
        _buildActionChip(irrigation.action, actionColor),
        const SizedBox(height: 12),
        _buildInfoRow(
          Icons.water,
          'Amount',
          '${irrigation.waterAmount.toStringAsFixed(0)} L/acre',
        ),
        _buildInfoRow(Icons.schedule, 'Timing', irrigation.timing),
        _buildInfoRow(Icons.repeat, 'Frequency', irrigation.frequency),
        const Divider(height: 24),
        Text(
          irrigation.reason,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildFertilizerCard(FarmingRecommendation rec) {
    final fertilizer = rec.fertilizerRecommendation;

    return _buildResultCard(
      icon: Icons.science,
      iconColor: Colors.orange,
      title:
          AppStrings.isHindi
              ? '🧪 खाद सिफारिश'
              : '🧪 Fertilizer Recommendation',
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.eco, color: Colors.orange),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fertilizer.type,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${fertilizer.quantity.toStringAsFixed(0)} kg/acre',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildInfoRow(
          Icons.construction,
          'Method',
          fertilizer.applicationMethod,
        ),
        _buildInfoRow(Icons.schedule, 'Timing', fertilizer.timing),
        const Divider(height: 24),
        Text(
          fertilizer.reason,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildCostSavingsCard(FarmingRecommendation rec) {
    final savings = rec.profitAnalysis.costSavings;

    return _buildResultCard(
      icon: Icons.savings,
      iconColor: Colors.green,
      title: AppStrings.isHindi ? '💰 लागत बचत' : '💰 Cost Savings',
      children: [
        _buildSavingsBar('Water', savings.water, Colors.blue),
        const SizedBox(height: 12),
        _buildSavingsBar('Fertilizer', savings.fertilizer, Colors.orange),
        const Divider(height: 24),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppStrings.isHindi ? 'कुल बचत' : 'Total Savings',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '₹${savings.total.toStringAsFixed(0)}/acre',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSavingsBar(String label, double amount, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: LinearProgressIndicator(
            value: amount / 5000,
            backgroundColor: color.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '₹${amount.toStringAsFixed(0)}',
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildWeeklyPlanCard(FarmingRecommendation rec) {
    return _buildResultCard(
      icon: Icons.calendar_today,
      iconColor: Colors.purple,
      title:
          AppStrings.isHindi ? '📅 साप्ताहिक योजना' : '📅 Weekly Action Plan',
      children: [
        ...rec.weeklyActionPlan.map(
          (action) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    action.day,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.purple,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    action.action,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMarketTimingCard(FarmingRecommendation rec) {
    final market = rec.marketTiming;

    return _buildResultCard(
      icon: Icons.storefront,
      iconColor: Colors.teal,
      title: AppStrings.isHindi ? '🏪 बाजार समय' : '🏪 Market Timing',
      children: [
        _buildInfoRow(Icons.event, 'Harvest', market.optimalHarvestTime),
        _buildInfoRow(
          Icons.attach_money,
          'Expected Price',
          '₹${market.expectedMarketPrice.toStringAsFixed(0)}/qt',
        ),
        const Divider(height: 24),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.teal.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.lightbulb, color: Colors.teal),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  market.recommendation,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHealthTipsCard(FarmingRecommendation rec) {
    return _buildResultCard(
      icon: Icons.health_and_safety,
      iconColor: Colors.green,
      title:
          AppStrings.isHindi
              ? '🌱 फसल स्वास्थ्य युक्तियाँ'
              : '🌱 Crop Health Tips',
      children: [
        ...rec.cropHealthTips.asMap().entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${entry.key + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.green,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(entry.value)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRiskAlertsCard(FarmingRecommendation rec) {
    if (rec.riskAlerts.isEmpty) return const SizedBox.shrink();

    return _buildResultCard(
      icon: Icons.warning_amber,
      iconColor: Colors.red,
      title: AppStrings.isHindi ? '⚠️ जोखिम अलर्ट' : '⚠️ Risk Alerts',
      children: [
        ...rec.riskAlerts.map(
          (alert) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(alert, style: const TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildActionChip(String action, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            action == 'START'
                ? Icons.play_arrow
                : (action == 'STOP' ? Icons.stop : Icons.pause),
            color: color,
          ),
          const SizedBox(width: 8),
          Text(
            action,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text('$label: ', style: TextStyle(color: Colors.grey[600])),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // Helper color functions
  Color _getMoistureColor(double moisture) {
    if (moisture < 30) return Colors.red;
    if (moisture < 50) return Colors.orange;
    if (moisture < 70) return Colors.green;
    return Colors.blue;
  }

  Color _getPhColor(double ph) {
    if (ph < 5.5) return Colors.red;
    if (ph < 6.0) return Colors.orange;
    if (ph < 7.5) return Colors.green;
    return Colors.blue;
  }

  Color _getTemperatureColor(double temp) {
    if (temp < 15) return Colors.blue;
    if (temp < 25) return Colors.green;
    if (temp < 35) return Colors.orange;
    return Colors.red;
  }
}
