/// Represents the result of BLE proximity verification.
///
/// Contains detailed information about beacon detection, RSSI values,
/// and verification status.
class BleVerificationResult {
  final bool beaconDetected;
  final String? beaconUuid;
  final int? rssi;
  final double? rssiAverage; // Smoothed RSSI value
  final int threshold;
  final bool bluetoothVerified;
  final String verificationStatus; // 'approved' or 'rejected'
  final String? errorMessage;
  final DateTime timestamp;

  BleVerificationResult({
    required this.beaconDetected,
    this.beaconUuid,
    this.rssi,
    this.rssiAverage,
    this.threshold = -70,
    required this.bluetoothVerified,
    required this.verificationStatus,
    this.errorMessage,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create a successful verification result
  factory BleVerificationResult.success({
    required String beaconUuid,
    required int rssi,
    required double rssiAverage,
    int threshold = -70,
  }) {
    return BleVerificationResult(
      beaconDetected: true,
      beaconUuid: beaconUuid,
      rssi: rssi,
      rssiAverage: rssiAverage,
      threshold: threshold,
      bluetoothVerified: true,
      verificationStatus: 'approved',
    );
  }

  /// Create a failed verification result
  factory BleVerificationResult.failure({
    String? beaconUuid,
    int? rssi,
    double? rssiAverage,
    int threshold = -70,
    required String errorMessage,
  }) {
    return BleVerificationResult(
      beaconDetected: beaconUuid != null,
      beaconUuid: beaconUuid,
      rssi: rssi,
      rssiAverage: rssiAverage,
      threshold: threshold,
      bluetoothVerified: false,
      verificationStatus: 'rejected',
      errorMessage: errorMessage,
    );
  }

  /// Convert to map for Firestore storage
  Map<String, dynamic> toMap() {
    return {
      'beaconDetected': beaconDetected,
      'beaconUuid': beaconUuid,
      'rssi': rssi,
      'rssiAverage': rssiAverage,
      'threshold': threshold,
      'bluetoothVerified': bluetoothVerified,
      'verificationStatus': verificationStatus,
      'errorMessage': errorMessage,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  String toString() {
    if (bluetoothVerified) {
      return 'BLE Verified: RSSI $rssi dBm (avg: ${rssiAverage?.toStringAsFixed(1)} dBm)';
    } else {
      return 'BLE Failed: $errorMessage';
    }
  }
}
