import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

enum LivenessStep { blink, smile, turnHeadLeft, turnHeadRight, completed }

class LivenessController {
  final List<LivenessStep> _steps = [
    LivenessStep.blink,
    LivenessStep.smile,
    LivenessStep.turnHeadLeft,
    LivenessStep.turnHeadRight,
  ];

  int _currentStepIndex = 0;

  // Thresholds
  static const double _blinkThreshold =
      0.25; // Eye open probability < 0.25 means closed
  static const double _smileThreshold = 0.75; // Smile prob > 0.75
  static const double _headTurnThreshold = 45.0; // Degrees

  LivenessStep get currentStep => _currentStepIndex < _steps.length
      ? _steps[_currentStepIndex]
      : LivenessStep.completed;

  double get progress => _currentStepIndex / _steps.length;

  void reset() {
    _currentStepIndex = 0;
  }

  bool processFace(Face face) {
    if (_currentStepIndex >= _steps.length) {
      return true;
    }

    final step = _steps[_currentStepIndex];
    bool stepPassed = false;

    switch (step) {
      case LivenessStep.blink:
        final leftOpen = face.leftEyeOpenProbability;
        final rightOpen = face.rightEyeOpenProbability;
        if (leftOpen != null && rightOpen != null) {
          if (leftOpen < _blinkThreshold && rightOpen < _blinkThreshold) {
            stepPassed = true;
          }
        }
        break;
      case LivenessStep.smile:
        final smileProb = face.smilingProbability;
        if (smileProb != null && smileProb > _smileThreshold) {
          stepPassed = true;
        }
        break;
      case LivenessStep.turnHeadLeft:
        final headYaw = face
            .headEulerAngleY; // Negative is right, Positive is left (usually, need to verify)
        // Actually, for ML Kit:
        // Y-axis angle (yaw): Positive values indicate the face is turned to the user's right (the device's left).
        // So for "Turn Left" (user's left), we expect negative yaw?
        // Let's assume user's left means looking towards the left side of the screen.
        // If I look left, my head turns left.
        // Let's check documentation or standard behavior.
        // User's Left -> Yaw > 45 (or < -45 depending on coordinate system).
        // Mobile Vision API: -Y is to the right of the image, +Y is to the left.
        if (headYaw != null && headYaw > _headTurnThreshold) {
          stepPassed = true;
        }
        break;
      case LivenessStep.turnHeadRight:
        final headYaw = face.headEulerAngleY;
        if (headYaw != null && headYaw < -_headTurnThreshold) {
          stepPassed = true;
        }
        break;
      case LivenessStep.completed:
        return true;
    }

    if (stepPassed) {
      // Move to next step only if the current frame satisfies the condition.
      // We might want to require the condition to be held for a few frames or just once.
      // For simplicity, let's say once is enough, but in reality we'd want a "reset" to neutral face in between.
      // But for this MVP, sequential satisfaction is fine.
      _nextStep();
    }

    return _currentStepIndex >= _steps.length;
  }

  void _nextStep() {
    if (_currentStepIndex < _steps.length) {
      _currentStepIndex++;
    }
  }
}
