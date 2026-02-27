import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:krishimitra/presentation/screens/ai_advisor_screen.dart';
import 'package:krishimitra/presentation/providers/app_providers.dart';
import 'package:krishimitra/utils/app_theme.dart';
class MarketIntelligenceScreen extends ConsumerStatefulWidget {
  const MarketIntelligenceScreen({super.key});

  @override
  ConsumerState<MarketIntelligenceScreen> createState() =>
      _MarketIntelligenceScreenState();
}

class _MarketIntelligenceScreenState
    extends ConsumerState<MarketIntelligenceScreen> {
  String _selectedCrop = 'Wheat';
  bool _isLoading = false;
  final Map<String, CropMarketData> _marketData = {
    'Wheat': CropMarketData(
      cropName: 'Wheat',
      cropNameHindi: 'गेहूं',
      currentMarketPrice: 2500,
      expectedPrice: 2800,
      yourCropQuality: 75,
      marketDemand: 'High',
      marketDemandHindi: 'उच्च',
      profitPotential: 85,
      recommendations: [
        'Apply final irrigation before harvest',
        'Harvest when moisture is 12-14%',
        'Grade and clean before selling',
        'Wait 2-3 weeks for better prices',
      ],
      recommendationsHindi: [
        'कटाई से पहले अंतिम सिंचाई करें',
        'जब नमी 12-14% हो तब कटाई करें',
        'बेचने से पहले ग्रेडिंग और सफाई करें',
        'बेहतर कीमतों के लिए 2-3 सप्ताह प्रतीक्षा करें',
      ],
      qualityImprovements: [
        'Reduce moisture content to 12%',
        'Remove broken and shriveled grains',
        'Ensure uniform grain size',
        'Store in dry, pest-free environment',
      ],
      qualityImprovementsHindi: [
        'नमी को 12% तक कम करें',
        'टूटे और सिकुड़े दानों को निकालें',
        'समान दाने का आकार सुनिश्चित करें',
        'सूखे, कीट-मुक्त वातावरण में भंडारण करें',
      ],
      priceHistory: [2200, 2300, 2400, 2450, 2500],
      priceForecast: [2500, 2600, 2700, 2800, 2900],
    ),
    'Rice': CropMarketData(
      cropName: 'Rice',
      cropNameHindi: 'चावल',
      currentMarketPrice: 3200,
      expectedPrice: 3500,
      yourCropQuality: 80,
      marketDemand: 'Medium',
      marketDemandHindi: 'मध्यम',
      profitPotential: 78,
      recommendations: [
        'Dry to 13-14% moisture',
        'Remove impurities and broken rice',
        'Sell to mills directly',
        'Consider organic certification premium',
      ],
      recommendationsHindi: [
        '13-14% नमी तक सुखाएं',
        'अशुद्धियां और टूटे चावल निकालें',
        'सीधे मिलों को बेचें',
        'जैविक प्रमाणन प्रीमियम पर विचार करें',
      ],
      qualityImprovements: [
        'Maintain uniform paddy moisture',
        'Reduce broken percentage below 5%',
        'Improve grain length uniformity',
        'Proper storage to prevent yellowing',
      ],
      qualityImprovementsHindi: [
        'समान धान नमी बनाए रखें',
        'टूटे प्रतिशत को 5% से कम करें',
        'दाने की लंबाई में एकरूपता सुधारें',
        'पीलापन रोकने के लिए उचित भंडारण',
      ],
      priceHistory: [2800, 2900, 3000, 3100, 3200],
      priceForecast: [3200, 3300, 3400, 3500, 3600],
    ),
    'Sugarcane': CropMarketData(
      cropName: 'Sugarcane',
      cropNameHindi: 'गन्ना',
      currentMarketPrice: 350,
      expectedPrice: 380,
      yourCropQuality: 70,
      marketDemand: 'High',
      marketDemandHindi: 'उच्च',
      profitPotential: 82,
      recommendations: [
        'Harvest at optimal sucrose content',
        'Deliver to mill within 24 hours',
        'Negotiate for better payment terms',
        'Consider selling to jaggery units',
      ],
      recommendationsHindi: [
        'इष्टतम सुक्रोज सामग्री पर कटाई करें',
        '24 घंटे के भीतर मिल में पहुंचाएं',
        'बेहतर भुगतान शर्तों के लिए बातचीत करें',
        'गुड़ इकाइयों को बेचने पर विचार करें',
      ],
      qualityImprovements: [
        'Increase sucrose content (>10%)',
        'Reduce fiber and impurities',
        'Harvest at right maturity',
        'Proper trash management',
      ],
      qualityImprovementsHindi: [
        'सुक्रोज सामग्री बढ़ाएं (>10%)',
        'फाइबर और अशुद्धियां कम करें',
        'सही परिपक्वता पर कटाई करें',
        'उचित कचरा प्रबंधन',
      ],
      priceHistory: [320, 330, 340, 345, 350],
      priceForecast: [350, 360, 370, 380, 390],
    ),
  };

  @override
  Widget build(BuildContext context) {
    // Watch language changes to rebuild UI
    final isHindi = ref.watch(languageProvider);
    
    final data = _marketData[_selectedCrop]!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isHindi ? 'बाजार विश्लेषण' : 'Market Intelligence',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.psychology),
            tooltip: isHindi ? 'AI सलाहकार' : 'AI Advisor',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AIAdvisorScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              Future.delayed(const Duration(seconds: 1), () {
                setState(() => _isLoading = false);
              });
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AIAdvisorScreen(),
            ),
          );
        },
        backgroundColor: AppTheme.primaryGreen,
        icon: const Icon(Icons.auto_awesome, color: Colors.white),
        label: Text(
          isHindi ? 'AI सलाहकार' : 'AI Advisor',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildAIAdvisorBanner(isHindi),
                  _buildCropSelector(isHindi),
                  _buildPriceOverview(data, isHindi),
                  _buildQualityScore(data, isHindi),
                  _buildProfitPotential(data, isHindi),
                  _buildPriceChart(data, isHindi),
                  _buildRecommendations(data, isHindi),
                  _buildQualityImprovements(data, isHindi),
                  const SizedBox(height: 100),
                ],
              ),
            ),
    );
  }

  Widget _buildAIAdvisorBanner(bool isHindi) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AIAdvisorScreen(),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.purple[700]!, Colors.blue[600]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withOpacity(0.3),
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
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isHindi
                        ? '🤖 AI कृषि सलाहकार'
                        : '🤖 AI Farm Advisor',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isHindi
                        ? 'Gemini AI से व्यक्तिगत सिफारिशें प्राप्त करें और मुनाफा बढ़ाएं!'
                        : 'Get personalized recommendations from Gemini AI and boost profits!',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCropSelector(bool isHindi) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCrop,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: AppTheme.primaryGreen),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          items: _marketData.keys.map((crop) {
            final data = _marketData[crop]!;
            return DropdownMenuItem(
              value: crop,
              child: Row(
                children: [
                  const Icon(Icons.agriculture, color: AppTheme.primaryGreen),
                  const SizedBox(width: 12),
                  Text(
                    isHindi ? data.cropNameHindi : data.cropName,
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() => _selectedCrop = value!);
          },
        ),
      ),
    );
  }

  Widget _buildPriceOverview(CropMarketData data, bool isHindi) {
    final priceGap = data.expectedPrice - data.currentMarketPrice;
    final priceGapPercent = (priceGap / data.currentMarketPrice * 100);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryGreen, AppTheme.primaryGreen.withOpacity(0.8)],
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
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _buildPriceCard(
                  isHindi ? 'वर्तमान मूल्य' : 'Current Price',
                  '₹${data.currentMarketPrice}',
                  isHindi ? 'प्रति क्विंटल' : 'per quintal',
                  Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildPriceCard(
                  isHindi ? 'अपेक्षित मूल्य' : 'Expected Price',
                  '₹${data.expectedPrice}',
                  isHindi ? '2-3 सप्ताह में' : 'in 2-3 weeks',
                  Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  priceGap > 0 ? Icons.trending_up : Icons.trending_down,
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Text(
                  isHindi
                      ? '₹$priceGap (${priceGapPercent.toStringAsFixed(1)}%) लाभ की संभावना'
                      : '₹$priceGap (${priceGapPercent.toStringAsFixed(1)}%) Profit Potential',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceCard(String title, String value, String subtitle, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: textColor.withOpacity(0.9),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: textColor,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          subtitle,
          style: TextStyle(
            color: textColor.withOpacity(0.8),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildQualityScore(CropMarketData data, bool isHindi) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
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
              const Icon(Icons.star, color: Colors.amber, size: 28),
              const SizedBox(width: 8),
              Text(
                isHindi ? 'आपकी फसल की गुणवत्ता' : 'Your Crop Quality',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${data.yourCropQuality}%',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                    Text(
                      _getQualityLabel(data.yourCropQuality, isHindi),
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    _buildQualityBar(data.yourCropQuality),
                    const SizedBox(height: 8),
                    Text(
                      isHindi
                          ? '${100 - data.yourCropQuality}% सुधार से बाजार मूल्य तक पहुंचें'
                          : '${100 - data.yourCropQuality}% improvement to reach market price',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQualityBar(int quality) {
    Color color;
    if (quality >= 80) {
      color = Colors.green;
    } else if (quality >= 60) {
      color = Colors.orange;
    } else {
      color = Colors.red;
    }

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: quality / 100,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 20,
          ),
        ),
      ],
    );
  }

  String _getQualityLabel(int quality, bool isHindi) {
    if (isHindi) {
      if (quality >= 80) return 'उत्कृष्ट';
      if (quality >= 60) return 'अच्छा';
      return 'सुधार की आवश्यकता';
    } else {
      if (quality >= 80) return 'Excellent';
      if (quality >= 60) return 'Good';
      return 'Needs Improvement';
    }
  }

  Widget _buildProfitPotential(CropMarketData data, bool isHindi) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.trending_up, size: 40, color: Colors.white),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isHindi ? 'लाभ क्षमता' : 'Profit Potential',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${data.profitPotential}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.show_chart,
                      color: Colors.white.withOpacity(0.8),
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isHindi
                          ? 'बाजार मांग: ${data.marketDemandHindi}'
                          : 'Market Demand: ${data.marketDemand}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceChart(CropMarketData data, bool isHindi) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isHindi ? 'मूल्य रुझान' : 'Price Trend',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: CustomPaint(
              size: Size(MediaQuery.of(context).size.width - 72, 200),
              painter: PriceChartPainter(
                historicalPrices: data.priceHistory,
                forecastPrices: data.priceForecast,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegend(Colors.blue, isHindi ? 'पिछला' : 'Historical'),
              const SizedBox(width: 20),
              _buildLegend(Colors.green, isHindi ? 'पूर्वानुमान' : 'Forecast'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildRecommendations(CropMarketData data, bool isHindi) {
    final recommendations =
        isHindi ? data.recommendationsHindi : data.recommendations;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
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
              const Icon(Icons.lightbulb, color: Colors.amber, size: 28),
              const SizedBox(width: 8),
              Text(
                isHindi ? 'सिफारिशें' : 'Recommendations',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...recommendations.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${entry.key + 1}',
                      style: const TextStyle(
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: const TextStyle(fontSize: 15, height: 1.5),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildQualityImprovements(CropMarketData data, bool isHindi) {
    final improvements = isHindi
        ? data.qualityImprovementsHindi
        : data.qualityImprovements;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade400, Colors.deepOrange.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_fix_high, color: Colors.white, size: 28),
              const SizedBox(width: 8),
              Text(
                isHindi ? 'गुणवत्ता सुधार' : 'Quality Improvements',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...improvements.map((improvement) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      improvement,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
class CropMarketData {
  final String cropName;
  final String cropNameHindi;
  final double currentMarketPrice;
  final double expectedPrice;
  final int yourCropQuality;
  final String marketDemand;
  final String marketDemandHindi;
  final int profitPotential;
  final List<String> recommendations;
  final List<String> recommendationsHindi;
  final List<String> qualityImprovements;
  final List<String> qualityImprovementsHindi;
  final List<double> priceHistory;
  final List<double> priceForecast;

  CropMarketData({
    required this.cropName,
    required this.cropNameHindi,
    required this.currentMarketPrice,
    required this.expectedPrice,
    required this.yourCropQuality,
    required this.marketDemand,
    required this.marketDemandHindi,
    required this.profitPotential,
    required this.recommendations,
    required this.recommendationsHindi,
    required this.qualityImprovements,
    required this.qualityImprovementsHindi,
    required this.priceHistory,
    required this.priceForecast,
  });
}
class PriceChartPainter extends CustomPainter {
  final List<double> historicalPrices;
  final List<double> forecastPrices;

  PriceChartPainter({
    required this.historicalPrices,
    required this.forecastPrices,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final allPrices = [...historicalPrices, ...forecastPrices];
    final maxPrice = allPrices.reduce((a, b) => a > b ? a : b);
    final minPrice = allPrices.reduce((a, b) => a < b ? a : b);
    final priceRange = maxPrice - minPrice;

    final totalPoints = historicalPrices.length + forecastPrices.length;
    final xStep = size.width / (totalPoints - 1);
    paint.color = Colors.blue;
    final historicalPath = Path();
    for (var i = 0; i < historicalPrices.length; i++) {
      final x = i * xStep;
      final y = size.height - ((historicalPrices[i] - minPrice) / priceRange * size.height);
      if (i == 0) {
        historicalPath.moveTo(x, y);
      } else {
        historicalPath.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 5, Paint()..color = Colors.blue);
    }
    canvas.drawPath(historicalPath, paint);
    paint.color = Colors.green;
    paint.strokeWidth = 3;
    final forecastPath = Path();
    for (var i = 0; i < forecastPrices.length; i++) {
      final x = (historicalPrices.length - 1 + i) * xStep;
      final y = size.height - ((forecastPrices[i] - minPrice) / priceRange * size.height);
      if (i == 0) {
        forecastPath.moveTo(x, y);
      } else {
        forecastPath.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 5, Paint()..color = Colors.green);
    }
    paint.style = PaintingStyle.stroke;
    paint.shader = null;
    canvas.drawPath(forecastPath, paint);
    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
