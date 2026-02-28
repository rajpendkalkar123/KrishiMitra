import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;
import 'package:krishimitra/domain/models/models.dart';
import 'package:krishimitra/utils/env_config.dart';

class DiseaseDetectionService {
  static const String _apiUrl =
      'https://krishimitra-plant-diesease.onrender.com/predict';
  static const Duration _timeout = Duration(
    seconds: 90,
  ); // Increased for cold start

  /// Upload image to the disease detection API and get prediction
  static Future<DiseaseResult> detectDisease(String imagePath) async {
    try {
      print('🌿 Uploading image to disease detection API...');
      print(
        '⏳ Note: First request may take 30-60 seconds as server wakes up...',
      );

      final file = File(imagePath);
      if (!await file.exists()) {
        throw Exception('Image file not found');
      }

      // Determine file extension and MIME type
      final extension = path.extension(imagePath).toLowerCase();
      String mimeType;

      switch (extension) {
        case '.jpg':
        case '.jpeg':
          mimeType = 'image/jpeg';
          break;
        case '.png':
          mimeType = 'image/png';
          break;
        default:
          mimeType = 'image/jpeg'; // Default to jpeg
      }

      print('📸 File extension: $extension, MIME type: $mimeType');

      // Create multipart request
      final request = http.MultipartRequest('POST', Uri.parse(_apiUrl));

      // Add the image file with proper content type
      request.files.add(
        await http.MultipartFile.fromPath(
          'file', // Field name expected by the API
          imagePath,
          contentType: MediaType.parse(mimeType),
        ),
      );

      print('📤 Sending request to API...');

      // Send request with extended timeout
      final streamedResponse = await request.send().timeout(
        _timeout,
        onTimeout: () {
          throw Exception(
            'Request timed out. The server may be sleeping - please try again in a moment.',
          );
        },
      );
      final response = await http.Response.fromStream(streamedResponse);

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Actual API response format:
        // {
        //   "plant": "Corn (maize)",
        //   "disease": "Northern Leaf Blight",
        //   "is_healthy": false,
        //   "confidence": 0.528587281703949,
        //   "raw_class": "Corn_(maize)___Northern_Leaf_Blight",
        //   "recommendation": "Disease detected..."
        // }

        final plant = data['plant'] as String? ?? 'Unknown';
        final disease = data['disease'] as String? ?? 'Unknown';
        final confidence = (data['confidence'] as num?)?.toDouble() ?? 0.0;
        final rawClass = data['raw_class'] as String? ?? '';
        final apiRecommendation = data['recommendation'] as String? ?? '';

        print(
          '✅ Detected: $plant - $disease (${(confidence * 100).toStringAsFixed(1)}%)',
        );

        // Create disease result
        return DiseaseResult(
          label: disease,
          plant: plant,
          confidence: confidence,
          remedy: apiRecommendation, // Initial recommendation from API
          rawPrediction: rawClass,
        );
      } else {
        throw Exception('API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ Error detecting disease: $e');
      rethrow;
    }
  }

