/// AR Treatment Guidance Screen
/// Provides augmented reality-based step-by-step treatment instructions
library;

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:krishimitra/domain/models/ar_treatment_models.dart';
import 'package:krishimitra/services/ar_treatment_service.dart';
import 'package:krishimitra/services/marathi_tts_service.dart';
import 'package:krishimitra/utils/app_strings.dart';
import 'package:krishimitra/utils/app_theme.dart';

class ARTreatmentScreen extends StatefulWidget {
  final String plantName;
  final String diseaseName;
  final double confidence;
  final File? diseaseImage;

  const ARTreatmentScreen({
    super.key,
    required this.plantName,
    required this.diseaseName,
    required this.confidence,
    this.diseaseImage,
  });

  @override
  State<ARTreatmentScreen> createState() => _ARTreatmentScreenState();
}

class _ARTreatmentScreenState extends State<ARTreatmentScreen>
    with TickerProviderStateMixin {
  // Camera
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isCameraError = false;
  String _cameraErrorMessage = '';

  // AR Session State
  ARTreatmentPlan? _treatmentPlan;
  int _currentStepIndex = 0;
  bool _isLoading = true;
  bool _showOverlay = true;
  bool _isSpeaking = false;
  bool _isPaused = false;

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _arrowController;
  late AnimationController _floatController;
  late AnimationController _rotateController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _arrowAnimation;
  late Animation<double> _floatAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _fadeAnimation;

  // Timer for auto-progression
  Timer? _autoProgressTimer;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeCamera();
    _loadTreatmentPlan();

    // Register TTS callback
    MarathiTtsService.onSpeakingChanged = (speaking) {
      if (mounted) setState(() => _isSpeaking = speaking);
    };
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _arrowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _arrowAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _arrowController, curve: Curves.easeInOut),
    );

    _floatAnimation = Tween<double>(begin: -15, end: 15).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _rotateAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.linear),
    );

    _fadeAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _isCameraError = true;
          _cameraErrorMessage = 'No camera found';
        });
        return;
      }

      // Use back camera
      final backCamera = _cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      setState(() {
        _isCameraError = true;
        _cameraErrorMessage = 'Failed to initialize camera: $e';
      });
    }
  }

  Future<void> _loadTreatmentPlan() async {
    try {
      final plan = await ARTreatmentService.generateTreatmentPlan(
        plantName: widget.plantName,
        diseaseName: widget.diseaseName,
        confidence: widget.confidence,
        languageCode: AppStrings.languageCode,
      );

      if (mounted) {
        setState(() {
          _treatmentPlan = plan;
          _isLoading = false;
        });

        // Auto-play first step narration
        Future.delayed(const Duration(milliseconds: 500), () {
          _speakCurrentStep();
        });
      }
    } catch (e) {
      print('Error loading treatment plan: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _speakCurrentStep() {
    if (_treatmentPlan == null || _isSpeaking) return;
    
    final step = _treatmentPlan!.steps[_currentStepIndex];
    final narration = ARTreatmentService.getVoiceNarration(
      step,
      AppStrings.languageCode,
    );
    
    setState(() => _isSpeaking = true);
    MarathiTtsService.speak(narration);
  }

  void _stopSpeaking() {
    MarathiTtsService.stop();
    setState(() => _isSpeaking = false);
  }

  void _nextStep() {
    if (_treatmentPlan == null) return;
    if (_currentStepIndex < _treatmentPlan!.steps.length - 1) {
      _stopSpeaking();
      setState(() {
        _currentStepIndex++;
      });
      Future.delayed(const Duration(milliseconds: 300), () {
        _speakCurrentStep();
      });
    }
  }

  void _previousStep() {
    if (_currentStepIndex > 0) {
      _stopSpeaking();
      setState(() {
        _currentStepIndex--;
      });
      Future.delayed(const Duration(milliseconds: 300), () {
        _speakCurrentStep();
      });
    }
  }

  void _toggleOverlay() {
    setState(() {
      _showOverlay = !_showOverlay;
    });
  }

  // ignore: unused_element
  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
    });
    if (_isPaused) {
      _stopSpeaking();
      _autoProgressTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _pulseController.dispose();
    _arrowController.dispose();
    _floatController.dispose();
    _rotateController.dispose();
    _fadeController.dispose();
    _autoProgressTimer?.cancel();
    MarathiTtsService.stop();
    MarathiTtsService.onSpeakingChanged = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview / AR View
          _buildCameraView(),

          // AR Overlays
          if (_showOverlay && _treatmentPlan != null && _isCameraInitialized)
            _buildAROverlay(),

          // Top Controls
          _buildTopControls(),

          // Bottom Panel - Step Info
          _buildBottomPanel(),

          // Loading Overlay
          if (_isLoading) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildCameraView() {
    if (_isCameraError) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videocam_off, color: Colors.white54, size: 64),
              const SizedBox(height: 16),
              Text(
                _cameraErrorMessage,
                style: const TextStyle(color: Colors.white54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Show disease image as fallback
              if (widget.diseaseImage != null)
                Container(
                  height: 300,
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    image: DecorationImage(
                      image: FileImage(widget.diseaseImage!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    if (!_isCameraInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return SizedBox.expand(
      child: CameraPreview(_cameraController!),
    );
  }

  Widget _buildAROverlay() {
    final step = _treatmentPlan!.steps[_currentStepIndex];

    return AnimatedBuilder(
      animation: Listenable.merge([
        _pulseController,
        _arrowController,
        _floatController,
        _rotateController,
        _fadeController,
      ]),
      builder: (context, child) {
        return Stack(
          children: [
            // Corner scanning brackets (always shown)
            _buildScanBrackets(),
            // Step-specific main animation
            _buildStepAnimation(step),
            // Animated step icon badge (top center)
            _buildAnimatedStepBadge(step),
          ],
        );
      },
    );
  }

  Widget _buildScanBrackets() {
    final color = Colors.greenAccent.withOpacity(0.6 * _fadeAnimation.value);
    const bracketSize = 50.0;
    const thickness = 3.0;

    return Stack(
      children: [
        // Top-left
        Positioned(
          top: 80,
          left: 20,
          child: _buildBracketCorner(color, bracketSize, thickness, topLeft: true),
        ),
        // Top-right
        Positioned(
          top: 80,
          right: 20,
          child: _buildBracketCorner(color, bracketSize, thickness, topRight: true),
        ),
        // Bottom-left
        Positioned(
          bottom: 280,
          left: 20,
          child: _buildBracketCorner(color, bracketSize, thickness, bottomLeft: true),
        ),
        // Bottom-right
        Positioned(
          bottom: 280,
          right: 20,
          child: _buildBracketCorner(color, bracketSize, thickness, bottomRight: true),
        ),
      ],
    );
  }

  Widget _buildBracketCorner(Color color, double size, double thickness,
      {bool topLeft = false, bool topRight = false, bool bottomLeft = false, bool bottomRight = false}) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BracketPainter(
          color: color,
          thickness: thickness,
          topLeft: topLeft,
          topRight: topRight,
          bottomLeft: bottomLeft,
          bottomRight: bottomRight,
        ),
      ),
    );
  }

  Widget _buildAnimatedStepBadge(ARTreatmentStep step) {
    final stepColor = ARTreatmentService.getStepColor(step.type);
    final stepIcon = ARTreatmentService.getStepIcon(step.type);
    final emoji = _getStepEmoji(step.type);

    return Positioned(
      top: 100 + _floatAnimation.value,
      left: 0,
      right: 0,
      child: Center(
        child: Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: stepColor.withOpacity(0.85),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: stepColor.withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Icon(stepIcon, color: Colors.white, size: 20),
                const SizedBox(width: 6),
                Text(
                  step.getTitle(AppStrings.languageCode),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Colors.black38, blurRadius: 4)],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getStepEmoji(TreatmentStepType type) {
    switch (type) {
      case TreatmentStepType.identifyArea:
        return '🔍';
      case TreatmentStepType.prepareTools:
        return '🔧';
      case TreatmentStepType.prepareSolution:
        return '🧪';
      case TreatmentStepType.application:
        return '💨';
      case TreatmentStepType.soilTreatment:
        return '🌱';
      case TreatmentStepType.pruning:
        return '✂️';
      case TreatmentStepType.watering:
        return '💧';
      case TreatmentStepType.safety:
        return '⚠️';
      case TreatmentStepType.monitoring:
        return '👁️';
      case TreatmentStepType.prevention:
        return '🛡️';
    }
  }

  Widget _buildStepAnimation(ARTreatmentStep step) {
    switch (step.type) {
      case TreatmentStepType.identifyArea:
        return _buildIdentifyAnimation();
      case TreatmentStepType.prepareTools:
        return _buildToolsAnimation();
      case TreatmentStepType.prepareSolution:
        return _buildMixAnimation();
      case TreatmentStepType.application:
        return _buildSprayAnimation();
      case TreatmentStepType.soilTreatment:
        return _buildSoilAnimation();
      case TreatmentStepType.pruning:
        return _buildPruneAnimation();
      case TreatmentStepType.watering:
        return _buildWaterAnimation();
      case TreatmentStepType.safety:
        return _buildSafetyAnimation();
      case TreatmentStepType.monitoring:
        return _buildMonitorAnimation();
      case TreatmentStepType.prevention:
        return _buildShieldAnimation();
    }
  }

  // ── IDENTIFY AREA: Pulsing target crosshair ──
  Widget _buildIdentifyAnimation() {
    return Center(
      child: Transform.scale(
        scale: _pulseAnimation.value,
        child: SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer ring
              Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.redAccent.withOpacity(0.6),
                    width: 3,
                  ),
                ),
              ),
              // Inner ring
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.redAccent.withOpacity(0.4),
                    width: 2,
                  ),
                ),
              ),
              // Crosshair horizontal
              Container(
                width: 180,
                height: 2,
                color: Colors.redAccent.withOpacity(0.4 * _fadeAnimation.value),
              ),
              // Crosshair vertical
              Container(
                width: 2,
                height: 180,
                color: Colors.redAccent.withOpacity(0.4 * _fadeAnimation.value),
              ),
              // Center dot
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.redAccent.withOpacity(0.8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.5),
                      blurRadius: 12,
                      spreadRadius: 3,
                    ),
                  ],
                ),
              ),
              // Scanning text
              Positioned(
                bottom: 0,
                child: Text(
                  '🔍 ${AppStrings.isMarathi ? 'प्रभावित भाग शोधा' : AppStrings.isHindi ? 'प्रभावित क्षेत्र खोजें' : 'Locate infected area'}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(_fadeAnimation.value),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── TOOLS: Rotating gear + floating tool icons ──
  Widget _buildToolsAnimation() {
    return Center(
      child: SizedBox(
        width: 250,
        height: 250,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Rotating gear
            Transform.rotate(
              angle: _rotateAnimation.value * 3.14159 * 2,
              child: Text('⚙️', style: TextStyle(fontSize: 70 * _pulseAnimation.value)),
            ),
            // Floating tools around
            ..._buildOrbitingItems(['🔧', '🪣', '🧤', '📏'], 100),
            Positioned(
              bottom: 10,
              child: Text(
                AppStrings.isMarathi ? 'साधने तयार करा' : AppStrings.isHindi ? 'उपकरण तैयार करें' : 'Prepare tools',
                style: TextStyle(
                  color: Colors.white.withOpacity(_fadeAnimation.value),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildOrbitingItems(List<String> emojis, double radius) {
    return List.generate(emojis.length, (i) {
      final angle = (_rotateAnimation.value * 3.14159 * 2) + (i * 3.14159 * 2 / emojis.length);
      final x = radius * _cos(angle);
      final y = radius * _sin(angle);
      return Positioned(
        left: 125 + x - 18,
        top: 125 + y - 18,
        child: Opacity(
          opacity: _fadeAnimation.value,
          child: Text(emojis[i], style: const TextStyle(fontSize: 30)),
        ),
      );
    });
  }

  double _sin(double a) => (a - (a * a * a / 6) + (a * a * a * a * a / 120)).clamp(-1.0, 1.0) * 1.0;
  double _cos(double a) => _sin(a + 1.5708);

  // ── MIX SOLUTION: Beaker with bubbling animation ──
  Widget _buildMixAnimation() {
    return Center(
      child: SizedBox(
        width: 200,
        height: 250,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Beaker
            const Text('🧪', style: TextStyle(fontSize: 80)),
            // Rising bubbles
            ...List.generate(5, (i) {
              final progress = (_arrowAnimation.value + i * 0.2) % 1.0;
              return Positioned(
                bottom: 60 + progress * 120,
                left: 80 + (i % 3 - 1) * 25,
                child: Opacity(
                  opacity: (1 - progress).clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 0.5 + progress * 0.5,
                    child: Text(
                      i % 2 == 0 ? '💚' : '🫧',
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                ),
              );
            }),
            Positioned(
              bottom: 0,
              child: Text(
                AppStrings.isMarathi ? 'द्रावण तयार करा' : AppStrings.isHindi ? 'घोल तैयार करें' : 'Mix solution',
                style: TextStyle(
                  color: Colors.white.withOpacity(_fadeAnimation.value),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── SPRAY APPLICATION: Spray can with mist particles ──
  Widget _buildSprayAnimation() {
    return Center(
      child: SizedBox(
        width: 250,
        height: 300,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Spray can
            Positioned(
              top: 30 + _floatAnimation.value * 0.5,
              child: Transform.scale(
                scale: _pulseAnimation.value * 0.9,
                child: const Text('🧴', style: TextStyle(fontSize: 60)),
              ),
            ),
            // Spray mist particles falling down
            ...List.generate(12, (i) {
              final progress = (_arrowAnimation.value + i * 0.1) % 1.0;
              final xSpread = (i % 5 - 2) * 22.0;
              return Positioned(
                top: 100 + progress * 140,
                left: 110 + xSpread + _floatAnimation.value * 0.3,
                child: Opacity(
                  opacity: (1 - progress * 0.8).clamp(0.0, 0.8),
                  child: Text(
                    i % 3 == 0 ? '💨' : i % 3 == 1 ? '💦' : '·',
                    style: TextStyle(
                      fontSize: i % 3 == 2 ? 24 : 16,
                      color: Colors.greenAccent.withOpacity(0.7),
                    ),
                  ),
                ),
              );
            }),
            // Target plant area
            Positioned(
              bottom: 20,
              child: Transform.scale(
                scale: _pulseAnimation.value * 0.85,
                child: const Text('🌿', style: TextStyle(fontSize: 50)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── SOIL TREATMENT: Digging/soil particles ──
  Widget _buildSoilAnimation() {
    return Center(
      child: SizedBox(
        width: 220,
        height: 250,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Shovel
            Positioned(
              top: 20 + _floatAnimation.value,
              child: Transform.rotate(
                angle: _pulseAnimation.value * 0.2 - 0.1,
                child: const Text('⛏️', style: TextStyle(fontSize: 60)),
              ),
            ),
            // Soil particles
            ...List.generate(8, (i) {
              final progress = (_arrowAnimation.value + i * 0.15) % 1.0;
              final xOff = (i % 4 - 1.5) * 30;
              return Positioned(
                bottom: 40 + progress * 80,
                left: 90 + xOff,
                child: Opacity(
                  opacity: (1 - progress).clamp(0.0, 1.0),
                  child: Text(
                    i % 2 == 0 ? '🟤' : '🌱',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              );
            }),
            Positioned(
              bottom: 10,
              child: Text(
                AppStrings.isMarathi ? 'माती उपचार' : AppStrings.isHindi ? 'मिट्टी का उपचार' : 'Soil treatment',
                style: TextStyle(
                  color: Colors.white.withOpacity(_fadeAnimation.value),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── PRUNING: Animated scissors cutting ──
  Widget _buildPruneAnimation() {
    return Center(
      child: SizedBox(
        width: 220,
        height: 220,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Infected branch
            const Text('🍂', style: TextStyle(fontSize: 50)),
            // Scissors with cutting motion
            Positioned(
              left: 40 + (_arrowAnimation.value * 40),
              top: 60,
              child: Transform.rotate(
                angle: _pulseAnimation.value * 0.3 - 0.15,
                child: const Text('✂️', style: TextStyle(fontSize: 50)),
              ),
            ),
            // Cut marks
            ...List.generate(3, (i) {
              final progress = (_arrowAnimation.value + i * 0.3) % 1.0;
              return Positioned(
                right: 30 + progress * 60,
                bottom: 70 + i * 20,
                child: Opacity(
                  opacity: (1 - progress).clamp(0.0, 1.0),
                  child: const Text('🍃', style: TextStyle(fontSize: 20)),
                ),
              );
            }),
            Positioned(
              bottom: 10,
              child: Text(
                AppStrings.isMarathi ? 'छाटणी करा' : AppStrings.isHindi ? 'छंटाई करें' : 'Prune infected parts',
                style: TextStyle(
                  color: Colors.white.withOpacity(_fadeAnimation.value),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── WATERING: Water drops falling animation ──
  Widget _buildWaterAnimation() {
    return Center(
      child: SizedBox(
        width: 220,
        height: 280,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Watering can
            Positioned(
              top: 10 + _floatAnimation.value * 0.5,
              child: Transform.rotate(
                angle: -0.3,
                child: Transform.scale(
                  scale: _pulseAnimation.value * 0.9,
                  child: const Text('🚿', style: TextStyle(fontSize: 60)),
                ),
              ),
            ),
            // Water drops falling
            ...List.generate(10, (i) {
              final progress = (_arrowAnimation.value + i * 0.12) % 1.0;
              final xOff = (i % 5 - 2) * 18.0;
              return Positioned(
                top: 80 + progress * 150,
                left: 95 + xOff,
                child: Opacity(
                  opacity: (1 - progress * 0.7).clamp(0.0, 1.0),
                  child: Text(
                    i % 2 == 0 ? '💧' : '💦',
                    style: TextStyle(fontSize: 14 + (progress * 8)),
                  ),
                ),
              );
            }),
            // Plant receiving water
            Positioned(
              bottom: 10,
              child: Transform.scale(
                scale: 0.9 + _pulseAnimation.value * 0.1,
                child: const Text('🌱', style: TextStyle(fontSize: 45)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── SAFETY: Pulsing warning with shield ──
  Widget _buildSafetyAnimation() {
    return Center(
      child: SizedBox(
        width: 220,
        height: 220,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Pulsing warning glow
            Container(
              width: 160 * _pulseAnimation.value,
              height: 160 * _pulseAnimation.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.orange.withOpacity(0.3 * _fadeAnimation.value),
                    Colors.orange.withOpacity(0.0),
                  ],
                ),
              ),
            ),
            // Safety icons
            Transform.scale(
              scale: _pulseAnimation.value,
              child: const Text('⚠️', style: TextStyle(fontSize: 70)),
            ),
            // Orbiting safety gear
            ..._buildFloatingItems(['🧤', '😷', '🥽', '👢'], 90),
            Positioned(
              bottom: 0,
              child: Text(
                AppStrings.isMarathi ? 'सुरक्षा प्रथम!' : AppStrings.isHindi ? 'सुरक्षा पहले!' : 'Safety first!',
                style: TextStyle(
                  color: Colors.orangeAccent.withOpacity(_fadeAnimation.value),
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFloatingItems(List<String> emojis, double radius) {
    return List.generate(emojis.length, (i) {
      final offset = _floatAnimation.value * (i.isEven ? 1 : -1);
      final baseAngle = i * 3.14159 * 2 / emojis.length;
      final x = radius * _cosApprox(baseAngle);
      final y = radius * _sinApprox(baseAngle) + offset;
      return Positioned(
        left: 110 + x - 15,
        top: 110 + y - 15 + offset,
        child: Opacity(
          opacity: _fadeAnimation.value,
          child: Text(emojis[i], style: const TextStyle(fontSize: 28)),
        ),
      );
    });
  }

  double _sinApprox(double x) {
    // Normalize to [-pi, pi]
    while (x > 3.14159) x -= 6.28318;
    while (x < -3.14159) x += 6.28318;
    // Taylor series approximation
    final x3 = x * x * x;
    final x5 = x3 * x * x;
    return x - x3 / 6 + x5 / 120;
  }

  double _cosApprox(double x) => _sinApprox(x + 1.5708);

  // ── MONITORING: Eye scanning animation ──
  Widget _buildMonitorAnimation() {
    return Center(
      child: SizedBox(
        width: 220,
        height: 220,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Scanning beam
            Positioned(
              top: 40,
              left: 30 + _arrowAnimation.value * 160,
              child: Container(
                width: 3,
                height: 140,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.cyanAccent.withOpacity(0),
                      Colors.cyanAccent.withOpacity(0.7),
                      Colors.cyanAccent.withOpacity(0),
                    ],
                  ),
                ),
              ),
            ),
            // Eye icon
            Transform.scale(
              scale: _pulseAnimation.value,
              child: const Text('👁️', style: TextStyle(fontSize: 60)),
            ),
            // Calendar
            Positioned(
              bottom: 30,
              right: 30,
              child: Opacity(
                opacity: _fadeAnimation.value,
                child: const Text('📅', style: TextStyle(fontSize: 35)),
              ),
            ),
            Positioned(
              bottom: 0,
              child: Text(
                AppStrings.isMarathi ? 'निरीक्षण करा' : AppStrings.isHindi ? 'निगरानी करें' : 'Monitor regularly',
                style: TextStyle(
                  color: Colors.cyanAccent.withOpacity(_fadeAnimation.value),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── PREVENTION: Shield with checkmark ──
  Widget _buildShieldAnimation() {
    return Center(
      child: SizedBox(
        width: 220,
        height: 220,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Glow
            Container(
              width: 150 * _pulseAnimation.value,
              height: 150 * _pulseAnimation.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.green.withOpacity(0.25 * _fadeAnimation.value),
                    Colors.green.withOpacity(0.0),
                  ],
                ),
              ),
            ),
            Transform.scale(
              scale: _pulseAnimation.value,
              child: const Text('🛡️', style: TextStyle(fontSize: 70)),
            ),
            // Floating checkmarks
            ...List.generate(4, (i) {
              final progress = (_arrowAnimation.value + i * 0.25) % 1.0;
              return Positioned(
                bottom: 50 + progress * 100,
                left: 60 + i * 30.0,
                child: Opacity(
                  opacity: (1 - progress).clamp(0.0, 1.0),
                  child: const Text('✅', style: TextStyle(fontSize: 18)),
                ),
              );
            }),
            Positioned(
              bottom: 0,
              child: Text(
                AppStrings.isMarathi ? 'प्रतिबंध उपाय' : AppStrings.isHindi ? 'रोकथाम' : 'Prevention',
                style: TextStyle(
                  color: Colors.greenAccent.withOpacity(_fadeAnimation.value),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopControls() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Back button
            _buildControlButton(
              icon: Icons.arrow_back,
              onTap: () => Navigator.pop(context),
            ),

            // Disease info badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.eco, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.plantName} - ${widget.diseaseName}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Toggle overlay button
            _buildControlButton(
              icon: _showOverlay ? Icons.visibility : Icons.visibility_off,
              onTap: _toggleOverlay,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _buildBottomPanel() {
    if (_treatmentPlan == null) return const SizedBox.shrink();

    final step = _treatmentPlan!.steps[_currentStepIndex];
    final stepColor = ARTreatmentService.getStepColor(step.type);
    final stepIcon = ARTreatmentService.getStepIcon(step.type);

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.7),
              Colors.black.withOpacity(0.95),
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Progress indicator
              _buildProgressIndicator(),

              const SizedBox(height: 12),

              // Step card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: stepColor.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Step header
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: stepColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(stepIcon, color: stepColor, size: 26),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${AppStrings.isHindi ? 'चरण' : AppStrings.isMarathi ? 'पायरी' : 'Step'} ${step.stepNumber}/${_treatmentPlan!.steps.length}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                step.getTitle(AppStrings.languageCode),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Voice button
                        GestureDetector(
                          onTap: _isSpeaking ? _stopSpeaking : _speakCurrentStep,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: _isSpeaking
                                  ? Colors.red.withOpacity(0.15)
                                  : AppTheme.primaryGreen.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _isSpeaking ? Icons.pause : Icons.volume_up,
                              color: _isSpeaking
                                  ? Colors.red
                                  : AppTheme.primaryGreen,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Step description
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        step.getDescription(AppStrings.languageCode),
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: Colors.black87,
                        ),
                      ),
                    ),

                    // Warnings
                    if (step.warnings.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning_amber,
                              color: Colors.orange,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                step.warnings.first,
                                style: TextStyle(
                                  color: Colors.orange[800],
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Navigation buttons
                    Row(
                      children: [
                        // Previous button
                        Expanded(
                          child: _buildNavButton(
                            label: AppStrings.isHindi
                                ? 'पिछला'
                                : AppStrings.isMarathi
                                    ? 'मागील'
                                    : 'Previous',
                            icon: Icons.arrow_back,
                            onTap: _currentStepIndex > 0 ? _previousStep : null,
                            isPrimary: false,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Next button
                        Expanded(
                          flex: 2,
                          child: _buildNavButton(
                            label: _currentStepIndex <
                                    _treatmentPlan!.steps.length - 1
                                ? (AppStrings.isHindi
                                    ? 'अगला'
                                    : AppStrings.isMarathi
                                        ? 'पुढील'
                                        : 'Next')
                                : (AppStrings.isHindi
                                    ? 'समाप्त'
                                    : AppStrings.isMarathi
                                        ? 'पूर्ण'
                                        : 'Finish'),
                            icon: _currentStepIndex <
                                    _treatmentPlan!.steps.length - 1
                                ? Icons.arrow_forward
                                : Icons.check,
                            onTap: _currentStepIndex <
                                    _treatmentPlan!.steps.length - 1
                                ? _nextStep
                                : () => _showCompletionDialog(),
                            isPrimary: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    if (_treatmentPlan == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: List.generate(
          _treatmentPlan!.steps.length,
          (index) {
            final isActive = index == _currentStepIndex;
            final isCompleted = index < _currentStepIndex;
            final step = _treatmentPlan!.steps[index];
            final stepColor = ARTreatmentService.getStepColor(step.type);

            return Expanded(
              child: Container(
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? stepColor
                      : isActive
                          ? stepColor.withOpacity(0.5)
                          : Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNavButton({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
    required bool isPrimary,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: onTap == null
              ? Colors.grey[200]
              : isPrimary
                  ? AppTheme.primaryGreen
                  : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!isPrimary) Icon(icon, size: 18, color: Colors.grey[600]),
            if (!isPrimary) const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: onTap == null
                    ? Colors.grey[400]
                    : isPrimary
                        ? Colors.white
                        : Colors.grey[700],
                fontWeight: FontWeight.bold,
              ),
            ),
            if (isPrimary) const SizedBox(width: 6),
            if (isPrimary)
              Icon(icon, size: 18, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  color: AppTheme.primaryGreen,
                  strokeWidth: 3,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              AppStrings.isHindi
                  ? '🎯 AR उपचार मार्गदर्शिका तैयार की जा रही है...'
                  : AppStrings.isMarathi
                      ? '🎯 AR उपचार मार्गदर्शक तयार करत आहे...'
                      : '🎯 Preparing AR Treatment Guide...',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.plantName} - ${widget.diseaseName}',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: AppTheme.primaryGreen,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                AppStrings.isHindi
                    ? 'उपचार पूर्ण!'
                    : AppStrings.isMarathi
                        ? 'उपचार पूर्ण!'
                        : 'Treatment Complete!',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.isHindi
                  ? 'आपने सभी ${_treatmentPlan?.steps.length ?? 0} चरण पूरे कर लिए हैं।'
                  : AppStrings.isMarathi
                      ? 'तुम्ही सर्व ${_treatmentPlan?.steps.length ?? 0} पायऱ्या पूर्ण केल्या.'
                      : 'You have completed all ${_treatmentPlan?.steps.length ?? 0} steps.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule, color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppStrings.isHindi
                          ? '7-10 दिनों में पौधे की जांच करें'
                          : AppStrings.isMarathi
                              ? '7-10 दिवसांत वनस्पती तपासा'
                              : 'Check the plant in 7-10 days',
                      style: TextStyle(
                        color: Colors.amber[800],
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showMaterialsDialog();
            },
            child: Text(
              AppStrings.isHindi
                  ? 'सामग्री देखें'
                  : AppStrings.isMarathi
                      ? 'साहित्य पहा'
                      : 'View Materials',
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              AppStrings.isHindi
                  ? 'पूर्ण'
                  : AppStrings.isMarathi
                      ? 'पूर्ण'
                      : 'Done',
            ),
          ),
        ],
      ),
    );
  }

  void _showMaterialsDialog() {
    if (_treatmentPlan == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _MaterialsBottomSheet(plan: _treatmentPlan!),
    );
  }
}

/// Simple bracket corner painter for AR scanning effect
class _BracketPainter extends CustomPainter {
  final Color color;
  final double thickness;
  final bool topLeft;
  final bool topRight;
  final bool bottomLeft;
  final bool bottomRight;

  _BracketPainter({
    required this.color,
    required this.thickness,
    this.topLeft = false,
    this.topRight = false,
    this.bottomLeft = false,
    this.bottomRight = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    if (topLeft) {
      canvas.drawLine(Offset(0, h * 0.5), const Offset(0, 0), paint);
      canvas.drawLine(const Offset(0, 0), Offset(w * 0.5, 0), paint);
    }
    if (topRight) {
      canvas.drawLine(Offset(w * 0.5, 0), Offset(w, 0), paint);
      canvas.drawLine(Offset(w, 0), Offset(w, h * 0.5), paint);
    }
    if (bottomLeft) {
      canvas.drawLine(Offset(0, h * 0.5), Offset(0, h), paint);
      canvas.drawLine(Offset(0, h), Offset(w * 0.5, h), paint);
    }
    if (bottomRight) {
      canvas.drawLine(Offset(w * 0.5, h), Offset(w, h), paint);
      canvas.drawLine(Offset(w, h * 0.5), Offset(w, h), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BracketPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.thickness != thickness;
  }
}

/// Bottom sheet showing required materials
class _MaterialsBottomSheet extends StatelessWidget {
  final ARTreatmentPlan plan;

  const _MaterialsBottomSheet({required this.plan});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.inventory_2, color: AppTheme.primaryGreen),
                const SizedBox(width: 12),
                Text(
                  AppStrings.isHindi
                      ? 'आवश्यक सामग्री'
                      : AppStrings.isMarathi
                          ? 'आवश्यक साहित्य'
                          : 'Required Materials',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                // Tools section
                _buildSectionHeader(
                  AppStrings.isHindi
                      ? '🔧 उपकरण'
                      : AppStrings.isMarathi
                          ? '🔧 साधने'
                          : '🔧 Tools',
                ),
                ...plan.requiredTools.map((tool) => _buildToolItem(tool)),

                const SizedBox(height: 24),

                // Chemicals section
                _buildSectionHeader(
                  AppStrings.isHindi
                      ? '🧪 रसायन / कीटनाशक'
                      : AppStrings.isMarathi
                          ? '🧪 रसायने / कीटकनाशके'
                          : '🧪 Chemicals / Pesticides',
                ),
                ...plan.requiredChemicals.map((chem) => _buildChemicalItem(chem)),

                const SizedBox(height: 24),

                // Safety section
                _buildSectionHeader(
                  AppStrings.isHindi
                      ? '⚠️ सुरक्षा दिशानिर्देश'
                      : AppStrings.isMarathi
                          ? '⚠️ सुरक्षा मार्गदर्शक तत्त्वे'
                          : '⚠️ Safety Guidelines',
                ),
                _buildSafetyCard(plan.safetyGuidelines),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildToolItem(RequiredTool tool) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Text(tool.icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tool.getName(AppStrings.languageCode),
              style: const TextStyle(fontSize: 14),
            ),
          ),
          if (tool.isEssential)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                AppStrings.isHindi
                    ? 'आवश्यक'
                    : AppStrings.isMarathi
                        ? 'आवश्यक'
                        : 'Required',
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChemicalItem(RequiredChemical chem) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  chem.getName(AppStrings.languageCode),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (chem.estimatedPrice != null)
                Text(
                  '₹${chem.estimatedPrice!.toInt()}',
                  style: const TextStyle(
                    color: AppTheme.primaryGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${chem.type.toUpperCase()} • ${chem.dosage}',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
          if (chem.brandSuggestion != null) ...[
            const SizedBox(height: 4),
            Text(
              '📦 ${chem.brandSuggestion}',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSafetyCard(SafetyGuidelines safety) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Protective gear
          Text(
            AppStrings.isHindi
                ? 'सुरक्षा उपकरण:'
                : AppStrings.isMarathi
                    ? 'सुरक्षा उपकरणे:'
                    : 'Protective Gear:',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: safety.getProtectiveGear(AppStrings.languageCode).map((gear) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(gear, style: const TextStyle(fontSize: 12)),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // Application time
          Row(
            children: [
              const Icon(Icons.schedule, size: 18, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  safety.getApplicationTime(AppStrings.languageCode),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Do Nots
          Text(
            AppStrings.isHindi
                ? '❌ ये न करें:'
                : AppStrings.isMarathi
                    ? '❌ हे करू नका:'
                    : '❌ Do NOT:',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 8),
          ...safety.getDoNots(AppStrings.languageCode).take(3).map((doNot) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(color: Colors.red)),
                  Expanded(
                    child: Text(
                      doNot,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
