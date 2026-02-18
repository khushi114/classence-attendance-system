import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attendance_system/features/sessions/domain/session_model.dart';
import 'package:attendance_system/core/errors/attendance_exception.dart';
import 'package:attendance_system/core/services/beacon_advertising_service.dart';

/// Service for managing attendance sessions in Firestore.
class SessionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _sessionsRef =>
      _firestore.collection('sessions');

  // ─────────────────── CREATE ───────────────────

  /// Start a new attendance session.
  ///
  /// - Generates a secure random session token
  /// - Prevents multiple active sessions per class
  /// - Sets auto-expiry time based on [durationMinutes]
  Future<SessionModel> startSession({
    required String classId,
    required String facultyId,
    int durationMinutes = 30,
    GeoPoint? location,
    double radiusMeters = 50.0,
    String? bluetoothBeaconId,
  }) async {
    // Check for existing active session in this class
    final existing = await getActiveSession(classId);
    if (existing != null) {
      throw ActiveSessionExistsException();
    }

    final now = DateTime.now();
    final token = _generateSecureToken();

    // Generate beacon UUID
    final beaconService = BeaconAdvertisingService();
    String? beaconUuid = bluetoothBeaconId;

    // If no beacon ID provided, generate one
    if (beaconUuid == null || beaconUuid.isEmpty) {
      beaconUuid = beaconService.generateBeaconUuid(classId);
    }

    final docRef = _sessionsRef.doc();
    final session = SessionModel(
      id: docRef.id,
      classId: classId,
      facultyId: facultyId,
      sessionToken: token,
      isActive: true,
      startTime: now,
      endTime: now.add(Duration(minutes: durationMinutes)),
      durationMinutes: durationMinutes,
      location: location,
      radiusMeters: radiusMeters,
      bluetoothBeaconId: beaconUuid,
    );

    print('📝 Saving session with beacon UUID: $beaconUuid');
    await docRef.set(session.toMap());
    print('✅ Session ${session.id} saved to Firestore');
    return session;
  }

  // ─────────────────── READ ───────────────────

  /// Get the currently active session for a class, or null.
  Future<SessionModel?> getActiveSession(String classId) async {
    final snapshot = await _sessionsRef
        .where('classId', isEqualTo: classId)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final doc = snapshot.docs.first;
    final session = SessionModel.fromMap(doc.id, doc.data());

    // Auto-expire if past end time
    if (session.isExpired) {
      await endSession(session.id);
      return null;
    }

    return session;
  }

  /// Get all active sessions for a specific faculty member.
  Future<List<SessionModel>> getActiveSessionsForFaculty(
    String facultyId,
  ) async {
    final snapshot = await _sessionsRef
        .where('facultyId', isEqualTo: facultyId)
        .where('isActive', isEqualTo: true)
        .get();

    final sessions = <SessionModel>[];
    for (final doc in snapshot.docs) {
      final session = SessionModel.fromMap(doc.id, doc.data());
      if (session.isExpired) {
        // Fire and forget expire
        endSession(session.id);
      } else {
        sessions.add(session);
      }
    }
    return sessions;
  }

  /// Get a session by ID.
  Future<SessionModel?> getSession(String sessionId) async {
    final doc = await _sessionsRef.doc(sessionId).get();
    if (!doc.exists) return null;
    return SessionModel.fromMap(doc.id, doc.data()!);
  }

  /// Validate a session token and return the session if valid.
  Future<SessionModel> validateSessionToken(String token) async {
    final snapshot = await _sessionsRef
        .where('sessionToken', isEqualTo: token.toUpperCase())
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      throw InvalidSessionException('Invalid or expired session token.');
    }

    final session = SessionModel.fromMap(
      snapshot.docs.first.id,
      snapshot.docs.first.data(),
    );

    if (session.isExpired) {
      await endSession(session.id);
      throw SessionExpiredException(session.id);
    }

    return session;
  }

  /// Get session history for a class.
  Future<List<SessionModel>> getSessionHistory(
    String classId, {
    int limit = 20,
  }) async {
    final snapshot = await _sessionsRef
        .where('classId', isEqualTo: classId)
        .orderBy('startTime', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => SessionModel.fromMap(doc.id, doc.data()))
        .toList();
  }

  // ─────────────────── UPDATE ───────────────────

  /// End an active session.
  Future<void> endSession(String sessionId) async {
    await _sessionsRef.doc(sessionId).update({'isActive': false});
  }

  /// Auto-expire all sessions that have passed their end time.
  Future<int> autoExpireSessions() async {
    final now = Timestamp.fromDate(DateTime.now());

    final snapshot = await _sessionsRef
        .where('isActive', isEqualTo: true)
        .where('endTime', isLessThanOrEqualTo: now)
        .get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'isActive': false});
    }
    await batch.commit();

    return snapshot.docs.length;
  }

  // ─────────────────── HELPERS ───────────────────

  /// Generate a cryptographically random 6-character alphanumeric token.
  String _generateSecureToken() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }
}
