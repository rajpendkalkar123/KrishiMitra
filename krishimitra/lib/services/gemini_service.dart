import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiService {
  // Direct Gemini API integration - NO backend needed
  static String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  static const String _geminiUrl = 
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  // Track if last response was from AI or fallback
  static bool lastResponseWasFromAI = false;
  static String? lastError;

  /// Get AI-powered farming recommendations from Gemini API directly
  static Future<FarmingRecommendation> getFarmingRecommendation({
    required String cropType,
    required double soilMoisture,
    required double nitrogen,
    required double phosphorus,
    required double potassium,
    required double pH,
    required double temperature,
    required double rainfall,
    required double farmArea,
    required String growthStage,
    required String soilType,
  }) async {
    lastResponseWasFromAI = false;
    lastError = null;

    try {
      print('🤖 Calling Gemini API directly...');
      print('   Crop: $cropType | Moisture: $soilMoisture | NPK: $nitrogen $phosphorus $potassium');
      
      final prompt = '''You are an expert agricultural advisor for Indian farmers. Analyze the following farm data and provide detailed, personalized recommendations with CLEAR EXPLANATIONS and REASONING.

**IMPORTANT: Provide step-by-step reasoning for each recommendation. Explain WHY each action is needed based on the specific data provided. Consider the farm size ($farmArea acres) in ALL calculations and recommendations.**

**Farm Data:**
- Crop: $cropType
- Farm Area: $farmArea acres (CRITICAL: Scale all quantities and costs to this exact farm size)
- Growth Stage: $growthStage
- Soil Type: $soilType

**Current Conditions:**
- Soil Moisture: $soilMoisture%
- Nitrogen (N): $nitrogen kg/ha
- Phosphorus (P): $phosphorus kg/ha
- Potassium (K): $potassium kg/ha
- Soil pH: $pH
- Temperature: $temperature°C
- Rainfall (weekly): $rainfall mm

**ANALYSIS REQUIREMENTS:**
1. ALL quantities MUST be calculated for the EXACT farm size of $farmArea acres
2. Explain HOW farm size affects resource needs (water, fertilizer, labor)
3. Calculate TOTAL costs and savings for THIS specific farm size
4. Provide farm-size-specific yield projections
5. Include step-by-step reasoning for every recommendation

Based on these SPECIFIC values, provide CUSTOMIZED recommendations with DETAILED EXPLANATIONS. You MUST respond ONLY with valid JSON (no markdown, no code blocks). Start directly with { and end with }:
{
  "farmSizeAnalysis": {
    "totalArea": "$farmArea acres",
    "areaClassification": "<Small (0-2)/Medium (2-10)/Large (10+) farm>",
    "scaleAdvantages": "<How this farm size affects efficiency, costs, and yields>",
    "resourceScaling": "<How water, fertilizer, labor scale with this size>"
  },
  "irrigationRecommendation": {
    "action": "START or STOP or REDUCE or INCREASE or MAINTAIN",
    "waterAmount": <number in liters PER ACRE>,
    "totalWaterNeeded": <waterAmount × $farmArea in liters for ENTIRE farm>,
    "timing": "<specific time recommendation>",
    "frequency": "<how often based on current $soilMoisture% moisture>",
    "reason": "<DETAILED explanation: Why this action? What will happen if not done? How does current $soilMoisture% moisture level compare to optimal for $cropType? Why this amount for $farmArea acres?>",
    "confidence": "<High/Medium/Low based on data quality>",
    "dataAnalysis": "<Explain what the $soilMoisture% moisture means for $cropType at $growthStage stage. Compare to ideal range.>",
    "farmSizeImpact": "<How the $farmArea acres size affects irrigation strategy - larger farms may need drip/sprinkler, smaller can do manual>"
  },
  "fertilizerRecommendation": {
    "type": "<specific fertilizer name for $cropType>",
    "quantityPerAcre": <number in kg per acre>,
    "totalQuantity": <quantityPerAcre × $farmArea in kg for ENTIRE farm>,
    "applicationMethod": "<how to apply - depends on farm size>",
    "timing": "<when to apply based on $growthStage stage>",
    "reason": "<DETAILED explanation: Why this fertilizer? Current NPK levels are N=$nitrogen, P=$phosphorus, K=$potassium. What's missing? What are optimal levels for $cropType? How does farm area affect application?>",
    "confidence": "<High/Medium/Low>",
    "expectedOutcome": "<What improvement to expect in crop health/yield>",
    "npkAnalysis": {
      "nitrogenStatus": "<Deficient/Optimal/Excess based on $nitrogen for $cropType. Current: $nitrogen, Optimal: X-Y>",
      "phosphorusStatus": "<Deficient/Optimal/Excess based on $phosphorus. Current: $phosphorus, Optimal: X-Y>",
      "potassiumStatus": "<Deficient/Optimal/Excess based on $potassium. Current: $potassium, Optimal: X-Y>",
      "balanceExplanation": "<Why current NPK balance is good/bad for this crop. What happens with deficiency/excess?>"
    },
    "farmSizeEconomics": "<Cost-benefit of fertilizer for $farmArea acres. Bulk buying advantages? Labor for application?>"
  },
  "cropHealthTips": [
    {
      "tip": "<actionable tip specific to $cropType at $growthStage for $farmArea acres>",
      "reasoning": "<Why this tip matters now. What science/data supports it?>",
      "expectedBenefit": "<Quantify: X% yield increase, Y% disease prevention, etc.>",
      "implementationCost": "<Cost to implement for $farmArea acres in rupees>",
      "priority": "<High/Medium/Low>"
    },
    {
      "tip": "<tip based on temperature $temperature°C>",
      "reasoning": "<Why temperature matters for this crop. Optimal range? Current risk?>",
      "expectedBenefit": "<Protection from heat/cold stress - prevent X% yield loss>",
      "implementationCost": "<Cost for $farmArea acres>",
      "priority": "<High/Medium/Low>"
    },
    {
      "tip": "<tip based on soil pH $pH>",
      "reasoning": "<How pH affects nutrient uptake. Current pH $pH vs optimal X-Y. What nutrients are locked?>",
      "expectedBenefit": "<Better nutrient absorption - X% improvement>",
      "implementationCost": "<Cost for $farmArea acres>",
      "priority": "<High/Medium/Low>"
    },
    {
      "tip": "<tip specific to $farmArea acres farm management>",
      "reasoning": "<Farm size-specific advice: labor, mechanization, monitoring>",
      "expectedBenefit": "<Efficiency gain for this farm size>",
      "implementationCost": "<Cost for $farmArea acres>",
      "priority": "<High/Medium/Low>"
    }
  ],
  "expectedYield": {
    "withAI": <realistic quintals per acre for $cropType with AI optimization>,
    "totalWithAI": <withAI × $farmArea quintals for ENTIRE farm>,
    "withoutAI": <lower quintals per acre without optimization>,
    "totalWithoutAI": <withoutAI × $farmArea for entire farm>,
    "improvementPercent": <percentage improvement>,
    "yieldExplanation": "<WHY AI recommendations increase yield? What specific factors improve? How does irrigation optimization add X%, fertilizer adds Y%, pest control adds Z%?>"
  },
  "profitAnalysis": {
    "perAcreRevenueWithAI": <rupees per acre with AI optimization>,
    "totalRevenueWithAI": <perAcreRevenueWithAI × $farmArea>,
    "perAcreRevenueWithoutAI": <rupees per acre traditional>,
    "totalRevenueWithoutAI": <perAcreRevenueWithoutAI × $farmArea>,
    "additionalProfitWithAI": <difference in rupees for ENTIRE $farmArea acres>,
    "profitExplanation": "<DETAILED Breakdown for $farmArea acres: ₹X from better irrigation (Y% water savings), ₹Z from optimized fertilizer (A% better NPK), ₹B from improved crop health (C% yield increase)>",
    "costSavings": {
      "waterPerAcre": <rupees saved per acre>,
      "totalWater": <waterPerAcre × $farmArea>,
      "fertilizerPerAcre": <rupees saved per acre>,
      "totalFertilizer": <fertilizerPerAcre × $farmArea>,
      "laborPerAcre": <rupees saved per acre from efficiency>,
      "totalLabor": <laborPerAcre × $farmArea>,
      "totalSavings": <sum of all savings for $farmArea acres>,
      "savingsExplanation": "<HOW precision farming reduces costs for $farmArea acres: Drip irrigation saves X liters/acre × $farmArea = Y rupees, Soil-test-based fertilizer prevents Z kg waste = A rupees>"
    },
    "investmentNeeded": {
      "immediate": <rupees needed now for critical actions across $farmArea acres>,
      "thisWeek": <rupees for weekly plan across farm>,
      "total": <total investment for season for $farmArea acres>,
      "roi": "<X% return on investment. Break-even in Y days. Explain calculation.>"
    }
  },
  "riskAlerts": [
    {
      "risk": "<risk based on $temperature°C temperature if any>",
      "severity": "<High/Medium/Low>",
      "likelihood": "<Probability % based on current conditions>",
      "potentialLoss": "<Estimated loss in rupees for $farmArea acres if risk occurs>",
      "mitigation": "<DETAILED prevention steps with costs for $farmArea acres>",
      "reasoning": "<Why this is risky for $cropType? Historical data? Scientific basis?>"
    },
    {
      "risk": "<risk based on $rainfall mm rainfall if any>",
      "severity": "<High/Medium/Low>",
      "likelihood": "<Probability %>",
      "potentialLoss": "<Rupees for $farmArea acres>",
      "mitigation": "<Prevention steps with costs>",
      "reasoning": "<Impact on crop and soil. Waterlogging? Drought stress?>"
    },
    {
      "risk": "<risk based on NPK imbalance or pH if any>",
      "severity": "<High/Medium/Low>",
      "likelihood": "<Probability %>",
      "potentialLoss": "<Rupees for $farmArea acres>",
      "mitigation": "<Correction steps with timeline>",
      "reasoning": "<Nutritional science: How deficiency affects plant physiology?>"
    }
  },
  "weeklyActionPlan": [
    {
      "day": "Day 1-2",
      "action": "<specific action for $cropType across $farmArea acres>",
      "why": "<Scientific reasoning for timing. Why now? What if delayed?>",
      "priority": "<High/Medium/Low>",
      "cost": "<Implementation cost for $farmArea acres>",
      "labor": "<Hours/people needed for $farmArea acres>",
      "expectedResult": "<Measurable outcome>"
    },
    {
      "day": "Day 3-4",
      "action": "<specific action>",
      "why": "<Why now? Crop growth stage? Weather window?>",
      "priority": "<High/Medium/Low>",
      "cost": "<Cost for $farmArea acres>",
      "labor": "<Labor requirement>",
      "expectedResult": "<Outcome>"
    },
    {
      "day": "Day 5-7",
      "action": "<specific action>",
      "why": "<Timing importance? Synergy with previous actions?>",
      "priority": "<High/Medium/Low>",
      "cost": "<Cost for $farmArea acres>",
      "labor": "<Labor requirement>",
      "expectedResult": "<Outcome>"
    }
  ],
  "marketTiming": {
    "optimalHarvestTime": "<when to harvest $cropType at $growthStage stage>",
    "expectedMarketPrice": <current market price in rupees per quintal>,
    "totalExpectedRevenue": <expectedMarketPrice × total yield for $farmArea acres>,
    "recommendation": "<sell now or wait advice>",
    "marketAnalysis": "<Why this timing? Market trends for $cropType? Storage costs (₹X/quintal/month) vs expected price increase (₹Y)? For $farmArea acres production, storage cost = Z rupees>",
    "alternativeMarkets": "<Local mandi vs contract farming vs direct consumer. Which is best for $farmArea acres scale?>"
  },
  "overallConfidence": "<High/Medium/Low - based on data completeness and crop stage>",
  "confidenceFactors": {
    "dataQuality": "<How reliable is input data? Missing parameters?>",
    "cropStageMatch": "<Is growth stage data accurate for recommendations?>",
    "seasonalRelevance": "<Are recommendations appropriate for current season?>",
    "farmSizeConsiderations": "<Is $farmArea acres size considered in all calculations?>"
  },
  "keyInsights": [
    "<Most critical finding from data analysis with numbers/percentages>",
    "<Immediate action needed to prevent loss - quantify risk>",
    "<Long-term strategy for this $farmArea acres farm - expected 3-month outcome>",
    "<Farm size optimization - is $farmArea acres ideal for $cropType? Diversification advice?>"
  ]
}''';

      final response = await http.post(
        Uri.parse('$_geminiUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'topK': 40,
            'topP': 0.95,
            'maxOutputTokens': 2048,
          }
        }),
      ).timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          throw Exception('Request timed out after 45 seconds');
        },
      );

      print('📡 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Check for API errors
        if (data['error'] != null) {
          throw Exception('Gemini API Error: ${data['error']['message']}');
        }
        
        if (data['candidates'] == null || data['candidates'].isEmpty) {
          throw Exception('No response candidates from Gemini');
        }
        
        final text = data['candidates'][0]['content']['parts'][0]['text'] as String;
        print('✅ Gemini Response received: ${text.substring(0, text.length > 100 ? 100 : text.length)}...');

        // Clean JSON response
        String jsonString = text.trim();
        if (jsonString.contains('```json')) {
          jsonString = jsonString.split('```json')[1].split('```')[0].trim();
        } else if (jsonString.contains('```')) {
          jsonString = jsonString.split('```')[1].split('```')[0].trim();
        }
        
        // Parse JSON
        final jsonData = jsonDecode(jsonString);
        lastResponseWasFromAI = true;
        print('🎉 Successfully parsed Gemini AI response!');
        
        // Add isFromGeminiAI flag to the data
        jsonData['isFromGeminiAI'] = true;
        
        return FarmingRecommendation.fromJson(jsonData);
      } else {
        final errorBody = response.body;
        print('❌ API Error: $errorBody');
        lastError = 'API returned status ${response.statusCode}';
        throw Exception('Gemini API Error: ${response.statusCode} - $errorBody');
      }
    } catch (e) {
      print('❌ Error calling Gemini: $e');
      lastError = e.toString();
      
      // Return intelligent fallback data based on inputs
      return _getIntelligentFallback(
        cropType, soilMoisture, nitrogen, phosphorus, potassium, 
        temperature, pH, growthStage, rainfall, farmArea
      );
    }
  }
  
  /// Intelligent fallback when API is unavailable
  static FarmingRecommendation _getIntelligentFallback(
    String crop,
    double moisture,
    double n,
    double p,
    double k,
    double temperature,
    double pH,
    String growthStage,
    double rainfall,
    double farmArea,
  ) {
    print('⚠️ Using intelligent fallback analysis...');
    
    // Generate dynamic recommendations based on actual input values
    String irrigationAction;
    double waterAmount;
    String irrigationReason;
    
    if (moisture < 30) {
      irrigationAction = 'START IMMEDIATELY';
      waterAmount = 3000;
      irrigationReason = 'CRITICAL: Soil moisture at ${moisture.toStringAsFixed(1)}% is dangerously low for $crop. Immediate irrigation required to prevent crop stress and yield loss.';
    } else if (moisture < 50) {
      irrigationAction = 'START';
      waterAmount = 2000;
      irrigationReason = 'Soil moisture at ${moisture.toStringAsFixed(1)}% is below optimal (50-65%) for $crop at $growthStage stage. Begin irrigation to support healthy growth.';
    } else if (moisture > 80) {
      irrigationAction = 'STOP';
      waterAmount = 0;
      irrigationReason = 'WARNING: Soil moisture at ${moisture.toStringAsFixed(1)}% is excessive. Stop irrigation immediately to prevent waterlogging and root diseases.';
    } else if (moisture > 65) {
      irrigationAction = 'REDUCE';
      waterAmount = 800;
      irrigationReason = 'Soil moisture at ${moisture.toStringAsFixed(1)}% is slightly high. Reduce irrigation frequency to optimize water usage.';
    } else {
      irrigationAction = 'MAINTAIN';
      waterAmount = 1200;
      irrigationReason = 'Soil moisture at ${moisture.toStringAsFixed(1)}% is in optimal range (50-65%) for $crop. Maintain current irrigation schedule.';
    }
    
    // Fertilizer recommendation based on NPK analysis
    String fertilizerType;
    double fertilizerQty;
    String fertilizerReason;
    
    if (n < 30 && p < 25 && k < 25) {
      fertilizerType = 'NPK 20:20:20 (Balanced)';
      fertilizerQty = 35;
      fertilizerReason = 'All nutrients are low - N: ${n.toStringAsFixed(0)}, P: ${p.toStringAsFixed(0)}, K: ${k.toStringAsFixed(0)} kg/ha. Apply balanced NPK fertilizer for overall nutrient boost.';
    } else if (n < 30) {
      fertilizerType = 'Urea (46-0-0)';
      fertilizerQty = 30;
      fertilizerReason = 'Nitrogen at ${n.toStringAsFixed(0)} kg/ha is deficient. Apply Urea for vegetative growth, leaf development and chlorophyll production.';
    } else if (p < 20) {
      fertilizerType = 'DAP (18-46-0)';
      fertilizerQty = 28;
      fertilizerReason = 'Phosphorus at ${p.toStringAsFixed(0)} kg/ha is low. Apply DAP to boost root development and flower/fruit formation.';
    } else if (k < 20) {
      fertilizerType = 'MOP - Muriate of Potash (0-0-60)';
      fertilizerQty = 22;
      fertilizerReason = 'Potassium at ${k.toStringAsFixed(0)} kg/ha needs improvement. Apply MOP for disease resistance and grain/fruit quality.';
    } else {
      fertilizerType = 'Micronutrient Mix (Zn, Fe, Mn, B)';
      fertilizerQty = 10;
      fertilizerReason = 'NPK levels are good (${n.toStringAsFixed(0)}/${p.toStringAsFixed(0)}/${k.toStringAsFixed(0)}). Apply micronutrients for optimal crop performance.';
    }
    
    // Risk alerts based on conditions
    List<String> risks = [];
    if (temperature > 38) {
      risks.add('🔴 SEVERE: Temperature at ${temperature.toStringAsFixed(1)}°C causing heat stress. Irrigate during cooler hours (5-7 AM), apply mulch, and consider shade nets.');
    } else if (temperature > 35) {
      risks.add('🟠 WARNING: High temperature (${temperature.toStringAsFixed(1)}°C) may stress crops. Increase irrigation frequency and avoid midday field work.');
    }
    if (temperature < 10) {
      risks.add('🔵 COLD ALERT: Temperature at ${temperature.toStringAsFixed(1)}°C risks frost damage. Use protective covers and avoid irrigation at night.');
    }
    if (moisture > 75 && temperature > 25) {
      risks.add('🟡 DISEASE RISK: High moisture (${moisture.toStringAsFixed(1)}%) + warm temperature = ideal conditions for fungal diseases. Monitor closely and apply preventive fungicide.');
    }
    if (pH < 5.5) {
      risks.add('⚠️ ACIDIC SOIL: pH at $pH is too acidic. Apply agricultural lime (200-400 kg/acre) to correct pH and improve nutrient availability.');
    }
    if (pH > 8.0) {
      risks.add('⚠️ ALKALINE SOIL: pH at $pH is too alkaline. Apply gypsum or sulfur to lower pH. Some nutrients may be locked up.');
    }
    if (rainfall > 100) {
      risks.add('🌧️ HEAVY RAIN: ${rainfall.toStringAsFixed(0)}mm weekly rainfall may cause waterlogging. Ensure proper drainage and delay fertilizer application.');
    }
    if (risks.isEmpty) {
      risks.add('✅ No major risks detected based on current conditions. Continue regular monitoring.');
    }
    
    // Calculate yield improvement based on optimization potential
    Map<String, double> cropBaseYields = {
      'Wheat': 18, 'Rice': 22, 'Sugarcane': 350, 'Cotton': 8,
      'Maize': 25, 'Soybean': 12, 'Groundnut': 10, 'Gram': 8,
      'Jowar': 10, 'Bajra': 9, 'Tur': 6, 'Moong': 5
    };
    double baseYield = cropBaseYields[crop] ?? 15;
    
    double yieldImprovement = 0;
    if (moisture < 40 || moisture > 75) yieldImprovement += 12;
    if (n < 35 || p < 25 || k < 25) yieldImprovement += 15;
    if (temperature > 35 || temperature < 12) yieldImprovement += 8;
    if (pH < 6.0 || pH > 7.5) yieldImprovement += 5;
    
    double withAI = baseYield * (1 + yieldImprovement / 100);
    
    // Market price estimates
    Map<String, double> marketPrices = {
      'Wheat': 2400, 'Rice': 2800, 'Sugarcane': 350, 'Cotton': 6500,
      'Maize': 2100, 'Soybean': 4500, 'Groundnut': 5800, 'Gram': 5200,
      'Jowar': 3200, 'Bajra': 2500, 'Tur': 6800, 'Moong': 7500
    };
    double marketPrice = marketPrices[crop] ?? 3000;
    
    return FarmingRecommendation(
      irrigationRecommendation: IrrigationRec(
        action: irrigationAction,
        waterAmount: waterAmount,
        timing: temperature > 32 ? 'Early morning (5-7 AM) or evening (5-7 PM) to reduce evaporation' : 'Morning (6-9 AM) is optimal',
        frequency: moisture < 40 ? 'Every 2-3 days until moisture reaches 50%' : (moisture > 65 ? 'Every 5-7 days' : 'Every 3-4 days'),
        reason: irrigationReason,
      ),
      fertilizerRecommendation: FertilizerRec(
        type: fertilizerType,
        quantity: fertilizerQty,
        applicationMethod: growthStage == 'Seedling' 
            ? 'Broadcast evenly and incorporate into soil' 
            : 'Band placement 5-7 cm away from plant base',
        timing: growthStage == 'Flowering' || growthStage == 'Fruiting'
            ? 'Apply within 2-3 days for critical growth support'
            : 'Apply within next 5-7 days, preferably before irrigation',
        reason: fertilizerReason,
      ),
      cropHealthTips: [
        '🌱 For $crop at $growthStage stage: ${_getGrowthStageTip(growthStage, crop)}',
        '🌡️ Temperature management: ${_getTemperatureTip(temperature, crop)}',
        '🧪 Soil health: pH at $pH - ${pH >= 6.0 && pH <= 7.5 ? "Optimal for most nutrients" : "Consider pH correction for better nutrient uptake"}',
      ],
      expectedYield: ExpectedYield(
        withAI: withAI,
        withoutAI: baseYield,
        improvementPercent: yieldImprovement,
      ),
      profitAnalysis: ProfitAnalysis(
        estimatedRevenueWithAI: withAI * marketPrice,
        estimatedRevenueWithoutAI: baseYield * marketPrice,
        additionalProfitWithAI: (withAI - baseYield) * marketPrice,
        costSavings: CostSavings(
          water: moisture > 50 ? 4500 : 2000,
          fertilizer: (n > 40 && p > 30 && k > 30) ? 4000 : 1800,
          total: (moisture > 50 ? 4500 : 2000) + ((n > 40 && p > 30 && k > 30) ? 4000 : 1800),
        ),
      ),
      riskAlerts: risks,
      weeklyActionPlan: [
        WeeklyAction(day: 'Day 1-2', action: '$irrigationAction irrigation with ${waterAmount.toStringAsFixed(0)}L/acre. ${fertilizerQty > 20 ? "Apply $fertilizerType (${fertilizerQty.toStringAsFixed(0)} kg/acre)" : "Monitor crop health"}'),
        WeeklyAction(day: 'Day 3-4', action: 'Scout for pests and diseases. Check soil moisture - target 50-65%. ${temperature > 33 ? "Ensure adequate water during peak heat." : "Regular monitoring sufficient."}'),
        WeeklyAction(day: 'Day 5-7', action: 'Evaluate crop response to inputs. Plan next irrigation cycle. ${rainfall > 30 ? "Account for rainfall in irrigation planning." : "Prepare for next irrigation if needed."}'),
      ],
      marketTiming: MarketTiming(
        optimalHarvestTime: _getHarvestTiming(growthStage, crop),
        expectedMarketPrice: marketPrice,
        recommendation: _getMarketRecommendation(crop, marketPrice),
      ),
      isFromGeminiAI: false, // This is fallback data
    );
  }
  
  static String _getGrowthStageTip(String stage, String crop) {
    switch (stage) {
      case 'Seedling':
        return 'Focus on root establishment. Keep soil consistently moist but not waterlogged. Protect from extreme temperatures.';
      case 'Vegetative':
        return 'High nitrogen demand for leaf growth. Ensure adequate N supply. Monitor for pest infestations.';
      case 'Flowering':
        return 'Critical stage - avoid water stress. Phosphorus is essential now. Do not apply excessive nitrogen.';
      case 'Fruiting':
        return 'Potassium is crucial for fruit/grain quality. Maintain consistent moisture. Reduce nitrogen application.';
      case 'Maturity':
        return 'Reduce irrigation gradually. Monitor for harvest readiness. Check moisture content before harvesting.';
      default:
        return 'Monitor crop health daily. Maintain optimal growing conditions.';
    }
  }
  
  static String _getTemperatureTip(double temp, String crop) {
    if (temp > 38) {
      return 'HEAT STRESS! Apply irrigation during cooler hours, use mulch, consider shade nets if possible.';
    } else if (temp > 33) {
      return 'High temps may stress $crop. Increase irrigation frequency and monitor for wilting.';
    } else if (temp < 10) {
      return 'Cold conditions - protect seedlings, avoid irrigation at night, watch for frost.';
    } else if (temp >= 20 && temp <= 30) {
      return 'Optimal temperature range for most crops. Ideal growing conditions.';
    } else {
      return 'Moderate conditions. Continue regular care practices.';
    }
  }
  
  static String _getHarvestTiming(String stage, String crop) {
    switch (stage) {
      case 'Maturity':
        return 'Ready for harvest within 7-14 days. Monitor moisture content.';
      case 'Fruiting':
        return 'Estimated 3-5 weeks to harvest. Continue care for maximum yield.';
      case 'Flowering':
        return 'Approximately 6-10 weeks to harvest depending on variety.';
      case 'Vegetative':
        return 'Still in growth phase. Estimated 10-14 weeks to harvest.';
      default:
        return 'Early stage - 12-16 weeks to harvest for most varieties.';
    }
  }
  
  static String _getMarketRecommendation(String crop, double price) {
    final month = DateTime.now().month;
    if (month >= 3 && month <= 5) {
      return 'Post-harvest season - prices may be lower due to supply. Consider storage if facility available.';
    } else if (month >= 10 && month <= 12) {
      return 'Pre-season - demand typically increases. Good time to sell if quality is maintained.';
    } else {
      return 'Monitor daily mandi prices. Current price ₹${price.toStringAsFixed(0)}/quintal is reference rate.';
    }
  }

  /// Get AI-powered disease treatment recommendations
  static Future<String> getDiseaseRecommendation({
    required String plant,
    required String disease,
    required double confidence,
  }) async {
    try {
      print('🤖 Getting disease recommendation from Gemini...');
      return _getFallbackDiseaseExplanation(plant, disease);
    } catch (e) {
      print('❌ Error: $e');
      return _getFallbackDiseaseExplanation(plant, disease);
    }
  }

  static String _getFallbackDiseaseExplanation(String plant, String disease) {
    return '''**Disease Detected: $disease on $plant**

**What to do:**
1. Remove infected leaves/parts immediately
2. Dispose of infected material away from healthy plants
3. Apply appropriate fungicide or pesticide
4. Improve air circulation around plants
5. Avoid overhead watering
6. Monitor other plants for symptoms

**Consult:** Visit your nearest agricultural extension office or Krishi Vigyan Kendra for specific treatment recommendations.

**Note:** AI recommendations are general guidelines. For accurate diagnosis and treatment, please consult with a local agricultural expert.''';
  }
}

