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
  late Animation<double> _pulseAnimation;
  late Animation<double> _arrowAnimation;

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
      duration: const Duration(milliseconds: 1000),
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _arrowAnimation = Tween<double>(begin: 0, end: 20).animate(
      CurvedAnimation(parent: _arrowController, curve: Curves.easeInOut),
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
    // config is accessed inside the painter

    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _arrowController]),
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: AROverlayPainter(
            step: step,
            pulseValue: _pulseAnimation.value,
            arrowOffset: _arrowAnimation.value,
            showOverlay: _showOverlay,
          ),
        );
      },
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

/// Custom painter for AR overlays
class AROverlayPainter extends CustomPainter {
  final ARTreatmentStep step;
  final double pulseValue;
  final double arrowOffset;
  final bool showOverlay;

  AROverlayPainter({
    required this.step,
    required this.pulseValue,
    required this.arrowOffset,
    required this.showOverlay,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!showOverlay) return;

    final config = step.overlayConfig;
    final color = config.highlightColor.withOpacity(config.highlightOpacity);

    // Draw different overlays based on step type
    switch (step.type) {
      case TreatmentStepType.identifyArea:
        _drawIdentifyOverlay(canvas, size, color);
        break;
      case TreatmentStepType.application:
        _drawSprayOverlay(canvas, size, config);
        break;
      case TreatmentStepType.pruning:
        _drawPruneOverlay(canvas, size, color);
        break;
      case TreatmentStepType.watering:
        _drawWaterOverlay(canvas, size);
        break;
      case TreatmentStepType.safety:
        _drawSafetyOverlay(canvas, size);
        break;
      default:
        _drawDefaultOverlay(canvas, size, color);
    }

    // Draw distance indicator if applicable
    if (config.safeDistance != null) {
      _drawDistanceIndicator(canvas, size, config.safeDistance!);
    }
  }

  void _drawIdentifyOverlay(Canvas canvas, Size size, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * pulseValue;

    // Draw pulsing circle in center
    final center = Offset(size.width / 2, size.height / 2);
    final radius = 80 * pulseValue;

    canvas.drawCircle(center, radius, paint);

    // Draw corner brackets
    _drawCornerBrackets(canvas, size, color);
  }

  void _drawSprayOverlay(Canvas canvas, Size size, AROverlayConfig config) {
    // Draw spray direction arrows
    final arrowPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.fill;

    final centerX = size.width / 2;
    final startY = size.height * 0.3;

    // Animated arrow
    final path = Path();
    path.moveTo(centerX, startY + arrowOffset);
    path.lineTo(centerX - 15, startY + 30 + arrowOffset);
    path.lineTo(centerX, startY + 20 + arrowOffset);
    path.lineTo(centerX + 15, startY + 30 + arrowOffset);
    path.close();

    canvas.drawPath(path, arrowPaint);

    // Spray pattern lines
    final sprayPaint = Paint()
      ..color = Colors.green.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 0; i < 5; i++) {
      final y = startY + 50 + (i * 40) + arrowOffset;
      final xOffset = (i % 2 == 0 ? 1 : -1) * 30.0;
      canvas.drawLine(
        Offset(centerX - 50 + xOffset, y),
        Offset(centerX + 50 + xOffset, y),
        sprayPaint,
      );
    }
  }

  void _drawPruneOverlay(Canvas canvas, Size size, Color color) {
    final paint = Paint()
      ..color = Colors.purple.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw cutting guide lines
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Scissors icon representation
    canvas.drawLine(
      Offset(centerX - 40, centerY - 20),
      Offset(centerX + 40, centerY + 20),
      paint,
    );
    canvas.drawLine(
      Offset(centerX - 40, centerY + 20),
      Offset(centerX + 40, centerY - 20),
      paint,
    );
  }

  void _drawWaterOverlay(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyan.withOpacity(0.4)
      ..style = PaintingStyle.fill;

    // Draw water droplet shapes
    final centerX = size.width / 2;
    final startY = size.height * 0.4;

    for (int i = 0; i < 3; i++) {
      final x = centerX + (i - 1) * 40;
      final y = startY + (arrowOffset * (i + 1) / 3);

      final dropPath = Path();
      dropPath.moveTo(x, y);
      dropPath.quadraticBezierTo(x - 10, y + 15, x, y + 25);
      dropPath.quadraticBezierTo(x + 10, y + 15, x, y);
      dropPath.close();

      canvas.drawPath(dropPath, paint);
    }
  }

  void _drawSafetyOverlay(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.orange.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Draw warning border
    final rect = Rect.fromLTWH(20, 100, size.width - 40, size.height - 200);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(20)),
      paint,
    );
  }

  void _drawDefaultOverlay(Canvas canvas, Size size, Color color) {
    _drawCornerBrackets(canvas, size, color);
  }

  void _drawCornerBrackets(Canvas canvas, Size size, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    const bracketSize = 40.0;
    const margin = 50.0;

    // Top-left
    canvas.drawLine(
      Offset(margin, margin + bracketSize),
      Offset(margin, margin),
      paint,
    );
    canvas.drawLine(
      Offset(margin, margin),
      Offset(margin + bracketSize, margin),
      paint,
    );

    // Top-right
    canvas.drawLine(
      Offset(size.width - margin - bracketSize, margin),
      Offset(size.width - margin, margin),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - margin, margin),
      Offset(size.width - margin, margin + bracketSize),
      paint,
    );

    // Bottom-left
    canvas.drawLine(
      Offset(margin, size.height - margin - bracketSize),
      Offset(margin, size.height - margin),
      paint,
    );
    canvas.drawLine(
      Offset(margin, size.height - margin),
      Offset(margin + bracketSize, size.height - margin),
      paint,
    );

    // Bottom-right
    canvas.drawLine(
      Offset(size.width - margin - bracketSize, size.height - margin),
      Offset(size.width - margin, size.height - margin),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - margin, size.height - margin - bracketSize),
      Offset(size.width - margin, size.height - margin),
      paint,
    );
  }

  void _drawDistanceIndicator(Canvas canvas, Size size, double distance) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: '${(distance * 100).toInt()}cm',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(color: Colors.black54, blurRadius: 4),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(size.width - 80, size.height - 150),
    );
  }

  @override
  bool shouldRepaint(covariant AROverlayPainter oldDelegate) {
    return oldDelegate.pulseValue != pulseValue ||
        oldDelegate.arrowOffset != arrowOffset ||
        oldDelegate.showOverlay != showOverlay ||
        oldDelegate.step != step;
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
