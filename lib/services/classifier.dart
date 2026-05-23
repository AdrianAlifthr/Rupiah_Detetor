// =============================================================================
// FILE: lib/services/classifier.dart
// FUNGSI: Klasifikasi nominal uang rupiah menggunakan model TFLite
// =============================================================================

import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class CurrencyClassifier {
  static const String _modelPath = '../ml_training/output/rupiah_model.tflite';
  static const String _labelsPath = 'assets/model/labels.txt';
  static const double _confidenceThreshold = 0.60;

  Interpreter? _interpreter;
  List<String> _labels = const [];
  List<int> _inputShape = const [1, 224, 224, 3];
  List<int> _outputShape = const [1, 7];

  bool get isLoaded => _interpreter != null && _labels.isNotEmpty;

  Future<void> loadModel() async {
    if (isLoaded) return;

    _interpreter = await Interpreter.fromAsset(_modelPath);
    _inputShape = _interpreter!.getInputTensor(0).shape;
    _outputShape = _interpreter!.getOutputTensor(0).shape;

    final labelsText = await rootBundle.loadString(_labelsPath);
    _labels = labelsText
        .split('\n')
        .map((label) => label.trim())
        .where((label) => label.isNotEmpty)
        .toList(growable: false);
  }

  Future<ClassificationResult?> classify(Uint8List imageBytes) async {
    if (!isLoaded) {
      await loadModel();
    }

    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) return null;

    final input = _preprocess(decoded);
    final output = List.generate(
      _outputShape[0],
      (_) => List<double>.filled(_outputShape[1], 0),
      growable: false,
    );

    _interpreter!.run(input, output);

    final probabilities = output.first;
    var bestIndex = 0;
    var bestConfidence = probabilities.first;

    for (var i = 1; i < probabilities.length; i++) {
      if (probabilities[i] > bestConfidence) {
        bestIndex = i;
        bestConfidence = probabilities[i];
      }
    }

    final allProbabilities = <String, double>{};
    final labelCount = math.min(_labels.length, probabilities.length);
    for (var i = 0; i < labelCount; i++) {
      allProbabilities[_labels[i]] = probabilities[i];
    }

    final detected = bestConfidence >= _confidenceThreshold;
    return ClassificationResult(
      label: detected && bestIndex < _labels.length
          ? _labels[bestIndex]
          : 'Tidak Terdeteksi',
      confidence: bestConfidence,
      isDetected: detected,
      allProbabilities: allProbabilities,
    );
  }

  List<List<List<List<double>>>> _preprocess(img.Image image) {
    final inputHeight = _inputShape[1];
    final inputWidth = _inputShape[2];
    final resized = img.copyResize(
      image,
      width: inputWidth,
      height: inputHeight,
      interpolation: img.Interpolation.linear,
    );

    return [
      List.generate(
        inputHeight,
        (y) => List.generate(
          inputWidth,
          (x) {
            final pixel = resized.getPixel(x, y);
            return [
              pixel.r / 255.0,
              pixel.g / 255.0,
              pixel.b / 255.0,
            ];
          },
          growable: false,
        ),
        growable: false,
      ),
    ];
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
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
    if (!isDetected) {
      return 'Uang tidak terdeteksi. Coba arahkan kamera lebih dekat.';
    }

    const map = {
      'Rp1000': 'Seribu rupiah',
      'Rp2000': 'Dua ribu rupiah',
      'Rp5000': 'Lima ribu rupiah',
      'Rp10000': 'Sepuluh ribu rupiah',
      'Rp20000': 'Dua puluh ribu rupiah',
      'Rp50000': 'Lima puluh ribu rupiah',
      'Rp100000': 'Seratus ribu rupiah',
    };
    return map[label] ?? label;
  }

  String get displayText {
    const map = {
      'Rp1000': 'Rp 1.000',
      'Rp2000': 'Rp 2.000',
      'Rp5000': 'Rp 5.000',
      'Rp10000': 'Rp 10.000',
      'Rp20000': 'Rp 20.000',
      'Rp50000': 'Rp 50.000',
      'Rp100000': 'Rp 100.000',
    };
    return map[label] ?? label;
  }

  String get confidencePercent => '${(confidence * 100).toStringAsFixed(0)}%';
}
