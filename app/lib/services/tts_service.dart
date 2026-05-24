// =============================================================================
// FILE: lib/services/tts_service.dart
// =============================================================================

import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;

  Future<void> initialize() async {
    await _tts.setLanguage('id-ID');
    await _tts.setSpeechRate(0.85);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _tts.setCompletionHandler(() => _isSpeaking = false);
    _tts.setStartHandler(() => _isSpeaking = true);
  }

  Future<void> speak(String text) async {
    if (_isSpeaking) await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> speakWelcome() async {
    await speak(
      'Aplikasi Deteksi Uang siap. '
      'Arahkan kamera ke uang kertas lalu ketuk layar untuk mendeteksi.',
    );
  }

  Future<void> speakGuide() async {
    await speak(
      'Arahkan kamera tepat di atas uang kertas. '
      'Pastikan uang terlihat penuh dan pencahayaan cukup. '
      'Ketuk layar untuk mendeteksi.',
    );
  }

  Future<void> speakDetectionResult(String text, double conf) async {
    if (conf > 0.90) {
      await speak(text);
    } else {
      await speak('$text. Keyakinan ${(conf * 100).toStringAsFixed(0)} persen.');
    }
  }

  Future<void> speakNotDetected() async {
    await speak('Uang tidak terdeteksi. Pastikan uang terlihat jelas di kamera.');
  }

  Future<void> stop() async => await _tts.stop();

  Future<void> dispose() async => await _tts.stop();
}
