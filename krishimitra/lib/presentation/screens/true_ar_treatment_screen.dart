/// TRUE AR Treatment Screen - Immersive Camera-Based AR Experience
/// Renders 3D-looking treatment objects on live camera feed
/// with Marathi/Hindi/English voice guidance via MarathiTtsService
library;

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:krishimitra/domain/models/ar_treatment_models.dart';
import 'package:krishimitra/services/ar_treatment_service.dart';
import 'package:krishimitra/services/marathi_tts_service.dart';
import 'package:krishimitra/utils/app_theme.dart';

// ─── Main Screen Widget ──────────────────────────────────────────────
class TrueARTreatmentScreen extends StatefulWidget {
  final String cropName;
  final String diseaseName;
  final double confidence;
  final String selectedLanguage;

  const TrueARTreatmentScreen({
    super.key,
    required this.cropName,
    required this.diseaseName,
    required this.confidence,
    required this.selectedLanguage,
  });

  @override
  State<TrueARTreatmentScreen> createState() => _TrueARTreatmentScreenState();
}

class _TrueARTreatmentScreenState extends State<TrueARTreatmentScreen>
    with TickerProviderStateMixin {
  // ── Camera ─────────────────────────────────────────────────────────
  CameraController? _cam;
  bool _camReady = false;

  // ── Data ───────────────────────────────────────────────────────────
  ARTreatmentPlan? _plan;
  bool _loading = true;
  String? _error;
  int _step = 0;
  bool _isSpeaking = false;

  // ── TTS ────────────────────────────────────────────────────────────
  final FlutterTts _flutterTts = FlutterTts();

  // ── AR State ───────────────────────────────────────────────────────
  _ARPhase _phase = _ARPhase.scanning;
  Offset _objectCenter = const Offset(0.5, 0.45); // normalised
  bool _showInfoCard = false;

  // ── Animations ─────────────────────────────────────────────────────
  late AnimationController _scanCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _objectEntryCtrl;
  late AnimationController _floatCtrl;
  late AnimationController _glowCtrl;
  late Animation<double> _scanAnim;
  late Animation<double> _pulseAnim;
  late Animation<double> _objectEntryAnim;
  late Animation<double> _floatAnim;
  late Animation<double> _glowAnim;

  Timer? _scanTimer;

  String get _lang {
    switch (widget.selectedLanguage) {
      case 'Marathi':
        return 'mr';
      case 'Hindi':
        return 'hi';
      default:
        return 'en';
    }
  }

  // ── Lifecycle ──────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _initAnimations();
    _initCamera();
    _loadPlan();

    MarathiTtsService.onSpeakingChanged = (s) {
      if (mounted) setState(() => _isSpeaking = s);
    };
    _flutterTts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
    _flutterTts.setStartHandler(() {
      if (mounted) setState(() => _isSpeaking = true);
    });
  }

  @override
  void dispose() {
    _scanCtrl.dispose();
    _pulseCtrl.dispose();
    _objectEntryCtrl.dispose();
    _floatCtrl.dispose();
    _glowCtrl.dispose();
    _scanTimer?.cancel();
    _cam?.dispose();
    MarathiTtsService.stop();
    MarathiTtsService.onSpeakingChanged = null;
    _flutterTts.stop();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  // ── Init helpers ───────────────────────────────────────────────────
  void _initAnimations() {
    _scanCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
    _scanAnim = Tween(begin: 0.0, end: 1.0).animate(_scanCtrl);

    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _objectEntryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _objectEntryAnim = CurvedAnimation(parent: _objectEntryCtrl, curve: Curves.elasticOut);

    _floatCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    _floatAnim = Tween(begin: -8.0, end: 8.0).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );

    _glowCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _glowAnim = Tween(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error = _t(
          'No camera available',
          'कोई कैमरा उपलब्ध नहीं',
          'कॅमेरा उपलब्ध नाही',
        ));
        return;
      }
      _cam = CameraController(cameras.first, ResolutionPreset.high, enableAudio: false);
      await _cam!.initialize();
      if (mounted) setState(() => _camReady = true);
    } catch (e) {
      if (mounted) {
        setState(() => _error = _t(
          'Camera error: $e',
          'कैमरा त्रुटि: $e',
          'कॅमेरा त्रुटी: $e',
        ));
      }
    }
  }

  Future<void> _loadPlan() async {
    try {
      final plan = await ARTreatmentService.generateTreatmentPlan(
        plantName: widget.cropName,
        diseaseName: widget.diseaseName,
        confidence: widget.confidence,
        languageCode: _lang,
      );
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _loading = false;
      });
      // Start scanning phase
      _startScanning();
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  // ── Scanning phase — simulates surface detection ───────────────────
  void _startScanning() {
    setState(() => _phase = _ARPhase.scanning);
    // Speak scanning instruction
    _speakCurrent(_t(
      'Point your camera at the plant. Scanning surface...',
      'कैमरा पौधे पर करें। सतह स्कैन हो रही है...',
      'कॅमेरा झाडावर धरा. पृष्ठभाग स्कॅन होत आहे...',
    ));
    _scanTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) _onSurfaceDetected();
    });
  }

  void _onSurfaceDetected() {
    setState(() => _phase = _ARPhase.placed);
    _objectEntryCtrl.forward(from: 0);
    // Speak the first step
    _speakStepNarration();
  }

  // ── TTS ────────────────────────────────────────────────────────────
  Future<void> _speakCurrent(String text) async {
    // For Marathi: use MarathiTtsService (Sarvam AI + flutter_tts fallback)
    // For Hindi/English: use flutter_tts directly with proper locale
    if (_lang == 'mr') {
      await MarathiTtsService.stop();
      await MarathiTtsService.speak(text);
    } else {
      await _flutterTts.stop();
      final locale = _lang == 'hi' ? 'hi-IN' : 'en-US';
      await _flutterTts.setLanguage(locale);
      await _flutterTts.setSpeechRate(0.45);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.speak(text);
    }
  }

  void _speakStepNarration() {
    if (_plan == null) return;
    final step = _plan!.steps[_step];
    final narration = ARTreatmentService.getVoiceNarration(step, _lang);
    _speakCurrent(narration);
  }

  // ── Navigation ─────────────────────────────────────────────────────
  void _nextStep() {
    if (_plan == null || _step >= _plan!.steps.length - 1) return;
    _objectEntryCtrl.reset();
    setState(() {
      _step++;
      _showInfoCard = false;
    });
    _objectEntryCtrl.forward(from: 0);
    _speakStepNarration();
  }

  void _prevStep() {
    if (_step <= 0) return;
    _objectEntryCtrl.reset();
    setState(() {
      _step--;
      _showInfoCard = false;
    });
    _objectEntryCtrl.forward(from: 0);
    _speakStepNarration();
  }

  void _replayVoice() => _speakStepNarration();

  // ── Helpers ────────────────────────────────────────────────────────
  String _t(String en, String hi, String mr) {
    switch (_lang) {
      case 'hi': return hi;
      case 'mr': return mr;
      default: return en;
    }
  }

  // ── BUILD ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Layer 0: Camera feed
          _buildCamera(),
          // Layer 1: AR overlays
          if (!_loading && _error == null) _buildAROverlay(),
          // Layer 2: Top bar
          _buildTopBar(),
          // Layer 3: Bottom controls
          if (_phase == _ARPhase.placed && _plan != null) _buildBottomPanel(),
          // Layer 4: Loading / Error
          if (_loading) _buildLoadingOverlay(),
          if (_error != null) _buildErrorOverlay(),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  CAMERA
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildCamera() {
    if (!_camReady || _cam == null) {
      return Container(color: Colors.black);
    }
    // Fill screen with camera maintaining aspect ratio
    final size = MediaQuery.of(context).size;
    final camAspect = _cam!.value.aspectRatio;
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: size.width,
          height: size.width * camAspect,
          child: CameraPreview(_cam!),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  AR OVERLAY — scanning vs placed
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildAROverlay() {
    if (_phase == _ARPhase.scanning) return _buildScanningOverlay();
    if (_plan == null) return const SizedBox.shrink();
    return _buildPlacedOverlay();
  }

  // ── Scanning animation ─────────────────────────────────────────────
  Widget _buildScanningOverlay() {
    return AnimatedBuilder(
      animation: _scanAnim,
      builder: (_, __) {
        return CustomPaint(
          painter: _ScannerPainter(
            progress: _scanAnim.value,
            color: AppTheme.primaryGreen,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 60),
                // Animated scanning reticle
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, __) => Transform.scale(
                    scale: _pulseAnim.value,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.primaryGreen.withValues(alpha: 0.7),
                          width: 2.5,
                        ),
                      ),
                      child: Icon(
                        Icons.grass,
                        size: 64,
                        color: AppTheme.primaryGreen.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _t(
                          'Scanning surface…',
                          'सतह स्कैन हो रही है…',
                          'पृष्ठभाग स्कॅन होत आहे…',
                        ),
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── 3D objects placed in scene ─────────────────────────────────────
  Widget _buildPlacedOverlay() {
    final step = _plan!.steps[_step];
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    final cx = _objectCenter.dx * screenW;
    final cy = _objectCenter.dy * screenH;

    return Stack(
      children: [
        // Shadow / ground plane indicator
        AnimatedBuilder(
          animation: _glowAnim,
          builder: (_, __) => Positioned(
            left: cx - 60,
            top: cy + 60,
            child: Opacity(
              opacity: _glowAnim.value * 0.5,
              child: Container(
                width: 120,
                height: 24,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(60),
                  gradient: RadialGradient(
                    colors: [
                      ARTreatmentService.getStepColor(step.type).withValues(alpha: 0.4),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // Main 3D AR object with entry + float animations
        AnimatedBuilder(
          animation: Listenable.merge([_objectEntryAnim, _floatAnim]),
          builder: (_, __) {
            final entryScale = _objectEntryAnim.value;
            final floatY = _floatAnim.value;
            return Positioned(
              left: cx - 75,
              top: cy - 75 + floatY,
              child: GestureDetector(
                onTap: () => setState(() => _showInfoCard = !_showInfoCard),
                onPanUpdate: (d) {
                  setState(() {
                    _objectCenter = Offset(
                      (_objectCenter.dx + d.delta.dx / screenW).clamp(0.15, 0.85),
                      (_objectCenter.dy + d.delta.dy / screenH).clamp(0.15, 0.75),
                    );
                  });
                },
                child: Transform.scale(
                  scale: entryScale,
                  child: _AR3DObject(
                    type: step.type,
                    color: ARTreatmentService.getStepColor(step.type),
                    pulseAnim: _pulseAnim,
                    glowAnim: _glowAnim,
                  ),
                ),
              ),
            );
          },
        ),

        // Tap hint ring
        if (!_showInfoCard)
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => Positioned(
              left: cx - 50,
              top: cy + 80 + _floatAnim.value,
              child: Opacity(
                opacity: 0.6,
                child: Transform.scale(
                  scale: _pulseAnim.value * 0.85,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _t('Tap for details', 'विवरण के लिए टैप करें', 'तपशीलांसाठी टॅप करा'),
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ),
                ),
              ),
            ),
          ),

        // Info card
        if (_showInfoCard) _buildInfoCard(step, cx, cy),
      ],
    );
  }

  // ── Info card that pops up when you tap the 3D object ──────────────
  Widget _buildInfoCard(ARTreatmentStep step, double cx, double cy) {
    final screenW = MediaQuery.of(context).size.width;
    final cardW = screenW * 0.82;
    return Positioned(
      left: (screenW - cardW) / 2,
      top: cy + 100,
      child: AnimatedOpacity(
        opacity: _showInfoCard ? 1 : 0,
        duration: const Duration(milliseconds: 250),
        child: Container(
          width: cardW,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: ARTreatmentService.getStepColor(step.type).withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: ARTreatmentService.getStepColor(step.type).withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ARTreatmentService.getStepColor(step.type).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      ARTreatmentService.getStepIcon(step.type),
                      color: ARTreatmentService.getStepColor(step.type),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      step.getTitle(_lang),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Close button
                  GestureDetector(
                    onTap: () => setState(() => _showInfoCard = false),
                    child: const Icon(Icons.close, color: Colors.white54, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Description
              Text(
                step.getDescription(_lang),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              // Warnings
              if (step.warnings.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...step.warnings.map((w) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('⚠️ ', style: TextStyle(fontSize: 13)),
                      Expanded(
                        child: Text(w,
                          style: TextStyle(
                            color: Colors.amber.shade200,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
              ],
              const SizedBox(height: 10),
              // Duration
              Row(
                children: [
                  Icon(Icons.timer_outlined, color: Colors.white38, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '~${step.estimatedDuration.inMinutes} ${_t('min', 'मिनट', 'मिनिटे')}',
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  TOP BAR
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          left: 12,
          right: 12,
          bottom: 10,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            // Back button
            _circleButton(Icons.arrow_back, () => Navigator.pop(context)),
            const SizedBox(width: 10),
            // Title
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t('AR Treatment', 'AR उपचार', 'AR उपचार'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${widget.cropName} - ${widget.diseaseName}',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Voice replay
            _circleButton(
              _isSpeaking ? Icons.volume_up : Icons.volume_up_outlined,
              _replayVoice,
              color: _isSpeaking ? AppTheme.primaryGreen : Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap, {Color color = Colors.white}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black38,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  BOTTOM PANEL — step controls + progress
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildBottomPanel() {
    final step = _plan!.steps[_step];
    final total = _plan!.steps.length;
    final progress = (_step + 1) / total;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 12,
          top: 16,
          left: 16,
          right: 16,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withValues(alpha: 0.9),
              Colors.black.withValues(alpha: 0.6),
              Colors.transparent,
            ],
            stops: const [0.0, 0.7, 1.0],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Step title + number
            Row(
              children: [
                // Step type icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ARTreatmentService.getStepColor(step.type).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: ARTreatmentService.getStepColor(step.type).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Icon(
                    ARTreatmentService.getStepIcon(step.type),
                    color: ARTreatmentService.getStepColor(step.type),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_t('Step', 'चरण', 'पायरी')} ${_step + 1}/$total',
                        style: TextStyle(
                          color: ARTreatmentService.getStepColor(step.type),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        step.getTitle(_lang),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation(
                  ARTreatmentService.getStepColor(step.type),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Navigation row
            Row(
              children: [
                // Previous
                Expanded(
                  child: _step > 0
                      ? _navButton(
                          Icons.arrow_back_rounded,
                          _t('Previous', 'पिछला', 'मागील'),
                          _prevStep,
                          outlined: true,
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(width: 12),
                // Voice
                _circleButton(
                  _isSpeaking ? Icons.stop_rounded : Icons.replay_rounded,
                  _isSpeaking ? () { MarathiTtsService.stop(); _flutterTts.stop(); } : _replayVoice,
                  color: _isSpeaking ? Colors.red.shade300 : Colors.white,
                ),
                const SizedBox(width: 12),
                // Next / Finish
                Expanded(
                  child: _step < total - 1
                      ? _navButton(
                          Icons.arrow_forward_rounded,
                          _t('Next', 'अगला', 'पुढील'),
                          _nextStep,
                        )
                      : _navButton(
                          Icons.check_circle_outline,
                          _t('Finish', 'समाप्त', 'पूर्ण'),
                          () => Navigator.pop(context),
                          color: AppTheme.primaryGreen,
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _navButton(IconData icon, String label, VoidCallback onTap,
      {bool outlined = false, Color? color}) {
    final c = color ?? AppTheme.primaryGreen;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : c.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: outlined ? Colors.white30 : c.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (outlined) Icon(icon, color: Colors.white70, size: 18),
            if (outlined) const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: outlined ? Colors.white70 : c,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (!outlined) const SizedBox(width: 6),
            if (!outlined) Icon(icon, color: c, size: 18),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  LOADING / ERROR
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 20),
            Text(
              _t(
                'Preparing AR treatment guide…',
                'AR उपचार मार्गदर्शक तैयार हो रहा है…',
                'AR उपचार मार्गदर्शक तयार होत आहे…',
              ),
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorOverlay() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 56),
              const SizedBox(height: 16),
              Text(
                _error ?? 'Unknown error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: Text(_t('Go Back', 'वापस जाएं', 'मागे जा')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
//  AR PHASE
// ═════════════════════════════════════════════════════════════════════
enum _ARPhase { scanning, placed }

// ═════════════════════════════════════════════════════════════════════
//  3D AR OBJECT WIDGET — renders different treatment items
// ═════════════════════════════════════════════════════════════════════
class _AR3DObject extends StatelessWidget {
  final TreatmentStepType type;
  final Color color;
  final Animation<double> pulseAnim;
  final Animation<double> glowAnim;

  const _AR3DObject({
    required this.type,
    required this.color,
    required this.pulseAnim,
    required this.glowAnim,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([pulseAnim, glowAnim]),
      builder: (_, __) {
        return SizedBox(
          width: 150,
          height: 150,
          child: CustomPaint(
            painter: _AR3DPainter(
              type: type,
              color: color,
              pulse: pulseAnim.value,
              glow: glowAnim.value,
            ),
          ),
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
//  3D OBJECT PAINTER — paints rich, 3D-looking treatment objects
// ═════════════════════════════════════════════════════════════════════
class _AR3DPainter extends CustomPainter {
  final TreatmentStepType type;
  final Color color;
  final double pulse;
  final double glow;

  _AR3DPainter({
    required this.type,
    required this.color,
    required this.pulse,
    required this.glow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Outer glow
    final glowPaint = Paint()
      ..color = color.withValues(alpha: glow * 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25);
    canvas.drawCircle(Offset(cx, cy), 55 * pulse, glowPaint);

    switch (type) {
      case TreatmentStepType.identifyArea:
        _paintMagnifyingGlass(canvas, size, cx, cy);
      case TreatmentStepType.safety:
        _paintShield(canvas, size, cx, cy);
      case TreatmentStepType.prepareTools:
        _paintToolbox(canvas, size, cx, cy);
      case TreatmentStepType.prepareSolution:
        _paintBeaker(canvas, size, cx, cy);
      case TreatmentStepType.application:
        _paintSprayer(canvas, size, cx, cy);
      case TreatmentStepType.pruning:
        _paintScissors(canvas, size, cx, cy);
      case TreatmentStepType.watering:
        _paintWateringCan(canvas, size, cx, cy);
      case TreatmentStepType.monitoring:
        _paintEye(canvas, size, cx, cy);
      case TreatmentStepType.prevention:
        _paintLeafShield(canvas, size, cx, cy);
      case TreatmentStepType.soilTreatment:
        _paintShovel(canvas, size, cx, cy);
    }
  }

  // ── Magnifying Glass (identifyArea) ────────────────────────────────
  void _paintMagnifyingGlass(Canvas canvas, Size size, double cx, double cy) {
    final s = size.width * 0.3 * pulse;
    // Glass circle
    final glassPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx - 5, cy - 8), s, glassPaint);
    // Glass ring
    final ringPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;
    canvas.drawCircle(Offset(cx - 5, cy - 8), s, ringPaint);
    // Handle
    final handlePaint = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    final hx = cx - 5 + s * 0.7;
    final hy = cy - 8 + s * 0.7;
    canvas.drawLine(Offset(hx, hy), Offset(hx + 20, hy + 20), handlePaint);
    // Cross-hair inside
    final crossPaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(cx - 5 - s * 0.5, cy - 8), Offset(cx - 5 + s * 0.5, cy - 8), crossPaint);
    canvas.drawLine(Offset(cx - 5, cy - 8 - s * 0.5), Offset(cx - 5, cy - 8 + s * 0.5), crossPaint);
  }

  // ── Shield (safety) ────────────────────────────────────────────────
  void _paintShield(Canvas canvas, Size size, double cx, double cy) {
    final s = size.width * 0.28 * pulse;
    final path = Path()
      ..moveTo(cx, cy - s * 1.1)
      ..quadraticBezierTo(cx + s * 1.1, cy - s * 0.5, cx + s * 0.9, cy + s * 0.3)
      ..quadraticBezierTo(cx + s * 0.4, cy + s * 1.1, cx, cy + s * 1.2)
      ..quadraticBezierTo(cx - s * 0.4, cy + s * 1.1, cx - s * 0.9, cy + s * 0.3)
      ..quadraticBezierTo(cx - s * 1.1, cy - s * 0.5, cx, cy - s * 1.1);
    // Shadow
    canvas.drawPath(path.shift(const Offset(3, 3)),
      Paint()..color = Colors.black26..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    // Fill
    canvas.drawPath(path, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color, color.withValues(alpha: 0.5)],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: s)));
    // Border
    canvas.drawPath(path, Paint()..color = Colors.white30..style = PaintingStyle.stroke..strokeWidth = 2);
    // Cross symbol
    final crossP = Paint()..color = Colors.white..strokeWidth = 3..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx, cy - s * 0.3), Offset(cx, cy + s * 0.3), crossP);
    canvas.drawLine(Offset(cx - s * 0.25, cy), Offset(cx + s * 0.25, cy), crossP);
  }

  // ── Toolbox (prepareTools) ─────────────────────────────────────────
  void _paintToolbox(Canvas canvas, Size size, double cx, double cy) {
    final w = size.width * 0.5 * pulse;
    final h = size.height * 0.35 * pulse;
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy + 5), width: w, height: h),
      const Radius.circular(6),
    );
    // Shadow
    canvas.drawRRect(rect.shift(const Offset(3, 3)),
      Paint()..color = Colors.black26..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    // Body
    canvas.drawRRect(rect, Paint()
      ..shader = LinearGradient(
        colors: [color, color.withValues(alpha: 0.6)],
      ).createShader(rect.outerRect));
    canvas.drawRRect(rect, Paint()..color = Colors.white24..style = PaintingStyle.stroke..strokeWidth = 1.5);
    // Handle
    final handleRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy - h / 2 - 6), width: w * 0.4, height: 10),
      const Radius.circular(5),
    );
    canvas.drawRRect(handleRect, Paint()..color = color.withValues(alpha: 0.8));
    // Lock
    canvas.drawCircle(Offset(cx, cy + 5), 4, Paint()..color = Colors.white54);
  }

  // ── Beaker (prepareSolution) ───────────────────────────────────────
  void _paintBeaker(Canvas canvas, Size size, double cx, double cy) {
    final s = size.width * 0.22 * pulse;
    // Beaker body
    final body = Path()
      ..moveTo(cx - s * 0.5, cy - s)
      ..lineTo(cx - s * 0.7, cy + s * 0.8)
      ..quadraticBezierTo(cx - s * 0.7, cy + s, cx - s * 0.4, cy + s)
      ..lineTo(cx + s * 0.4, cy + s)
      ..quadraticBezierTo(cx + s * 0.7, cy + s, cx + s * 0.7, cy + s * 0.8)
      ..lineTo(cx + s * 0.5, cy - s)
      ..close();
    // Shadow
    canvas.drawPath(body.shift(const Offset(3, 3)),
      Paint()..color = Colors.black26..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    // Glass body
    canvas.drawPath(body, Paint()..color = color.withValues(alpha: 0.2));
    canvas.drawPath(body, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2.5);
    // Liquid inside
    final liquid = Path()
      ..moveTo(cx - s * 0.6, cy + s * 0.2)
      ..quadraticBezierTo(cx, cy + s * 0.05, cx + s * 0.6, cy + s * 0.2)
      ..lineTo(cx + s * 0.65, cy + s * 0.75)
      ..quadraticBezierTo(cx + s * 0.65, cy + s * 0.95, cx + s * 0.35, cy + s * 0.95)
      ..lineTo(cx - s * 0.35, cy + s * 0.95)
      ..quadraticBezierTo(cx - s * 0.65, cy + s * 0.95, cx - s * 0.65, cy + s * 0.75)
      ..close();
    canvas.drawPath(liquid, Paint()..color = color.withValues(alpha: 0.4));
    // Measurement lines
    final linePaint = Paint()..color = Colors.white30..strokeWidth = 1;
    for (var i = 0; i < 3; i++) {
      final ly = cy + s * (0.0 + i * 0.3);
      canvas.drawLine(Offset(cx - s * 0.3, ly), Offset(cx - s * 0.1, ly), linePaint);
    }
  }

  // ── Sprayer (application) ──────────────────────────────────────────
  void _paintSprayer(Canvas canvas, Size size, double cx, double cy) {
    final s = size.width * 0.22 * pulse;
    // Tank
    final tank = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy + s * 0.3), width: s * 1.2, height: s * 1.6),
      const Radius.circular(8),
    );
    canvas.drawRRect(tank.shift(const Offset(3, 3)),
      Paint()..color = Colors.black26..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawRRect(tank, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color, color.withValues(alpha: 0.5)],
      ).createShader(tank.outerRect));
    canvas.drawRRect(tank, Paint()..color = Colors.white24..style = PaintingStyle.stroke..strokeWidth = 1.5);
    // Nozzle
    final nPaint = Paint()..color = color.withValues(alpha: 0.8)..strokeWidth = 4..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx + s * 0.3, cy - s * 0.5), Offset(cx + s * 0.8, cy - s * 1.0), nPaint);
    // Spray particles
    final particlePaint = Paint()..color = color.withValues(alpha: glow * 0.7);
    final rng = math.Random(42);
    for (var i = 0; i < 8; i++) {
      final px = cx + s * 0.8 + rng.nextDouble() * s * 0.8;
      final py = cy - s * 1.0 + (rng.nextDouble() - 0.5) * s * 0.9;
      canvas.drawCircle(Offset(px, py), 2 + rng.nextDouble() * 2.5, particlePaint);
    }
    // Pump handle
    canvas.drawLine(
      Offset(cx - s * 0.3, cy - s * 0.5),
      Offset(cx - s * 0.3, cy - s * 1.0),
      Paint()..color = Colors.white38..strokeWidth = 3..strokeCap = StrokeCap.round,
    );
  }

  // ── Scissors (pruning) ─────────────────────────────────────────────
  void _paintScissors(Canvas canvas, Size size, double cx, double cy) {
    final s = size.width * 0.25 * pulse;
    final bladePaint = Paint()..color = color..strokeWidth = 3.5..strokeCap = StrokeCap.round;
    // Blade 1
    canvas.drawLine(Offset(cx, cy), Offset(cx - s * 0.9, cy - s * 0.8), bladePaint);
    // Blade 2
    canvas.drawLine(Offset(cx, cy), Offset(cx + s * 0.9, cy - s * 0.8), bladePaint);
    // Handles
    final handlePaint = Paint()..color = color.withValues(alpha: 0.7)..strokeWidth = 4..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx, cy), Offset(cx - s * 0.6, cy + s * 0.9), handlePaint);
    canvas.drawLine(Offset(cx, cy), Offset(cx + s * 0.6, cy + s * 0.9), handlePaint);
    // Pivot
    canvas.drawCircle(Offset(cx, cy), 5, Paint()..color = Colors.white54);
    // Handle rings
    canvas.drawCircle(Offset(cx - s * 0.6, cy + s * 0.9), 10, Paint()..color = color.withValues(alpha: 0.3));
    canvas.drawCircle(Offset(cx - s * 0.6, cy + s * 0.9), 10,
      Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2);
    canvas.drawCircle(Offset(cx + s * 0.6, cy + s * 0.9), 10, Paint()..color = color.withValues(alpha: 0.3));
    canvas.drawCircle(Offset(cx + s * 0.6, cy + s * 0.9), 10,
      Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2);
  }

  // ── Watering Can (watering) ────────────────────────────────────────
  void _paintWateringCan(Canvas canvas, Size size, double cx, double cy) {
    final s = size.width * 0.22 * pulse;
    // Can body
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy + s * 0.1), width: s * 1.5, height: s * 1.2),
      const Radius.circular(6),
    );
    canvas.drawRRect(body.shift(const Offset(3, 3)),
      Paint()..color = Colors.black26..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawRRect(body, Paint()
      ..shader = LinearGradient(colors: [color, color.withValues(alpha: 0.5)])
        .createShader(body.outerRect));
    canvas.drawRRect(body, Paint()..color = Colors.white24..style = PaintingStyle.stroke..strokeWidth = 1.5);
    // Spout
    final spoutPaint = Paint()..color = color.withValues(alpha: 0.8)..strokeWidth = 3.5..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx + s * 0.75, cy - s * 0.2), Offset(cx + s * 1.3, cy - s * 0.8), spoutPaint);
    // Water drops
    final dropPaint = Paint()..color = Colors.lightBlueAccent.withValues(alpha: glow);
    for (var i = 0; i < 5; i++) {
      final dx = cx + s * 1.3 + (i - 2) * 6.0;
      final dy = cy - s * 0.7 + i * 8.0;
      canvas.drawCircle(Offset(dx, dy), 2.5, dropPaint);
    }
    // Handle
    final handlePath = Path()
      ..moveTo(cx - s * 0.5, cy - s * 0.6)
      ..quadraticBezierTo(cx - s * 0.8, cy - s * 1.0, cx - s * 0.2, cy - s * 0.6);
    canvas.drawPath(handlePath, Paint()..color = color.withValues(alpha: 0.7)..style = PaintingStyle.stroke..strokeWidth = 3);
  }

  // ── Eye (monitoring) ───────────────────────────────────────────────
  void _paintEye(Canvas canvas, Size size, double cx, double cy) {
    final s = size.width * 0.28 * pulse;
    // Eye outline
    final eyePath = Path()
      ..moveTo(cx - s, cy)
      ..quadraticBezierTo(cx, cy - s * 0.7, cx + s, cy)
      ..quadraticBezierTo(cx, cy + s * 0.7, cx - s, cy);
    canvas.drawPath(eyePath.shift(const Offset(2, 2)),
      Paint()..color = Colors.black26..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawPath(eyePath, Paint()..color = Colors.white.withValues(alpha: 0.15));
    canvas.drawPath(eyePath, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2.5);
    // Iris
    canvas.drawCircle(Offset(cx, cy), s * 0.35, Paint()..color = color.withValues(alpha: 0.6));
    canvas.drawCircle(Offset(cx, cy), s * 0.35,
      Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2);
    // Pupil
    canvas.drawCircle(Offset(cx, cy), s * 0.15, Paint()..color = Colors.black87);
    // Highlight
    canvas.drawCircle(Offset(cx - s * 0.08, cy - s * 0.08), s * 0.06, Paint()..color = Colors.white70);
  }

  // ── Leaf + shield (prevention) ─────────────────────────────────────
  void _paintLeafShield(Canvas canvas, Size size, double cx, double cy) {
    final s = size.width * 0.25 * pulse;
    // Leaf shape
    final leaf = Path()
      ..moveTo(cx, cy - s)
      ..quadraticBezierTo(cx + s * 1.2, cy - s * 0.3, cx + s * 0.5, cy + s * 0.8)
      ..quadraticBezierTo(cx + s * 0.1, cy + s * 1.0, cx, cy + s * 0.9)
      ..quadraticBezierTo(cx - s * 0.1, cy + s * 1.0, cx - s * 0.5, cy + s * 0.8)
      ..quadraticBezierTo(cx - s * 1.2, cy - s * 0.3, cx, cy - s);
    canvas.drawPath(leaf.shift(const Offset(2, 2)),
      Paint()..color = Colors.black26..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawPath(leaf, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color, color.withValues(alpha: 0.4)],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: s)));
    canvas.drawPath(leaf, Paint()..color = Colors.white24..style = PaintingStyle.stroke..strokeWidth = 1.5);
    // Vein
    final vein = Paint()..color = Colors.white30..strokeWidth = 1.2;
    canvas.drawLine(Offset(cx, cy - s * 0.7), Offset(cx, cy + s * 0.8), vein);
    canvas.drawLine(Offset(cx, cy - s * 0.2), Offset(cx + s * 0.4, cy - s * 0.5), vein);
    canvas.drawLine(Offset(cx, cy + s * 0.1), Offset(cx - s * 0.4, cy - s * 0.2), vein);
    // Check mark
    final check = Paint()..color = Colors.white..strokeWidth = 3..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx - s * 0.2, cy + s * 0.2), Offset(cx - s * 0.05, cy + s * 0.4), check);
    canvas.drawLine(Offset(cx - s * 0.05, cy + s * 0.4), Offset(cx + s * 0.3, cy), check);
  }

  // ── Shovel (soilTreatment) ─────────────────────────────────────────
  void _paintShovel(Canvas canvas, Size size, double cx, double cy) {
    final s = size.width * 0.22 * pulse;
    // Handle
    final handle = Paint()..color = Colors.brown.shade300..strokeWidth = 5..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx, cy - s * 1.0), Offset(cx, cy + s * 0.3), handle);
    // Blade
    final blade = Path()
      ..moveTo(cx - s * 0.5, cy + s * 0.3)
      ..lineTo(cx + s * 0.5, cy + s * 0.3)
      ..lineTo(cx + s * 0.3, cy + s * 1.1)
      ..quadraticBezierTo(cx, cy + s * 1.3, cx - s * 0.3, cy + s * 1.1)
      ..close();
    canvas.drawPath(blade.shift(const Offset(2, 2)),
      Paint()..color = Colors.black26..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.drawPath(blade, Paint()
      ..shader = LinearGradient(
        colors: [color, color.withValues(alpha: 0.5)],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy + s * 0.7), radius: s)));
    canvas.drawPath(blade, Paint()..color = Colors.white24..style = PaintingStyle.stroke..strokeWidth = 1.5);
    // T-handle
    canvas.drawLine(Offset(cx - s * 0.3, cy - s * 1.0), Offset(cx + s * 0.3, cy - s * 1.0),
      Paint()..color = Colors.brown.shade400..strokeWidth = 4..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant _AR3DPainter old) => true;
}

// ═════════════════════════════════════════════════════════════════════
//  SCANNER PAINTER — radar sweep effect during surface detection
// ═════════════════════════════════════════════════════════════════════
class _ScannerPainter extends CustomPainter {
  final double progress;
  final Color color;

  _ScannerPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxR = size.width * 0.45;

    // Sweep
    final sweepAngle = progress * 2 * math.pi;
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        startAngle: sweepAngle - 0.8,
        endAngle: sweepAngle,
        colors: [Colors.transparent, color.withValues(alpha: 0.15)],
        tileMode: TileMode.clamp,
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: maxR));
    canvas.drawCircle(Offset(cx, cy), maxR, sweepPaint);

    // Concentric rings
    final ringPaint = Paint()
      ..color = color.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (var r = maxR * 0.3; r <= maxR; r += maxR * 0.25) {
      canvas.drawCircle(Offset(cx, cy), r, ringPaint);
    }

    // Corner brackets
    final bracketPaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    const bl = 30.0;
    const m = 40.0;
    // Top-left
    canvas.drawLine(Offset(m, m), Offset(m + bl, m), bracketPaint);
    canvas.drawLine(Offset(m, m), Offset(m, m + bl), bracketPaint);
    // Top-right
    canvas.drawLine(Offset(size.width - m, m), Offset(size.width - m - bl, m), bracketPaint);
    canvas.drawLine(Offset(size.width - m, m), Offset(size.width - m, m + bl), bracketPaint);
    // Bottom-left
    canvas.drawLine(Offset(m, size.height - m), Offset(m + bl, size.height - m), bracketPaint);
    canvas.drawLine(Offset(m, size.height - m), Offset(m, size.height - m - bl), bracketPaint);
    // Bottom-right
    canvas.drawLine(Offset(size.width - m, size.height - m), Offset(size.width - m - bl, size.height - m), bracketPaint);
    canvas.drawLine(Offset(size.width - m, size.height - m), Offset(size.width - m, size.height - m - bl), bracketPaint);

    // Grid dots
    final dotPaint = Paint()..color = color.withValues(alpha: 0.06);
    for (var x = m; x < size.width - m; x += 30) {
      for (var y = m; y < size.height - m; y += 30) {
        canvas.drawCircle(Offset(x, y), 1, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ScannerPainter old) => old.progress != progress;
}
