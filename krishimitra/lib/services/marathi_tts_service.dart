import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:krishimitra/services/sarvam_tts_service.dart';

/// Orchestrator TTS service: Sarvam AI (primary) → flutter_tts (fallback)
class MarathiTtsService {
  static final FlutterTts _flutterTts = FlutterTts();
  static final AudioPlayer _audioPlayer = AudioPlayer();
  static bool _initialized = false;
  static bool _isSpeaking = false;
  static String? _currentAudioPath;
  // Multi-chunk streaming state
  static List<Uint8List> _remainingAudio = [];
  static bool _remainingReady = false;
  static bool _remainingFailed = false;
  static bool _hasRemainingToPlay = false;
  // Callback to notify UI of state changes
  static void Function(bool speaking)? onSpeakingChanged;

  /// Initialize flutter_tts for Marathi
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      final isAvailable = await _flutterTts.isLanguageAvailable('mr-IN');
      if (isAvailable) {
        await _flutterTts.setLanguage('mr-IN');
        print('✅ flutter_tts: Marathi (mr-IN) is available (fallback ready)');
      } else {
        final isMrAvailable = await _flutterTts.isLanguageAvailable('mr');
        if (isMrAvailable) {
          await _flutterTts.setLanguage('mr');
          print('✅ flutter_tts: Marathi (mr) is available (fallback ready)');
        } else {
          print('⚠️ flutter_tts: Marathi voice pack not installed on device');
        }
      }

