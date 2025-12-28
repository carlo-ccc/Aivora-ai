import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class TfliteFoodClassifierResult {
  final List<String> labels;
  final double topConfidence;

  const TfliteFoodClassifierResult({
    required this.labels,
    required this.topConfidence,
  });
}

class TfliteFoodClassifierService {
  Interpreter? _interpreter;
  List<String>? _labels;

  Future<void> _ensureLoaded() async {
    if (_interpreter != null && _labels != null) return;

    _interpreter ??= await Interpreter.fromAsset(
      'assets/models/food_classifier.tflite',
      options: InterpreterOptions()..threads = 2,
    );

    String raw;
    try {
      raw = await rootBundle.loadString('assets/models/probability-labels-en.txt');
    } catch (_) {
      raw = await rootBundle.loadString('assets/models/probability-labels.txt');
    }

    _labels = raw
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  int _numElements(List<int> shape) => shape.fold(1, (a, b) => a * b);

  Future<TfliteFoodClassifierResult> classifyFoodFromBytes(
    Uint8List imageBytes, {
    int topK = 3,
  }) async {
    await _ensureLoaded();
    final interpreter = _interpreter!;
    final labels = _labels!;

    final inputTensor = interpreter.getInputTensor(0);
    final inputShape = inputTensor.shape;
    if (inputShape.length != 4 || inputShape[0] != 1) {
      throw Exception('不支持的输入维度: $inputShape');
    }

    final height = inputShape[1];
    final width = inputShape[2];
    final channels = inputShape[3];
    if (channels != 3) {
      throw Exception('不支持的通道数: $channels');
    }

    final codec = await ui.instantiateImageCodec(
      imageBytes,
      targetWidth: width,
      targetHeight: height,
    );
    final frame = await codec.getNextFrame();
    final img = frame.image;

    final rgbaData = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (rgbaData == null) {
      throw Exception('无法读取图片像素');
    }
    final rgba = rgbaData.buffer.asUint8List();

    final inputType = inputTensor.type;
    final inputSize = _numElements(inputShape);

    Object input;
    if (inputType == TfLiteType.float32) {
      final buf = Float32List(inputSize);
      var p = 0;
      var o = 0;
      final pixelCount = height * width;
      for (var i = 0; i < pixelCount; i++) {
        final r = rgba[p];
        final g = rgba[p + 1];
        final b = rgba[p + 2];
        p += 4;

        buf[o++] = r / 255.0;
        buf[o++] = g / 255.0;
        buf[o++] = b / 255.0;
      }
      input = buf;
    } else if (inputType == TfLiteType.uint8) {
      final buf = Uint8List(inputSize);
      var p = 0;
      var o = 0;
      final pixelCount = height * width;
      for (var i = 0; i < pixelCount; i++) {
        final r = rgba[p];
        final g = rgba[p + 1];
        final b = rgba[p + 2];
        p += 4;

        buf[o++] = r;
        buf[o++] = g;
        buf[o++] = b;
      }
      input = buf;
    } else {
      throw Exception('不支持的输入类型: $inputType');
    }

    final outputTensor = interpreter.getOutputTensor(0);
    final outputShape = outputTensor.shape;
    final outputType = outputTensor.type;
    if (outputType != TfLiteType.float32) {
      throw Exception('当前实现仅支持 float32 输出模型，实际为: $outputType');
    }

    final output = Float32List(_numElements(outputShape));
    interpreter.run(input, output);

    final indices = List<int>.generate(output.length, (i) => i);
    indices.sort((a, b) => output[b].compareTo(output[a]));

    final k = topK.clamp(1, indices.length);
    final topLabels = <String>[];
    var topConfidence = 0.0;

    for (var rank = 0; rank < k; rank++) {
      final idx = indices[rank];
      final conf = output[idx].toDouble();
      if (conf > topConfidence) topConfidence = conf;

      if (idx >= 0 && idx < labels.length) {
        topLabels.add(labels[idx]);
      } else {
        topLabels.add('class_$idx');
      }
    }

    return TfliteFoodClassifierResult(
      labels: topLabels,
      topConfidence: topConfidence,
    );
  }

  Future<void> dispose() async {
    _interpreter?.close();
    _interpreter = null;
    _labels = null;
  }
}

final tfliteFoodClassifierServiceProvider =
    Provider<TfliteFoodClassifierService>((ref) {
  final svc = TfliteFoodClassifierService();
  ref.onDispose(svc.dispose);
  return svc;
});