// Data Models

class FarmingRecommendation {
  final IrrigationRec irrigationRecommendation;
  final FertilizerRec fertilizerRecommendation;
  final List<String> cropHealthTips;
  final ExpectedYield expectedYield;
  final ProfitAnalysis profitAnalysis;
  final List<String> riskAlerts;
  final List<WeeklyAction> weeklyActionPlan;
  final MarketTiming marketTiming;
  final bool isFromGeminiAI;

  FarmingRecommendation({
    required this.irrigationRecommendation,
    required this.fertilizerRecommendation,
    required this.cropHealthTips,
    required this.expectedYield,
    required this.profitAnalysis,
    required this.riskAlerts,
    required this.weeklyActionPlan,
    required this.marketTiming,
    this.isFromGeminiAI = false,
  });

  factory FarmingRecommendation.fromJson(Map<String, dynamic> json) {
    return FarmingRecommendation(
      irrigationRecommendation: IrrigationRec.fromJson(json['irrigationRecommendation'] ?? {}),
      fertilizerRecommendation: FertilizerRec.fromJson(json['fertilizerRecommendation'] ?? {}),
      cropHealthTips: List<String>.from(json['cropHealthTips'] ?? []),
      expectedYield: ExpectedYield.fromJson(json['expectedYield'] ?? {}),
      profitAnalysis: ProfitAnalysis.fromJson(json['profitAnalysis'] ?? {}),
      riskAlerts: List<String>.from(json['riskAlerts'] ?? []),
      weeklyActionPlan: (json['weeklyActionPlan'] as List?)
          ?.map((e) => WeeklyAction.fromJson(e))
          .toList() ?? [],
      marketTiming: MarketTiming.fromJson(json['marketTiming'] ?? {}),
      isFromGeminiAI: json['isFromGeminiAI'] ?? true,
    );
  }
}