      await _flutterTts.setSpeechRate(0.45);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
        onSpeakingChanged?.call(false);
      });

      _flutterTts.setErrorHandler((msg) {
        print('❌ flutter_tts error: $msg');
        _isSpeaking = false;
        onSpeakingChanged?.call(false);
      });

      // Audio player completion → handle remaining chunks or finish
      _audioPlayer.onPlayerComplete.listen((_) async {
        if (_hasRemainingToPlay) {
          _hasRemainingToPlay = false;
          if (_remainingReady && _remainingAudio.isNotEmpty && _isSpeaking) {
            print('🔊 Playing remaining ${_remainingAudio.length} chunks...');
            if (_remainingAudio.length == 1) {
              await _playSarvamAudio(_remainingAudio.first);
            } else {
              final combined = _combineWavAudio(_remainingAudio);
              if (combined != null) {
                await _playSarvamAudio(combined);
              } else {
                _isSpeaking = false;
                onSpeakingChanged?.call(false);
              }
            }
            return;
          } else if (!_remainingReady && !_remainingFailed && _isSpeaking) {
            // Still synthesizing — wait and play
            _waitAndPlayRemaining();
            return;
          }
        }
        print('✅ Sarvam audio playback completed');
        _isSpeaking = false;
        onSpeakingChanged?.call(false);
      });

      _initialized = true;
    } catch (e) {
      print('❌ MarathiTtsService init error: $e');
    }
  }

  /// Strip markdown and newlines for TTS (Sarvam stops at newlines)
  static String _cleanTextForTts(String text) {
    String cleaned = text;
    cleaned = cleaned.replaceAll('**', '');
    cleaned = cleaned.replaceAll('*', '');
    cleaned = cleaned.replaceAll('#', '');
    cleaned = cleaned.replaceAll('•', '');
    cleaned = cleaned.replaceAll('⚠️', '');
    cleaned = cleaned.replaceAll('✅', '');
    cleaned = cleaned.replaceAll('⚕️', '');
    cleaned = cleaned.replaceAll('🌿', '');
    cleaned = cleaned.replaceAll('🤖', '');
    cleaned = cleaned.replaceAll('💧', '');
    cleaned = cleaned.replaceAll('🌱', '');
    cleaned = cleaned.replaceAll('📸', '');
    cleaned = cleaned.replaceAll('💰', '');
    cleaned = cleaned.replaceAll('🔬', '');
    cleaned = cleaned.replaceAll('🧪', '');
    cleaned = cleaned.replaceAll('🌤️', '');
    // CRITICAL: Replace ALL newlines with spaces so Sarvam reads full text
    cleaned = cleaned.replaceAll('\r\n', ' ');
    cleaned = cleaned.replaceAll('\n', ' ');
    cleaned = cleaned.replaceAll('\r', ' ');
    // Collapse multiple spaces
    while (cleaned.contains('  ')) {
      cleaned = cleaned.replaceAll('  ', ' ');
    }
    return cleaned.trim();
  }

  /// Speak Marathi text: Sarvam AI primary → flutter_tts fallback
  static Future<void> speak(String marathiText) async {
    if (!_initialized) await initialize();

    // Stop any current playback
    await stop();

    // Clean markdown formatting
    final cleanedText = _cleanTextForTts(marathiText);
    print('🎙️ TTS input: ${cleanedText.length} chars (cleaned from ${marathiText.length})');

    _isSpeaking = true;

    // ========== PRIMARY: Sarvam AI TTS ==========
    if (SarvamTtsService.isConfigured) {
      try {
        print('🎙️ [PRIMARY] Trying Sarvam AI TTS...');

        // Chunk text to max 500 chars for Sarvam API
        final chunks = _chunkText(cleanedText, 490);
        print('🎙️ Split into ${chunks.length} chunks');

        if (chunks.isEmpty) {
          await _speakWithFlutterTts(cleanedText);
          return;
        }

        // OPTIMIZATION: Synthesize and play FIRST chunk immediately
        // while synthesizing remaining chunks in background
        print('🎙️ Synthesizing chunk 1/${chunks.length} (fast start)...');
        final firstAudio = await SarvamTtsService.synthesize(chunks[0]);

        if (firstAudio == null || firstAudio.isEmpty || !_isSpeaking) {
          print('⚠️ First chunk failed, falling back to flutter_tts');
          await _speakWithFlutterTts(cleanedText);
          return;
        }

        print('✅ Chunk 1: received ${firstAudio.length} bytes — playing immediately');

        if (chunks.length == 1) {
          // Single chunk — just play it
          final played = await _playSarvamAudio(firstAudio);
          if (played) return;
          await _speakWithFlutterTts(cleanedText);
          return;
        }

        // Multiple chunks: play first now, synthesize rest in background
        _remainingAudio = [];
        _remainingReady = false;
        _remainingFailed = false;
        _hasRemainingToPlay = true;

        // Start background synthesis of remaining chunks
        _synthesizeRemaining(chunks, _remainingAudio).then((_) {
          _remainingReady = true;
          print('✅ All remaining ${chunks.length - 1} chunks synthesized');
        }).catchError((e) {
          print('⚠️ Background synthesis failed: $e');
          _remainingFailed = true;
        });

        // Play first chunk immediately — global listener handles the rest
        onSpeakingChanged?.call(true);
        await _playSarvamAudio(firstAudio);
        return;
      } catch (e) {
        print('⚠️ Sarvam TTS failed: $e, falling back to device TTS');
        await _speakWithFlutterTts(cleanedText);
      }
      return;
    }

    // ========== FALLBACK: flutter_tts ==========
    await _speakWithFlutterTts(cleanedText);
  }

  /// Synthesize chunks 1..N in background (chunk 0 is already playing)
  static Future<void> _synthesizeRemaining(List<String> chunks, List<Uint8List> output) async {
    for (int i = 1; i < chunks.length; i++) {
      if (!_isSpeaking) return;
      print('🎙️ [BG] Synthesizing chunk ${i + 1}/${chunks.length}: ${chunks[i].length} chars');
      final audioBytes = await SarvamTtsService.synthesize(chunks[i]);
      if (audioBytes != null && audioBytes.isNotEmpty) {
        output.add(audioBytes);
        print('✅ [BG] Chunk ${i + 1}: ${audioBytes.length} bytes');
      } else {
        throw Exception('Chunk ${i + 1} synthesis failed');
      }
    }
  }

  /// Wait for background synthesis to finish, then play remaining audio
  static Future<void> _waitAndPlayRemaining() async {
    // Poll every 500ms for up to 30s
    for (int i = 0; i < 60; i++) {
      if (!_isSpeaking) return;
      await Future.delayed(const Duration(milliseconds: 500));
      if (_remainingReady) {
        if (_remainingAudio.isNotEmpty) {
          if (_remainingAudio.length == 1) {
            await _playSarvamAudio(_remainingAudio.first);
          } else {
            final combined = _combineWavAudio(_remainingAudio);
            if (combined != null) {
              await _playSarvamAudio(combined);
            }
          }
        } else {
          _isSpeaking = false;
          onSpeakingChanged?.call(false);
        }
        return;
      }
      if (_remainingFailed) {
        _isSpeaking = false;
        onSpeakingChanged?.call(false);
        return;
      }
    }
    // Timeout
    print('⚠️ Background synthesis timed out');
    _isSpeaking = false;
    onSpeakingChanged?.call(false);
  }

  /// Combine multiple WAV audio byte arrays into one
  /// WAV format: 44-byte header + PCM data
  static Uint8List? _combineWavAudio(List<Uint8List> audioChunks) {
    if (audioChunks.isEmpty) return null;
    if (audioChunks.length == 1) return audioChunks.first;

    try {
      // WAV header is 44 bytes; PCM data starts at byte 44
      const headerSize = 44;

      // Calculate total PCM data size
      int totalPcmSize = 0;
      for (final chunk in audioChunks) {
        if (chunk.length > headerSize) {
          totalPcmSize += chunk.length - headerSize;
        }
      }

      // Take header from first chunk, append all PCM data
      final header = audioChunks.first.sublist(0, headerSize);
      final combined = BytesBuilder();
      combined.add(header);

      for (final chunk in audioChunks) {
        if (chunk.length > headerSize) {
          combined.add(chunk.sublist(headerSize));
        }
      }

      final result = combined.toBytes();

      // Update WAV header with correct sizes
      // Bytes 4-7: ChunkSize = file size - 8
      final chunkSize = result.length - 8;
      result[4] = chunkSize & 0xFF;
      result[5] = (chunkSize >> 8) & 0xFF;
      result[6] = (chunkSize >> 16) & 0xFF;
      result[7] = (chunkSize >> 24) & 0xFF;

      // Bytes 40-43: Subchunk2Size = total PCM data size
      result[40] = totalPcmSize & 0xFF;
      result[41] = (totalPcmSize >> 8) & 0xFF;
      result[42] = (totalPcmSize >> 16) & 0xFF;
      result[43] = (totalPcmSize >> 24) & 0xFF;

      print('✅ Combined ${audioChunks.length} WAV chunks: ${result.length} bytes total');
      return result;
    } catch (e) {
      print('❌ Error combining WAV audio: $e');
      return audioChunks.first; // fallback to first chunk
    }
  }

  /// Speak using flutter_tts (fallback)
  static Future<void> _speakWithFlutterTts(String text) async {
    try {
      print('📱 [FALLBACK] Using flutter_tts with mr-IN...');
      await _flutterTts.setLanguage('mr-IN');
      await _flutterTts.setSpeechRate(0.45);
      await _flutterTts.awaitSpeakCompletion(true);
      await _flutterTts.speak(text);
      // Completion handler will set _isSpeaking = false
    } catch (e) {
      print('❌ flutter_tts failed: $e');
      _isSpeaking = false;
      onSpeakingChanged?.call(false);
    }
  }

  /// Play audio bytes using audioplayers
  static Future<bool> _playSarvamAudio(Uint8List audioBytes) async {
    try {
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/sarvam_tts_output.wav';
      final file = File(filePath);
      await file.writeAsBytes(audioBytes);
      _currentAudioPath = filePath;

      print('🔊 Playing Sarvam audio: ${audioBytes.length} bytes');
      await _audioPlayer.play(DeviceFileSource(filePath));
      return true;
    } catch (e) {
      print('❌ Error playing Sarvam audio: $e');
      return false;
    }
  }

  /// Break text into chunks at sentence boundaries (max chars each)
  static List<String> _chunkText(String text, int maxLen) {
    if (text.length <= maxLen) return [text];

    final chunks = <String>[];
    // Split by sentences (period, Devanagari danda, question mark, newline)
    final sentences = text.split(RegExp(r'(?<=[.।?\n])\s*'));
    String current = '';

    for (final sentence in sentences) {
      if (sentence.isEmpty) continue;
      if ((current.length + sentence.length + 1) > maxLen && current.isNotEmpty) {
        chunks.add(current.trim());
        current = sentence;
      } else {
        current += (current.isEmpty ? '' : ' ') + sentence;
      }
    }
    if (current.isNotEmpty) chunks.add(current.trim());

    // If any chunk is still > maxLen, hard split
    final result = <String>[];
    for (final chunk in chunks) {
      if (chunk.length <= maxLen) {
        result.add(chunk);
      } else {
        for (int i = 0; i < chunk.length; i += maxLen) {
          result.add(chunk.substring(i, i + maxLen > chunk.length ? chunk.length : i + maxLen));
        }
      }
    }

    return result;
  }

  /// Stop current playback
  static Future<void> stop() async {
    _isSpeaking = false;

    try { await _audioPlayer.stop(); } catch (_) {}
    try { await _flutterTts.stop(); } catch (_) {}

    if (_currentAudioPath != null) {
      try {
        final file = File(_currentAudioPath!);
        if (await file.exists()) await file.delete();
      } catch (_) {}
      _currentAudioPath = null;
    }
  }

  /// Check if currently speaking
  static bool get isSpeaking => _isSpeaking;

  /// Check if Marathi TTS is available
  static Future<bool> isMarathiAvailable() async {
    if (SarvamTtsService.isConfigured) return true;
    try {
      final isAvailable = await _flutterTts.isLanguageAvailable('mr-IN');
      return isAvailable == true;
    } catch (e) {
      return false;
    }
  }
}
