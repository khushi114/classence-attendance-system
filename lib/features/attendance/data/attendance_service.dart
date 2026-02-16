import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attendance_system/features/attendance/domain/attendance_record.dart';
import 'package:attendance_system/features/sessions/data/session_service.dart';
import 'package:attendance_system/core/errors/attendance_exception.dart';

/// Service to handle attendance operations with full multi-factor validation.
class AttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SessionService _sessionService = SessionService();

  CollectionReference<Map<String, dynamic>> get _attendanceRef =>
      _firestore.collection('attendance');

  // ─────────────────── MARK ATTENDANCE ───────────────────

  /// Mark attendance for a student in an active session.
  ///
  /// Validates ALL conditions before writing:
  /// 1. Session is active and not expired
  /// 2. Student is enrolled in the class
  /// 3. Student hasn't already marked attendance for this session
  /// 4. All verification factors passed
  Future<AttendanceRecord> markAttendance({
    required String sessionId,
    required String studentId,
    required String classId,
    required bool bluetoothVerified,
    required bool geoVerified,
    required bool faceVerified,
    required bool livenessVerified,
    required double confidenceScore,
    Map<String, dynamic>? metadata,
  }) async {
    // 1. Validate session is active
    final session = await _sessionService.getSession(sessionId);
    if (session == null) {
      throw InvalidSessionException();
    }
    if (!session.isActive) {
      throw InvalidSessionException('Session is no longer active.');
    }
    if (session.isExpired) {
      await _sessionService.endSession(sessionId);
      throw SessionExpiredException(sessionId);
    }

    // 2. Check student is enrolled
    final classDoc = await _firestore.collection('classes').doc(classId).get();
    if (!classDoc.exists) {
      throw InvalidSessionException('Class not found.');
    }
    final studentIds = List<String>.from(classDoc.data()?['studentIds'] ?? []);
    if (!studentIds.contains(studentId)) {
      throw NotEnrolledException();
    }

    // 3. Prevent duplicate attendance
    final existingAttendance = await _attendanceRef
        .where('sessionId', isEqualTo: sessionId)
        .where('studentId', isEqualTo: studentId)
        .limit(1)
        .get();
    if (existingAttendance.docs.isNotEmpty) {
      throw DuplicateAttendanceException();
    }

    // 4. Validate all verification factors
    final failedSteps = <String>[];
    if (!bluetoothVerified) failedSteps.add('Bluetooth');
    if (!geoVerified) failedSteps.add('Geolocation');
    if (!faceVerified) failedSteps.add('Face Recognition');
    if (!livenessVerified) failedSteps.add('Liveness Detection');
    if (failedSteps.isNotEmpty) {
      throw VerificationFailedException(failedSteps);
    }

    // 5. Determine status (late if > halfway through session)
    final now = DateTime.now();
    final halfwayTime = session.startTime.add(
      Duration(minutes: session.durationMinutes ~/ 2),
    );
    final status = now.isAfter(halfwayTime) ? 'late' : 'present';

    // 6. Write the record
    final docRef = _attendanceRef.doc();
    final record = AttendanceRecord(
      id: docRef.id,
      sessionId: sessionId,
      studentId: studentId,
      classId: classId,
      status: status,
      bluetoothVerified: bluetoothVerified,
      geoVerified: geoVerified,
      faceVerified: faceVerified,
      livenessVerified: livenessVerified,
      confidenceScore: confidenceScore,
      markedAt: now,
      metadata: metadata,
    );

    await docRef.set(record.toMap());
    return record;
  }

  // ─────────────────── QUERIES ───────────────────

  /// Get all attendance records for a session (faculty view).
  Future<List<AttendanceRecord>> getSessionAttendance(String sessionId) async {
    final snapshot = await _attendanceRef
        .where('sessionId', isEqualTo: sessionId)
        .orderBy('markedAt', descending: false)
        .get();

    return snapshot.docs
        .map((doc) => AttendanceRecord.fromMap(doc.id, doc.data()))
        .toList();
  }

  /// Get a student's attendance history for a specific class.
  Future<List<AttendanceRecord>> getStudentAttendance({
    required String studentId,
    required String classId,
    int limit = 50,
  }) async {
    final snapshot = await _attendanceRef
        .where('studentId', isEqualTo: studentId)
        .where('classId', isEqualTo: classId)
        .orderBy('markedAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => AttendanceRecord.fromMap(doc.id, doc.data()))
        .toList();
  }

  /// Check if a student has already marked attendance for a session.
  Future<bool> hasMarkedAttendance({
    required String studentId,
    required String sessionId,
  }) async {
    final snapshot = await _attendanceRef
        .where('sessionId', isEqualTo: sessionId)
        .where('studentId', isEqualTo: studentId)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  /// Get today's attendance for a user (legacy compat).
  Future<AttendanceRecord?> getTodayAttendance(String userId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snapshot = await _attendanceRef
        .where('studentId', isEqualTo: userId)
        .where(
          'markedAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .where('markedAt', isLessThan: Timestamp.fromDate(endOfDay))
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return AttendanceRecord.fromMap(
      snapshot.docs.first.id,
      snapshot.docs.first.data(),
    );
  }

  /// Get monthly attendance count for a student.
  Future<int> getMonthlyAttendanceCount(String studentId) async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 1);

    final snapshot = await _attendanceRef
        .where('studentId', isEqualTo: studentId)
        .where(
          'markedAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth),
        )
        .where('markedAt', isLessThan: Timestamp.fromDate(endOfMonth))
        .get();

    return snapshot.docs.length;
  }

  /// Get weekly attendance count for a student.
  Future<int> getWeeklyAttendanceCount(String studentId) async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeekDay = DateTime(
      startOfWeek.year,
      startOfWeek.month,
      startOfWeek.day,
    );

    final snapshot = await _attendanceRef
        .where('studentId', isEqualTo: studentId)
        .where(
          'markedAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeekDay),
        )
        .get();

    return snapshot.docs.length;
  }
}