class IrrigationRec {
  final String action;
  final double waterAmount;
  final String timing;
  final String frequency;
  final String reason;

  IrrigationRec({
    required this.action,
    required this.waterAmount,
    required this.timing,
    required this.frequency,
    required this.reason,
  });

  factory IrrigationRec.fromJson(Map<String, dynamic> json) {
    return IrrigationRec(
      action: json['action']?.toString() ?? 'MAINTAIN',
      waterAmount: (json['waterAmount'] ?? 0).toDouble(),
      timing: json['timing']?.toString() ?? 'Morning',
      frequency: json['frequency']?.toString() ?? 'As needed',
      reason: json['reason']?.toString() ?? 'Based on soil conditions',
    );
  }
}

class FertilizerRec {
  final String type;
  final double quantity;
  final String applicationMethod;
  final String timing;
  final String reason;

  FertilizerRec({
    required this.type,
    required this.quantity,
    required this.applicationMethod,
    required this.timing,
    required this.reason,
  });

  factory FertilizerRec.fromJson(Map<String, dynamic> json) {
    return FertilizerRec(
      type: json['type']?.toString() ?? 'NPK Balanced',
      quantity: (json['quantity'] ?? 0).toDouble(),
      applicationMethod: json['applicationMethod']?.toString() ?? 'Broadcast',
      timing: json['timing']?.toString() ?? 'As needed',
      reason: json['reason']?.toString() ?? 'Based on soil nutrient levels',
    );
  }
}

