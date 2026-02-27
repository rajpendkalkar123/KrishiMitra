import 'dart:io';

/// Simple .env loader for keeping API keys out of source code.
/// Reads key=value pairs from the .env file in the project root.
class EnvConfig {
  static final Map<String, String> _cache = {};
  static bool _loaded = false;

  /// Load .env file. Safe to call multiple times.
  static Future<void> load() async {
    if (_loaded) return;
    try {
      // Try finding .env relative to the executable or working directory
      final candidates = [File('.env'), File('assets/.env')];
      for (final f in candidates) {
        if (await f.exists()) {
          final lines = await f.readAsLines();
          for (final line in lines) {
            final trimmed = line.trim();
            if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
            final idx = trimmed.indexOf('=');
            if (idx > 0) {
              final key = trimmed.substring(0, idx).trim();
              final val = trimmed.substring(idx + 1).trim();
              _cache[key] = val;
            }
          }
          break;
        }
      }
    } catch (e) {
      // silently ignore - will use fallbacks
    }
    _loaded = true;
  }

  /// Get a value from .env or from platform environment.
  static String get(String key, {String fallback = ''}) {
    return _cache[key] ?? Platform.environment[key] ?? fallback;
  }

  static String get geminiApiKey => get('GEMINI_API_KEY');
  static String get sarvamApiKey => get('SARVAM_API_KEY');
}
