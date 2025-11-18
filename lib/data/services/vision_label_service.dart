import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

class LabelResult {
  final List<String> labels;
  final bool isFood;
  final double topConfidence;
  const LabelResult({
    required this.labels,
    required this.isFood,
    required this.topConfidence,
  });
}

class VisionLabelService {
  final ImageLabeler _labeler =
      ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.55));

  Future<LabelResult> labelFoodFromFile(String filePath) async {
    final inputImage = InputImage.fromFilePath(filePath);
    final labels = await _labeler.processImage(inputImage);

    double topConf = 0.0;
    final pickedLabels = <String>[];
    for (final l in labels) {
      if (l.confidence > topConf) topConf = l.confidence;
      if (l.confidence >= 0.55) {
        pickedLabels.add(l.label);
      }
    }

    final isFood = _looksLikeFood(labels);
    return LabelResult(labels: pickedLabels, isFood: isFood, topConfidence: topConf);
  }

  bool _looksLikeFood(List<ImageLabel> labels) {
    const keywords = [
      'food',
      'dish',
      'meal',
      'cuisine',
      'fruit',
      'vegetable',
      'dessert',
      'drink',
      'beverage',
      'snack',
      'meat',
      'seafood',
      'bread',
      'cake',
      'pizza',
      'burger',
      'noodle',
      'rice',
      'soup',
      'salad',
      'sushi',
      'egg',
      'cheese',
      'yogurt',
      'pasta',
    ];
    return labels.any(
      (l) => keywords.contains(l.label.toLowerCase()) && l.confidence >= 0.5,
    );
  }

  Future<void> dispose() async {
    await _labeler.close();
  }
}

final visionLabelServiceProvider = Provider<VisionLabelService>((ref) {
  final svc = VisionLabelService();
  ref.onDispose(svc.dispose);
  return svc;
});