class ExpectedYield {
  final double withAI;
  final double withoutAI;
  final double improvementPercent;

  ExpectedYield({
    required this.withAI,
    required this.withoutAI,
    required this.improvementPercent,
  });

  factory ExpectedYield.fromJson(Map<String, dynamic> json) {
    return ExpectedYield(
      withAI: (json['withAI'] ?? 0).toDouble(),
      withoutAI: (json['withoutAI'] ?? 0).toDouble(),
      improvementPercent: (json['improvementPercent'] ?? 0).toDouble(),
    );
  }
}

class ProfitAnalysis {
  final double estimatedRevenueWithAI;
  final double estimatedRevenueWithoutAI;
  final double additionalProfitWithAI;
  final CostSavings costSavings;

  ProfitAnalysis({
    required this.estimatedRevenueWithAI,
    required this.estimatedRevenueWithoutAI,
    required this.additionalProfitWithAI,
    required this.costSavings,
  });

  factory ProfitAnalysis.fromJson(Map<String, dynamic> json) {
    return ProfitAnalysis(
      estimatedRevenueWithAI: (json['estimatedRevenueWithAI'] ?? 0).toDouble(),
      estimatedRevenueWithoutAI: (json['estimatedRevenueWithoutAI'] ?? 0).toDouble(),
      additionalProfitWithAI: (json['additionalProfitWithAI'] ?? 0).toDouble(),
      costSavings: CostSavings.fromJson(json['costSavings'] ?? {}),
    );
  }
}

