// =============================================================================
// FILE: lib/widgets/top_bar.dart
// FUNGSI: Bar status di bagian atas layar
// =============================================================================

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TopBar extends StatelessWidget {
  final bool isAutoMode;

  const TopBar({super.key, required this.isAutoMode});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.padMd,
            vertical: 10,
          ),
          // Gradient gelap dari atas — supaya teks tetap terbaca di atas kamera
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.75),
                Colors.transparent,
              ],
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Judul aplikasi ──
              const Text(
                'Deteksi Rupiah',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),

              const Spacer(),

              // ── Badge AUTO (muncul saat mode otomatis aktif) ──
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: isAutoMode
                    ? _AutoBadge(key: const ValueKey('auto'))
                    : const SizedBox.shrink(key: ValueKey('none')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Badge hijau kecil bertulisan "AUTO"
class _AutoBadge extends StatelessWidget {
  const _AutoBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.green,
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: const Text(
        'AUTO',
        style: TextStyle(
          color: AppTheme.black,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}
