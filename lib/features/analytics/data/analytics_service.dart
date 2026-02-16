import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attendance_system/features/attendance/domain/attendance_record.dart';

/// Service for computing attendance analytics.
class AnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _attendanceRef =>
      _firestore.collection('attendance');

  CollectionReference<Map<String, dynamic>> get _sessionsRef =>
      _firestore.collection('sessions');

  // ─────────────────── STUDENT ANALYTICS ───────────────────

  /// Calculate attendance percentage for a student in a class.
  ///
  /// Returns a value 0.0 – 100.0.
  Future<double> getAttendancePercentage({
    required String studentId,
    required String classId,
  }) async {
    // Total sessions for this class
    final totalSessions = await _sessionsRef
        .where('classId', isEqualTo: classId)
        .get();

    if (totalSessions.docs.isEmpty) return 0.0;

    // Sessions this student attended
    final attended = await _attendanceRef
        .where('studentId', isEqualTo: studentId)
        .where('classId', isEqualTo: classId)
        .where('status', whereIn: ['present', 'late'])
        .get();

    return (attended.docs.length / totalSessions.docs.length) * 100.0;
  }

  /// Get a student's cross-class attendance summary.
  ///
  /// Returns a list of maps: `{ classId, className, percentage, attended, total }`.
  Future<List<Map<String, dynamic>>> getStudentReport(String studentId) async {
    // Get all classes the student is enrolled in
    final classesSnapshot = await _firestore
        .collection('classes')
        .where('studentIds', arrayContains: studentId)
        .get();

    final report = <Map<String, dynamic>>[];

    for (final classDoc in classesSnapshot.docs) {
      final classId = classDoc.id;
      final className = classDoc.data()['name'] ?? 'Unknown';

      final totalSessions = await _sessionsRef
          .where('classId', isEqualTo: classId)
          .get();

      final attended = await _attendanceRef
          .where('studentId', isEqualTo: studentId)
          .where('classId', isEqualTo: classId)
          .where('status', whereIn: ['present', 'late'])
          .get();

      final total = totalSessions.docs.length;
      final presentCount = attended.docs.length;
      final percentage = total > 0 ? (presentCount / total) * 100.0 : 0.0;

      report.add({
        'classId': classId,
        'className': className,
        'percentage': percentage,
        'attended': presentCount,
        'total': total,
      });
    }

    return report;
  }

  // ─────────────────── CLASS ANALYTICS ───────────────────

  /// Get analytics for a class: average attendance percentage across sessions.
  Future<Map<String, dynamic>> getClassAnalytics(String classId) async {
    final classDoc = await _firestore.collection('classes').doc(classId).get();
    if (!classDoc.exists) {
      return {'error': 'Class not found'};
    }

    final studentIds = List<String>.from(classDoc.data()?['studentIds'] ?? []);
    final totalStudents = studentIds.length;

    final sessions = await _sessionsRef
        .where('classId', isEqualTo: classId)
        .get();
    final totalSessions = sessions.docs.length;

    if (totalSessions == 0 || totalStudents == 0) {
      return {
        'classId': classId,
        'totalStudents': totalStudents,
        'totalSessions': totalSessions,
        'averageAttendance': 0.0,
      };
    }

    // For each session, count how many students attended
    int totalAttended = 0;
    for (final sessionDoc in sessions.docs) {
      final attendanceSnapshot = await _attendanceRef
          .where('sessionId', isEqualTo: sessionDoc.id)
          .where('status', whereIn: ['present', 'late'])
          .get();
      totalAttended += attendanceSnapshot.docs.length;
    }

    final avgAttendance =
        (totalAttended / (totalSessions * totalStudents)) * 100.0;

    return {
      'classId': classId,
      'totalStudents': totalStudents,
      'totalSessions': totalSessions,
      'averageAttendance': avgAttendance,
      'totalRecords': totalAttended,
    };
  }

  // ─────────────────── SECURITY / SUSPICIOUS ───────────────────

  /// Get attendance records with low confidence scores.
  ///
  /// Useful for identifying potential spoofing attempts.
  Future<List<AttendanceRecord>> getSuspiciousAttempts({
    required String classId,
    double threshold = 0.6,
    int limit = 20,
  }) async {
    final snapshot = await _attendanceRef
        .where('classId', isEqualTo: classId)
        .where('confidenceScore', isLessThan: threshold)
        .orderBy('confidenceScore', descending: false)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => AttendanceRecord.fromMap(doc.id, doc.data()))
        .toList();
  }

  /// Get students with repeatedly low confidence matches.
  ///
  /// Returns map of `studentId -> count` of low-confidence records.
  Future<Map<String, int>> getRepeatedLowConfidence({
    required String classId,
    double threshold = 0.6,
  }) async {
    final records = await getSuspiciousAttempts(
      classId: classId,
      threshold: threshold,
      limit: 100,
    );

    final counts = <String, int>{};
    for (final record in records) {
      counts[record.studentId] = (counts[record.studentId] ?? 0) + 1;
    }

    // Only return students with 2+ low-confidence attempts
    counts.removeWhere((_, value) => value < 2);
    return counts;
  }
}
