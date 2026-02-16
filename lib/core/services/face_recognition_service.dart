import 'dart:math';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

// import 'package:tflite_flutter/tflite_flutter.dart'; // Future integration

class FaceRecognitionService {
  // Interpreter? _interpreter;

  Future<void> initialize() async {
    // Load TFLite model
    // _interpreter = await Interpreter.fromAsset('mobilefacenet.tflite');
    await Future.delayed(Duration(milliseconds: 500)); // Simulate loading
  }

  Future<List<double>> extractEmbedding(Face face) async {
    // 1. Crop the face from the image (InputImage).
    // 2. Resize to model input size (e.g., 112x112).
    // 3. Normalize pixel values.
    // 4. Run inference.

    // For this prototype, return a mock embedding.
    // In a real app, we need the original image bytes to crop the face.
    // The 'Face' object only gives bounding box.

    await Future.delayed(Duration(milliseconds: 100)); // Simulate processing
    return List.generate(
      192,
      (index) => Random().nextDouble(),
    ); // Mock 192-d vector
  }

  double calculateSimilarity(List<double> embedding1, List<double> embedding2) {
    if (embedding1.length != embedding2.length) {
      return 0.0;
    }

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < embedding1.length; i++) {
      dotProduct += embedding1[i] * embedding2[i];
      normA += embedding1[i] * embedding1[i];
      normB += embedding2[i] * embedding2[i];
    }

    if (normA == 0 || normB == 0) {
      return 0.0;
    }

    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  bool verify(
    List<double> liveEmbedding,
    List<double> registeredEmbedding, {
    double threshold = 0.8,
  }) {
    double score = calculateSimilarity(liveEmbedding, registeredEmbedding);
    return score >= threshold;
  }
}
