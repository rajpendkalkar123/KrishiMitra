import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;
import 'package:krishimitra/domain/models/models.dart';

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
    try {
      print('🤖 Getting detailed explanation from Gemini (lang: $language)...');
      
      const apiKey = 'AIzaSyCP9zWDvrUcrOSoFnDslAfUqLlH9e1ZS_I';
      const geminiUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

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

      final prompt = '''You are an expert plant pathologist and agricultural advisor. A farmer has detected a plant disease using AI.

**Detection Results:**
- Plant: $plant
- Disease: $disease
- Confidence: ${(confidence * 100).toStringAsFixed(1)}%

Please provide a comprehensive analysis in a clear, farmer-friendly format:

1. **Disease Overview**: What is $disease and how does it affect $plant plants?

2. **Symptoms to Look For**: What visual symptoms should the farmer check for to confirm this diagnosis?

3. **Causes**: What environmental or agricultural factors cause this disease?

4. **Immediate Actions**: What should the farmer do RIGHT NOW to prevent spread?

5. **Treatment Plan**: 
   - Organic/Natural remedies (if applicable)
   - Chemical treatments (specific fungicide/pesticide names)
   - Application method and frequency
   - Expected recovery timeline

6. **Prevention**: How to prevent this disease in the future?

7. **Impact on Crop**: If left untreated, what % of yield loss can be expected?

8. **Cost Estimate**: Approximate treatment cost for 1 acre

Keep the language simple and practical. Focus on actionable advice for Indian farmers.$langInstruction''';

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
                'maxOutputTokens': 2048,
              },
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['candidates'] != null && data['candidates'].isNotEmpty) {
          final text = data['candidates'][0]['content']['parts'][0]['text'];
          return text;
        } else {
          throw Exception('No response from Gemini');
        }
      } else {
        throw Exception('Gemini API error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error getting Gemini explanation: $e');
      // Return fallback explanation
      return _getFallbackExplanation(plant, disease, language);
    }
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
