// =============================================================================
// FILE: lib/widgets/bottom_controls.dart
// FUNGSI: Kontrol di bagian bawah layar
// =============================================================================
//
// Berisi:
//   - Teks panduan singkat
//   - Tombol Panduan (kiri) — ucapkan instruksi
//   - Tombol Kamera BESAR (tengah) — deteksi manual
//   - Tombol Otomatis (kanan) — toggle mode otomatis
//
// Desain khusus tunanetra:
//   - Tombol tengah berukuran 80x80 — mudah ditemukan secara haptic
//   - Seluruh layar juga bisa di-tap (GestureDetector di HomeScreen)
//
// =============================================================================

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BottomControls extends StatelessWidget {
  final String hint;
  final bool isProcessing;
  final bool isAutoMode;
  final VoidCallback onDetect;
  final VoidCallback onToggleAuto;
  final VoidCallback onGuide;

  const BottomControls({
    super.key,
    required this.hint,
    required this.isProcessing,
    required this.isAutoMode,
    required this.onDetect,
    required this.onToggleAuto,
    required this.onGuide,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          // Gradient dari bawah — membuat area kontrol terlihat jelas
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withOpacity(0.90),
                Colors.black.withOpacity(0.60),
                Colors.transparent,
              ],
              stops: const [0.0, 0.6, 1.0],
            ),
          ),
          padding: const EdgeInsets.only(
            left: AppSizes.padLg,
            right: AppSizes.padLg,
            bottom: AppSizes.padLg,
            top: AppSizes.padXl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Teks panduan ──
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  hint,
                  key: ValueKey(hint),
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 20),

              // ── Baris tombol ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Tombol kiri: Panduan
                  _IconBtn(
                    icon: Icons.record_voice_over_rounded,
                    label: 'Panduan',
                    onTap: onGuide,
                  ),

                  // Tombol tengah: Deteksi (BESAR)
                  _MainDetectButton(
                    isProcessing: isProcessing,
                    onTap: onDetect,
                  ),

                  // Tombol kanan: Mode Otomatis
                  _IconBtn(
                    icon: isAutoMode
                        ? Icons.stop_circle_rounded
                        : Icons.autorenew_rounded,
                    label: isAutoMode ? 'Stop' : 'Otomatis',
                    isActive: isAutoMode,
                    onTap: onToggleAuto,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// TOMBOL UTAMA — DETEKSI
// ===========================================================================

class _MainDetectButton extends StatefulWidget {
  final bool isProcessing;
  final VoidCallback onTap;

  const _MainDetectButton({
    required this.isProcessing,
    required this.onTap,
  });

  @override
  State<_MainDetectButton> createState() => _MainDetectButtonState();
}

class _MainDetectButtonState extends State<_MainDetectButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();

    // Animasi glow berdenyut di sekitar tombol
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _glowAnim = Tween<double>(begin: 0.2, end: 0.5).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.isProcessing ? null : widget.onTap,
      child: AnimatedBuilder(
        animation: _glowAnim,
        builder: (context, child) {
          return Container(
            width: AppSizes.mainButtonSize,
            height: AppSizes.mainButtonSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.isProcessing ? Colors.grey.shade800 : AppTheme.green,
              border: Border.all(color: Colors.white, width: 3),
              // Efek glow berdenyut
              boxShadow: widget.isProcessing
                  ? null
                  : [
                      BoxShadow(
                        color: AppTheme.green.withOpacity(_glowAnim.value),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
            ),
            child: Icon(
              widget.isProcessing
                  ? Icons.hourglass_top_rounded
                  : Icons.camera_alt_rounded,
              color: Colors.white,
              size: 34,
            ),
          );
        },
      ),
    );
  }
}

// ===========================================================================
// TOMBOL IKON KECIL (kiri & kanan)
// ===========================================================================

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _IconBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Lingkaran ikon
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: AppSizes.iconButtonSize,
            height: AppSizes.iconButtonSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? AppTheme.green.withOpacity(0.15)
                  : Colors.white.withOpacity(0.08),
              border: Border.all(
                color: isActive
                    ? AppTheme.green
                    : Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Icon(
              icon,
              color: isActive ? AppTheme.green : AppTheme.textSecondary,
              size: 22,
            ),
          ),

          const SizedBox(height: 6),

          // Label teks
          Text(
            label,
            style: TextStyle(
              color: isActive ? AppTheme.green : AppTheme.textHint,
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w500 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
