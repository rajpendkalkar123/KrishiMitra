/// REAL 3D AR Treatment Screen - Using GLB 3D Models in Camera Space
/// Shows actual 3D farmer model overlaid on camera feed
library;

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:krishimitra/domain/models/ar_treatment_models.dart';
import 'package:krishimitra/services/ar_treatment_service.dart';
import 'package:krishimitra/services/marathi_tts_service.dart';
import 'package:krishimitra/utils/app_theme.dart';

class Real3DARTreatmentScreen extends StatefulWidget {
  final String cropName;
  final String diseaseName;
  final double confidence;
  final String selectedLanguage;

  const Real3DARTreatmentScreen({
    super.key,
    required this.cropName,
    required this.diseaseName,
    required this.confidence,
    required this.selectedLanguage,
  });

  @override
  State<Real3DARTreatmentScreen> createState() => _Real3DARTreatmentScreenState();
}

class _Real3DARTreatmentScreenState extends State<Real3DARTreatmentScreen>
    with TickerProviderStateMixin {
  // Camera
  CameraController? _cam;
  bool _camReady = false;

  // Data
  ARTreatmentPlan? _plan;
  bool _loading = true;
  String? _error;
  int _step = 0;
  bool _isSpeaking = false;

  // TTS
  final FlutterTts _flutterTts = FlutterTts();

  // AR State
  _ARPhase _phase = _ARPhase.scanning;
  bool _showInfoCard = false;
  bool _show3DModel = false;

  // Animations
  late AnimationController _scanCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _modelEntryCtrl;
  late Animation<double> _scanAnim;
  late Animation<double> _pulseAnim;
  late Animation<double> _modelEntryAnim;

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
    _modelEntryCtrl.dispose();
    _scanTimer?.cancel();
    _cam?.dispose();
    MarathiTtsService.stop();
    MarathiTtsService.onSpeakingChanged = null;
    _flutterTts.stop();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  void _initAnimations() {
    _scanCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
    _scanAnim = Tween(begin: 0.0, end: 1.0).animate(_scanCtrl);

    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _modelEntryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _modelEntryAnim = CurvedAnimation(parent: _modelEntryCtrl, curve: Curves.elasticOut);
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
      _startScanning();
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  void _startScanning() {
    setState(() => _phase = _ARPhase.scanning);
    _speakCurrent(_t(
      'Point your camera at the ground. Scanning for surface placement...',
      'कैमरा ज़मीन पर करें। सतह स्कैन हो रही है...',
      'कॅमेरा जमिनीवर धरा. पृष्ठभाग स्कॅन होत आहे...',
    ));
    _scanTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) _onSurfaceDetected();
    });
  }

  void _onSurfaceDetected() {
    setState(() {
      _phase = _ARPhase.placed;
      _show3DModel = true;
    });
    _modelEntryCtrl.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 500), _speakStepNarration);
  }

  Future<void> _speakCurrent(String text) async {
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

  void _nextStep() {
    if (_plan == null || _step >= _plan!.steps.length - 1) return;
    setState(() {
      _step++;
      _showInfoCard = false;
    });
    _speakStepNarration();
  }

  void _prevStep() {
    if (_step <= 0) return;
    setState(() {
      _step--;
      _showInfoCard = false;
    });
    _speakStepNarration();
  }

  void _replayVoice() => _speakStepNarration();

  String _t(String en, String hi, String mr) {
    switch (_lang) {
      case 'hi': return hi;
      case 'mr': return mr;
      default: return en;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Layer 0: Camera feed
          _buildCamera(),
          
          // Layer 1: 3D Model Overlay (AR)
          if (_show3DModel && _phase == _ARPhase.placed) _build3DModelOverlay(),
          
          // Layer 2: Scanning overlay
          if (_phase == _ARPhase.scanning) _buildScanningOverlay(),
          
          // Layer 3: Info card
          if (_showInfoCard && _plan != null) _buildInfoCard(),
          
          // Layer 4: Top bar
          _buildTopBar(),
          
          // Layer 5: Bottom controls
          if (_phase == _ARPhase.placed && _plan != null) _buildBottomPanel(),
          
          // Layer 6: Loading / Error
          if (_loading) _buildLoadingOverlay(),
          if (_error != null) _buildErrorOverlay(),
        ],
      ),
    );
  }

  Widget _buildCamera() {
    if (!_camReady || _cam == null) {
      return Container(color: Colors.black);
    }
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

  Widget _build3DModelOverlay() {
    return AnimatedBuilder(
      animation: _modelEntryAnim,
      builder: (_, __) {
        final scale = _modelEntryAnim.value;
        return Positioned.fill(
          child: IgnorePointer(
            ignoring: false,
            child: Stack(
              children: [
                // 3D Model Viewer - ENHANCED for true 3D AR experience
                Positioned(
                  left: MediaQuery.of(context).size.width * 0.05,
                  right: MediaQuery.of(context).size.width * 0.05,
                  bottom: MediaQuery.of(context).size.height * 0.2,
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: Transform.scale(
                    scale: scale,
                    child: AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (_, __) {
                        return ModelViewer(
                          src: 'assets/models/farmer.glb',
                          alt: 'Farmer 3D Model',
                          ar: false,
                          autoRotate: true, // Auto-rotate for 3D effect
                          autoRotateDelay: 0,
                          rotationPerSecond: '30deg', // Slow continuous rotation
                          cameraControls: true, // Allow user to rotate/zoom
                          touchAction: TouchAction.panY,
                          backgroundColor: Colors.transparent,
                          loading: Loading.eager,
                          // Better 3D camera angle - see the farmer from front-side
                          cameraOrbit: '45deg 80deg 3.5m',
                          minCameraOrbit: 'auto 60deg auto',
                          maxCameraOrbit: 'auto 100deg auto',
                          fieldOfView: '35deg',
                          // Lighting for 3D depth
                          shadowIntensity: 1.0,
                          shadowSoftness: 0.8,
                          exposure: 1.2,
                          // Animation (if GLB has animations)
                          autoPlay: true,
                          animationName: 'idle',
                        );
                      },
                    ),
                  ),
                ),
                
                // Enhanced ground shadow with AR circle
                Positioned(
                  left: MediaQuery.of(context).size.width * 0.25,
                  right: MediaQuery.of(context).size.width * 0.25,
                  bottom: MediaQuery.of(context).size.height * 0.18,
                  child: AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (_, __) => Container(
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppTheme.primaryGreen.withOpacity(0.3 * _pulseAnim.value),
                            AppTheme.primaryGreen.withOpacity(0.15 * _pulseAnim.value),
                            Colors.black.withOpacity(0.2 * _pulseAnim.value),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.4, 0.7, 1.0],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryGreen.withOpacity(0.2),
                            blurRadius: 20 * _pulseAnim.value,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // AR grid lines under model for depth
                Positioned(
                  left: MediaQuery.of(context).size.width * 0.2,
                  right: MediaQuery.of(context).size.width * 0.2,
                  bottom: MediaQuery.of(context).size.height * 0.18,
                  height: 2,
                  child: AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (_, __) => CustomPaint(
                      painter: _ARGridPainter(
                        color: AppTheme.primaryGreen,
                        progress: _pulseAnim.value,
                      ),
                    ),
                  ),
                ),
                
                // Interactive hints with animations
                if (!_showInfoCard)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: MediaQuery.of(context).size.height * 0.72,
                    child: AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (_, __) => Center(
                        child: Column(
                          children: [
                            // Rotate hint
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGreen.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppTheme.primaryGreen.withOpacity(0.4),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.rotate_right, 
                                    color: AppTheme.primaryGreen, 
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _t('Drag to rotate', 'घुमाने के लिए खींचें', 'फिरवण्यासाठी ओढा'),
                                    style: TextStyle(
                                      color: AppTheme.primaryGreen,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Tap for details
                            GestureDetector(
                              onTap: () => setState(() => _showInfoCard = true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.info_outline, color: Colors.white, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      _t('Tap for step details', 'विवरण के लिए टैप करें', 'तपशीलांसाठी टॅप करा'),
                                      style: const TextStyle(color: Colors.white, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildScanningOverlay() {
    return AnimatedBuilder(
      animation: _scanAnim,
      builder: (_, __) {
        return Container(
          color: Colors.black.withOpacity(0.5),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, __) => Transform.scale(
                    scale: _pulseAnim.value,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.primaryGreen.withOpacity(0.7),
                          width: 3,
                        ),
                      ),
                      child: Icon(
                        Icons.my_location,
                        size: 80,
                        color: AppTheme.primaryGreen.withOpacity(0.8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _t(
                          'Detecting surface...',
                          'सतह का पता लगा रहे हैं...',
                          'पृष्ठभाग शोधत आहे...',
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

  Widget _buildInfoCard() {
    final step = _plan!.steps[_step];
    return Positioned(
      left: 20,
      right: 20,
      top: MediaQuery.of(context).size.height * 0.15,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: ARTreatmentService.getStepColor(step.type).withOpacity(0.6),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: ARTreatmentService.getStepColor(step.type).withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ARTreatmentService.getStepColor(step.type).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    ARTreatmentService.getStepIcon(step.type),
                    color: ARTreatmentService.getStepColor(step.type),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    step.getTitle(_lang),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _showInfoCard = false),
                  child: const Icon(Icons.close, color: Colors.white54, size: 22),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              step.getDescription(_lang),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.5,
              ),
            ),
            if (step.warnings.isNotEmpty) ...[
              const SizedBox(height: 14),
              ...step.warnings.map((w) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('⚠️ ', style: TextStyle(fontSize: 14)),
                    Expanded(
                      child: Text(
                        w,
                        style: TextStyle(
                          color: Colors.amber.shade300,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }

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
          bottom: 12,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withOpacity(0.8), Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            _circleButton(Icons.arrow_back, () => Navigator.pop(context)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.view_in_ar, color: AppTheme.primaryGreen, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        _t('3D AR Treatment', '3D AR उपचार', '3D AR उपचार'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${widget.cropName} - ${widget.diseaseName}',
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
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
          color: Colors.black54,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }

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
              Colors.black.withOpacity(0.95),
              Colors.black.withOpacity(0.7),
              Colors.transparent,
            ],
            stops: const [0.0, 0.7, 1.0],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation(
                  ARTreatmentService.getStepColor(step.type),
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            // Step info
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ARTreatmentService.getStepColor(step.type).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    ARTreatmentService.getStepIcon(step.type),
                    color: ARTreatmentService.getStepColor(step.type),
                    size: 22,
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
                          fontSize: 15,
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
            
            // Navigation buttons
            Row(
              children: [
                if (_step > 0)
                  Expanded(
                    child: _navButton(
                      Icons.arrow_back_rounded,
                      _t('Previous', 'पिछला', 'मागील'),
                      _prevStep,
                      outlined: true,
                    ),
                  ),
                if (_step > 0) const SizedBox(width: 12),
                Expanded(
                  flex: 2,
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
          color: outlined ? Colors.transparent : c.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: outlined ? Colors.white30 : c.withOpacity(0.6)),
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

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppTheme.primaryGreen),
            const SizedBox(height: 20),
            Text(
              _t(
                'Loading 3D AR experience…',
                '3D AR अनुभव लोड हो रहा है…',
                '3D AR अनुभव लोड होत आहे…',
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ARPhase { scanning, placed }

// AR Grid Painter for depth effect
class _ARGridPainter extends CustomPainter {
  final Color color;
  final double progress;

  _ARGridPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.3 * progress)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Draw horizontal grid lines
    final spacing = size.width / 8;
    for (var i = 0; i < 9; i++) {
      final x = i * spacing;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    // Draw perspective lines from center
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    for (var i = 0; i < 4; i++) {
      final angle = (i * 90) * math.pi / 180;
      final endX = centerX + (size.width * 0.4) * math.cos(angle);
      final endY = centerY + (size.height * 0.4) * math.sin(angle);
      canvas.drawLine(
        Offset(centerX, centerY),
        Offset(endX, endY),
        paint..strokeWidth = 0.8,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ARGridPainter old) => old.progress != progress;
}
