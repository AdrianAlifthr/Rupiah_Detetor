// =============================================================================
// FILE: lib/main.dart
// FUNGSI: Entry point aplikasi
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Kunci orientasi ke portrait
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Set warna status bar agar senada dengan tema gelap
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(const RupiahDetectorApp());
}

class RupiahDetectorApp extends StatelessWidget {
  const RupiahDetectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Deteksi Rupiah',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const _AppRoot(),
    );
  }
}

/// Root widget yang mengurus navigasi splash → home
class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  bool _ready = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    if (_ready) return const HomeScreen();

    return SplashScreen(
      onInit: () async {
        // Minta izin kamera
        final status = await Permission.camera.request();
        if (status.isDenied) {
          return 'Izin kamera diperlukan';
        }

        // Navigasi ke HomeScreen setelah selesai
        if (mounted) {
          await Future.delayed(const Duration(milliseconds: 1000));
          setState(() => _ready = true);
        }
        return null;
      },
    );
  }
}
