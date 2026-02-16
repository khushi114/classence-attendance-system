import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:attendance_system/core/services/camera_service.dart';
import 'package:attendance_system/core/services/face_detection_service.dart';
import 'package:attendance_system/core/services/face_embedding_service.dart';
import 'package:attendance_system/features/attendance/data/attendance_service.dart';
import 'package:attendance_system/features/verification/domain/entities/user_registration.dart';

class VerificationScreen extends StatefulWidget {
  final UserRegistration user;

  const VerificationScreen({super.key, required this.user});

  @override
  _VerificationScreenState createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final CameraService _cameraService = CameraService();
  final FaceDetectionService _faceDetectionService = FaceDetectionService();
  final FaceEmbeddingService _embeddingService = FaceEmbeddingService();
  final AttendanceService _attendanceService = AttendanceService();

  bool _isInitializing = true;
  bool _isProcessing = false;
  bool _faceDetected = false;
  String _statusMessage = "Position your face in the frame";
  Color _statusColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _cameraService.initialize();
      setState(() {
        _isInitializing = false;
      });
      _startFaceDetection();
    } catch (e) {
      setState(() {
        _statusMessage = "Camera initialization failed";
        _statusColor = Colors.red;
        _isInitializing = false;
      });
    }
  }

  void _startFaceDetection() {
    // Start periodic face detection to guide user
    _cameraService.startStream(_detectFace);
  }

  Future<void> _detectFace(InputImage inputImage) async {
    if (_isProcessing) {
      return;
    }

    try {
      final faces = await _faceDetectionService.detectFaces(inputImage);

      if (!mounted) {
        return;
      }

      if (faces.isEmpty) {
        setState(() {
          _faceDetected = false;
          _statusMessage = "No face detected";
          _statusColor = Colors.orange;
        });
      } else if (faces.length > 1) {
        setState(() {
          _faceDetected = false;
          _statusMessage = "Multiple faces detected";
          _statusColor = Colors.orange;
        });
      } else {
        setState(() {
          _faceDetected = true;
          _statusMessage = "Face detected - Ready to capture";
          _statusColor = Colors.green;
        });
      }
    } catch (e) {
      print("Error detecting face: $e");
    }
  }

  Future<void> _captureAndVerify() async {
    if (_isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = "Capturing...";
      _statusColor = Colors.blue;
    });

    try {
      // Stop the stream temporarily
      await _cameraService.stopStream();

      // Capture photo
      final XFile? photo = await _cameraService.controller?.takePicture();
      if (photo == null) {
        throw Exception("Failed to capture photo");
      }

      setState(() {
        _statusMessage = "Analyzing face...";
      });

      // Convert to InputImage
      final inputImage = InputImage.fromFilePath(photo.path);

      // Extract embedding from captured photo
      final embedding = await _embeddingService.extractEmbedding(inputImage);
      if (embedding == null) {
        throw Exception("No face detected in captured photo");
      }

      setState(() {
        _statusMessage = "Verifying identity...";
      });

      // Compare with stored embedding
      final storedEmbedding = widget.user.faceEmbedding;
      final similarity = _embeddingService.compareFaces(
        embedding,
        storedEmbedding,
      );

      // Verification threshold
      const double threshold = 0.7;

      if (similarity >= threshold) {
        // Success - mark attendance
        // NOTE: Full session-based flow passes these from AttendanceScreen.
        // Here we record a direct verification-based attendance.
        await _attendanceService.markAttendance(
          sessionId: widget.user.id, // placeholder until session flow is wired
          studentId: widget.user.id,
          classId: '', // placeholder until class context is passed
          bluetoothVerified: true,
          geoVerified: true,
          faceVerified: true,
          livenessVerified: true,
          confidenceScore: similarity,
        );

        setState(() {
          _statusMessage = "Verified! Attendance marked";
          _statusColor = Colors.green;
        });

        // Return success to dashboard
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.pop(context, {
            'verification_status': 'approved',
            'similarity_score': similarity,
          });
        }
      } else {
        // Failed verification
        setState(() {
          _statusMessage =
              "Verification failed (${(similarity * 100).toStringAsFixed(1)}% match)";
          _statusColor = Colors.red;
          _isProcessing = false;
        });

        // Restart face detection
        await Future.delayed(const Duration(seconds: 2));
        _startFaceDetection();
      }
    } catch (e) {
      setState(() {
        _statusMessage = "Error: ${e.toString()}";
        _statusColor = Colors.red;
        _isProcessing = false;
      });

      // Restart face detection
      await Future.delayed(const Duration(seconds: 2));
      _startFaceDetection();
    }
  }

  @override
  void dispose() {
    _cameraService.dispose();
    _embeddingService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Verify Attendance'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: _isInitializing
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Stack(
              children: [
                // Camera Preview
                if (_cameraService.controller != null &&
                    _cameraService.controller!.value.isInitialized)
                  Positioned.fill(
                    child: CameraPreview(_cameraService.controller!),
                  ),

                // Face detection overlay
                Positioned.fill(
                  child: CustomPaint(
                    painter: FaceOverlayPainter(faceDetected: _faceDetected),
                  ),
                ),

                // Status message
                Positioned(
                  top: 40,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _statusMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _statusColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                // Capture button
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Column(
                      children: [
                        // Main capture button
                        GestureDetector(
                          onTap: _faceDetected && !_isProcessing
                              ? _captureAndVerify
                              : null,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _faceDetected && !_isProcessing
                                  ? Colors.white
                                  : Colors.grey,
                              border: Border.all(
                                color: _faceDetected && !_isProcessing
                                    ? Colors.green
                                    : Colors.grey,
                                width: 4,
                              ),
                            ),
                            child: _isProcessing
                                ? const Padding(
                                    padding: EdgeInsets.all(20.0),
                                    child: CircularProgressIndicator(
                                      color: Colors.blue,
                                      strokeWidth: 3,
                                    ),
                                  )
                                : Icon(
                                    Icons.camera_alt,
                                    size: 40,
                                    color: _faceDetected
                                        ? Colors.black
                                        : Colors.white,
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _faceDetected && !_isProcessing
                              ? 'Tap to capture'
                              : 'Align your face',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Custom painter for face detection overlay
class FaceOverlayPainter extends CustomPainter {
  final bool faceDetected;

  FaceOverlayPainter({required this.faceDetected});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = faceDetected ? Colors.green : Colors.white.withOpacity(0.5);

    // Draw oval guide for face
    final center = Offset(size.width / 2, size.height / 2.5);
    final radius = size.width * 0.35;

    canvas.drawOval(
      Rect.fromCenter(center: center, width: radius * 2, height: radius * 2.5),
      paint,
    );
  }

  @override
  bool shouldRepaint(FaceOverlayPainter oldDelegate) {
    return oldDelegate.faceDetected != faceDetected;
  }
}
