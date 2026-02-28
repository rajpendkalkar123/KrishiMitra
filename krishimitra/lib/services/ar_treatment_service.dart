/// AR Treatment Service - Provides AR-based treatment guidance for plant diseases
/// Uses Gemini AI to generate contextual treatment plans with AR overlays
library;

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:krishimitra/domain/models/ar_treatment_models.dart';
import 'package:krishimitra/utils/env_config.dart';

class ARTreatmentService {
  static String get _apiKey => EnvConfig.geminiApiKey;
  static const String _geminiUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';
  static const Duration _requestTimeout = Duration(seconds: 30);

  /// Generate AR treatment plan for detected disease
  static Future<ARTreatmentPlan> generateTreatmentPlan({
    required String plantName,
    required String diseaseName,
    required double confidence,
    String languageCode = 'en',
  }) async {
    try {
      print('🎯 Generating AR treatment plan for: $plantName - $diseaseName');

      final prompt = _buildTreatmentPrompt(plantName, diseaseName, confidence);
      
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
            'maxOutputTokens': 4096,
          }
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
        
        // Parse the JSON response
        final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(text);
        if (jsonMatch != null) {
          final planJson = jsonDecode(jsonMatch.group(0)!);
          return _parseTreatmentPlan(planJson, plantName, diseaseName);
        }
      }
      
