import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:krishimitra/presentation/widgets/dashboard_widgets.dart'
    show FarmHealthScore;
import 'package:krishimitra/presentation/providers/app_providers.dart';
import 'package:krishimitra/presentation/screens/farm_sector_map_screen.dart';
import 'package:krishimitra/presentation/screens/farm_list_screen.dart';
import 'package:krishimitra/presentation/screens/market_intelligence_screen.dart';
import 'package:krishimitra/presentation/screens/ai_advisor_screen.dart';
import 'package:krishimitra/presentation/widgets/saved_farms_widget.dart';
import 'package:krishimitra/utils/app_strings.dart'
    show AppStrings, AppLanguage;
import 'package:krishimitra/utils/app_theme.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weatherAsync = ref.watch(weatherProvider);
    final farmHealth = ref.watch(farmHealthScoreProvider);
    final isHindi = ref.watch(languageProvider);
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, dd MMM yyyy').format(now);

    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ══ HEADER with Weather ════════════════════════════════════════
            _DashboardHeader(
              dateStr: dateStr,
              isHindi: isHindi,
              ref: ref,
              weatherAsync: weatherAsync,
              context: context,
            ),

            const SizedBox(height: 20),

            // ══ MY FIELDS - Map section ════════════════════════════════════
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _SectionTitle(title: isHindi ? 'मेरे खेत' : 'My Fields'),
                  TextButton.icon(
                    onPressed:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const FarmListScreen(),
                          ),
                        ),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: Text(
                      isHindi ? 'सभी देखें' : 'See all',
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primaryGreen,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Map card
            Container(
              height: 240,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryGreen.withOpacity(0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    FlutterMap(
                      options: const MapOptions(
                        initialCenter: LatLng(20.5937, 78.9629),
                        initialZoom: 5.0,
                        interactionOptions: InteractionOptions(
                          flags:
                              InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.krishimitra.app',
                        ),
                      ],
                    ),
                    // Overlay with tap action
                    Positioned.fill(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap:
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const FarmSectorMapScreen(),
                                ),
                              ),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.3),
                                ],
                              ),
                            ),
                            alignment: Alignment.bottomCenter,
                            padding: const EdgeInsets.all(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.map_rounded,
                                    color: AppTheme.primaryGreen,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isHindi
                                        ? 'पूरा नक्शा देखें'
                                        : 'View Full Map',
                                    style: GoogleFonts.poppins(
                                      color: AppTheme.darkGreen,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    color: AppTheme.primaryGreen,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            const SavedFarmsWidget(),

            const SizedBox(height: 36),

            // ══ PRIMARY ACTIONS - Large prominent buttons ══════════════════
            _SectionTitle(
              title: isHindi ? 'मुख्य सेवाएं' : 'Primary Services',
              subtitle: isHindi ? 'सबसे महत्वपूर्ण' : 'Most important',
              sectionPadding: const EdgeInsets.symmetric(horizontal: 24),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  // Crop Recommendation - LARGE
                  _LargePrimaryActionCard(
                    icon: Icons.agriculture_rounded,
                    title: isHindi ? 'फसल सिफारिश' : 'Crop Recommendation',
                    subtitle:
                        isHindi
                            ? 'मिट्टी और मौसम के आधार पर सर्वोत्तम फसल'
                            : 'Best crop based on soil & weather',
                    gradientColors: const [
                      Color(0xFF4CAF50),
                      Color(0xFF81C784),
                    ],
                    onTap:
                        () => Navigator.pushNamed(
                          context,
                          '/crop-recommendation',
                        ),
                  ),
                  const SizedBox(height: 16),

                  // AI Advisor - LARGE
                  _LargePrimaryActionCard(
                    icon: Icons.psychology_rounded,
                    title: isHindi ? 'AI सलाहकार' : 'AI Advisor',
                    subtitle:
                        isHindi
                            ? 'अपने खेती के सवालों का जवाब पाएं'
                            : 'Get answers to your farming questions',
                    gradientColors: const [
                      Color(0xFF7E57C2),
                      Color(0xFFAB47BC),
                    ],
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AIAdvisorScreen(),
                          ),
                        ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 36),

            // ══ FARM MANAGEMENT - Medium cards ═════════════════════════════
            _SectionTitle(
              title: isHindi ? 'खेत प्रबंधन' : 'Farm Management',
              subtitle: isHindi ? 'अपनी खेती को संभालें' : 'Manage your farm',
              sectionPadding: const EdgeInsets.symmetric(horizontal: 24),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _MediumActionCard(
                          icon: Icons.water_drop_rounded,
                          title: isHindi ? 'सिंचाई' : 'Irrigation',
                          gradientColors: const [
                            Color(0xFF2196F3),
                            Color(0xFF64B5F6),
                          ],
                          onTap:
                              () => Navigator.pushNamed(
                                context,
                                '/irrigation-prediction',
                              ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _MediumActionCard(
                          icon: Icons.sensors_rounded,
                          title: isHindi ? 'मिट्टी सेंसर' : 'Soil Sensor',
                          gradientColors: const [
                            Color(0xFF8D6E63),
                            Color(0xFFBCAAA4),
                          ],
                          onTap:
                              () => Navigator.pushNamed(
                                context,
                                '/soil-moisture',
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _MediumActionCard(
                          icon: Icons.calendar_today_rounded,
                          title: isHindi ? 'फसल कैलेंडर' : 'Task Calendar',
                          gradientColors: const [
                            Color(0xFFEF5350),
                            Color(0xFFE57373),
                          ],
                          onTap:
                              () => Navigator.pushNamed(
                                context,
                                '/task-calendar',
                              ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _MediumActionCard(
                          icon: Icons.map_rounded,
                          title: isHindi ? 'खेत नक्शा' : 'Farm Map',
                          gradientColors: const [
                            Color(0xFF00897B),
                            Color(0xFF4DB6AC),
                          ],
                          onTap:
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const FarmSectorMapScreen(),
                                ),
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 36),

            // ══ MARKETPLACE - Medium cards ═════════════════════════════════
            _SectionTitle(
              title: isHindi ? 'बाजार' : 'Marketplace',
              subtitle: isHindi ? 'खरीदें और बेचें' : 'Buy and sell',
              sectionPadding: const EdgeInsets.symmetric(horizontal: 24),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _MediumActionCard(
                          icon: Icons.shopping_basket_rounded,
                          title: isHindi ? 'मंडी भाव' : 'Mandi Prices',
                          gradientColors: const [
                            Color(0xFFF57C00),
                            Color(0xFFFFB74D),
                          ],
                          onTap:
                              () =>
                                  Navigator.pushNamed(context, '/mandi-prices'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _MediumActionCard(
                          icon: Icons.bar_chart_rounded,
                          title: isHindi ? 'बाजार विश्लेषण' : 'Market Intel',
                          gradientColors: const [
                            Color(0xFFFF6F00),
                            Color(0xFFFF9800),
                          ],
                          onTap:
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (_) => const MarketIntelligenceScreen(),
                                ),
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _MediumActionCard(
                          icon: Icons.precision_manufacturing_rounded,
                          title: isHindi ? 'उपकरण किराया' : 'Equipment',
                          gradientColors: const [
                            Color(0xFF5E35B1),
                            Color(0xFF9575CD),
                          ],
                          onTap:
                              () => Navigator.pushNamed(
                                context,
                                '/equipment-rental',
                              ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(child: Container()), // Empty space
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 36),

            // ══ Farm Health ════════════════════════════════════════════════
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: FarmHealthScore(score: farmHealth),
            ),

            const SizedBox(height: 100), // bottom nav padding
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Dashboard Header with improved color scheme
// ══════════════════════════════════════════════════════════════════════════════
class _DashboardHeader extends StatelessWidget {
  final String dateStr;
  final bool isHindi;
  final WidgetRef ref;
  final AsyncValue weatherAsync;
  final BuildContext context;

  const _DashboardHeader({
    required this.dateStr,
    required this.isHindi,
    required this.ref,
    required this.weatherAsync,
    required this.context,
  });

  @override
  Widget build(BuildContext ctx) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.primaryGreen.withOpacity(0.08), AppTheme.lightBg],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top row: greeting + language + refresh ────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isHindi
                              ? 'नमस्तते, किसान भाई 🌾'
                              : 'Hello, Farmer 🌾',
                          style: GoogleFonts.poppins(
                            color: AppTheme.darkGreen,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 15,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              dateStr,
                              style: GoogleFonts.poppins(
                                color: Colors.grey[600],
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      // Language toggle
                      GestureDetector(
                        onTap: () {
                          // Cycle: English → Hindi → Marathi → English
                          final current = AppStrings.language;
                          AppLanguage next;
                          switch (current) {
                            case AppLanguage.english:
                              next = AppLanguage.hindi;
                              break;
                            case AppLanguage.hindi:
                              next = AppLanguage.marathi;
                              break;
                            case AppLanguage.marathi:
                              next = AppLanguage.english;
                              break;
                          }
                          AppStrings.setLanguage(next);
                          ref.read(languageProvider.notifier).state =
                              next == AppLanguage.hindi;
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.primaryGreen.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            isHindi ? 'EN' : 'हिं',
                            style: GoogleFonts.poppins(
                              color: AppTheme.darkGreen,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Refresh
                      GestureDetector(
                        onTap: () => ref.invalidate(weatherProvider),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.primaryGreen.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            Icons.refresh_rounded,
                            color: AppTheme.darkGreen,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── Weather section ────────────────────────────────────────────
              weatherAsync.when(
                data:
                    (weather) =>
                        _WeatherInHeader(weather: weather, isHindi: isHindi),
                loading:
                    () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryGreen,
                          strokeWidth: 3,
                        ),
                      ),
                    ),
                error:
                    (e, _) => Text(
                      isHindi ? 'मौसम अनुपलब्ध' : 'Weather unavailable',
                      style: GoogleFonts.poppins(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Weather display inside header
// ══════════════════════════════════════════════════════════════════════════════
class _WeatherInHeader extends StatelessWidget {
  final dynamic weather;
  final bool isHindi;

  const _WeatherInHeader({required this.weather, required this.isHindi});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryGreen.withOpacity(0.65),
                AppTheme.mediumGreen.withOpacity(0.55),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryGreen.withOpacity(0.15),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Location + Big temp row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.location_on_rounded,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        weather.locationName ?? 'Your Farm',
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${weather.temperature.toStringAsFixed(0)}',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 64,
                                fontWeight: FontWeight.w800,
                                height: 1.0,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                '°C',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w600,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          weather.condition,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(weather.emoji, style: const TextStyle(fontSize: 80)),
                ],
              ),

              const SizedBox(height: 24),
              Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.1),
                      Colors.white.withOpacity(0.4),
                      Colors.white.withOpacity(0.1),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Stats row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _WeatherStat(
                    icon: Icons.water_drop_rounded,
                    label: isHindi ? 'नमी' : 'Humidity',
                    value: '${weather.humidity?.toStringAsFixed(0) ?? '60'}%',
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.white.withOpacity(0.3),
                  ),
                  _WeatherStat(
                    icon: Icons.air_rounded,
                    label: isHindi ? 'हवा' : 'Wind',
                    value:
                        '${weather.windSpeed?.toStringAsFixed(0) ?? '6'} m/s',
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.white.withOpacity(0.3),
                  ),
                  _WeatherStat(
                    icon: Icons.grain_rounded,
                    label: isHindi ? 'वर्षा' : 'Rain',
                    value: '${weather.precipitation.toStringAsFixed(0)} mm',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeatherStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _WeatherStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white.withOpacity(0.95),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// LARGE Primary Action Card - For most important features
// ══════════════════════════════════════════════════════════════════════════════
class _LargePrimaryActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const _LargePrimaryActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    gradientColors.first.withOpacity(0.8),
                    gradientColors.last.withOpacity(0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: gradientColors.first.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.4),
                              width: 1,
                            ),
                          ),
                          child: Icon(icon, color: Colors.white, size: 36),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            style: GoogleFonts.poppins(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// MEDIUM Action Card - For secondary features
// ══════════════════════════════════════════════════════════════════════════════
class _MediumActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const _MediumActionCard({
    required this.icon,
    required this.title,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              height: 130,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    gradientColors.first.withOpacity(0.75),
                    gradientColors.last.withOpacity(0.65),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: gradientColors.first.withOpacity(0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.4),
                            width: 1,
                          ),
                        ),
                        child: Icon(icon, color: Colors.white, size: 28),
                      ),
                    ),
                  ),
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ══ Section title ══════════════════════════════════════════════════════════════
class _SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final EdgeInsetsGeometry sectionPadding;

  const _SectionTitle({
    required this.title,
    this.subtitle,
    this.sectionPadding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: sectionPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.darkGreen,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
