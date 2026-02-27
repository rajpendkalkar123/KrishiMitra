/// Supported languages in KrishiMitra
enum AppLanguage { english, hindi, marathi }

class AppStrings {
  static AppLanguage _language = AppLanguage.marathi; // Marathi is primary

  static void setLanguage(AppLanguage language) {
    _language = language;
  }

  /// Backward-compatible setter for existing code
  static void setLanguageLegacy(bool isHindi) {
    _language = isHindi ? AppLanguage.hindi : AppLanguage.english;
  }

  static AppLanguage get language => _language;

  /// Backward-compatible getter — returns true for Hindi
  static bool get isHindi => _language == AppLanguage.hindi;

  /// Returns true for Marathi
  static bool get isMarathi => _language == AppLanguage.marathi;

  /// Get language code for API calls ('en', 'hi', 'mr')
  static String get languageCode {
    switch (_language) {
      case AppLanguage.marathi:
        return 'mr';
      case AppLanguage.hindi:
        return 'hi';
      case AppLanguage.english:
        return 'en';
    }
  }

  /// Helper for 3-way string selection
  static String _t(String en, String hi, String mr) {
    switch (_language) {
      case AppLanguage.marathi:
        return mr;
      case AppLanguage.hindi:
        return hi;
      case AppLanguage.english:
        return en;
    }
  }

  static String get appTitle => _t('KrishiMitra', 'कृषि मित्र', 'कृषी मित्र');

  static String get navHome => _t('Home', 'घर', 'मुख्यपृष्ठ');
  static String get navMonitor => _t('Monitor', 'निगरानी', 'निरीक्षण');
  static String get navScan => _t('Scan', 'स्कैन', 'स्कॅन');
  static String get navProfile => _t('Profile', 'प्रोफाइल', 'प्रोफाइल');

  static String get analyzeAndAct =>
      _t('Analyse & Act', 'विश्लेषण और कार्रवाई', 'विश्लेषण आणि कृती');
  static String get weatherCard => _t('Weather', 'मौसम', 'हवामान');
  static String get temperature => _t('Temperature', 'तापमान', 'तापमान');
  static String get heatWaveAlert =>
      _t('Heat Wave Alert', 'लू की चेतावनी', 'उष्णतेची लाट इशारा');
  static String get heatWaveMessage =>
      _t('Alert! Temperature exceeds 35°C', 'सावधान! 35°C से अधिक तापमान',
          'सावधान! तापमान ३५°C पेक्षा जास्त');
  static String get precipitation => _t('Precipitation', 'वर्षा', 'पाऊस');
  static String get waterSaved =>
      _t('Water Saved', 'पानी बचाया गया', 'पाणी वाचले');

  static String get irrigationPanel =>
      _t('Irrigation Panel', 'सिंचाई पैनल', 'सिंचन पॅनेल');
  static String get soilMoisture =>
      _t('Soil Moisture', 'मिट्टी की नमी', 'मातीतील ओलावा');
  static String get startPump =>
      _t('Start Pump', 'पंप शुरू करें', 'पंप सुरू करा');
  static String get stopPump =>
      _t('Stop Pump', 'पंप बंद करें', 'पंप बंद करा');
  static String get pumpRunning =>
      _t('Pump Running', 'पंप चल रहा है', 'पंप चालू आहे');
  static String get irrigationAlert =>
      _t('Irrigation Alert', 'सिंचाई सतर्कता', 'सिंचन सतर्कता');
  static String get drySoilAlert => _t(
      'Soil is dry and no rain forecast',
      'मिट्टी सूखी है और बारिश संभव नहीं है',
      'माती कोरडी आहे आणि पावसाचा अंदाज नाही');
  static String get overWaterAlert => _t(
      'Soil is over-watered', 'मिट्टी अत्यधिक गीली है', 'माती जास्त ओली आहे');

  static String get fertilizerRecommender =>
      _t('Fertilizer Recommender', 'खाद सिफारिश', 'खत शिफारस');
  static String get nitrogen =>
      _t('Nitrogen (N)', 'नाइट्रोजन', 'नायट्रोजन (N)');
  static String get phosphorus =>
      _t('Phosphorus (P)', 'फॉस्फोरस', 'फॉस्फरस (P)');
  static String get potassium =>
      _t('Potassium (K)', 'पोटेशियम', 'पोटॅशियम (K)');
  static String get recommendation =>
      _t('Recommendation', 'सिफारिश', 'शिफारस');
  static String get noMatch =>
      _t('No match found', 'कोई मेल नहीं मिला', 'जुळणी सापडली नाही');

  static String get diseaseDetection =>
      _t('Disease Detection', 'रोग पहचान', 'रोग ओळख');
  static String get drLeaf => _t('Dr. Leaf', 'डॉक्टर लीफ', 'डॉ. पान');
  static String get scanPlant =>
      _t('Scan Plant', 'पौधे को स्कैन करें', 'वनस्पती स्कॅन करा');
  static String get disease => _t('Disease', 'रोग', 'रोग');
  static String get confidence =>
      _t('Confidence', 'विश्वसनीयता', 'विश्वासार्हता');
  static String get cameraPermissionRequired => _t(
      'Camera permission required',
      'कैमरा अनुमति आवश्यक है',
      'कॅमेरा परवानगी आवश्यक');
  static String get processingImage =>
      _t('Processing image...', 'छवि प्रसंस्करण...', 'प्रतिमा प्रक्रिया...');

  static String get listeningToVoice =>
      _t('Listening to voice...', 'वॉयस सुन रहे हैं...', 'आवाज ऐकत आहे...');
  static String get voiceCommand =>
      _t('Voice Command', 'वॉयस कमांड', 'आवाज आदेश');
  static String get waterCommand =>
      _t('Water|Paani', 'पानी|Paani', 'पाणी|Paani');
  static String get doctorCommand =>
      _t('Doctor|Rog', 'डॉक्टर|Rog', 'डॉक्टर|Rog');
  static String get statusCommand => _t('Status', 'स्थिति|Status', 'स्थिती');

  static String get farmerProfile =>
      _t('Farmer Profile', 'किसान प्रोफाइल', 'शेतकरी प्रोफाइल');
  static String get farmHealth =>
      _t('Farm Health', 'खेत का स्वास्थ्य', 'शेताचे आरोग्य');
  static String get location => _t('Location', 'स्थान', 'स्थान');

  static String get ok => _t('OK', 'ठीक है', 'ठीक आहे');
  static String get cancel => _t('Cancel', 'रद्द करें', 'रद्द करा');
  static String get apply => _t('Apply', 'लागू करें', 'लागू करा');
  static String get save => _t('Save', 'सहेजें', 'जतन करा');

  // New strings for TTS feature
  static String get listenInMarathi => _t('Listen', 'सुनें', '🔊 ऐका');
  static String get stopListening =>
      _t('Stop', 'रोकें', 'थांबा');
  static String get aiExpertAdvice =>
      _t('🤖 AI Expert Advice', '🤖 AI विशेषज्ञ सलाह', '🤖 AI तज्ञ सल्ला');
  static String get loadingExplanation => _t(
      '🤖 Getting AI expert advice...',
      '🤖 AI विशेषज्ञ सलाह प्राप्त हो रही है...',
      '🤖 AI तज्ञ सल्ला मिळवत आहे...');
}
