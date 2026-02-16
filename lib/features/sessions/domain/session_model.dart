import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents an attendance session created by faculty.
class SessionModel {
  final String id;
  final String classId;
  final String facultyId;
  final String sessionToken; // Secure UUID for verification
  final bool isActive;
  final DateTime startTime;
  final DateTime endTime;
  final int durationMinutes;
  final GeoPoint? location; // Classroom lat/lng
  final double radiusMeters; // Geofence radius
  final String? bluetoothBeaconId;

  SessionModel({
    required this.id,
    required this.classId,
    required this.facultyId,
    required this.sessionToken,
    this.isActive = true,
    required this.startTime,
    required this.endTime,
    this.durationMinutes = 30,
    this.location,
    this.radiusMeters = 50.0,
    this.bluetoothBeaconId,
  });

  /// Whether this session has passed its end time.
  bool get isExpired => DateTime.now().isAfter(endTime);

  /// Whether attendance can be marked right now.
  bool get isOpen => isActive && !isExpired;

  Map<String, dynamic> toMap() {
    return {
      'classId': classId,
      'facultyId': facultyId,
      'sessionToken': sessionToken,
      'isActive': isActive,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'durationMinutes': durationMinutes,
      'location': location,
      'radiusMeters': radiusMeters,
      'bluetoothBeaconId': bluetoothBeaconId,
    };
  }

  factory SessionModel.fromMap(String id, Map<String, dynamic> map) {
    return SessionModel(
      id: id,
      classId: map['classId'] ?? '',
      facultyId: map['facultyId'] ?? '',
      sessionToken: map['sessionToken'] ?? '',
      isActive: map['isActive'] ?? false,
      startTime: (map['startTime'] as Timestamp).toDate(),
      endTime: (map['endTime'] as Timestamp).toDate(),
      durationMinutes: map['durationMinutes'] ?? 30,
      location: map['location'] as GeoPoint?,
      radiusMeters: (map['radiusMeters'] ?? 50.0).toDouble(),
      bluetoothBeaconId: map['bluetoothBeaconId'] as String?,
    );
  }

  SessionModel copyWith({bool? isActive}) {
    return SessionModel(
      id: id,
      classId: classId,
      facultyId: facultyId,
      sessionToken: sessionToken,
      isActive: isActive ?? this.isActive,
      startTime: startTime,
      endTime: endTime,
      durationMinutes: durationMinutes,
      location: location,
      radiusMeters: radiusMeters,
      bluetoothBeaconId: bluetoothBeaconId,
    );
  }
}
