// =============================================================================
// FILE: lib/widgets/result_overlay.dart
// FUNGSI: Card hasil deteksi yang muncul di atas kamera
// =============================================================================
//
// Card ini muncul dengan animasi pop setelah deteksi selesai,
// dan menampilkan:
//   - Icon centang (hijau) atau silang (merah)
//   - Nominal uang dalam huruf BESAR (untuk low vision)
//   - Confidence bar (tingkat keyakinan model)
//   - Animasi wave speaker saat TTS berbicara
//
// Card auto-hilang setelah 4 detik.
//
// =============================================================================

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/classifier.dart';

class ResultOverlay extends StatefulWidget {
  final ClassificationResult result;

  const ResultOverlay({super.key, required this.result});

  @override
  State<ResultOverlay> createState() => _ResultOverlayState();
}

class _ResultOverlayState extends State<ResultOverlay>
    with TickerProviderStateMixin {

  // Animasi muncul (scale + fade)
  late AnimationController _inCtrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  // Animasi wave speaker
  late AnimationController _waveCtrl;

  // Animasi confidence bar
  late AnimationController _barCtrl;
  late Animation<double> _barAnim;

  @override
  void initState() {
    super.initState();

    // ── Pop-in animation ──
    _inCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _scaleAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _inCtrl, curve: Curves.easeOutBack),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _inCtrl, curve: Curves.easeOut),
    );

    _inCtrl.forward();

    // ── Speaker wave (hanya saat berhasil) ──
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    if (widget.result.isDetected) {
      _waveCtrl.repeat(reverse: true);
    }

    // ── Confidence bar fill animation ──
    _barCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _barAnim = Tween<double>(begin: 0.0, end: widget.result.confidence)
        .animate(CurvedAnimation(parent: _barCtrl, curve: Curves.easeOut));

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _barCtrl.forward();
    });
  }

  @override
  void dispose() {
    _inCtrl.dispose();
    _waveCtrl.dispose();
    _barCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOk  = widget.result.isDetected;
    final color = isOk ? AppTheme.green : AppTheme.red;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 60,
      left: 20,
      right: 20,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: ScaleTransition(
          scale: _scaleAnim,
          child: Container(
            padding: const EdgeInsets.all(AppSizes.padMd),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(AppSizes.radiusXl),
              border: Border.all(color: color, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.25),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Icon status ──
                _StatusIcon(isOk: isOk, color: color),

                const SizedBox(height: 10),

                // ── Teks nominal (BESAR) ──
                Text(
                  isOk ? widget.result.displayText : 'Tidak Terdeteksi',
                  style: isOk
                      ? Theme.of(context).textTheme.displayLarge
                      : const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 12),

                // ── Confidence bar ──
                _ConfidenceBar(animation: _barAnim, color: color),

                const SizedBox(height: 4),

                Text(
                  'Keyakinan: ${widget.result.confidencePercent}',
                  style: const TextStyle(
                    color: AppTheme.textHint,
                    fontSize: 12,
                  ),
                ),

                const SizedBox(height: 10),

                // ── Speaker indicator atau hint ──
                if (isOk)
                  _SpeakerIndicator(
                    waveCtrl: _waveCtrl,
                    text: widget.result.spokenText,
                  )
                else
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'Pastikan uang terlihat penuh\ndan pencahayaan cukup terang',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.textHint,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// SUB-WIDGET
// ===========================================================================

/// Icon centang atau silang dengan circle border
class _StatusIcon extends StatelessWidget {
  final bool isOk;
  final Color color;

  const _StatusIcon({required this.isOk, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.12),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Icon(
        isOk ? Icons.check_rounded : Icons.close_rounded,
        color: color,
        size: 24,
      ),
    );
  }
}

/// Bar progress yang mengisi sesuai nilai confidence
class _ConfidenceBar extends StatelessWidget {
  final Animation<double> animation;
  final Color color;

  const _ConfidenceBar({required this.animation, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: animation.value,
            backgroundColor: Colors.white.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 5,
          ),
        );
      },
    );
  }
}

/// Animasi wave speaker + teks yang diucapkan
class _SpeakerIndicator extends StatelessWidget {
  final AnimationController waveCtrl;
  final String text;

  const _SpeakerIndicator({
    required this.waveCtrl,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.green.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        border: Border.all(
          color: AppTheme.green.withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Bar-bar wave ──
          ...List.generate(5, (i) {
            return AnimatedBuilder(
              animation: waveCtrl,
              builder: (context, _) {
                final delays = [0.0, 0.15, 0.3, 0.15, 0.0];
                final val = ((waveCtrl.value + delays[i]) % 1.0);
                final h = 4.0 + (val * 9.0); // tinggi 4–13 px

                return Container(
                  width: 2.5,
                  height: h,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(
                    color: AppTheme.green,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                );
              },
            );
          }),

          const SizedBox(width: 8),

          // ── Teks singkat yang diucapkan ──
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                color: AppTheme.green,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