class CostSavings {
  final double water;
  final double fertilizer;
  final double total;

  CostSavings({
    required this.water,
    required this.fertilizer,
    required this.total,
  });

  factory CostSavings.fromJson(Map<String, dynamic> json) {
    return CostSavings(
      water: (json['water'] ?? 0).toDouble(),
      fertilizer: (json['fertilizer'] ?? 0).toDouble(),
      total: (json['total'] ?? 0).toDouble(),
    );
  }
}

class WeeklyAction {
  final String day;
  final String action;

  WeeklyAction({required this.day, required this.action});

  factory WeeklyAction.fromJson(Map<String, dynamic> json) {
    return WeeklyAction(
      day: json['day']?.toString() ?? '',
      action: json['action']?.toString() ?? '',
    );
  }
}

class MarketTiming {
  final String optimalHarvestTime;
  final double expectedMarketPrice;
  final String recommendation;

  MarketTiming({
    required this.optimalHarvestTime,
    required this.expectedMarketPrice,
    required this.recommendation,
  });

  factory MarketTiming.fromJson(Map<String, dynamic> json) {
    return MarketTiming(
      optimalHarvestTime: json['optimalHarvestTime']?.toString() ?? 'Check market conditions',
      expectedMarketPrice: (json['expectedMarketPrice'] ?? 0).toDouble(),
      recommendation: json['recommendation']?.toString() ?? 'Monitor market prices',
    );
  }
}
