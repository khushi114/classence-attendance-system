import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:attendance_system/core/utils/geo_utils.dart';
import 'package:attendance_system/features/attendance/domain/geo_verification_result.dart';

/// Service to handle geolocation-based proximity verification.
///
/// Features:
/// - Request and check location permissions
/// - Obtain high-accuracy GPS coordinates
/// - Validate location freshness and accuracy
/// - Detect mock/fake locations
/// - Calculate distance using Haversine formula
/// - Verify proximity to classroom coordinates
class GeolocationService {
  /// Maximum allowed GPS accuracy in meters
  static const double maxAccuracyMeters = 50.0;

  /// Maximum age of location reading in seconds
  static const int maxLocationAgeSeconds = 30;

  /// Default classroom proximity radius in meters
  static const double defaultRadiusMeters = 30.0;

  // ──────────────────── PERMISSION HANDLING ────────────────────

  /// Check if location permission has been granted.
  Future<bool> hasLocationPermission() async {
    final status = await Permission.location.status;
    return status.isGranted;
  }

  /// Request location permission from the user.
  ///
  /// Returns true if permission was granted, false otherwise.
  Future<bool> requestLocationPermission() async {
    final status = await Permission.location.request();
    return status.isGranted;
  }

  /// Check if location services are enabled on the device.
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  // ──────────────────── LOCATION ACQUISITION ────────────────────

  /// Get the current device position with high accuracy.
  ///
  /// Returns null if location cannot be obtained.
  Future<Position?> getCurrentPosition() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return position;
    } catch (e) {
      return null;
    }
  }

  // ──────────────────── PROXIMITY VERIFICATION ────────────────────

  /// Verify that the student is within the allowed proximity of the classroom.
  ///
  /// This is the main entry point for geolocation verification.
  ///
  /// Returns a [GeoVerificationResult] with detailed information about the verification.
  Future<GeoVerificationResult> verifyProximity({
    required double classLatitude,
    required double classLongitude,
    required double allowedRadiusMeters,
  }) async {
    // 1. Check location service is enabled
    final serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      return GeoVerificationResult.failure(
        errorMessage: 'Location services are disabled. Please enable GPS.',
      );
    }

    // 2. Check permission
    final hasPermission = await hasLocationPermission();
    if (!hasPermission) {
      final granted = await requestLocationPermission();
      if (!granted) {
        return GeoVerificationResult.failure(
          errorMessage:
              'Location permission denied. Please grant permission in settings.',
        );
      }
    }

    // 3. Get current position
    final position = await getCurrentPosition();
    if (position == null) {
      return GeoVerificationResult.failure(
        errorMessage: 'Unable to obtain GPS location. Please try again.',
      );
    }

    // 4. Validate accuracy
    if (position.accuracy > maxAccuracyMeters) {
      return GeoVerificationResult.failure(
        studentLat: position.latitude,
        studentLon: position.longitude,
        classLat: classLatitude,
        classLon: classLongitude,
        errorMessage:
            'GPS accuracy too low (${position.accuracy.toStringAsFixed(0)}m). Please move to a location with better signal.',
      );
    }

    // 5. Validate timestamp (freshness)
    final locationAge = DateTime.now().difference(position.timestamp).inSeconds;
    if (locationAge > maxLocationAgeSeconds) {
      return GeoVerificationResult.failure(
        studentLat: position.latitude,
        studentLon: position.longitude,
        classLat: classLatitude,
        classLon: classLongitude,
        errorMessage: 'Location reading is too old. Please try again.',
      );
    }

    // 6. Check for mock location
    if (position.isMocked) {
      return GeoVerificationResult.failure(
        studentLat: position.latitude,
        studentLon: position.longitude,
        classLat: classLatitude,
        classLon: classLongitude,
        errorMessage:
            'Mock location detected. Please disable GPS spoofing apps.',
      );
    }

    // 7. Calculate distance using Haversine formula
    final distance = GeoUtils.calculateDistance(
      lat1: position.latitude,
      lon1: position.longitude,
      lat2: classLatitude,
      lon2: classLongitude,
    );

    // 8. Verify proximity
    if (distance > allowedRadiusMeters) {
      return GeoVerificationResult.failure(
        studentLat: position.latitude,
        studentLon: position.longitude,
        classLat: classLatitude,
        classLon: classLongitude,
        distanceMeters: distance,
        radiusAllowed: allowedRadiusMeters,
        errorMessage:
            'You are ${GeoUtils.formatDistance(distance)} from the classroom (max: ${allowedRadiusMeters.toStringAsFixed(0)}m).',
      );
    }

    // 9. Success!
    return GeoVerificationResult.success(
      studentLat: position.latitude,
      studentLon: position.longitude,
      classLat: classLatitude,
      classLon: classLongitude,
      distanceMeters: distance,
      radiusAllowed: allowedRadiusMeters,
    );
  }

  /// Quick check to see if geolocation verification is possible.
  ///
  /// Returns an error message if not possible, null if OK.
  Future<String?> checkPrerequisites() async {
    if (!await isLocationServiceEnabled()) {
      return 'Location services are disabled';
    }
    if (!await hasLocationPermission()) {
      return 'Location permission not granted';
    }
    return null;
  }
}
