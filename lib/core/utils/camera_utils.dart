import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:flutter/foundation.dart';

class CameraUtils {
  static InputImage? convertCameraImage(
    CameraImage image,
    CameraDescription camera,
    InputImageRotation rotation,
  ) {
    if (image.planes.isEmpty) {
      return null;
    }

    final allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final Size imageSize = Size(
      image.width.toDouble(),
      image.height.toDouble(),
    );

    InputImageFormat inputImageFormat = InputImageFormat.nv21;

    // Map Camera's ImageFormatGroup to ML Kit's InputImageFormat
    if (image.format.group == ImageFormatGroup.yuv420) {
      inputImageFormat = InputImageFormat.yuv420;
    } else if (image.format.group == ImageFormatGroup.bgra8888) {
      inputImageFormat = InputImageFormat.bgra8888;
    } else if (image.format.group == ImageFormatGroup.nv21) {
      inputImageFormat = InputImageFormat.nv21;
    }

    // For Android, the plane data is not directly used in Metadata construction in simpler ways,
    // but usually we just provide bytesPerRow from the first plane for iOS,
    // or 0 for Android if verified.
    // However, InputImageMetadata expects 'bytesPerRow'.

    final plane = image.planes.first;

    final inputImageData = InputImageMetadata(
      size: imageSize,
      rotation: rotation,
      format: inputImageFormat,
      bytesPerRow: plane.bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: inputImageData);
  }

  static InputImageRotation rotationIntToImageRotation(int rotation) {
    switch (rotation) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }
}
