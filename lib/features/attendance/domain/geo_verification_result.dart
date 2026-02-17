/// Result of geolocation proximity verification.
class GeoVerificationResult {
  /// Whether location was successfully obtained from device
  final bool locationObtained;

  /// Student's current latitude
  final double? studentLat;

  /// Student's current longitude
  final double? studentLon;

  /// Classroom's latitude
  final double? classLat;

  /// Classroom's longitude
  final double? classLon;

  /// Calculated distance between student and classroom in meters
  final double? distanceMeters;

  /// Maximum allowed radius from classroom center in meters
  final double? radiusAllowed;

  /// Whether the student is within the allowed proximity radius
  final bool geoVerified;

  /// Verification status: "approved", "rejected", "pending"
  final String verificationStatus;

  /// Error message if verification failed
  final String? errorMessage;

  /// Timestamp when verification was performed
  final DateTime timestamp;

  GeoVerificationResult({
    required this.locationObtained,
    this.studentLat,
    this.studentLon,
    this.classLat,
    this.classLon,
    this.distanceMeters,
    this.radiusAllowed,
    required this.geoVerified,
    required this.verificationStatus,
    this.errorMessage,
    required this.timestamp,
  });

  /// Factory constructor for successful verification
  factory GeoVerificationResult.success({
    required double studentLat,
    required double studentLon,
    required double classLat,
    required double classLon,
    required double distanceMeters,
    required double radiusAllowed,
  }) {
    return GeoVerificationResult(
      locationObtained: true,
      studentLat: studentLat,
      studentLon: studentLon,
      classLat: classLat,
      classLon: classLon,
      distanceMeters: distanceMeters,
      radiusAllowed: radiusAllowed,
      geoVerified: true,
      verificationStatus: 'approved',
      timestamp: DateTime.now(),
    );
  }

  /// Factory constructor for failed verification
  factory GeoVerificationResult.failure({
    double? studentLat,
    double? studentLon,
    double? classLat,
    double? classLon,
    double? distanceMeters,
    double? radiusAllowed,
    required String errorMessage,
  }) {
    return GeoVerificationResult(
      locationObtained: studentLat != null && studentLon != null,
      studentLat: studentLat,
      studentLon: studentLon,
      classLat: classLat,
      classLon: classLon,
      distanceMeters: distanceMeters,
      radiusAllowed: radiusAllowed,
      geoVerified: false,
      verificationStatus: 'rejected',
      errorMessage: errorMessage,
      timestamp: DateTime.now(),
    );
  }

  /// Convert to map for storage or logging
  Map<String, dynamic> toMap() {
    return {
      'locationObtained': locationObtained,
      'studentLat': studentLat,
      'studentLon': studentLon,
      'classLat': classLat,
      'classLon': classLon,
      'distanceMeters': distanceMeters,
      'radiusAllowed': radiusAllowed,
      'geoVerified': geoVerified,
      'verificationStatus': verificationStatus,
      'errorMessage': errorMessage,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  String toString() {
    if (geoVerified) {
      return 'Location verified: ${distanceMeters?.toStringAsFixed(1)}m from classroom';
    } else {
      return 'Location verification failed: $errorMessage';
    }
  }
}