  /// Get detailed explanation and remedy from Gemini AI
  /// [language] can be 'mr' (Marathi), 'hi' (Hindi), or 'en' (English)
  static Future<String> getGeminiExplanation({
    required String plant,
    required String disease,
    required double confidence,
    String language = 'mr',
  }) async {
    const maxAttempts = 3;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final apiKey = EnvConfig.geminiApiKey;
        print('🤖 Getting explanation from Gemini (lang: $language, attempt: $attempt)...');
        
        const geminiUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

        // Language instruction appended to the prompt
        String langInstruction;
        switch (language) {
          case 'mr':
            langInstruction = '\n\nIMPORTANT: कृपया संपूर्ण उत्तर मराठीत द्या. महाराष्ट्रातील शेतकऱ्यांसाठी सोप्या व समजण्यायोग्य भाषेत लिहा. Use Devanagari script only.';
            break;
          case 'hi':
            langInstruction = '\n\nIMPORTANT: कृपया पूरा उत्तर हिंदी में दें। भारतीय किसानों के लिए सरल भाषा में लिखें। Use Devanagari script only.';
            break;
          default:
            langInstruction = '';
        }

        final prompt = '''You are an expert plant pathologist. A farmer detected "$disease" on "$plant" (${(confidence * 100).toStringAsFixed(1)}% confidence).

You MUST cover ALL 5 sections below. Do NOT stop early. Every section is MANDATORY. Keep each bullet point to ONE short sentence only. Be concise and summarized — no lengthy explanations. Use bullet points.

**1. Disease Identification**
- Disease Name
- Severity Level (Low / Moderate / High)
- Affected Crop Stage

**2. Disease Explanation**
- What the disease is
- Causes of the disease
- How it spreads
- Impact if left untreated (yield loss %)

**3. Immediate Action Required**
- First action to take immediately
- Isolation or removal instructions (if required)
- Urgency level (Immediate / Within 24hrs / Within a week)

**4. Treatment Recommendation**
**A. Chemical Treatment**
- Recommended pesticide/fungicide name (SPECIFIC Indian brand name e.g. Bavistin, Mancozeb, Dithane M-45, Ridomil Gold)
- Dosage per liter
- Mixing ratio
- Total quantity required per acre
- Spray method
- Spray frequency
- Best time of application

**B. Organic / Low-Cost Alternative (if available)**
- Materials required
- Preparation steps
- Application method
- Expected effectiveness

**5. Nearby Agri-Store Locator**
- Recommended product name to purchase
- Type of product (pesticide/fungicide/nutrient)
- Suggest common agri-store chains or local Krishi Seva Kendra
- What to ask for at the store

IMPORTANT: You MUST include ALL 5 sections. Do NOT stop after section 2. Summarize each point — keep every bullet to 1 short sentence max. Be SPECIFIC to "$disease" on "$plant". No generic advice.$langInstruction''';

        final response = await http
            .post(
              Uri.parse('$geminiUrl?key=$apiKey'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'contents': [
                  {
                    'parts': [
                      {'text': prompt},
                    ],
                  },
                ],
                'generationConfig': {
                  'temperature': 0.7,
                  'topK': 40,
                  'topP': 0.95,
                  'maxOutputTokens': 4096,
                },
              }),
            )
            .timeout(const Duration(seconds: 45));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);

          if (data['candidates'] != null && data['candidates'].isNotEmpty) {
            final text = data['candidates'][0]['content']['parts'][0]['text'];
            if (text != null && text.toString().trim().isNotEmpty) {
              print('✅ Got Gemini explanation for $disease on $plant');
              return text;
            }
          }
          throw Exception('Empty response from Gemini');
        } else if (response.statusCode == 429 || response.statusCode == 403) {
          // Rate limited or key issue - rotate to backup key
          print('⚠️ API key issue (${response.statusCode}), retrying...');
          await Future.delayed(const Duration(seconds: 2));
          continue;
        } else if (response.statusCode >= 500) {
          // Server error - retry with same key first, then rotate
          print('⚠️ Gemini server error ${response.statusCode}');
          await Future.delayed(const Duration(seconds: 2));
          continue;
        } else {
          print('⚠️ Gemini API error: ${response.statusCode} - ${response.body.length > 200 ? response.body.substring(0, 200) : response.body}');
          await Future.delayed(const Duration(seconds: 1));
          continue;
        }
      } catch (e) {
        print('❌ Error getting Gemini explanation (attempt $attempt): $e');
        if (attempt >= maxAttempts) {
          return _getFallbackExplanation(plant, disease, language);
        }
        await Future.delayed(const Duration(seconds: 1));
      }
    }
    // Should not reach here, but just in case
    return _getFallbackExplanation(plant, disease, language);
  }

  static String _getFallbackExplanation(String plant, String disease, [String language = 'mr']) {
    if (language == 'mr') {
      if (disease.toLowerCase().contains('healthy')) {
        return '''✅ **चांगली बातमी!** तुमची $plant वनस्पती निरोगी दिसते!

**निरोगी ठेवण्यासाठी:**
• नियमित पाणी द्या.
• पुरेसा सूर्यप्रकाश मिळवा.
• पानांचा रंग व गुणवत्ता तपासत राहा.
• दर महिन्याला संतुलित खत द्या.
• वनस्पतींच्या आसपास स्वच्छता ठेवा.

**प्रतिबंधात्मक उपाय:**
• दर आठवड्याला रोग तपासणी करा.
• जास्त पाणी देणे टाळा.
• हवा खेळण्यासाठी पुरेसे अंतर ठेवा.
• सुकलेली पाने लगेच काढा.''';
      }
      return '''⚠️ **$plant मध्ये $disease आढळले.**

**तात्काळ कृती:**
1. बाधित वनस्पती वेगळ्या करा.
2. गंभीरपणे बाधित पाने आणि भाग काढा.
3. वरून पाणी देणे टाळा.
4. हवा खेळती ठेवा.

**उपचार:**
• योग्य बुरशीनाशक आणि कीटकनाशक वापरा.
• कडुनिंबाचे तेल सेंद्रिय पर्याय म्हणून वापरा.
• सकाळी लवकर किंवा संध्याकाळी फवारणी करा.
• 3 ते 4 आठवडे दर आठवड्याला उपचार करा.

**प्रतिबंध:**
• दरवर्षी पीक बदला.
• रोग-प्रतिरोधक वाण वापरा.
• कंपोस्ट खत वापरून मातीचे आरोग्य राखा.

**निरीक्षण:**
दर 2 ते 3 दिवसांनी सुधारणा किंवा प्रसार तपासा.

⚕️ आपल्या भागासाठी विशिष्ट कीटकनाशक शिफारसींसाठी स्थानिक कृषी कार्यालयाशी संपर्क साधा.''';
    }

    // English/Hindi fallback
    if (disease.toLowerCase().contains('healthy')) {
      return '''✅ **Good News!** Your $plant plant appears healthy!

**Maintain Good Health:**
• Continue regular watering schedule.
• Ensure adequate sunlight.
• Monitor for any changes in leaf color or texture.
• Apply balanced fertilizer monthly.
• Keep the area around plants clean.

**Prevention Tips:**
• Inspect plants weekly for early disease detection.
• Avoid overwatering to prevent fungal issues.
• Maintain proper spacing for air circulation.
• Remove dead leaves promptly.''';
    }

    return '''⚠️ **$disease Detected in $plant.**

**Immediate Actions:**
1. Isolate affected plants if possible.
2. Remove severely infected leaves and parts.
3. Avoid overhead watering.
4. Improve air circulation.

**Treatment:**
• Apply appropriate fungicide or pesticide.
• Use neem oil as organic alternative.
• Spray in early morning or late evening.
• Repeat treatment weekly for 3 to 4 weeks.

**Prevention:**
• Rotate crops annually.
• Use disease-resistant varieties.
• Maintain soil health with compost.
• Avoid working with wet plants.

**Monitoring:**
Check plants every 2 to 3 days for improvement or spread.

⚕️ Consult local agricultural extension office for specific pesticide recommendations for your region.''';
  }
}
