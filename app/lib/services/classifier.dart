// =============================================================================
// FILE: lib/services/classifier.dart
// FUNGSI: Klasifikasi nominal uang rupiah menggunakan model TFLite
// =============================================================================

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class CurrencyClassifier {
  static const String _modelPath = 'assets/model/rupiah_model.tflite';
  static const String _labelsPath = 'assets/model/labels.txt';
  static const double _confidenceThreshold = 0.60;
  static const double _minTop1Top2Margin = 0.10;
  static const String _backgroundLabel = 'Background';
  static const double _roiWidthRatio = 0.82;
  static const double _roiHeightRatio = 0.30;
  static const double _roiCenterYRatio = 0.52;

  Interpreter? _interpreter;
  List<String> _labels = const [];
  List<int> _inputShape = const [1, 224, 224, 3];
  List<int> _outputShape = const [1, 7];
  TensorType _inputType = TensorType.float32;
  TensorType _outputType = TensorType.float32;
  QuantizationParams? _inputQuant;
  QuantizationParams? _outputQuant;

  bool get isLoaded => _interpreter != null && _labels.isNotEmpty;

  Future<void> loadModel() async {
    if (isLoaded) return;

    _interpreter = await Interpreter.fromAsset(_modelPath);
    final inputTensor = _interpreter!.getInputTensor(0);
    final outputTensor = _interpreter!.getOutputTensor(0);
    _inputShape = inputTensor.shape;
    _outputShape = outputTensor.shape;
    _inputType = inputTensor.type;
    _outputType = outputTensor.type;
    _inputQuant = inputTensor.params;
    _outputQuant = outputTensor.params;

    final labelsText = await rootBundle.loadString(_labelsPath);
    _labels = labelsText
        .split('\n')
        .map((label) => label.trim())
        .where((label) => label.isNotEmpty)
        .toList(growable: false);

    if (kDebugMode) {
      debugPrint('TFLite input shape: $_inputShape');
      debugPrint(
          'TFLite input type: $_inputType, quant: ${_inputQuant?.scale}/${_inputQuant?.zeroPoint}');
      debugPrint('TFLite output shape: $_outputShape');
      debugPrint(
          'TFLite output type: $_outputType, quant: ${_outputQuant?.scale}/${_outputQuant?.zeroPoint}');
      debugPrint('Labels (${_labels.length}): ${_labels.join(', ')}');
    }
  }

  Future<ClassificationResult?> classify(Uint8List imageBytes) async {
    if (!isLoaded) {
      await loadModel();
    }

    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) return null;

    final input = _buildInputTensor(decoded);
    final output = _buildOutputTensor();

    _interpreter!.run(input, output);

    final rawOutput = _extractOutputAsDouble(output);
    final probabilities = _normalizeOutput(rawOutput);
    var bestIndex = 0;
    var bestConfidence = probabilities.first;
    var secondBestConfidence = -1.0;

    for (var i = 1; i < probabilities.length; i++) {
      final value = probabilities[i];
      if (value > bestConfidence) {
        secondBestConfidence = bestConfidence;
        bestConfidence = value;
        bestIndex = i;
      } else if (value > secondBestConfidence) {
        secondBestConfidence = value;
      }
    }

    if (kDebugMode) {
      final scored = <MapEntry<String, double>>[];
      for (var i = 0; i < math.min(_labels.length, probabilities.length); i++) {
        scored.add(MapEntry(_labels[i], probabilities[i]));
      }
      scored.sort((a, b) => b.value.compareTo(a.value));
      debugPrint(
          'Top-3: ${scored.take(3).map((e) => '${e.key}:${(e.value * 100).toStringAsFixed(1)}%').join(', ')}');
    }

    final allProbabilities = <String, double>{};
    final labelCount = math.min(_labels.length, probabilities.length);
    for (var i = 0; i < labelCount; i++) {
      allProbabilities[_labels[i]] = probabilities[i];
    }

    final margin = bestConfidence - secondBestConfidence;
    final isBackground =
        bestIndex < _labels.length && _labels[bestIndex] == _backgroundLabel;
    final detected = !isBackground &&
        bestConfidence >= _confidenceThreshold &&
        margin >= _minTop1Top2Margin;
    return ClassificationResult(
      label: detected && bestIndex < _labels.length
          ? _labels[bestIndex]
          : 'Tidak Terdeteksi',
      confidence: bestConfidence,
      isDetected: detected,
      allProbabilities: allProbabilities,
    );
  }

  dynamic _buildInputTensor(img.Image image) {
    if (_inputType == TensorType.uint8) {
      return _preprocessUint8(image);
    }
    if (_inputType == TensorType.int8) {
      return _preprocessInt8(image);
    }
    return _preprocessFloat(image);
  }

  dynamic _buildOutputTensor() {
    if (_outputType == TensorType.uint8 || _outputType == TensorType.int8) {
      return List.generate(
        _outputShape[0],
        (_) => List<int>.filled(_outputShape[1], 0),
        growable: false,
      );
    }
    return List.generate(
      _outputShape[0],
      (_) => List<double>.filled(_outputShape[1], 0),
      growable: false,
    );
  }

  List<double> _extractOutputAsDouble(dynamic output) {
    if (output is List<List<double>>) return output.first;
    if (output is List<List<int>>) {
      final scale = _outputQuant?.scale ?? 1.0;
      final zeroPoint = _outputQuant?.zeroPoint ?? 0;
      return output.first
          .map((v) => (v - zeroPoint) * scale)
          .toList(growable: false);
    }
    throw StateError('Unsupported output tensor type: ${output.runtimeType}');
  }

  List<List<List<List<double>>>> _preprocessFloat(img.Image image) {
    final inputHeight = _inputShape[1];
    final inputWidth = _inputShape[2];
    final roi = _extractRoi(image);
    final resized = _letterboxResize(
      roi,
      targetWidth: inputWidth,
      targetHeight: inputHeight,
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

  List<List<List<List<int>>>> _preprocessUint8(img.Image image) {
    final inputHeight = _inputShape[1];
    final inputWidth = _inputShape[2];
    final roi = _extractRoi(image);
    final resized = _letterboxResize(
      roi,
      targetWidth: inputWidth,
      targetHeight: inputHeight,
    );
    return [
      List.generate(
        inputHeight,
        (y) => List.generate(
          inputWidth,
          (x) {
            final pixel = resized.getPixel(x, y);
            return [pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt()];
          },
          growable: false,
        ),
        growable: false,
      ),
    ];
  }

  List<List<List<List<int>>>> _preprocessInt8(img.Image image) {
    final inputHeight = _inputShape[1];
    final inputWidth = _inputShape[2];
    final roi = _extractRoi(image);
    final resized = _letterboxResize(
      roi,
      targetWidth: inputWidth,
      targetHeight: inputHeight,
    );
    final scale = _inputQuant?.scale ?? (1 / 128.0);
    final zeroPoint = _inputQuant?.zeroPoint ?? 0;
    int quantize(int channel) {
      final normalized = channel / 255.0;
      final q = (normalized / scale + zeroPoint).round();
      return q.clamp(-128, 127).toInt();
    }

    return [
      List.generate(
        inputHeight,
        (y) => List.generate(
          inputWidth,
          (x) {
            final pixel = resized.getPixel(x, y);
            return [
              quantize(pixel.r.toInt()),
              quantize(pixel.g.toInt()),
              quantize(pixel.b.toInt()),
            ];
          },
          growable: false,
        ),
        growable: false,
      ),
    ];
  }

  img.Image _extractRoi(img.Image image) {
    final width = image.width;
    final height = image.height;
    final roiW = (width * _roiWidthRatio).round().clamp(1, width);
    final roiH = (height * _roiHeightRatio).round().clamp(1, height);
    final centerX = width ~/ 2;
    final centerY = (height * _roiCenterYRatio).round();
    final left = (centerX - (roiW ~/ 2)).clamp(0, width - roiW);
    final top = (centerY - (roiH ~/ 2)).clamp(0, height - roiH);
    return img.copyCrop(
      image,
      x: left,
      y: top,
      width: roiW,
      height: roiH,
    );
  }

  List<double> _normalizeOutput(List<double> raw) {
    if (raw.isEmpty) return raw;
    final hasOutOfRange = raw.any((v) => v < 0.0 || v > 1.0);
    final sum = raw.fold<double>(0.0, (a, b) => a + b);
    final looksLikeProbabilities =
        !hasOutOfRange && (sum - 1.0).abs() < 0.1;

    if (looksLikeProbabilities) return raw;

    final maxLogit = raw.reduce(math.max);
    final exp = raw.map((v) => math.exp(v - maxLogit)).toList(growable: false);
    final expSum = exp.fold<double>(0.0, (a, b) => a + b);
    if (expSum == 0.0) return raw;
    return exp.map((v) => v / expSum).toList(growable: false);
  }

  img.Image _letterboxResize(
    img.Image image, {
    required int targetWidth,
    required int targetHeight,
  }) {
    final srcW = image.width.toDouble();
    final srcH = image.height.toDouble();
    final scale = math.min(targetWidth / srcW, targetHeight / srcH);
    final resizedW = (srcW * scale).round().clamp(1, targetWidth);
    final resizedH = (srcH * scale).round().clamp(1, targetHeight);

    final resized = img.copyResize(
      image,
      width: resizedW,
      height: resizedH,
      interpolation: img.Interpolation.linear,
    );

    final canvas = img.Image(width: targetWidth, height: targetHeight);
    img.fill(canvas, color: img.ColorRgb8(0, 0, 0));
    final dx = ((targetWidth - resizedW) / 2).round();
    final dy = ((targetHeight - resizedH) / 2).round();
    img.compositeImage(canvas, resized, dstX: dx, dstY: dy);
    return canvas;
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
