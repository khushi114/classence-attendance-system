import 'package:cloud_firestore/cloud_firestore.dart';

/// Attendance record with multi-factor verification flags.
class AttendanceRecord {
  final String id;
  final String sessionId;
  final String studentId;
  final String classId;
  final String status; // 'present', 'late', 'absent'
  final bool bluetoothVerified;
  final bool geoVerified;
  final bool faceVerified;
  final bool livenessVerified;
  final double confidenceScore; // 0.0 - 1.0
  final DateTime markedAt;
  final Map<String, dynamic>? metadata; // device info, etc.

  AttendanceRecord({
    required this.id,
    required this.sessionId,
    required this.studentId,
    required this.classId,
    required this.status,
    this.bluetoothVerified = false,
    this.geoVerified = false,
    this.faceVerified = false,
    this.livenessVerified = false,
    this.confidenceScore = 0.0,
    required this.markedAt,
    this.metadata,
  });

  /// Whether all verification factors passed.
  bool get isFullyVerified =>
      bluetoothVerified && geoVerified && faceVerified && livenessVerified;

  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'studentId': studentId,
      'classId': classId,
      'status': status,
      'bluetoothVerified': bluetoothVerified,
      'geoVerified': geoVerified,
      'faceVerified': faceVerified,
      'livenessVerified': livenessVerified,
      'confidenceScore': confidenceScore,
      'markedAt': Timestamp.fromDate(markedAt),
      'metadata': metadata,
    };
  }

  factory AttendanceRecord.fromMap(String id, Map<String, dynamic> map) {
    return AttendanceRecord(
      id: id,
      sessionId: map['sessionId'] ?? '',
      studentId: map['studentId'] ?? '',
      classId: map['classId'] ?? '',
      status: map['status'] ?? 'absent',
      bluetoothVerified: map['bluetoothVerified'] ?? false,
      geoVerified: map['geoVerified'] ?? false,
      faceVerified: map['faceVerified'] ?? false,
      livenessVerified: map['livenessVerified'] ?? false,
      confidenceScore: (map['confidenceScore'] ?? 0.0).toDouble(),
      markedAt: (map['markedAt'] as Timestamp).toDate(),
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }
}
