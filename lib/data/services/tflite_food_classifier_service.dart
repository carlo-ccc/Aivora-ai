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

  int _clampInt(int v, int min, int max) {
    if (v < min) return min;
    if (v > max) return max;
    return v;
  }

  bool _typeMatches(Object t, String needle) {
    final s = t.toString().toLowerCase();
    return s == needle || s.endsWith('.$needle') || s.contains(needle);
  }

  bool _isFloat32(Object t) => _typeMatches(t, 'float32');
  bool _isFloat16(Object t) => _typeMatches(t, 'float16');
  bool _isUInt8(Object t) => _typeMatches(t, 'uint8');
  bool _isInt8(Object t) => _typeMatches(t, 'int8');

  int _float32ToFloat16Bits(double value) {
    final bd = ByteData(4)..setFloat32(0, value, Endian.little);
    final x = bd.getUint32(0, Endian.little);

    final sign = (x >> 31) & 0x1;
    var exp = (x >> 23) & 0xFF;
    var mant = x & 0x7FFFFF;

    var halfSign = sign << 15;

    if (exp == 255) {
      if (mant != 0) {
        return halfSign | 0x7E00;
      }
      return halfSign | 0x7C00;
    }

    final newExp = exp - 127 + 15;

    if (newExp >= 31) {
      return halfSign | 0x7C00;
    }

    if (newExp <= 0) {
      if (newExp < -10) {
        return halfSign;
      }
      mant |= 0x800000;
      final shift = 14 - newExp;
      var halfMant = mant >> shift;
      if (((mant >> (shift - 1)) & 0x1) == 1) {
        halfMant += 1;
      }
      return halfSign | halfMant;
    }

    var halfExp = (newExp & 0x1F) << 10;
    var halfMant = mant >> 13;
    if ((mant & 0x00001000) != 0) {
      halfMant += 1;
      if (halfMant == 0x400) {
        halfMant = 0;
        halfExp += 0x0400;
        if (halfExp >= 0x7C00) {
          return halfSign | 0x7C00;
        }
      }
    }

    return halfSign | halfExp | (halfMant & 0x3FF);
  }

  double _float16BitsToFloat32(int h) {
    final sign = (h >> 15) & 0x1;
    final exp = (h >> 10) & 0x1F;
    final mant = h & 0x3FF;

    int fSign = sign << 31;
    int fExp;
    int fMant;

    if (exp == 0) {
      if (mant == 0) {
        fExp = 0;
        fMant = 0;
      } else {
        var e = -1;
        var m = mant;
        while ((m & 0x400) == 0) {
          m <<= 1;
          e--;
        }
        m &= 0x3FF;
        fExp = (127 - 15 + 1 + e) << 23;
        fMant = m << 13;
      }
    } else if (exp == 31) {
      fExp = 0xFF << 23;
      fMant = mant << 13;
      if (fMant != 0) {
        fMant |= 0x400000;
      }
    } else {
      fExp = (exp - 15 + 127) << 23;
      fMant = mant << 13;
    }

    final bits = fSign | fExp | fMant;
    final bd = ByteData(4)..setUint32(0, bits, Endian.little);
    return bd.getFloat32(0, Endian.little).toDouble();
  }

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
    if (_isFloat32(inputType)) {
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
    } else if (_isFloat16(inputType)) {
      final buf = Uint16List(inputSize);
      var p = 0;
      var o = 0;
      final pixelCount = height * width;
      for (var i = 0; i < pixelCount; i++) {
        final r = rgba[p];
        final g = rgba[p + 1];
        final b = rgba[p + 2];
        p += 4;

        buf[o++] = _float32ToFloat16Bits(r / 255.0);
        buf[o++] = _float32ToFloat16Bits(g / 255.0);
        buf[o++] = _float32ToFloat16Bits(b / 255.0);
      }
      input = buf;
    } else if (_isUInt8(inputType)) {
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
    } else if (_isInt8(inputType)) {
      final qp = inputTensor.params;
      final scale = qp.scale;
      final zeroPoint = qp.zeroPoint;

      final buf = Int8List(inputSize);
      var p = 0;
      var o = 0;
      final pixelCount = height * width;
      for (var i = 0; i < pixelCount; i++) {
        final r = rgba[p];
        final g = rgba[p + 1];
        final b = rgba[p + 2];
        p += 4;

        final rf = r / 255.0;
        final gf = g / 255.0;
        final bf = b / 255.0;

        final rq = (rf / scale + zeroPoint).round();
        final gq = (gf / scale + zeroPoint).round();
        final bq = (bf / scale + zeroPoint).round();

        buf[o++] = _clampInt(rq, -128, 127);
        buf[o++] = _clampInt(gq, -128, 127);
        buf[o++] = _clampInt(bq, -128, 127);
      }
      input = buf;
    } else {
      throw Exception('不支持的输入类型: $inputType');
    }

    final outputTensor = interpreter.getOutputTensor(0);
    final outputShape = outputTensor.shape;
    final outputType = outputTensor.type;

    final outputElements = _numElements(outputShape);
    final probs = Float32List(outputElements);

    if (_isFloat32(outputType)) {
      interpreter.run(input, probs);
    } else if (_isUInt8(outputType)) {
      final raw = Uint8List(outputElements);
      interpreter.run(input, raw);
      final qp = outputTensor.params;
      final scale = qp.scale;
      final zeroPoint = qp.zeroPoint;
      for (var i = 0; i < raw.length; i++) {
        probs[i] = ((raw[i] - zeroPoint) * scale).toDouble();
      }
    } else if (_isInt8(outputType)) {
      final raw = Int8List(outputElements);
      interpreter.run(input, raw);
      final qp = outputTensor.params;
      final scale = qp.scale;
      final zeroPoint = qp.zeroPoint;
      for (var i = 0; i < raw.length; i++) {
        probs[i] = ((raw[i] - zeroPoint) * scale).toDouble();
      }
    } else if (_isFloat16(outputType)) {
      final raw = Uint16List(outputElements);
      interpreter.run(input, raw);
      for (var i = 0; i < raw.length; i++) {
        probs[i] = _float16BitsToFloat32(raw[i]).toDouble();
      }
    } else {
      throw Exception('不支持的输出类型: $outputType');
    }

    final indices = List<int>.generate(probs.length, (i) => i);
    indices.sort((a, b) => probs[b].compareTo(probs[a]));

    final k = topK.clamp(1, indices.length);
    final topLabels = <String>[];
    var topConfidence = 0.0;

    for (var rank = 0; rank < k; rank++) {
      final idx = indices[rank];
      final conf = probs[idx].toDouble();
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