// =============================================================================
// FILE: lib/widgets/camera_frame_overlay.dart
// FUNGSI: Bingkai panduan di tengah layar untuk memposisikan uang
// =============================================================================
//
// Widget ini menggambar 4 sudut bingkai sebagai panduan visual.
// Ukuran bingkai dirancang sesuai proporsi uang kertas rupiah (~1.8:1).
//
// Bingkai ini juga memiliki garis scan animasi dari atas ke bawah,
// sebagai indikator bahwa kamera sedang aktif dan siap mendeteksi.
//
// =============================================================================

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CameraFrameOverlay extends StatefulWidget {
  const CameraFrameOverlay({super.key});

  @override
  State<CameraFrameOverlay> createState() => _CameraFrameOverlayState();
}

class _CameraFrameOverlayState extends State<CameraFrameOverlay>
    with SingleTickerProviderStateMixin {
  // Animasi garis scan
  late AnimationController _scanCtrl;
  late Animation<double> _scanAnim;

  @override
  void initState() {
    super.initState();

    _scanCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    // Garis bergerak dari atas (0.0) ke bawah (1.0) bingkai
    _scanAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _scanCtrl,
        // Ease-in-out: lambat di ujung, cepat di tengah
        curve: const Interval(0.05, 0.95, curve: Curves.easeInOut),
      ),
    );
  }

  @override
  void dispose() {
    _scanCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;

    // Lebar bingkai = 80% lebar layar
    final frameW = screenW * 0.80;
    // Tinggi bingkai = proporsi uang kertas (~55% dari lebar)
    final frameH = frameW * 0.54;

    return IgnorePointer(
      child: Center(
        child: SizedBox(
          width: frameW,
          height: frameH + 30, // +30 untuk teks di bawah
          child: Stack(
            children: [
              // ── Sudut-sudut bingkai ──
              CustomPaint(
                size: Size(frameW, frameH),
                painter: _FrameCornerPainter(),
              ),

              // ── Uang di dalam bingkai (simulasi) ──
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: frameH,
                child: const SizedBox(), // Area kamera
              ),

              // ── Garis scan animasi ──
              AnimatedBuilder(
                animation: _scanAnim,
                builder: (context, _) {
                  return Positioned(
                    left: 8,
                    right: 8,
                    top: 8 + (_scanAnim.value * (frameH - 16)),
                    child: Opacity(
                      opacity: _scanAnim.value < 0.05 || _scanAnim.value > 0.95
                          ? 0
                          : 1,
                      child: Container(
                        height: 1.5,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              AppTheme.green.withOpacity(0.8),
                              AppTheme.green,
                              AppTheme.green.withOpacity(0.8),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              // ── Teks panduan di bawah bingkai ──
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Text(
                  'Letakkan uang di dalam bingkai',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 12,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Painter yang menggambar 4 sudut bingkai
class _FrameCornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.75)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Panjang setiap garis sudut
    const len = 28.0;

    // ── Sudut kiri atas ──
    canvas.drawLine(Offset(0, len), const Offset(0, 0), paint);
    canvas.drawLine(const Offset(0, 0), Offset(len, 0), paint);

    // ── Sudut kanan atas ──
    canvas.drawLine(Offset(size.width - len, 0), Offset(size.width, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, len), paint);

    // ── Sudut kiri bawah ──
    canvas.drawLine(Offset(0, size.height - len), Offset(0, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(len, size.height), paint);

    // ── Sudut kanan bawah ──
    canvas.drawLine(Offset(size.width - len, size.height),
        Offset(size.width, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height - len),
        Offset(size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
