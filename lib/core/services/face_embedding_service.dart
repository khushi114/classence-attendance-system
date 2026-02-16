import 'dart:math';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Service to handle face embedding extraction and comparison
class FaceEmbeddingService {
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  /// Extract face embedding from an InputImage
  /// Returns a 192-dimensional vector representing the face
  Future<List<double>?> extractEmbedding(InputImage inputImage) async {
    try {
      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        return null;
      }

      // Get the first detected face
      final face = faces.first;

      // Generate embedding from face landmarks and contours
      // In a production app, you would use a proper face recognition model
      // For now, we'll create a simplified embedding based on facial features
      final embedding = _generateEmbeddingFromFace(face);

      return embedding;
    } catch (e) {
      print('Error extracting embedding: $e');
      return null;
    }
  }

  /// Generate a simplified embedding from face landmarks
  /// In production, use a proper face recognition model like FaceNet
  List<double> _generateEmbeddingFromFace(Face face) {
    final embedding = List<double>.filled(192, 0.0);

    // Use face landmarks to create a unique signature
    final landmarks = face.landmarks;
    int index = 0;

    // Add normalized landmark positions
    landmarks.forEach((landmarkType, landmark) {
      if (landmark != null && index < 190) {
        embedding[index++] = landmark.position.x / 1000.0;
        embedding[index++] = landmark.position.y / 1000.0;
      }
    });

    // Add face angles
    if (index < 192) {
      embedding[index++] = (face.headEulerAngleX ?? 0.0) / 180.0;
      embedding[index++] = (face.headEulerAngleY ?? 0.0) / 180.0;
    }

    // Normalize the embedding
    return _normalizeEmbedding(embedding);
  }

  /// Normalize embedding to unit length
  List<double> _normalizeEmbedding(List<double> embedding) {
    final magnitude = sqrt(
      embedding.fold<double>(0.0, (sum, val) => sum + val * val),
    );

    if (magnitude == 0) {
      return embedding;
    }

    return embedding.map((val) => val / magnitude).toList();
  }

  /// Compare two face embeddings using cosine similarity
  /// Returns a score between 0 and 1 (1 = identical, 0 = completely different)
  double compareFaces(List<double> embedding1, List<double> embedding2) {
    if (embedding1.length != embedding2.length) {
      throw ArgumentError('Embeddings must have the same length');
    }

    // Calculate cosine similarity
    double dotProduct = 0.0;
    double magnitude1 = 0.0;
    double magnitude2 = 0.0;

    for (int i = 0; i < embedding1.length; i++) {
      dotProduct += embedding1[i] * embedding2[i];
      magnitude1 += embedding1[i] * embedding1[i];
      magnitude2 += embedding2[i] * embedding2[i];
    }

    magnitude1 = sqrt(magnitude1);
    magnitude2 = sqrt(magnitude2);

    if (magnitude1 == 0 || magnitude2 == 0) {
      return 0.0;
    }

    // Cosine similarity ranges from -1 to 1, normalize to 0 to 1
    final similarity = dotProduct / (magnitude1 * magnitude2);
    return (similarity + 1) / 2;
  }

  /// Average multiple embeddings to create a more robust representation
  List<double> averageEmbeddings(List<List<double>> embeddings) {
    if (embeddings.isEmpty) {
      throw ArgumentError('Cannot average empty list of embeddings');
    }

    final length = embeddings.first.length;
    final averaged = List<double>.filled(length, 0.0);

    for (final embedding in embeddings) {
      if (embedding.length != length) {
        throw ArgumentError('All embeddings must have the same length');
      }
      for (int i = 0; i < length; i++) {
        averaged[i] += embedding[i];
      }
    }

    for (int i = 0; i < length; i++) {
      averaged[i] /= embeddings.length;
    }

    return _normalizeEmbedding(averaged);
  }

  /// Dispose of resources
  void dispose() {
    _faceDetector.close();
  }
}
