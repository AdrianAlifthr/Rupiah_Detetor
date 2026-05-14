// =============================================================================
// FILE: lib/screens/splash_screen.dart
// FUNGSI: Layar loading yang muncul saat aplikasi pertama dibuka
// =============================================================================
//
// Layar ini ditampilkan selama:
//   - Model TFLite sedang dimuat dari assets
//   - Kamera sedang diinisialisasi
//   - TTS engine sedang disiapkan
//
// Setelah semua siap, navigasi otomatis ke HomeScreen.
//
// =============================================================================

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  /// Callback yang dipanggil saat semua inisialisasi selesai
  /// Parameter: pesan error (null jika sukses)
  final Future<String?> Function() onInit;

  const SplashScreen({super.key, required this.onInit});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  // ── Animasi ──
  late AnimationController _rotateCtrl;   // Untuk lingkaran loading berputar
  late AnimationController _pulseCtrl;    // Untuk icon berdetak
  late AnimationController _fadeCtrl;     // Untuk fade-in seluruh layar

  late Animation<double> _fadeAnim;

  // Teks status yang ditampilkan di bawah icon
  String _statusText = 'Memuat model AI...';

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startInit();
  }

  void _setupAnimations() {
    // Animasi rotasi lingkaran (berputar terus)
    _rotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    // Animasi pulse pada icon (naik-turun opacity)
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    // Fade-in seluruh layar saat pertama muncul
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  Future<void> _startInit() async {
    // Update status text saat loading
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) setState(() => _statusText = 'Memuat model AI...');

    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) setState(() => _statusText = 'Menyiapkan kamera...');

    // Panggil inisialisasi sebenarnya
    final error = await widget.onInit();

    if (!mounted) return;

    if (error != null) {
      setState(() => _statusText = 'Error: $error');
    }
    // HomeScreen akan di-navigate dari main.dart setelah onInit selesai
  }

  @override
  void dispose() {
    _rotateCtrl.dispose();
    _pulseCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Logo dengan lingkaran loading ──
              _buildLogo(),

              const SizedBox(height: 40),

              // ── Nama Aplikasi ──
              const Text(
                'Deteksi Rupiah',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Asisten Identifikasi Uang untuk Tunanetra',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  letterSpacing: 0.2,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 48),

              // ── Status loading ──
              _buildStatusIndicator(),

              const SizedBox(height: 20),

              // ── Teks status ──
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: Text(
                  _statusText,
                  key: ValueKey(_statusText),
                  style: const TextStyle(
                    color: AppTheme.textHint,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Logo icon dengan lingkaran berputar di sekelilingnya
  Widget _buildLogo() {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Lingkaran background (gelap)
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.greenGlow,
              border: Border.all(
                color: AppTheme.green.withOpacity(0.3),
                width: 1.5,
              ),
            ),
          ),

          // Lingkaran berputar (animasi loading)
          RotationTransition(
            turns: _rotateCtrl,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.transparent,
                  width: 0,
                ),
              ),
              child: CustomPaint(
                painter: _ArcPainter(color: AppTheme.green),
              ),
            ),
          ),

          // Icon uang dengan pulse
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (context, child) {
              return Opacity(
                opacity: 0.7 + (_pulseCtrl.value * 0.3),
                child: child,
              );
            },
            child: const Icon(
              Icons.currency_exchange_rounded,
              size: 44,
              color: AppTheme.green,
            ),
          ),
        ],
      ),
    );
  }

  /// Tiga titik loading yang berkedip bergantian
  Widget _buildStatusIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (context, _) {
            // Setiap titik punya delay berbeda
            final delay = i * 0.2;
            final value = ((_pulseCtrl.value + delay) % 1.0);
            final opacity = (0.2 + (value * 0.8)).clamp(0.2, 1.0);

            return Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.green.withOpacity(opacity),
              ),
            );
          },
        );
      }),
    );
  }
}

/// Painter untuk menggambar arc (busur) yang berputar — efek loading
class _ArcPainter extends CustomPainter {
  final Color color;
  const _ArcPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Gambar arc 3/4 lingkaran (270 derajat dari atas)
    canvas.drawArc(
      Rect.fromLTWH(0, 0, size.width, size.height),
      -1.57, // startAngle: mulai dari atas (-π/2)
      4.71,  // sweepAngle: 270 derajat (3/4 lingkaran)
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
