// =============================================================================
// FILE: lib/screens/home_screen.dart
// FUNGSI: Layar utama — preview kamera + tombol deteksi + hasil
// =============================================================================

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';

import '../theme/app_theme.dart';
import '../services/classifier.dart';
import '../services/tts_service.dart';
import '../widgets/result_overlay.dart';
import '../widgets/camera_frame_overlay.dart';
import '../widgets/bottom_controls.dart';
import '../widgets/top_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {

  // ── Services ──
  CameraController? _camCtrl;
  final _classifier  = CurrencyClassifier();
  final _tts         = TtsService();

  // ── State ──
  ClassificationResult? _result;
  bool _isProcessing = false;
  bool _isAutoMode   = false;
  Timer? _autoTimer;
  String _hint = 'Ketuk layar untuk mendeteksi';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initAll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoTimer?.cancel();
    _camCtrl?.dispose();
    _classifier.dispose();
    _tts.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _camCtrl?.pausePreview();
      _autoTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      _camCtrl?.resumePreview();
      if (_isAutoMode) _startAutoMode();
    }
  }

  // ===========================================================================
  // INISIALISASI
  // ===========================================================================

  Future<void> _initAll() async {
    await _tts.initialize();
    await _classifier.loadModel();
    await _initCamera();

    if (mounted) {
      await Future.delayed(const Duration(milliseconds: 400));
      await _tts.speakWelcome();
    }
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    // Prioritaskan kamera belakang
    final cam = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _camCtrl = CameraController(
      cam,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isIOS
          ? ImageFormatGroup.bgra8888
          : ImageFormatGroup.yuv420,
    );

    await _camCtrl!.initialize();
    await _camCtrl!.setFocusMode(FocusMode.auto);
    if (mounted) setState(() {});
  }

  // ===========================================================================
  // DETEKSI UANG
  // ===========================================================================

  Future<void> _detect() async {
    if (_isProcessing) return;
    if (_camCtrl == null || !_camCtrl!.value.isInitialized) return;

    setState(() => _isProcessing = true);

    try {
      // Getaran saat mulai
      await HapticFeedback.mediumImpact();

      // Ambil foto
      final file  = await _camCtrl!.takePicture();
      final bytes = await file.readAsBytes();

      // Klasifikasi
      final result = await _classifier.classify(bytes);

      if (result != null && mounted) {
        setState(() {
          _result = result;
          _hint = result.isDetected
              ? result.displayText
              : 'Tidak terdeteksi — coba lagi';
        });

        if (result.isDetected) {
          await HapticFeedback.heavyImpact();
          await _tts.speakDetectionResult(result.spokenText, result.confidence);
        } else {
          await HapticFeedback.vibrate();
          await _tts.speakNotDetected();
        }

        // Sembunyikan result setelah 4 detik
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) {
            setState(() {
              _result = null;
              _hint = _isAutoMode
                  ? 'Mode otomatis aktif'
                  : 'Ketuk layar untuk mendeteksi';
            });
          }
        });
      }
    } catch (e) {
      debugPrint('Detection error: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ===========================================================================
  // MODE OTOMATIS
  // ===========================================================================

  void _toggleAutoMode() {
    setState(() => _isAutoMode = !_isAutoMode);

    if (_isAutoMode) {
      setState(() => _hint = 'Mode otomatis aktif');
      _tts.speak('Mode otomatis aktif. Deteksi setiap 3 detik.');
      _startAutoMode();
    } else {
      setState(() => _hint = 'Ketuk layar untuk mendeteksi');
      _tts.speak('Mode otomatis nonaktif.');
      _autoTimer?.cancel();
    }
  }

  void _startAutoMode() {
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(const Duration(seconds: 3), (_) => _detect());
  }

  void _onGuide() => _tts.speakGuide();

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final camReady = _camCtrl != null && _camCtrl!.value.isInitialized;

    return GestureDetector(
      onTap: _detect,
      onLongPress: _onGuide,
      child: Stack(
        fit: StackFit.expand,
        children: [

          // ── Layer 1: Preview kamera ──
          camReady
              ? CameraPreview(_camCtrl!)
              : _buildNoCameraPlaceholder(),

          // ── Layer 2: Overlay gelap di tepi (vignette) ──
          _buildVignette(),

          // ── Layer 3: Bingkai panduan ──
          const CameraFrameOverlay(),

          // ── Layer 4: Hasil deteksi (muncul jika ada) ──
          if (_result != null)
            ResultOverlay(result: _result!),

          // ── Layer 5: Top bar ──
          TopBar(isAutoMode: _isAutoMode),

          // ── Layer 6: Kontrol bawah ──
          BottomControls(
            hint: _hint,
            isProcessing: _isProcessing,
            isAutoMode: _isAutoMode,
            onDetect: _detect,
            onToggleAuto: _toggleAutoMode,
            onGuide: _onGuide,
          ),

          // ── Layer 7: Indikator processing ──
          if (_isProcessing)
            _buildProcessingIndicator(),
        ],
      ),
    );
  }

  Widget _buildNoCameraPlaceholder() {
    return Container(
      color: const Color(0xFF050F05),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt_outlined, color: AppTheme.textHint, size: 40),
            SizedBox(height: 12),
            Text(
              'Kamera tidak tersedia',
              style: TextStyle(color: AppTheme.textHint, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  /// Efek gelap di tepi layar — membuat objek di tengah lebih menonjol
  Widget _buildVignette() {
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.5),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProcessingIndicator() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.padLg,
          vertical: AppSizes.padMd,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.75),
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          border: Border.all(
            color: AppTheme.green.withOpacity(0.4),
            width: 0.5,
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                color: AppTheme.green,
                strokeWidth: 2,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Menganalisis...',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
