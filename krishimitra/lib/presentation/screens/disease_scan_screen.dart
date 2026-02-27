import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:async';
import 'package:krishimitra/services/disease_detection_service.dart';
import 'package:krishimitra/services/esp32_camera_service.dart';
import 'package:krishimitra/services/marathi_tts_service.dart';
import 'package:krishimitra/domain/models/models.dart';
import 'package:krishimitra/utils/app_strings.dart';
import 'package:krishimitra/utils/app_theme.dart';

class DiseaseScanScreen extends StatefulWidget {
  const DiseaseScanScreen({super.key});

  @override
  State<DiseaseScanScreen> createState() => _DiseaseScanScreenState();
}

class _DiseaseScanScreenState extends State<DiseaseScanScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  bool _isProcessing = false;
  DiseaseResult? _result;
  String? _errorMessage;
  String? _geminiExplanation;
  bool _loadingExplanation = false;
  bool _isTtsSpeaking = false;
  final TextEditingController _esp32UrlController = TextEditingController(
    text: 'http://192.168.206.36/capture', // Default ESP32 camera URL
  );

  // ESP32 Auto-Capture variables
  Timer? _esp32Timer;
  bool _isESP32Active = false;
  String? _activeESP32Url;
  int _capturedImageCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCapturedImageCount();
    // Register TTS callback so button stays in sync with actual playback
    MarathiTtsService.onSpeakingChanged = (speaking) {
      if (mounted) setState(() => _isTtsSpeaking = speaking);
    };
  }

  @override
  void dispose() {
    _esp32UrlController.dispose();
    _stopESP32Capture();
    MarathiTtsService.onSpeakingChanged = null;
    MarathiTtsService.stop();
    super.dispose();
  }

  Future<void> _loadCapturedImageCount() async {
    final count = await ESP32CameraService.getImageCount();
    setState(() {
      _capturedImageCount = count;
    });
  }

  Future<void> _startESP32Capture() async {
    try {
      // Show dialog to enter/confirm ESP32 URL
      final url = await showDialog<String>(
        context: context,
        builder: (context) => _buildESP32UrlDialog(),
      );

      if (url == null || url.isEmpty) return;

      setState(() {
        _isESP32Active = true;
        _activeESP32Url = url;
      });

      // Start periodic capture every 5 seconds
      _esp32Timer = Timer.periodic(const Duration(seconds: 5), (timer) {
        _captureFromESP32Silent();
      });

      // Capture first image immediately
      _captureFromESP32Silent();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppStrings.isHindi
                  ? '✅ ESP32 कैप्चर शुरू हो गया - हर 5 सेकंड'
                  : '✅ ESP32 capture started - every 5 seconds',
            ),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'ESP32 Start Error: $e';
        _isESP32Active = false;
      });
    }
  }

  void _stopESP32Capture() {
    _esp32Timer?.cancel();
    setState(() {
      _isESP32Active = false;
      _activeESP32Url = null;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.isHindi
                ? '⏹️ ESP32 कैप्चर बंद हो गया'
                : '⏹️ ESP32 capture stopped',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _captureFromESP32Silent() async {
    if (!_isESP32Active || _activeESP32Url == null) return;

    try {
      final imagePath = await ESP32CameraService.captureImage(_activeESP32Url!);

      if (imagePath != null) {
        await _loadCapturedImageCount();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppStrings.isHindi
                    ? '📸 छवि कैप्चर हो गई ($_capturedImageCount)'
                    : '📸 Image captured ($_capturedImageCount)',
              ),
              duration: const Duration(seconds: 1),
              backgroundColor: AppTheme.primaryGreen,
            ),
          );
        }
      }
    } catch (e) {
      print('Silent capture error: $e');
    }
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (photo != null) {
        setState(() {
          _selectedImage = File(photo.path);
          _result = null;
          _geminiExplanation = null;
          _errorMessage = null;
        });
        await _analyzeImage();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error accessing camera: $e';
      });
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _result = null;
          _geminiExplanation = null;
          _errorMessage = null;
        });
        await _analyzeImage();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error selecting image: $e';
      });
    }
  }

  Future<void> _showCapturedImagesGallery() async {
    final images = await ESP32CameraService.getAllImages();

    if (!mounted) return;

    if (images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.isHindi
                ? 'कोई कैप्चर की गई छवियां नहीं'
                : 'No captured images',
          ),
        ),
      );
      return;
    }

    final selectedImage = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildGalleryBottomSheet(images),
    );

    if (selectedImage != null) {
      setState(() {
        _selectedImage = File(selectedImage['filePath'] as String);
        _result = null;
        _geminiExplanation = null;
        _errorMessage = null;
      });
      await _analyzeImage();

      // Mark as analyzed after analysis
      if (_result != null) {
        await ESP32CameraService.markImageAnalyzed(
          selectedImage['id'] as String,
          {
            'plant': _result!.plant,
            'disease': _result!.label,
            'confidence': _result!.confidence,
            'remedy': _result!.remedy,
          },
        );
      }
    }
  }

  Future<void> _analyzeImage() async {
    if (_selectedImage == null) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      // Step 1: Get disease prediction from API
      final result = await DiseaseDetectionService.detectDisease(
        _selectedImage!.path,
      );

      setState(() {
        _result = result;
        _isProcessing = false;
      });

      // Step 2: Get detailed explanation from Gemini
      if (result.confidence > 0.5) {
        _getGeminiExplanation();
      }
    } catch (e) {
      String errorMsg = e.toString();

      // Make error messages more user-friendly
      if (errorMsg.contains('timeout') || errorMsg.contains('Timeout')) {
        errorMsg =
            AppStrings.isHindi
                ? 'समय समाप्त: सर्वर सो रहा था। कृपया फिर से प्रयास करें (अब यह तेज होगा)'
                : 'Timeout: Server was sleeping. Please retry (it will be faster now)';
      } else if (errorMsg.contains('SocketException') ||
          errorMsg.contains('network')) {
        errorMsg =
            AppStrings.isHindi
                ? 'नेटवर्क त्रुटि: कृपया अपना इंटरनेट कनेक्शन जांचें'
                : 'Network error: Please check your internet connection';
      }

      setState(() {
        _errorMessage = errorMsg;
        _isProcessing = false;
      });
    }
  }

  Future<void> _getGeminiExplanation() async {
    if (_result == null) return;

    setState(() {
      _loadingExplanation = true;
    });

    try {
      final explanation = await DiseaseDetectionService.getGeminiExplanation(
        plant: _result!.plant ?? 'Unknown',
        disease: _result!.label,
        confidence: _result!.confidence,
        language: AppStrings.languageCode,
      );

      setState(() {
        _geminiExplanation = explanation;
        _loadingExplanation = false;
      });
    } catch (e) {
      print('Error getting explanation: $e');
      setState(() {
        _loadingExplanation = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.diseaseDetection),
        backgroundColor: AppTheme.primaryGreen,
      ),
      body: _errorMessage != null ? _buildErrorView() : _buildMainView(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 80, color: AppTheme.alertRed),
            const SizedBox(height: 24),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                });
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainView() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Scan Options Card
          _buildScanOptionsCard(),

          // Selected Image Preview
          if (_selectedImage != null) _buildImagePreview(),

          // Processing Indicator
          if (_isProcessing) _buildProcessingIndicator(),

          // Result Card
          if (_result != null && !_isProcessing) _buildResultCard(),

          // Gemini Explanation
          if (_geminiExplanation != null) _buildGeminiExplanationCard(),

          // Loading explanation indicator
          if (_loadingExplanation) _buildLoadingExplanation(),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildScanOptionsCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryGreen,
            AppTheme.primaryGreen.withOpacity(0.8),
          ],
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
          const Icon(Icons.local_hospital, size: 48, color: Colors.white),
          const SizedBox(height: 16),
          Text(
            AppStrings.isHindi
                ? '🌿 पौधे की बीमारी की पहचान'
                : '🌿 Plant Disease Detection',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.isHindi
                ? 'AI का उपयोग करके पौधों की बीमारियों का पता लगाएं'
                : 'Detect plant diseases using AI technology',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _pickImageFromCamera,
                  icon: const Icon(Icons.camera_alt),
                  label: Text(
                    AppStrings.isHindi ? 'कैमरा' : 'Camera',
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _pickImageFromGallery,
                  icon: const Icon(Icons.photo_library),
                  label: Text(
                    AppStrings.isHindi ? 'गैलरी' : 'Gallery',
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // ESP32 Camera Button (Start/Stop)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
                  _isProcessing
                      ? null
                      : (_isESP32Active
                          ? _stopESP32Capture
                          : _startESP32Capture),
              icon: Icon(_isESP32Active ? Icons.stop : Icons.videocam),
              label: Text(
                _isESP32Active
                    ? (AppStrings.isHindi ? 'ESP32 बंद करें' : 'Stop ESP32')
                    : (AppStrings.isHindi ? 'ESP32 कैमरा' : 'ESP32 Camera'),
                style: const TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isESP32Active ? Colors.orange : Colors.white,
                foregroundColor:
                    _isESP32Active ? Colors.white : AppTheme.primaryGreen,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          // ESP32 Status and Gallery Button
          if (_isESP32Active || _capturedImageCount > 0) ...[
            const SizedBox(height: 12),
            if (_isESP32Active)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.fiber_manual_record,
                      color: Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppStrings.isHindi
                            ? 'ESP32 सक्रिय - हर 5 सेकंड में कैप्चर हो रहा है'
                            : 'ESP32 Active - Capturing every 5 seconds',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$_capturedImageCount',
                        style: TextStyle(
                          color: AppTheme.primaryGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (_capturedImageCount > 0)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showCapturedImagesGallery,
                  icon: const Icon(Icons.photo_library),
                  label: Text(
                    AppStrings.isHindi
                        ? 'कैप्चर की गई छवियां देखें ($_capturedImageCount)'
                        : 'View Captured Images ($_capturedImageCount)',
                    style: const TextStyle(fontSize: 14),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppStrings.isHindi
                        ? 'ESP32 हर 5 सेकंड में स्वचालित रूप से फोटो लेता है'
                        : 'ESP32 captures automatically every 5 seconds',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          _selectedImage!,
          height: 300,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildProcessingIndicator() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.lightGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.lightGreen),
      ),
      child: Column(
        children: [
          CircularProgressIndicator(color: AppTheme.primaryGreen),
          const SizedBox(height: 16),
          Text(
            AppStrings.isHindi
                ? '🔬 AI द्वारा विश्लेषण किया जा रहा है...'
                : '🔬 Analyzing image with AI...',
            style: TextStyle(
              color: AppTheme.primaryGreen,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.isHindi
                ? 'कृपया प्रतीक्षा करें\nपहली बार 30-60 सेकंड लग सकता है (सर्वर वेक-अप)'
                : 'Please wait\nFirst time may take 30-60 seconds (server wake-up)',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppStrings.isHindi
                        ? 'समय समाप्त हो जाए तो फिर से प्रयास करें'
                        : 'If timeout, please retry',
                    style: TextStyle(color: Colors.blue[700], fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    if (_result == null) return const SizedBox.shrink();

    final isHealthy = _result!.label.toLowerCase().contains('healthy');
    final confidenceColor =
        _result!.confidence > 0.7
            ? AppTheme.successGreen
            : _result!.confidence > 0.5
            ? AppTheme.warningOrange
            : AppTheme.alertRed;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color:
                  isHealthy
                      ? AppTheme.successGreen.withOpacity(0.1)
                      : AppTheme.warningOrange.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isHealthy ? Icons.check_circle : Icons.warning_amber_rounded,
                  color:
                      isHealthy
                          ? AppTheme.successGreen
                          : AppTheme.warningOrange,
                  size: 40,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.isHindi
                            ? 'पहचान परिणाम'
                            : 'Detection Result',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isHealthy
                            ? (AppStrings.isHindi
                                ? 'स्वस्थ पौधा ✅'
                                : 'Healthy Plant ✅')
                            : (AppStrings.isHindi
                                ? 'बीमारी का पता चला ⚠️'
                                : 'Disease Detected ⚠️'),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color:
                              isHealthy
                                  ? AppTheme.successGreen
                                  : AppTheme.warningOrange,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Details
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_result!.plant != null) ...[
                  _buildInfoRow(
                    AppStrings.isHindi ? 'पौधा' : 'Plant',
                    _result!.plant!,
                    Icons.eco,
                  ),
                  const SizedBox(height: 12),
                ],
                _buildInfoRow(
                  AppStrings.isHindi ? 'स्थिति' : 'Condition',
                  _result!.label,
                  Icons.local_hospital,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.speed, color: confidenceColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      AppStrings.isHindi ? 'विश्वास स्तर:' : 'Confidence:',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: _result!.confidence,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation(confidenceColor),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(_result!.confidence * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: confidenceColor,
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

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryGreen, size: 20),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingExplanation() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              color: AppTheme.primaryGreen,
              strokeWidth: 2,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              AppStrings.isHindi
                  ? '🤖 AI से विस्तृत सिफारिशें प्राप्त की जा रही हैं...'
                  : '🤖 Getting detailed recommendations from AI...',
              style: TextStyle(color: Colors.grey[700], fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  /// Strip markdown formatting for clean display
  String _cleanMarkdown(String text) {
    String cleaned = text;
    cleaned = cleaned.replaceAll(RegExp(r'\*\*'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\*'), '');
    cleaned = cleaned.replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '');
    return cleaned.trim();
  }

  Widget _buildGeminiExplanationCard() {
    if (_geminiExplanation == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Play/Pause button
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryGreen,
                  AppTheme.primaryGreen.withOpacity(0.8),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.psychology, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppStrings.aiExpertAdvice,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                // Play / Pause toggle button
                GestureDetector(
                  onTap: () async {
                    if (_isTtsSpeaking) {
                      // Pause/Stop — button switches back to play
                      await MarathiTtsService.stop();
                      setState(() => _isTtsSpeaking = false);
                    } else {
                      // Play — button switches to pause and STAYS there
                      setState(() => _isTtsSpeaking = true);
                      // speak() runs async; onSpeakingChanged callback
                      // will set _isTtsSpeaking=false when audio ends
                      MarathiTtsService.speak(_geminiExplanation!);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _isTtsSpeaking ? Colors.red.withOpacity(0.3) : Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isTtsSpeaking ? Icons.pause : Icons.volume_up,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isTtsSpeaking ? AppStrings.stopListening : AppStrings.listenInMarathi,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content — markdown stripped for clean display
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              _cleanMarkdown(_geminiExplanation!),
              style: const TextStyle(
                fontSize: 14,
                height: 1.6,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildESP32UrlDialog() {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.videocam, color: AppTheme.primaryGreen),
          const SizedBox(width: 8),
          const Text('ESP32 Camera'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter your ESP32 camera URL:',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _esp32UrlController,
            decoration: InputDecoration(
              hintText: 'http://192.168.x.x/capture',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              prefixIcon: const Icon(Icons.link),
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Make sure your ESP32 is on the same network',
                    style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            final url = _esp32UrlController.text.trim();
            if (ESP32CameraService.isValidCameraUrl(url)) {
              Navigator.pop(context, url);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please enter a valid URL'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          icon: const Icon(Icons.play_arrow),
          label: Text(AppStrings.isHindi ? 'शुरू करें' : 'Start'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryGreen,
          ),
        ),
      ],
    );
  }

  Widget _buildGalleryBottomSheet(List<Map<String, dynamic>> images) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.photo_library, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppStrings.isHindi
                        ? 'कैप्चर की गई छवियां (${images.length})'
                        : 'Captured Images (${images.length})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            title: Text(
                              AppStrings.isHindi ? 'सभी हटाएं?' : 'Delete All?',
                            ),
                            content: Text(
                              AppStrings.isHindi
                                  ? 'क्या आप सभी कैप्चर की गई छवियों को हटाना चाहते हैं?'
                                  : 'Are you sure you want to delete all captured images?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: Text(
                                  AppStrings.isHindi ? 'रद्द करें' : 'Cancel',
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                child: Text(
                                  AppStrings.isHindi ? 'हटाएं' : 'Delete',
                                ),
                              ),
                            ],
                          ),
                    );

                    if (confirm == true) {
                      await ESP32CameraService.deleteAllImages();
                      await _loadCapturedImageCount();
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              AppStrings.isHindi
                                  ? 'सभी छवियां हटा दी गईं'
                                  : 'All images deleted',
                            ),
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.delete_outline, color: Colors.white),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),
          // Image Grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.75,
              ),
              itemCount: images.length,
              itemBuilder: (context, index) {
                final image = images[index];
                final filePath = image['filePath'] as String;
                final capturedAt = image['capturedAt'] as DateTime;
                final analyzed = image['analyzed'] as bool;

                return GestureDetector(
                  onTap: () => Navigator.pop(context, image),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            analyzed
                                ? AppTheme.primaryGreen
                                : Colors.grey.shade300,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Image
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(10),
                            ),
                            child:
                                File(filePath).existsSync()
                                    ? Image.file(
                                      File(filePath),
                                      fit: BoxFit.cover,
                                    )
                                    : Container(
                                      color: Colors.grey.shade200,
                                      child: const Icon(
                                        Icons.image_not_supported,
                                        color: Colors.grey,
                                      ),
                                    ),
                          ),
                        ),
                        // Info
                        Container(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    analyzed
                                        ? Icons.check_circle
                                        : Icons.circle_outlined,
                                    size: 16,
                                    color:
                                        analyzed
                                            ? AppTheme.primaryGreen
                                            : Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      analyzed
                                          ? (AppStrings.isHindi
                                              ? 'विश्लेषित'
                                              : 'Analyzed')
                                          : (AppStrings.isHindi
                                              ? 'नया'
                                              : 'New'),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color:
                                            analyzed
                                                ? AppTheme.primaryGreen
                                                : Colors.grey,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${capturedAt.hour.toString().padLeft(2, '0')}:${capturedAt.minute.toString().padLeft(2, '0')}:${capturedAt.second.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed:
                                      () => Navigator.pop(context, image),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryGreen,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Text(
                                    AppStrings.isHindi ? 'विश्लेषण' : 'Analyze',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
