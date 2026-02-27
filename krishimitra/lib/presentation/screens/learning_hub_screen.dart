import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:krishimitra/presentation/providers/app_providers.dart';
import 'package:krishimitra/utils/env_config.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Learning Hub Screen — Government schemes, farming knowledge, finance
// ═══════════════════════════════════════════════════════════════════════════
class LearningHubScreen extends ConsumerStatefulWidget {
  const LearningHubScreen({super.key});

  @override
  ConsumerState<LearningHubScreen> createState() => _LearningHubScreenState();
}

class _LearningHubScreenState extends ConsumerState<LearningHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Category data
  List<_SchemeCard> _govSchemes = [];
  List<_SchemeCard> _farmingTips = [];
  List<_SchemeCard> _financeSchemes = [];

  bool _isLoading = true;
  String? _error;
  String _selectedState = 'All India';

  final _states = [
    'All India',
    'Andhra Pradesh',
    'Assam',
    'Bihar',
    'Chhattisgarh',
    'Gujarat',
    'Haryana',
    'Himachal Pradesh',
    'Jharkhand',
    'Karnataka',
    'Kerala',
    'Madhya Pradesh',
    'Maharashtra',
    'Odisha',
    'Punjab',
    'Rajasthan',
    'Tamil Nadu',
    'Telangana',
    'Uttar Pradesh',
    'West Bengal',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadContent();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadContent() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _fetchGovSchemes(),
        _fetchFarmingTips(),
        _fetchFinanceSchemes(),
      ]);
      setState(() {
        _govSchemes = results[0];
        _farmingTips = results[1];
        _financeSchemes = results[2];
        _isLoading = false;
      });
    } catch (e) {
      // Fallback to built-in content
      setState(() {
        _govSchemes = _defaultGovSchemes();
        _farmingTips = _defaultFarmingTips();
        _financeSchemes = _defaultFinanceSchemes();
        _isLoading = false;
      });
    }
  }

  Future<List<_SchemeCard>> _fetchGovSchemes() async {
    try {
      final prompt = '''
List 8 current Indian government agricultural schemes${_selectedState != 'All India' ? ' available in $_selectedState' : ''}.
For each scheme provide EXACTLY this JSON format (array of objects):
[{
  "title": "scheme name",
  "description": "2-line description of benefits",
  "eligibility": "who can apply",
  "benefit": "amount or key benefit",
  "icon": "one of: agriculture, money, water, insurance, technology, organic, solar, storage"
}]
Only return the JSON array, no other text.''';
      final data = await _callGemini(prompt);
      if (data != null) {
        final list = jsonDecode(data) as List;
        return list
            .map(
              (e) => _SchemeCard(
                title: e['title'] ?? '',
                description: e['description'] ?? '',
                extra: e['eligibility'] ?? '',
                benefit: e['benefit'] ?? '',
                iconName: e['icon'] ?? 'agriculture',
                category: _Category.government,
              ),
            )
            .toList();
      }
    } catch (_) {}
    return _defaultGovSchemes();
  }

  Future<List<_SchemeCard>> _fetchFarmingTips() async {
    try {
      final prompt = '''
List 8 practical modern farming techniques and knowledge tips for Indian farmers.
For each provide EXACTLY this JSON format (array of objects):
[{
  "title": "technique/tip name",
  "description": "2-line explanation of the technique",
  "steps": "key steps to implement",
  "benefit": "expected improvement",
  "icon": "one of: crop_rotation, drip_irrigation, organic, soil_testing, pest_management, seed_selection, weather, harvest"
}]
Only return the JSON array, no other text.''';
      final data = await _callGemini(prompt);
      if (data != null) {
        final list = jsonDecode(data) as List;
        return list
            .map(
              (e) => _SchemeCard(
                title: e['title'] ?? '',
                description: e['description'] ?? '',
                extra: e['steps'] ?? '',
                benefit: e['benefit'] ?? '',
                iconName: e['icon'] ?? 'crop_rotation',
                category: _Category.farming,
              ),
            )
            .toList();
      }
    } catch (_) {}
    return _defaultFarmingTips();
  }

  Future<List<_SchemeCard>> _fetchFinanceSchemes() async {
    try {
      final prompt = '''
List 8 agricultural finance and loan schemes available to Indian farmers including bank loans, subsidies, and insurance.
For each provide EXACTLY this JSON format (array of objects):
[{
  "title": "scheme name",
  "description": "2-line description",
  "eligibility": "who can apply",
  "benefit": "interest rate or key financial benefit",
  "icon": "one of: loan, insurance, subsidy, credit_card, savings, investment, market, export"
}]
Only return the JSON array, no other text.''';
      final data = await _callGemini(prompt);
      if (data != null) {
        final list = jsonDecode(data) as List;
        return list
            .map(
              (e) => _SchemeCard(
                title: e['title'] ?? '',
                description: e['description'] ?? '',
                extra: e['eligibility'] ?? '',
                benefit: e['benefit'] ?? '',
                iconName: e['icon'] ?? 'loan',
                category: _Category.finance,
              ),
            )
            .toList();
      }
    } catch (_) {}
    return _defaultFinanceSchemes();
  }

  Future<String?> _callGemini(String prompt) async {
    final apiKey = EnvConfig.geminiApiKey;
    const url =
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

    final response = await http
        .post(
          Uri.parse('$url?key=$apiKey'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': prompt},
                ],
              },
            ],
            'generationConfig': {'temperature': 0.3, 'maxOutputTokens': 4096},
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final text =
          json['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
      if (text != null) {
        // Strip markdown code fences if present
        final cleaned =
            text
                .replaceAll(RegExp(r'```json\s*'), '')
                .replaceAll(RegExp(r'```\s*'), '')
                .trim();
        return cleaned;
      }
    }
    return null;
  }

  // ── Default content (offline fallback) ───────────────────────────────

  List<_SchemeCard> _defaultGovSchemes() => [
    _SchemeCard(
      title: 'PM-KISAN',
      description:
          'Direct income support of ₹6,000/year in 3 instalments to all land-holding farmer families.',
      extra: 'All farmer families with cultivable land',
      benefit: '₹6,000 per year',
      iconName: 'money',
      category: _Category.government,
    ),
    _SchemeCard(
      title: 'PM Fasal Bima Yojana',
      description:
          'Crop insurance scheme providing financial support against crop loss due to natural calamities.',
      extra: 'All farmers growing notified crops',
      benefit: 'Premium: 2% Kharif, 1.5% Rabi',
      iconName: 'insurance',
      category: _Category.government,
    ),
    _SchemeCard(
      title: 'Soil Health Card Scheme',
      description:
          'Free soil testing and nutrient-based recommendations for every farm plot across India.',
      extra: 'All farmers',
      benefit: 'Free soil analysis + recommendations',
      iconName: 'agriculture',
      category: _Category.government,
    ),
    _SchemeCard(
      title: 'Kisan Credit Card (KCC)',
      description:
          'Affordable short-term credit for crop production, post-harvest needs, and consumption.',
      extra: 'Farmers, fishermen, animal husbandry',
      benefit: '4% interest (with subvention)',
      iconName: 'money',
      category: _Category.government,
    ),
    _SchemeCard(
      title: 'PM Krishi Sinchai Yojana',
      description:
          'Promotes efficient water use with micro-irrigation — drip and sprinkler systems.',
      extra: 'All farmers',
      benefit: 'Up to 55% subsidy on micro-irrigation',
      iconName: 'water',
      category: _Category.government,
    ),
    _SchemeCard(
      title: 'e-NAM',
      description:
          'Online trading platform for agricultural commodities providing better price discovery.',
      extra: 'Farmers, traders, buyers',
      benefit: 'Transparent pricing + wider market access',
      iconName: 'technology',
      category: _Category.government,
    ),
    _SchemeCard(
      title: 'Paramparagat Krishi Vikas Yojana',
      description:
          'Supports organic farming through cluster-based adoption and certification.',
      extra: 'Farmer groups (min 50 farmers)',
      benefit: '₹50,000/ha over 3 years',
      iconName: 'organic',
      category: _Category.government,
    ),
    _SchemeCard(
      title: 'PM-KUSUM',
      description:
          'Solar energy scheme for farmers — solar pumps and grid-connected solar plants.',
      extra: 'All farmers',
      benefit: 'Up to 60% subsidy on solar pumps',
      iconName: 'solar',
      category: _Category.government,
    ),
  ];

  List<_SchemeCard> _defaultFarmingTips() => [
    _SchemeCard(
      title: 'Crop Rotation',
      description:
          'Alternate between cereals and legumes to maintain soil fertility and break pest cycles.',
      extra: 'Plan: Wheat → Moong → Rice → Mustard',
      benefit: '15-25% yield improvement',
      iconName: 'crop_rotation',
      category: _Category.farming,
    ),
    _SchemeCard(
      title: 'Drip Irrigation',
      description:
          'Deliver water directly to plant roots — saves 30-50% water with better crop growth.',
      extra: 'Install lateral pipes + emitters at root zone',
      benefit: '30-50% water savings',
      iconName: 'drip_irrigation',
      category: _Category.farming,
    ),
    _SchemeCard(
      title: 'Integrated Pest Management',
      description:
          'Combine biological, cultural, and chemical methods to manage pests sustainably.',
      extra: 'Monitor → Identify → Act threshold-based',
      benefit: '40-60% reduction in pesticide use',
      iconName: 'pest_management',
      category: _Category.farming,
    ),
    _SchemeCard(
      title: 'Soil Testing',
      description:
          'Test soil every 2-3 years for NPK, pH, and micronutrients to optimize fertilizer use.',
      extra: 'Collect samples → Lab analysis → Follow plan',
      benefit: '20-30% savings on fertilizers',
      iconName: 'soil_testing',
      category: _Category.farming,
    ),
    _SchemeCard(
      title: 'Quality Seed Selection',
      description:
          'Use certified, disease-resistant varieties suited to your region and season.',
      extra: 'Buy from ICAR/SAU approved dealers',
      benefit: '10-20% higher yield',
      iconName: 'seed_selection',
      category: _Category.farming,
    ),
    _SchemeCard(
      title: 'Vermicomposting',
      description:
          'Convert farm waste into nutrient-rich organic compost using earthworms.',
      extra: 'Set up bed → Add waste → Harvest in 60 days',
      benefit: 'Reduce chemical fertilizer by 50%',
      iconName: 'organic',
      category: _Category.farming,
    ),
    _SchemeCard(
      title: 'Weather-Based Farming',
      description:
          'Use weather forecasts to time sowing, irrigation, and harvesting decisions.',
      extra: 'Check IMD/Meghdoot app daily',
      benefit: 'Reduce crop losses by 15-30%',
      iconName: 'weather',
      category: _Category.farming,
    ),
    _SchemeCard(
      title: 'Post-Harvest Management',
      description:
          'Proper drying, grading, and storage to reduce post-harvest losses from 20% to under 5%.',
      extra: 'Dry → Clean → Grade → Hermetic storage',
      benefit: '15-20% higher income from same crop',
      iconName: 'harvest',
      category: _Category.farming,
    ),
  ];

  List<_SchemeCard> _defaultFinanceSchemes() => [
    _SchemeCard(
      title: 'Kisan Credit Card Loan',
      description:
          'Short-term crop loan up to ₹3 lakh at 4% interest with timely repayment.',
      extra: 'All farmers with land records',
      benefit: '4% interest (7% - 3% subvention)',
      iconName: 'loan',
      category: _Category.finance,
    ),
    _SchemeCard(
      title: 'Agri Infrastructure Fund',
      description:
          'Long-term loans for post-harvest infrastructure — cold storage, warehouses, processing units.',
      extra: 'Farmers, FPOs, agri-startups',
      benefit: '3% interest subvention, up to ₹2 Cr',
      iconName: 'investment',
      category: _Category.finance,
    ),
    _SchemeCard(
      title: 'NABARD Refinance',
      description:
          'Refinance support through cooperative banks for seasonal and term agricultural loans.',
      extra: 'Through cooperative / RRBs',
      benefit: 'Low interest term loans',
      iconName: 'loan',
      category: _Category.finance,
    ),
    _SchemeCard(
      title: 'PM-AASHA',
      description:
          'Price support scheme ensuring farmers get MSP for their produce through procurement.',
      extra: 'Farmers growing notified crops',
      benefit: 'Guaranteed MSP procurement',
      iconName: 'market',
      category: _Category.finance,
    ),
    _SchemeCard(
      title: 'SHG Bank Linkage',
      description:
          'Self-help group financing for small and marginal farmers through group micro-loans.',
      extra: 'SHG members (primarily women)',
      benefit: 'Collateral-free group loans',
      iconName: 'savings',
      category: _Category.finance,
    ),
    _SchemeCard(
      title: 'Agri Export Zones',
      description:
          'Financial incentives and support for farmers producing export-quality agri products.',
      extra: 'Farmers in designated export zones',
      benefit: 'Export subsidies + infrastructure',
      iconName: 'export',
      category: _Category.finance,
    ),
    _SchemeCard(
      title: 'PM Kisan MaanDhan',
      description:
          'Pension scheme for small and marginal farmers — ₹3,000/month after age 60.',
      extra: 'Farmers aged 18-40, land < 2 hectares',
      benefit: '₹3,000/month pension',
      iconName: 'savings',
      category: _Category.finance,
    ),
    _SchemeCard(
      title: 'Weather-Based Crop Insurance',
      description:
          'Automatic payout if weather deviates from threshold — no need to file damage claims.',
      extra: 'All farmers in covered districts',
      benefit: 'Automatic payout on weather trigger',
      iconName: 'insurance',
      category: _Category.finance,
    ),
  ];

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isHindi = ref.watch(languageProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(isHindi),
            _buildTabs(isHindi),
            Expanded(
              child:
                  _isLoading
                      ? _buildLoading()
                      : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildSchemeList(_govSchemes, isHindi),
                          _buildSchemeList(_farmingTips, isHindi),
                          _buildSchemeList(_financeSchemes, isHindi),
                        ],
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isHindi) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
            iconSize: 20,
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1B5E20), Color(0xFF388E3C)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isHindi ? 'सीखें और जानें' : 'Learn & Grow',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
                Text(
                  isHindi
                      ? 'सरकारी योजनाएं • खेती ज्ञान • वित्त'
                      : 'Govt Schemes • Farming • Finance',
                  style: GoogleFonts.poppins(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // State filter
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list_rounded, color: Colors.white70),
            color: const Color(0xFF1A2A40),
            onSelected: (state) {
              setState(() => _selectedState = state);
              _loadContent();
            },
            itemBuilder:
                (_) =>
                    _states
                        .map(
                          (s) => PopupMenuItem(
                            value: s,
                            child: Row(
                              children: [
                                if (s == _selectedState)
                                  const Icon(
                                    Icons.check,
                                    color: Color(0xFF4CAF50),
                                    size: 18,
                                  )
                                else
                                  const SizedBox(width: 18),
                                const SizedBox(width: 8),
                                Text(
                                  s,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(bool isHindi) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1B5E20), Color(0xFF388E3C)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        labelStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(fontSize: 12),
        dividerColor: Colors.transparent,
        tabs: [
          Tab(
            icon: const Icon(Icons.account_balance_rounded, size: 18),
            text: isHindi ? 'सरकारी' : 'Govt',
          ),
          Tab(
            icon: const Icon(Icons.eco_rounded, size: 18),
            text: isHindi ? 'खेती' : 'Farming',
          ),
          Tab(
            icon: const Icon(Icons.account_balance_wallet_rounded, size: 18),
            text: isHindi ? 'वित्त' : 'Finance',
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Color(0xFF4CAF50)),
          SizedBox(height: 16),
          Text('Loading schemes...', style: TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }

  Widget _buildSchemeList(List<_SchemeCard> schemes, bool isHindi) {
    if (schemes.isEmpty) {
      return Center(
        child: Text(
          isHindi ? 'कोई योजना उपलब्ध नहीं' : 'No schemes available',
          style: GoogleFonts.poppins(color: Colors.white54, fontSize: 14),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: schemes.length,
      itemBuilder: (ctx, i) => _buildCardTile(schemes[i], isHindi),
    );
  }

  Widget _buildCardTile(_SchemeCard card, bool isHindi) {
    final colors = _categoryColors(card.category);
    final icon = _iconForName(card.iconName);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.$1.withOpacity(0.25)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [colors.$1, colors.$2]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          title: Text(
            card.title,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          subtitle: Text(
            card.description,
            style: GoogleFonts.poppins(
              color: Colors.white60,
              fontSize: 12,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          iconColor: Colors.white54,
          collapsedIconColor: Colors.white38,
          children: [
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 12),
            // Benefit chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colors.$1.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.star_rounded, color: colors.$1, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      card.benefit,
                      style: GoogleFonts.poppins(
                        color: colors.$1,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (card.extra.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: Colors.white38,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      card.extra,
                      style: GoogleFonts.poppins(
                        color: Colors.white54,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  (Color, Color) _categoryColors(_Category cat) {
    switch (cat) {
      case _Category.government:
        return (const Color(0xFF1B5E20), const Color(0xFF388E3C));
      case _Category.farming:
        return (const Color(0xFF00695C), const Color(0xFF26A69A));
      case _Category.finance:
        return (const Color(0xFFE65100), const Color(0xFFFFA726));
    }
  }

  IconData _iconForName(String name) {
    switch (name) {
      case 'agriculture':
        return Icons.agriculture_rounded;
      case 'money':
        return Icons.currency_rupee_rounded;
      case 'water':
        return Icons.water_drop_rounded;
      case 'insurance':
        return Icons.shield_rounded;
      case 'technology':
        return Icons.devices_rounded;
      case 'organic':
        return Icons.eco_rounded;
      case 'solar':
        return Icons.solar_power_rounded;
      case 'storage':
        return Icons.warehouse_rounded;
      case 'crop_rotation':
        return Icons.rotate_right_rounded;
      case 'drip_irrigation':
        return Icons.water_drop_outlined;
      case 'pest_management':
        return Icons.bug_report_rounded;
      case 'soil_testing':
        return Icons.science_rounded;
      case 'seed_selection':
        return Icons.grass_rounded;
      case 'weather':
        return Icons.wb_sunny_rounded;
      case 'harvest':
        return Icons.inventory_2_rounded;
      case 'loan':
        return Icons.account_balance_rounded;
      case 'investment':
        return Icons.trending_up_rounded;
      case 'credit_card':
        return Icons.credit_card_rounded;
      case 'savings':
        return Icons.savings_rounded;
      case 'market':
        return Icons.storefront_rounded;
      case 'export':
        return Icons.local_shipping_rounded;
      case 'subsidy':
        return Icons.redeem_rounded;
      default:
        return Icons.info_rounded;
    }
  }
}

// ── Data models ──────────────────────────────────────────────────────────

enum _Category { government, farming, finance }

class _SchemeCard {
  final String title;
  final String description;
  final String extra;
  final String benefit;
  final String iconName;
  final _Category category;

  const _SchemeCard({
    required this.title,
    required this.description,
    required this.extra,
    required this.benefit,
    required this.iconName,
    required this.category,
  });
}
