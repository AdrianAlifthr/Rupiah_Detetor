// =============================================================================
// FILE: lib/theme/app_theme.dart
// FUNGSI: Mendefinisikan semua warna, ukuran, dan gaya teks aplikasi
// =============================================================================
//
// Kenapa perlu file tema terpisah?
//   Supaya perubahan warna cukup dilakukan di SATU tempat ini,
//   dan langsung berlaku ke seluruh aplikasi.
//
// =============================================================================

import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._(); // Kelas ini tidak boleh di-instantiate

  // ===========================================================================
  // WARNA UTAMA
  // ===========================================================================

  // Hijau utama — warna aksen aplikasi
  // Dipilih karena kontras tinggi di atas latar hitam
  static const Color green        = Color(0xFF00C853);
  static const Color greenDark    = Color(0xFF009624);
  static const Color greenGlow    = Color(0x3300C853); // transparan untuk glow

  // Merah — untuk status tidak terdeteksi
  static const Color red          = Color(0xFFFF5252);
  static const Color redGlow      = Color(0x33FF5252);

  // Hitam dan abu-abu
  static const Color black        = Color(0xFF000000);
  static const Color surface      = Color(0xFF0D0D0D); // background utama
  static const Color surfaceCard  = Color(0xDD000000); // background card (88% opak)
  static const Color border       = Color(0x33FFFFFF); // border putih transparan
  static const Color borderGreen  = Color(0xFF00C853);

  // Teks
  static const Color textPrimary   = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0x99FFFFFF); // putih 60%
  static const Color textHint      = Color(0x55FFFFFF); // putih 33%

  // ===========================================================================
  // TEMA MATERIAL
  // ===========================================================================

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: black,

    colorScheme: const ColorScheme.dark(
      primary: green,
      onPrimary: black,
      surface: surface,
      onSurface: textPrimary,
    ),

    // Tidak pakai AppBar bawaan — kita buat custom
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),

    textTheme: const TextTheme(
      // Nominal uang — SANGAT BESAR untuk low vision
      displayLarge: TextStyle(
        color: textPrimary,
        fontSize: 44,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.0,
        height: 1.1,
      ),
      // Label besar
      headlineMedium: TextStyle(
        color: textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
      // Body teks biasa
      bodyLarge: TextStyle(
        color: textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: TextStyle(
        color: textSecondary,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      bodySmall: TextStyle(
        color: textHint,
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
      // Label tombol
      labelLarge: TextStyle(
        color: textPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
      ),
      labelSmall: TextStyle(
        color: textSecondary,
        fontSize: 10,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.2,
      ),
    ),
  );
}

// ===========================================================================
// KONSTANTA UKURAN & SPACING
// ===========================================================================

class AppSizes {
  AppSizes._();

  // Border radius
  static const double radiusSm  = 8.0;
  static const double radiusMd  = 12.0;
  static const double radiusLg  = 16.0;
  static const double radiusXl  = 24.0;
  static const double radiusFull = 999.0;

  // Ukuran tombol utama (tombol kamera besar)
  static const double mainButtonSize = 80.0;
  static const double iconButtonSize = 56.0;

  // Padding
  static const double padSm  = 8.0;
  static const double padMd  = 16.0;
  static const double padLg  = 24.0;
  static const double padXl  = 32.0;

  // Tinggi bar bawah
  static const double bottomBarHeight = 160.0;
}