      // Fallback to default plan
      print('⚠️ Using fallback treatment plan');
      return _getDefaultTreatmentPlan(plantName, diseaseName);
    } catch (e) {
      print('❌ Error generating treatment plan: $e');
      return _getDefaultTreatmentPlan(plantName, diseaseName);
    }
  }

  static String _buildTreatmentPrompt(String plantName, String diseaseName, double confidence) {
    return '''You are an expert agricultural advisor specializing in plant disease treatment.

Generate a detailed AR-guided treatment plan for the following disease:

**Plant:** $plantName
**Disease:** $diseaseName
**Confidence:** ${(confidence * 100).toStringAsFixed(1)}%

Create a step-by-step treatment guide that can be visualized in Augmented Reality. Each step should include visual guidance for the farmer.

Respond ONLY with valid JSON (no markdown, no code blocks). Start directly with { and end with }:

{
  "severityLevel": "mild|moderate|severe",
  "steps": [
    {
      "stepNumber": 1,
      "titleEn": "English title",
      "titleHi": "हिंदी शीर्षक",
      "titleMr": "मराठी शीर्षक",
      "descriptionEn": "Detailed English description for AR guidance",
      "descriptionHi": "AR मार्गदर्शन के लिए विस्तृत हिंदी विवरण",
      "descriptionMr": "AR मार्गदर्शनासाठी विस्तृत मराठी वर्णन",
      "type": "identifyArea|prepareTools|prepareSolution|application|soilTreatment|pruning|watering|safety|monitoring|prevention",
      "overlayConfig": {
        "highlightColor": "#FF0000",
        "shape": "circle|rectangle|arrow|grid",
        "safeDistance": 0.5,
        "targetRadius": 30,
        "sprayPattern": "zigzag|circular|linear"
      },
      "estimatedMinutes": 5,
      "warnings": ["Warning 1", "Warning 2"]
    }
  ],
  "requiredTools": [
    {
      "nameEn": "Sprayer",
      "nameHi": "स्प्रेयर",
      "nameMr": "फवारणी यंत्र",
      "icon": "🔧",
      "isEssential": true
    }
  ],
  "requiredChemicals": [
    {
      "nameEn": "Chemical name",
      "nameHi": "रासायनिक नाम",
      "nameMr": "रासायनिक नाव",
      "type": "fungicide|pesticide|herbicide|fertilizer",
      "dosage": "2ml per liter",
      "brandSuggestion": "Brand Name",
      "estimatedPrice": 250
    }
  ],
  "safetyGuidelines": {
    "protectiveGearEn": ["Gloves", "Mask", "Goggles"],
    "protectiveGearHi": ["दस्ताने", "मास्क", "चश्मे"],
    "protectiveGearMr": ["हातमोजे", "मास्क", "चष्मा"],
    "safeDistanceMeters": 0.5,
    "applicationTimeEn": "Early morning or late evening",
    "applicationTimeHi": "सुबह जल्दी या शाम को",
    "applicationTimeMr": "सकाळी लवकर किंवा संध्याकाळी",
    "doNotEn": ["Do not spray during rain", "Do not eat/drink while spraying"],
    "doNotHi": ["बारिश के दौरान स्प्रे न करें", "स्प्रे करते समय खाएं/पियें नहीं"],
    "doNotMr": ["पावसात फवारणी करू नका", "फवारणी करताना खाऊ/पिऊ नका"]
  }
}

Include 5-8 detailed steps covering:
1. Identifying infected areas (AR highlights)
2. Safety precautions
3. Preparing required materials/chemicals
4. Step-by-step application with spray direction/distance guidance
5. Post-treatment care
6. Prevention measures

Make instructions practical for Indian farmers with local context.''';
  }

  static ARTreatmentPlan _parseTreatmentPlan(
    Map<String, dynamic> json,
    String plantName,
    String diseaseName,
  ) {
    // Parse steps
    final stepsJson = json['steps'] as List? ?? [];
    final steps = stepsJson.map((s) => _parseStep(s)).toList();

    // Parse required tools
    final toolsJson = json['requiredTools'] as List? ?? [];
    final tools = toolsJson.map((t) => RequiredTool(
      nameEn: t['nameEn'] ?? 'Tool',
      nameHi: t['nameHi'] ?? 'उपकरण',
      nameMr: t['nameMr'] ?? 'साधन',
      icon: t['icon'] ?? '🔧',
      isEssential: t['isEssential'] ?? true,
    )).toList();

    // Parse required chemicals
    final chemicalsJson = json['requiredChemicals'] as List? ?? [];
    final chemicals = chemicalsJson.map((c) => RequiredChemical(
      nameEn: c['nameEn'] ?? 'Chemical',
      nameHi: c['nameHi'] ?? 'रसायन',
      nameMr: c['nameMr'] ?? 'रसायन',
      type: c['type'] ?? 'pesticide',
      dosage: c['dosage'] ?? '2ml/L',
      brandSuggestion: c['brandSuggestion'],
      estimatedPrice: (c['estimatedPrice'] as num?)?.toDouble(),
    )).toList();

    // Parse safety guidelines
    final safetyJson = json['safetyGuidelines'] as Map<String, dynamic>? ?? {};
    final safety = SafetyGuidelines(
      protectiveGearEn: List<String>.from(safetyJson['protectiveGearEn'] ?? ['Gloves', 'Mask']),
      protectiveGearHi: List<String>.from(safetyJson['protectiveGearHi'] ?? ['दस्ताने', 'मास्क']),
      protectiveGearMr: List<String>.from(safetyJson['protectiveGearMr'] ?? ['हातमोजे', 'मास्क']),
      safeDistanceMeters: (safetyJson['safeDistanceMeters'] as num?)?.toDouble() ?? 0.5,
      applicationTimeEn: safetyJson['applicationTimeEn'] ?? 'Early morning',
      applicationTimeHi: safetyJson['applicationTimeHi'] ?? 'सुबह जल्दी',
      applicationTimeMr: safetyJson['applicationTimeMr'] ?? 'सकाळी लवकर',
      doNotEn: List<String>.from(safetyJson['doNotEn'] ?? []),
      doNotHi: List<String>.from(safetyJson['doNotHi'] ?? []),
      doNotMr: List<String>.from(safetyJson['doNotMr'] ?? []),
    );

    return ARTreatmentPlan(
      diseaseId: '${plantName}_${diseaseName}'.replaceAll(' ', '_').toLowerCase(),
      diseaseName: diseaseName,
      plantName: plantName,
      severityLevel: json['severityLevel'] ?? 'moderate',
      steps: steps,
      requiredTools: tools,
      requiredChemicals: chemicals,
      safetyGuidelines: safety,
    );
  }

  static ARTreatmentStep _parseStep(Map<String, dynamic> s) {
    final overlayJson = s['overlayConfig'] as Map<String, dynamic>? ?? {};
    
    return ARTreatmentStep(
      stepNumber: s['stepNumber'] ?? 1,
      titleEn: s['titleEn'] ?? 'Step',
      titleHi: s['titleHi'] ?? 'चरण',
      titleMr: s['titleMr'] ?? 'पायरी',
      descriptionEn: s['descriptionEn'] ?? '',
      descriptionHi: s['descriptionHi'] ?? '',
      descriptionMr: s['descriptionMr'] ?? '',
      type: _parseStepType(s['type']),
      overlayConfig: AROverlayConfig(
        highlightColor: _parseColor(overlayJson['highlightColor']),
        shape: _parseShape(overlayJson['shape']),
        safeDistance: (overlayJson['safeDistance'] as num?)?.toDouble(),
        targetRadius: (overlayJson['targetRadius'] as num?)?.toDouble(),
        sprayDirection: overlayJson['sprayPattern'] != null
            ? SprayDirection(
                angle: 45,
                distance: 30,
                pattern: overlayJson['sprayPattern'] ?? 'linear',
              )
            : null,
      ),
      estimatedDuration: Duration(minutes: s['estimatedMinutes'] ?? 5),
      warnings: List<String>.from(s['warnings'] ?? []),
    );
  }

  static TreatmentStepType _parseStepType(String? type) {
    switch (type) {
      case 'identifyArea': return TreatmentStepType.identifyArea;
      case 'prepareTools': return TreatmentStepType.prepareTools;
      case 'prepareSolution': return TreatmentStepType.prepareSolution;
      case 'application': return TreatmentStepType.application;
      case 'soilTreatment': return TreatmentStepType.soilTreatment;
      case 'pruning': return TreatmentStepType.pruning;
      case 'watering': return TreatmentStepType.watering;
      case 'safety': return TreatmentStepType.safety;
      case 'monitoring': return TreatmentStepType.monitoring;
      case 'prevention': return TreatmentStepType.prevention;
      default: return TreatmentStepType.application;
    }
  }

  static OverlayShape _parseShape(String? shape) {
    switch (shape) {
      case 'circle': return OverlayShape.circle;
      case 'rectangle': return OverlayShape.rectangle;
      case 'arrow': return OverlayShape.arrow;
      case 'grid': return OverlayShape.grid;
      case 'freeform': return OverlayShape.freeform;
      default: return OverlayShape.circle;
    }
  }

  static Color _parseColor(String? colorHex) {
    if (colorHex == null) return Colors.red;
    try {
      final hex = colorHex.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (e) {
      return Colors.red;
    }
  }

  /// Get default treatment plan for common diseases
  static ARTreatmentPlan _getDefaultTreatmentPlan(String plantName, String diseaseName) {
    return ARTreatmentPlan(
      diseaseId: '${plantName}_${diseaseName}'.replaceAll(' ', '_').toLowerCase(),
      diseaseName: diseaseName,
      plantName: plantName,
      severityLevel: 'moderate',
      steps: [
        // Step 1: Identify infected area
        ARTreatmentStep(
          stepNumber: 1,
          titleEn: 'Identify Infected Area',
          titleHi: 'संक्रमित क्षेत्र की पहचान करें',
          titleMr: 'संक्रमित भाग ओळखा',
          descriptionEn: 'Look for discolored, spotted, or wilting leaves. The AR overlay will highlight the infected regions in red. Focus on areas showing disease symptoms.',
          descriptionHi: 'रंग बदले हुए, धब्बेदार या मुरझाई हुई पत्तियों की तलाश करें। AR ओवरले संक्रमित क्षेत्रों को लाल रंग में हाइलाइट करेगा।',
          descriptionMr: 'रंग बदललेली, डाग असलेली किंवा कोमेजलेली पाने शोधा. AR ओव्हरले संक्रमित भागांना लाल रंगात हायलाइट करेल.',
          type: TreatmentStepType.identifyArea,
          overlayConfig: AROverlayConfig(
            highlightColor: Colors.red,
            shape: OverlayShape.circle,
            highlightOpacity: 0.5,
          ),
          estimatedDuration: const Duration(minutes: 3),
        ),
        
        // Step 2: Safety precautions
        ARTreatmentStep(
          stepNumber: 2,
          titleEn: 'Wear Safety Equipment',
          titleHi: 'सुरक्षा उपकरण पहनें',
          titleMr: 'सुरक्षा उपकरणे घाला',
          descriptionEn: 'Before handling any chemicals: Wear rubber gloves, face mask (N95 recommended), and protective goggles. Keep children and animals away from the treatment area.',
          descriptionHi: 'किसी भी रसायन को संभालने से पहले: रबर के दस्ताने, फेस मास्क (N95 अनुशंसित), और सुरक्षा चश्मे पहनें। बच्चों और जानवरों को उपचार क्षेत्र से दूर रखें।',
          descriptionMr: 'कोणत्याही रसायनांना हाताळण्यापूर्वी: रबर हातमोजे, फेस मास्क (N95 शिफारसीय), आणि सुरक्षा चष्मा घाला. मुले आणि प्राणी यांना उपचार क्षेत्रापासून दूर ठेवा.',
          type: TreatmentStepType.safety,
          overlayConfig: AROverlayConfig(
            highlightColor: Colors.orange,
            shape: OverlayShape.rectangle,
          ),
          estimatedDuration: const Duration(minutes: 2),
          warnings: ['Do not touch face while handling chemicals', 'Wash hands thoroughly after treatment'],
        ),
        
        // Step 3: Prepare solution
        ARTreatmentStep(
          stepNumber: 3,
          titleEn: 'Prepare Treatment Solution',
          titleHi: 'उपचार घोल तैयार करें',
          titleMr: 'उपचार द्रावण तयार करा',
          descriptionEn: 'Mix the recommended fungicide/pesticide in clean water. Use 2-3ml per liter of water. Stir well until fully dissolved. Fill the sprayer tank.',
          descriptionHi: 'अनुशंसित कवकनाशी/कीटनाशक को साफ पानी में मिलाएं। प्रति लीटर पानी में 2-3ml का उपयोग करें। पूरी तरह घुलने तक अच्छी तरह हिलाएं।',
          descriptionMr: 'शिफारस केलेले बुरशीनाशक/कीटकनाशक स्वच्छ पाण्यात मिसळा. प्रति लीटर पाण्यात 2-3ml वापरा. पूर्णपणे विरघळेपर्यंत चांगले ढवळा.',
          type: TreatmentStepType.prepareSolution,
          overlayConfig: AROverlayConfig(
            highlightColor: Colors.blue,
            shape: OverlayShape.rectangle,
          ),
          estimatedDuration: const Duration(minutes: 5),
        ),
        
        // Step 4: Apply treatment
        ARTreatmentStep(
          stepNumber: 4,
          titleEn: 'Spray Treatment',
          titleHi: 'उपचार का छिड़काव करें',
          titleMr: 'उपचार फवारणी करा',
          descriptionEn: 'Hold the sprayer 30-40cm away from the plant. Spray in a zigzag pattern covering both sides of leaves. Follow the AR arrows for spray direction. Ensure complete coverage of infected areas.',
          descriptionHi: 'स्प्रेयर को पौधे से 30-40cm दूर रखें। पत्तियों के दोनों तरफ ज़िगज़ैग पैटर्न में स्प्रे करें। स्प्रे दिशा के लिए AR तीरों का पालन करें।',
          descriptionMr: 'फवारणी यंत्र वनस्पतीपासून 30-40cm अंतरावर धरा. पानांच्या दोन्ही बाजूंना झिगझॅग पद्धतीने फवारणी करा. फवारणी दिशेसाठी AR बाणांचे अनुसरण करा.',
          type: TreatmentStepType.application,
          overlayConfig: AROverlayConfig(
            highlightColor: Colors.green,
            shape: OverlayShape.arrow,
            safeDistance: 0.4,
            sprayDirection: SprayDirection(
              angle: 45,
              distance: 35,
              pattern: 'zigzag',
            ),
            arrows: [
              ARArrow(startX: 0.5, startY: 0.3, endX: 0.5, endY: 0.7, color: Colors.green, label: 'Spray'),
              ARArrow(startX: 0.3, startY: 0.5, endX: 0.7, endY: 0.5, color: Colors.green, label: ''),
            ],
          ),
          estimatedDuration: const Duration(minutes: 10),
        ),
        
        // Step 5: Remove severely infected parts
        ARTreatmentStep(
          stepNumber: 5,
          titleEn: 'Remove Severely Infected Parts',
          titleHi: 'गंभीर रूप से संक्रमित हिस्सों को हटाएं',
          titleMr: 'गंभीरपणे संक्रमित भाग काढून टाका',
          descriptionEn: 'Cut and remove heavily infected leaves or branches. Make clean cuts at a 45° angle. Dispose of infected material away from healthy plants - do not compost.',
          descriptionHi: 'भारी संक्रमित पत्तियों या शाखाओं को काटकर हटा दें। 45° कोण पर साफ कट करें। संक्रमित सामग्री को स्वस्थ पौधों से दूर फेंक दें।',
          descriptionMr: 'जास्त संक्रमित पाने किंवा फांद्या कापून काढा. 45° कोनात स्वच्छ कट करा. संक्रमित साहित्य निरोगी वनस्पतींपासून दूर फेकून द्या.',
          type: TreatmentStepType.pruning,
          overlayConfig: AROverlayConfig(
            highlightColor: Colors.purple,
            shape: OverlayShape.freeform,
          ),
          estimatedDuration: const Duration(minutes: 8),
        ),
        
        // Step 6: Post-treatment watering
        ARTreatmentStep(
          stepNumber: 6,
          titleEn: 'Water the Roots',
          titleHi: 'जड़ों को पानी दें',
          titleMr: 'मुळांना पाणी द्या',
          descriptionEn: 'After spraying, water the plant at the root zone only. Avoid wetting the leaves. This helps the plant recover and absorb nutrients. Water in the morning if possible.',
          descriptionHi: 'छिड़काव के बाद, केवल जड़ क्षेत्र में पौधे को पानी दें। पत्तियों को गीला करने से बचें। यह पौधे को ठीक होने और पोषक तत्व अवशोषित करने में मदद करता है।',
          descriptionMr: 'फवारणीनंतर, फक्त मूळ भागात वनस्पतीला पाणी द्या. पाने ओले होणे टाळा. यामुळे वनस्पतीला बरे होण्यास आणि पोषक द्रव्ये शोषण्यास मदत होते.',
          type: TreatmentStepType.watering,
          overlayConfig: AROverlayConfig(
            highlightColor: Colors.cyan,
            shape: OverlayShape.circle,
            targetRadius: 20,
          ),
          estimatedDuration: const Duration(minutes: 3),
        ),
        
        // Step 7: Monitor progress
        ARTreatmentStep(
          stepNumber: 7,
          titleEn: 'Monitor & Repeat',
          titleHi: 'निगरानी करें और दोहराएं',
          titleMr: 'निरीक्षण करा आणि पुन्हा करा',
          descriptionEn: 'Check the plant after 3-5 days. Look for improvement or spread of disease. Repeat the treatment after 7-10 days if needed. Take photos to track progress using this app.',
          descriptionHi: '3-5 दिनों के बाद पौधे की जांच करें। सुधार या बीमारी के फैलाव की तलाश करें। यदि आवश्यक हो तो 7-10 दिनों के बाद उपचार दोहराएं।',
          descriptionMr: '3-5 दिवसांनंतर वनस्पती तपासा. सुधारणा किंवा रोगाचा प्रसार पहा. आवश्यक असल्यास 7-10 दिवसांनंतर उपचार पुन्हा करा.',
          type: TreatmentStepType.monitoring,
          overlayConfig: AROverlayConfig(
            highlightColor: Colors.amber,
            shape: OverlayShape.rectangle,
          ),
          estimatedDuration: const Duration(minutes: 5),
        ),
        
        // Step 8: Prevention
        ARTreatmentStep(
          stepNumber: 8,
          titleEn: 'Prevent Future Outbreaks',
          titleHi: 'भविष्य में प्रकोप रोकें',
          titleMr: 'भविष्यातील उद्रेक टाळा',
          descriptionEn: 'Maintain proper spacing between plants. Ensure good air circulation. Avoid overwatering. Apply preventive fungicide spray monthly. Remove fallen leaves regularly.',
          descriptionHi: 'पौधों के बीच उचित दूरी बनाए रखें। अच्छा वायु संचार सुनिश्चित करें। अधिक पानी देने से बचें। मासिक रूप से निवारक कवकनाशी स्प्रे करें।',
          descriptionMr: 'वनस्पतींमध्ये योग्य अंतर ठेवा. चांगले हवा परिसंचरण सुनिश्चित करा. जास्त पाणी देणे टाळा. दरमहा प्रतिबंधात्मक बुरशीनाशक फवारणी करा.',
          type: TreatmentStepType.prevention,
          overlayConfig: AROverlayConfig(
            highlightColor: Colors.teal,
            shape: OverlayShape.grid,
          ),
          estimatedDuration: const Duration(minutes: 5),
        ),
      ],
      requiredTools: [
        RequiredTool(
          nameEn: 'Knapsack Sprayer',
          nameHi: 'नेपसैक स्प्रेयर',
          nameMr: 'नॅपसॅक फवारणी यंत्र',
          icon: '💨',
          isEssential: true,
        ),
        RequiredTool(
          nameEn: 'Pruning Shears',
          nameHi: 'छंटाई कैंची',
          nameMr: 'छाटणी कात्री',
          icon: '✂️',
          isEssential: true,
        ),
        RequiredTool(
          nameEn: 'Rubber Gloves',
          nameHi: 'रबर के दस्ताने',
          nameMr: 'रबर हातमोजे',
          icon: '🧤',
          isEssential: true,
        ),
        RequiredTool(
          nameEn: 'Face Mask (N95)',
          nameHi: 'फेस मास्क (N95)',
          nameMr: 'फेस मास्क (N95)',
          icon: '😷',
          isEssential: true,
        ),
        RequiredTool(
          nameEn: 'Safety Goggles',
          nameHi: 'सुरक्षा चश्मा',
          nameMr: 'सुरक्षा चष्मा',
          icon: '🥽',
          isEssential: false,
        ),
        RequiredTool(
          nameEn: 'Watering Can',
          nameHi: 'पानी का कनस्तर',
          nameMr: 'पाणी पिंप',
          icon: '🚿',
          isEssential: false,
        ),
      ],
      requiredChemicals: [
        RequiredChemical(
          nameEn: 'Copper Oxychloride (COC)',
          nameHi: 'कॉपर ऑक्सीक्लोराइड',
          nameMr: 'कॉपर ऑक्सीक्लोराइड',
          type: 'fungicide',
          dosage: '3g per liter of water',
          brandSuggestion: 'Blitox, Blue Copper',
          estimatedPrice: 180,
        ),
        RequiredChemical(
          nameEn: 'Mancozeb 75% WP',
          nameHi: 'मैंकोज़ेब 75% WP',
          nameMr: 'मँकोझेब 75% WP',
          type: 'fungicide',
          dosage: '2.5g per liter of water',
          brandSuggestion: 'Dithane M-45, Indofil M-45',
          estimatedPrice: 220,
        ),
        RequiredChemical(
          nameEn: 'Neem Oil Extract',
          nameHi: 'नीम तेल अर्क',
          nameMr: 'कडुनिंब तेल अर्क',
          type: 'pesticide',
          dosage: '5ml per liter of water',
          brandSuggestion: 'Nimbecidine, NeemAzal',
          estimatedPrice: 150,
        ),
      ],
      safetyGuidelines: SafetyGuidelines(
        protectiveGearEn: ['Rubber Gloves', 'Face Mask (N95)', 'Safety Goggles', 'Full-sleeve shirt', 'Long pants'],
        protectiveGearHi: ['रबर के दस्ताने', 'फेस मास्क (N95)', 'सुरक्षा चश्मा', 'पूरी बाजू की शर्ट', 'लंबी पैंट'],
        protectiveGearMr: ['रबर हातमोजे', 'फेस मास्क (N95)', 'सुरक्षा चष्मा', 'पूर्ण बाही शर्ट', 'लांब पँट'],
        safeDistanceMeters: 0.5,
        applicationTimeEn: 'Early morning (6-8 AM) or late evening (5-7 PM) - avoid midday heat',
        applicationTimeHi: 'सुबह जल्दी (6-8 AM) या शाम को (5-7 PM) - दोपहर की गर्मी से बचें',
        applicationTimeMr: 'सकाळी लवकर (6-8 AM) किंवा संध्याकाळी (5-7 PM) - दुपारची उष्णता टाळा',
        doNotEn: [
          'Do not spray during rain or strong wind',
          'Do not eat, drink, or smoke while handling chemicals',
          'Do not spray on flowering plants when bees are active',
          'Do not store pesticides near food or water',
          'Do not dispose chemicals in water bodies',
        ],
        doNotHi: [
          'बारिश या तेज हवा में स्प्रे न करें',
          'रसायनों को संभालते समय खाएं, पिएं या धूम्रपान न करें',
          'जब मधुमक्खियां सक्रिय हों तो फूल वाले पौधों पर स्प्रे न करें',
          'भोजन या पानी के पास कीटनाशकों का भंडारण न करें',
          'जलाशयों में रसायनों का निपटान न करें',
        ],
        doNotMr: [
          'पाऊस किंवा जोरदार वारा असताना फवारणी करू नका',
          'रसायने हाताळताना खाऊ, पिऊ किंवा धूम्रपान करू नका',
          'मधमाश्या सक्रिय असताना फुलांच्या वनस्पतींवर फवारणी करू नका',
          'अन्न किंवा पाण्याजवळ कीटकनाशके साठवू नका',
          'जलाशयांमध्ये रसायने टाकू नका',
        ],
      ),
    );
  }

  /// Get step icon based on type
  static IconData getStepIcon(TreatmentStepType type) {
    switch (type) {
      case TreatmentStepType.identifyArea:
        return Icons.search;
      case TreatmentStepType.prepareTools:
        return Icons.build;
      case TreatmentStepType.prepareSolution:
        return Icons.science;
      case TreatmentStepType.application:
        return Icons.air;
      case TreatmentStepType.soilTreatment:
        return Icons.grass;
      case TreatmentStepType.pruning:
        return Icons.content_cut;
      case TreatmentStepType.watering:
        return Icons.water_drop;
      case TreatmentStepType.safety:
        return Icons.health_and_safety;
      case TreatmentStepType.monitoring:
        return Icons.visibility;
      case TreatmentStepType.prevention:
        return Icons.shield;
    }
  }

  /// Get step color based on type
  static Color getStepColor(TreatmentStepType type) {
    switch (type) {
      case TreatmentStepType.identifyArea:
        return Colors.red;
      case TreatmentStepType.prepareTools:
        return Colors.brown;
      case TreatmentStepType.prepareSolution:
        return Colors.blue;
      case TreatmentStepType.application:
        return Colors.green;
      case TreatmentStepType.soilTreatment:
        return Colors.brown;
      case TreatmentStepType.pruning:
        return Colors.purple;
      case TreatmentStepType.watering:
        return Colors.cyan;
      case TreatmentStepType.safety:
        return Colors.orange;
      case TreatmentStepType.monitoring:
        return Colors.amber;
      case TreatmentStepType.prevention:
        return Colors.teal;
    }
  }

  /// Generate voice narration text for a step
  static String getVoiceNarration(ARTreatmentStep step, String languageCode) {
    final title = step.getTitle(languageCode);
    final description = step.getDescription(languageCode);
    return '$title. $description';
  }
}
