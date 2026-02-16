import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../utils/camera_utils.dart';

class CameraService {
  CameraController? _controller;
  CameraDescription? _cameraDescription;
  bool _isStreaming = false;

  CameraController? get controller => _controller;
  bool get isStreaming => _isStreaming;

  Future<void> initialize() async {
    final cameras = await availableCameras();
    // Prefer front camera
    _cameraDescription = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      _cameraDescription!,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: defaultTargetPlatform == TargetPlatform.android
          ? ImageFormatGroup
                .nv21 // Android specific
          : ImageFormatGroup
                .bgra8888, // iOS/Web specific (Web usually handles implicitly)
    );

    await _controller!.initialize();
  }

  Future<void> startStream(Function(InputImage inputImage) onImage) async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isStreaming) {
      return;
    }

    _isStreaming = true;
    _controller!.startImageStream((CameraImage image) {
      final rotation = CameraUtils.rotationIntToImageRotation(
        _cameraDescription!.sensorOrientation,
      );

      final inputImage = CameraUtils.convertCameraImage(
        image,
        _cameraDescription!,
        rotation,
      );

      if (inputImage != null) {
        onImage(inputImage);
      }
    });
  }

  Future<void> stopStream() async {
    if (_controller == null || !_isStreaming) {
      return;
    }

    await _controller!.stopImageStream();
    _isStreaming = false;
  }

  Future<void> dispose() async {
    await stopStream();
    await _controller?.dispose();
    _controller = null;
  }
}
