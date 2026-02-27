import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Service for Sarvam AI Bulbul TTS (Marathi voice synthesis)
class SarvamTtsService {
  static const String _apiUrl = 'https://api.sarvam.ai/text-to-speech';
  static String get _apiKey => dotenv.env['SARVAM_API_KEY'] ?? '';
  static const int _maxCharsPerRequest = 500;

  /// Convert text to speech using Sarvam Bulbul v2
  ///
  /// Returns WAV audio bytes on success, null on failure.
  /// [text]: The Marathi text to synthesize
  /// [languageCode]: Language code (default: 'mr-IN')
  static Future<Uint8List?> synthesize(
    String text, {
    String languageCode = 'mr-IN',
    String speaker = 'anushka',
    String model = 'bulbul:v2',
    double pace = 1.0,
  }) async {
    if (_apiKey.isEmpty) {
      print('⚠️ Sarvam API key not set — skipping cloud TTS');
      return null;
    }

    try {
      // Truncate to max chars if needed
      final truncatedText = text.length > _maxCharsPerRequest
          ? text.substring(0, _maxCharsPerRequest)
          : text;

      print('🎙️ Requesting Sarvam TTS for ${truncatedText.length} chars...');

      final response = await http
          .post(
            Uri.parse(_apiUrl),
            headers: {
              'Content-Type': 'application/json',
              'api-subscription-key': _apiKey,
            },
            body: jsonEncode({
              'inputs': [truncatedText],
              'target_language_code': languageCode,
              'speaker': speaker,
              'model': model,
              'pace': pace,
              'enable_preprocessing': true,
            }),
          )
          .timeout(
            const Duration(seconds: 8),
            onTimeout: () {
              throw Exception('Sarvam TTS request timed out');
            },
          );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final audios = data['audios'] as List?;

        if (audios != null && audios.isNotEmpty) {
          final base64Audio = audios[0] as String;
          final audioBytes = base64Decode(base64Audio);
          print('✅ Sarvam TTS: received ${audioBytes.length} bytes of audio');
          return audioBytes;
        } else {
          print('❌ Sarvam TTS: no audio in response');
          return null;
        }
      } else {
        print('❌ Sarvam TTS error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Sarvam TTS exception: $e');
      return null;
    }
  }

  /// Check if the Sarvam API key is configured
  static bool get isConfigured => _apiKey.isNotEmpty;
}
