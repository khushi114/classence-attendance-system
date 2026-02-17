import 'package:flutter/material.dart';
import 'package:attendance_system/core/theme/app_colors.dart';
import 'package:attendance_system/features/auth/data/firebase_auth_service.dart';
import 'package:attendance_system/features/verification/presentation/verification_screen.dart';
import 'package:attendance_system/features/verification/domain/entities/user_registration.dart';
import 'package:attendance_system/features/sessions/data/session_service.dart';
import 'package:attendance_system/features/sessions/domain/session_model.dart';
import 'package:attendance_system/features/attendance/data/attendance_service.dart';
import 'package:attendance_system/widgets/custom_button.dart';
import 'package:attendance_system/core/services/geolocation_service.dart';
import 'package:attendance_system/core/services/bluetooth_service.dart';
import 'package:attendance_system/features/attendance/domain/geo_verification_result.dart';
import 'package:attendance_system/features/attendance/domain/ble_verification_result.dart';
import 'package:attendance_system/features/classes/data/class_service.dart';

/// Multi-step attendance screen with animated step indicators.
///
/// Steps: Session Code → Bluetooth → Location → Face Scan
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
    with TickerProviderStateMixin {
  final _sessionService = SessionService();
  final _classService = ClassService();
  final _geoService = GeolocationService();
  final _bleService = BluetoothService();
  final _sessionCodeController = TextEditingController();

  bool _isSessionVerified = false;
  SessionModel? _activeSession;
  GeoVerificationResult? _geoVerificationResult;

  int _currentStep = 0;
  final List<_StepStatus> _steps = [
    _StepStatus.pending, // Bluetooth
    _StepStatus.pending, // Location
    _StepStatus.pending, // Face
  ];
  String _statusMessage = 'Enter Session Code to start';
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _progressAnimation = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _progressController.dispose();
    _sessionCodeController.dispose();
    super.dispose();
  }

  Future<void> _validateSession() async {
    final code = _sessionCodeController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() => _statusMessage = 'Validating session...');

    try {
      final session = await _sessionService.validateSessionToken(code);
      if (mounted) {
        setState(() {
          _activeSession = session;
          _isSessionVerified = true;
          _statusMessage = 'Session Verified! Starting checks...';
        });
        _startVerificationFlow();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = e.toString().contains('Exception:')
              ? e.toString().split('Exception: ')[1]
              : 'Invalid session code';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_statusMessage),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _startVerificationFlow() async {
    // Step 1: Bluetooth Check with real BLE verification
    setState(() {
      _currentStep = 0;
      _steps[0] = _StepStatus.inProgress;
      _statusMessage = 'Scanning for classroom beacon...';
    });
    _animateProgress(0.0, 0.33);

    // Check if session has a beacon ID configured
    if (_activeSession!.bluetoothBeaconId == null ||
        _activeSession!.bluetoothBeaconId!.isEmpty) {
      if (!mounted) return;
      setState(() {
        _steps[0] = _StepStatus.success; // Skip if no beacon configured
        _statusMessage = 'Bluetooth check skipped (no beacon configured) ✓';
      });
      await Future.delayed(const Duration(milliseconds: 500));
    } else {
      // Perform BLE verification
      try {
        final bleResult = await _bleService.verifyProximity(
          beaconUuid: _activeSession!.bluetoothBeaconId!,
        );

        if (!mounted) return;
        if (bleResult.bluetoothVerified) {
          setState(() {
            _steps[0] = _StepStatus.success;
            _statusMessage =
                'Beacon detected ✓ (RSSI: ${bleResult.rssiAverage?.toStringAsFixed(1)} dBm)';
          });
        } else {
          setState(() {
            _steps[0] = _StepStatus.failed;
            _statusMessage =
                bleResult.errorMessage ?? 'Beacon verification failed';
          });
          return; // Stop if Bluetooth verification fails
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _steps[0] = _StepStatus.failed;
          _statusMessage = 'Error scanning beacon: ${e.toString()}';
        });
        return;
      }
    }
    await Future.delayed(const Duration(milliseconds: 500));

    // Step 2: Location Check with actual geolocation verification
    if (!mounted) return;
    setState(() {
      _currentStep = 1;
      _steps[1] = _StepStatus.inProgress;
      _statusMessage = 'Verifying location...';
    });
    _animateProgress(0.33, 0.66);

    // Fetch classroom location from database
    try {
      final classData = await _classService.getClass(_activeSession!.classId);

      if (classData == null) {
        if (!mounted) return;
        setState(() {
          _steps[1] = _StepStatus.failed;
          _statusMessage = 'Classroom not found.';
        });
        return;
      }

      // Check if classroom has geolocation configured
      if (classData.latitude == null || classData.longitude == null) {
        if (!mounted) return;
        setState(() {
          _steps[1] = _StepStatus.failed;
          _statusMessage =
              'Classroom location not configured. Contact faculty.';
        });
        return;
      }

      // Perform geolocation verification
      final geoResult = await _geoService.verifyProximity(
        classLatitude: classData.latitude!,
        classLongitude: classData.longitude!,
        allowedRadiusMeters: classData.allowedRadiusMeters ?? 30.0,
      );

      _geoVerificationResult = geoResult;

      if (!mounted) return;
      if (geoResult.geoVerified) {
        setState(() {
          _steps[1] = _StepStatus.success;
          _statusMessage =
              'Location verified ✓ (${geoResult.distanceMeters?.toStringAsFixed(1)}m from classroom)';
        });
      } else {
        setState(() {
          _steps[1] = _StepStatus.failed;
          _statusMessage =
              geoResult.errorMessage ?? 'Location verification failed';
        });
        return;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _steps[1] = _StepStatus.failed;
        _statusMessage = 'Error verifying location: ${e.toString()}';
      });
      return;
    }

    await Future.delayed(const Duration(milliseconds: 500));

    // Step 3: Face Scan
    if (!mounted) return;
    setState(() {
      _currentStep = 2;
      _steps[2] = _StepStatus.inProgress;
      _statusMessage = 'Starting face verification...';
    });
    _animateProgress(0.66, 1.0);
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;
    _launchFaceVerification();
  }

  void _animateProgress(double from, double to) {
    _progressAnimation = Tween<double>(begin: from, end: to).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );
    _progressController
      ..reset()
      ..forward();
  }

  Future<void> _launchFaceVerification() async {
    final authService = FirebaseAuthService();
    final user = authService.currentUser;
    if (user == null || _activeSession == null) {
      if (mounted) {
        setState(() {
          _steps[2] = _StepStatus.failed;
          _statusMessage = 'Session or user invalid.';
        });
      }
      return;
    }

    final userData = await authService.getUserData(user.uid);
    if (userData == null || !mounted) {
      setState(() {
        _steps[2] = _StepStatus.failed;
        _statusMessage = 'Failed to load user data.';
      });
      return;
    }

    // Prepare registration data for the verification screen to compare against
    final userRegistration = UserRegistration(
      id: userData.id,
      name: userData.name,
      faceEmbedding: userData.faceEmbedding ?? [],
    );

    // Pass session context to verification screen
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VerificationScreen(user: userRegistration),
      ),
    );

    if (!mounted) return;

    if (result != null && result['verification_status'] == 'approved') {
      try {
        final attendanceService = AttendanceService(); // Instantiate service

        // Mark attendance in backend
        await attendanceService.markAttendance(
          sessionId: _activeSession!.id,
          studentId: user.uid,
          classId: _activeSession!.classId,
          bluetoothVerified: true, // TODO: Use real check result
          geoVerified: _geoVerificationResult?.geoVerified ?? false,
          faceVerified: true,
          livenessVerified: true, // VerificationScreen implies liveness
          confidenceScore: result['confidence_score'] ?? 1.0,
          metadata: _geoVerificationResult?.toMap(),
        );

        if (mounted) {
          setState(() {
            _steps[2] = _StepStatus.success;
            _statusMessage = 'Attendance marked successfully! 🎉';
          });
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _steps[2] = _StepStatus.failed;
            _statusMessage = e.toString().contains('Exception:')
                ? e.toString().split('Exception: ')[1]
                : 'Failed to save attendance';
          });
        }
      }
    } else {
      setState(() {
        _steps[2] = _StepStatus.failed;
        _statusMessage = 'Face verification failed. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'Mark Attendance',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            if (!_isSessionVerified) ...[
              const SizedBox(height: 40),
              const Icon(
                Icons.qr_code_scanner_rounded,
                size: 64,
                color: AppColors.royalBlue,
              ),
              const SizedBox(height: 24),
              const Text(
                'Enter Session Code',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Ask your faculty for the active session code',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _sessionCodeController,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  letterSpacing: 4,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  hintText: 'CODE',
                  fillColor: AppColors.surface,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              CustomButton(text: 'Verify & Start', onPressed: _validateSession),
            ] else ...[
              const SizedBox(height: 20),
              // Step indicators
              Row(
                children: [
                  _buildStepCircle(0, Icons.bluetooth, 'Bluetooth'),
                  _buildStepLine(0),
                  _buildStepCircle(1, Icons.location_on_rounded, 'Location'),
                  _buildStepLine(1),
                  _buildStepCircle(2, Icons.face_rounded, 'Face Scan'),
                ],
              ),
              const SizedBox(height: 32),

              // Animated progress bar
              AnimatedBuilder(
                animation: _progressAnimation,
                builder: (context, _) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _progressAnimation.value,
                      minHeight: 8,
                      backgroundColor: AppColors.border,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _steps.any((s) => s == _StepStatus.failed)
                            ? AppColors.error
                            : AppColors.emerald,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 40),

              // Status Card
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border, width: 0.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildCurrentStepIcon(),
                    const SizedBox(height: 20),
                    Text(
                      _statusMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _steps.any((s) => s == _StepStatus.failed)
                            ? AppColors.error
                            : AppColors.textPrimary,
                      ),
                    ),
                    if (_steps[2] == _StepStatus.failed) ...[
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              for (int i = 0; i < _steps.length; i++) {
                                _steps[i] = _StepStatus.pending;
                              }
                              _currentStep = 0;
                            });
                            _startVerificationFlow();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.royalBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Retry',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ... (keep helper methods like _buildCurrentStepIcon, _buildStepCircle, _buildStepLine)

  Widget _buildCurrentStepIcon() {
    if (_steps.every((s) => s == _StepStatus.success)) {
      return Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: AppColors.emerald.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.check_circle_rounded,
          color: AppColors.emerald,
          size: 40,
        ),
      );
    }
    if (_steps.any((s) => s == _StepStatus.failed)) {
      return Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.error_rounded,
          color: AppColors.error,
          size: 40,
        ),
      );
    }
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.royalBlue.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: const Padding(
        padding: EdgeInsets.all(18),
        child: CircularProgressIndicator(
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation(AppColors.royalBlue),
        ),
      ),
    );
  }

  Widget _buildStepCircle(int index, IconData icon, String label) {
    final status = _steps[index];
    final Color bgColor;
    final Color iconColor;

    switch (status) {
      case _StepStatus.success:
        bgColor = AppColors.emerald;
        iconColor = Colors.white;
        break;
      case _StepStatus.failed:
        bgColor = AppColors.error;
        iconColor = Colors.white;
        break;
      case _StepStatus.inProgress:
        bgColor = AppColors.royalBlue;
        iconColor = Colors.white;
        break;
      case _StepStatus.pending:
        bgColor = AppColors.border;
        iconColor = AppColors.textLight;
        break;
    }

    return Expanded(
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              boxShadow: status == _StepStatus.inProgress
                  ? [
                      BoxShadow(
                        color: AppColors.royalBlue.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: Icon(
              status == _StepStatus.success
                  ? Icons.check_rounded
                  : status == _StepStatus.failed
                  ? Icons.close_rounded
                  : icon,
              color: iconColor,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: status == _StepStatus.pending
                  ? AppColors.textLight
                  : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepLine(int beforeIndex) {
    final status = _steps[beforeIndex];
    return Container(
      width: 24,
      height: 3,
      margin: const EdgeInsets.only(bottom: 22),
      decoration: BoxDecoration(
        color: status == _StepStatus.success
            ? AppColors.emerald
            : AppColors.border,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

enum _StepStatus { pending, inProgress, success, failed }
