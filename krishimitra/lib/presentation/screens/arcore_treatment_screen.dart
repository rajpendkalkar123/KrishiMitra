import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../services/marathi_tts_service.dart';
import 'dart:async';

class ARCoreTreatmentScreen extends ConsumerStatefulWidget {
  final String disease;
  final String treatment;
  final String language;

  const ARCoreTreatmentScreen({
    Key? key,
    required this.disease,
    required this.treatment,
    required this.language,
  }) : super(key: key);

  @override
  ConsumerState<ARCoreTreatmentScreen> createState() =>
      _ARCoreTreatmentScreenState();
}

class _ARCoreTreatmentScreenState
    extends ConsumerState<ARCoreTreatmentScreen> {
  final FlutterTts _flutterTts = FlutterTts();
  int _currentModelIndex = 0;
  bool _showDiseaseCard = false;
  bool _modelLoaded = false;
  String _loadStatus = 'Initializing...';

  // Start with the SMALLEST model to test loading
  // First entry is a REMOTE GLB to test if WebView/model-viewer works at all
  final List<String> _models = [
    'https://modelviewer.dev/shared-assets/models/Astronaut.glb',
    'assets/models/peasant_watering.glb',
    'assets/models/peasant_digging.glb',
    'assets/models/farmer.glb',
  ];

  final List<String> _modelNames = [
    'Test (Remote)',
    'Watering',
    'Digging & Planting',
    'Standing',
  ];

  @override
  void initState() {
    super.initState();
    _speakTreatment();
  }

  Future<void> _speakTreatment() async {
    if (widget.language == 'Marathi') {
      await MarathiTtsService.stop();
      await MarathiTtsService.speak(widget.treatment);
    } else {
      await _flutterTts.stop();
      final locale = widget.language == 'Hindi' ? 'hi-IN' : 'en-US';
      await _flutterTts.setLanguage(locale);
      await _flutterTts.setSpeechRate(0.45);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.speak(widget.treatment);
    }
  }

  @override
  void dispose() {
    MarathiTtsService.stop();
    _flutterTts.stop();
    super.dispose();
  }

  void _switchModel(int delta) {
    setState(() {
      _currentModelIndex =
          (_currentModelIndex + delta + _models.length) % _models.length;
      _modelLoaded = false;
      _loadStatus = 'Switching model...';
    });
  }

  @override
  Widget build(BuildContext context) {
    // JavaScript to monitor model-viewer events and send status back
    const modelViewerJs = '''
      const mv = document.querySelector('model-viewer');
      if (mv) {
        mv.addEventListener('load', function() {
          document.title = 'LOADED';
        });
        mv.addEventListener('error', function(e) {
          document.title = 'ERROR: ' + (e.detail ? JSON.stringify(e.detail) : 'unknown');
        });
        mv.addEventListener('progress', function(e) {
          document.title = 'PROGRESS: ' + Math.round(e.detail.totalProgress * 100) + '%';
        });
        // Force a status check after 3 seconds
        setTimeout(function() {
          if (!mv.loaded) {
            document.title = 'NOT_LOADED_AFTER_3S: src=' + mv.src;
          }
        }, 3000);
      } else {
        document.title = 'NO_MODEL_VIEWER_ELEMENT';
      }
    ''';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.language == 'Marathi'
              ? 'उपचार AR'
              : widget.language == 'Hindi'
                  ? 'उपचार AR'
                  : 'Treatment AR',
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // ── ModelViewer ──
          // CRITICAL: Do NOT pass shadowIntensity or shadowSoftness
          // model_viewer_plus v1.9.3 html_builder.dart has stray "}" in:
          //   shadow-intensity="$shadowIntensity}"
          //   shadow-softness="$shadowSoftness}"
          // This corrupts the HTML and prevents model rendering.
          Positioned.fill(
            child: ModelViewer(
              key: ValueKey('model_$_currentModelIndex'),
              src: _models[_currentModelIndex],
              alt: _modelNames[_currentModelIndex],
              ar: true,
              arModes: const ['scene-viewer', 'webxr', 'quick-look'],
              arPlacement: ArPlacement.floor,
              arScale: ArScale.fixed,
              autoPlay: true,
              autoRotate: true,
              cameraControls: true,
              disableZoom: false,
              loading: Loading.eager,
              // Use transparent background so we know it's not just white-on-white
              backgroundColor: const Color(0xFFE8F5E9),
              cameraOrbit: '0deg 75deg 2.5m',
              cameraTarget: '0m 0.5m 0m',
              fieldOfView: '45deg',
              // FIX: The template CSS has body{height:100%} but NOT html{height:100%},
              // causing the model-viewer element to collapse to 0 height on some WebViews.
              relatedCss: 'html { height: 100%; width: 100%; margin: 0; padding: 0; overflow: hidden; } body { height: 100%; width: 100%; margin: 0; padding: 0; overflow: hidden; } model-viewer { width: 100%; height: 100%; display: block; }',
              relatedJs: modelViewerJs,
              debugLogging: true,
            ),
          ),

          // ── Loading overlay ──
          if (!_modelLoaded)
            Positioned.fill(
              child: Container(
                color: Colors.black26,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Colors.green),
                      const SizedBox(height: 16),
                      Text(
                        _loadStatus,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Model: ${_modelNames[_currentModelIndex]}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Manual dismiss after 5 seconds
                      TextButton(
                        onPressed: () =>
                            setState(() => _modelLoaded = true),
                        child: const Text(
                          'Dismiss loading overlay',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Model name badge (top right) ──
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _modelNames[_currentModelIndex],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // ── Model switcher (bottom left) ──
          Positioned(
            bottom: 16,
            left: 16,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _navButton(Icons.chevron_left, () => _switchModel(-1)),
                  const SizedBox(width: 6),
                  ...List.generate(
                    _models.length,
                    (i) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _currentModelIndex
                            ? Colors.greenAccent
                            : Colors.white30,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _navButton(Icons.chevron_right, () => _switchModel(1)),
                ],
              ),
            ),
          ),

          // ── Info + TTS buttons (bottom right) ──
          Positioned(
            bottom: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_showDiseaseCard) _buildDiseaseCard(),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _circleButton(
                      icon: _showDiseaseCard
                          ? Icons.close
                          : Icons.info_outline,
                      color: _showDiseaseCard ? Colors.red : Colors.black87,
                      onTap: () => setState(
                          () => _showDiseaseCard = !_showDiseaseCard),
                    ),
                    const SizedBox(width: 8),
                    _circleButton(
                      icon: Icons.volume_up,
                      color: Colors.green,
                      onTap: _speakTreatment,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── AR instruction banner ──
          Positioned(
            bottom: 70,
            left: 16,
            right: 16,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.green.shade700,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.view_in_ar,
                      color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.language == 'Marathi'
                          ? 'AR बटण टॅप करा → फोन हलवा → मजल्यावर ठेवा'
                          : widget.language == 'Hindi'
                              ? 'AR बटन टैप करें → फोन हिलाएं → फर्श पर रखें'
                              : 'Tap AR icon → Scan floor → Place model',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helper widgets ──

  Widget _navButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, color: Colors.white, size: 22),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _buildDiseaseCard() {
    return Container(
      width: MediaQuery.of(context).size.width * 0.7,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.language == 'Marathi'
                ? 'रोग'
                : widget.language == 'Hindi'
                    ? 'रोग'
                    : 'Disease',
            style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500),
          ),
          Text(
            widget.disease,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.red),
          ),
          const SizedBox(height: 10),
          Text(
            widget.language == 'Marathi'
                ? 'उपचार'
                : widget.language == 'Hindi'
                    ? 'उपचार'
                    : 'Treatment',
            style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 2),
          Text(
            widget.treatment,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _showFullTreatmentDialog,
              child: Text(
                widget.language == 'Marathi'
                    ? 'संपूर्ण माहिती'
                    : widget.language == 'Hindi'
                        ? 'पूरी जानकारी'
                        : 'Full Details',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFullTreatmentDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          widget.language == 'Marathi'
              ? 'उपचार तपशील'
              : widget.language == 'Hindi'
                  ? 'उपचार विवरण'
                  : 'Treatment Details',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.disease,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red)),
              const SizedBox(height: 16),
              Text(widget.treatment,
                  style: const TextStyle(
                      fontSize: 16, color: Colors.black87)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(widget.language == 'Marathi'
                ? 'बंद करा'
                : widget.language == 'Hindi'
                    ? 'बंद करें'
                    : 'Close'),
          ),
          TextButton.icon(
            icon: const Icon(Icons.volume_up),
            label: Text(widget.language == 'Marathi'
                ? 'ऐका'
                : widget.language == 'Hindi'
                    ? 'सुनें'
                    : 'Listen'),
            onPressed: _speakTreatment,
          ),
        ],
      ),
    );
  }
}
