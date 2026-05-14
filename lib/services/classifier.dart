// =============================================================================
// FILE: lib/services/classifier.dart  (STUB untuk UI preview)
// FUNGSI: Versi dummy tanpa TFLite — untuk test UI tanpa model AI
// =============================================================================
//
// File ini adalah PLACEHOLDER. Setelah training ML selesai,
// ganti dengan classifier.dart dari zip project utama (rupiah_ml_pipeline).
//
// Stub ini mengembalikan hasil random untuk keperluan UI testing.
//
// =============================================================================

import 'dart:math';
import 'dart:typed_data';

class CurrencyClassifier {
  bool get isLoaded => true;

  final _labels = [
    'Rp1000', 'Rp2000', 'Rp5000', 'Rp10000',
    'Rp20000', 'Rp50000', 'Rp100000'
  ];

  Future<void> loadModel() async {
    // Simulasi loading 1 detik
    await Future.delayed(const Duration(milliseconds: 1000));
  }

  Future<ClassificationResult?> classify(Uint8List imageBytes) async {
    // Simulasi inferensi 500ms
    await Future.delayed(const Duration(milliseconds: 500));

    // Hasil dummy: 80% berhasil, 20% tidak terdeteksi
    final rand = Random();
    final detected = rand.nextDouble() > 0.2;

    if (detected) {
      final idx = rand.nextInt(_labels.length);
      final conf = 0.75 + rand.nextDouble() * 0.24;
      return ClassificationResult(
        label: _labels[idx],
        confidence: conf,
        isDetected: true,
        allProbabilities: {},
      );
    } else {
      return ClassificationResult(
        label: 'Tidak Terdeteksi',
        confidence: 0.35 + rand.nextDouble() * 0.25,
        isDetected: false,
        allProbabilities: {},
      );
    }
  }

  void dispose() {}
}

class ClassificationResult {
  final String label;
  final double confidence;
  final bool isDetected;
  final Map<String, double> allProbabilities;

  const ClassificationResult({
    required this.label,
    required this.confidence,
    required this.isDetected,
    required this.allProbabilities,
  });

  String get spokenText {
    if (!isDetected) return 'Uang tidak terdeteksi. Coba arahkan kamera lebih dekat.';
    const map = {
      'Rp1000':   'Seribu rupiah',
      'Rp2000':   'Dua ribu rupiah',
      'Rp5000':   'Lima ribu rupiah',
      'Rp10000':  'Sepuluh ribu rupiah',
      'Rp20000':  'Dua puluh ribu rupiah',
      'Rp50000':  'Lima puluh ribu rupiah',
      'Rp100000': 'Seratus ribu rupiah',
    };
    return map[label] ?? label;
  }

  String get displayText {
    const map = {
      'Rp1000':   'Rp 1.000',
      'Rp2000':   'Rp 2.000',
      'Rp5000':   'Rp 5.000',
      'Rp10000':  'Rp 10.000',
      'Rp20000':  'Rp 20.000',
      'Rp50000':  'Rp 50.000',
      'Rp100000': 'Rp 100.000',
    };
    return map[label] ?? label;
  }

  String get confidencePercent => '${(confidence * 100).toStringAsFixed(0)}%';
}
