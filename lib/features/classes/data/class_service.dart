import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attendance_system/features/classes/domain/class_model.dart';
import 'package:attendance_system/core/errors/attendance_exception.dart';

/// Service for managing classes/courses in Firestore.
class ClassService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _classesRef =>
      _firestore.collection('classes');

  // ─────────────────── CREATE ───────────────────

  /// Create a new class. Only faculty or admin should call this.
  Future<ClassModel> createClass({
    required String name,
    required String code,
    required String facultyId,
    required String department,
    String schedule = '',
    required String callerRole,
  }) async {
    if (callerRole != 'faculty' && callerRole != 'admin') {
      throw UnauthorizedRoleException('faculty');
    }

    final docRef = _classesRef.doc();
    final classModel = ClassModel(
      id: docRef.id,
      name: name,
      code: code,
      facultyId: facultyId,
      department: department,
      schedule: schedule,
      createdAt: DateTime.now(),
    );

    await docRef.set(classModel.toMap());
    return classModel;
  }

  // ─────────────────── READ ───────────────────

  /// Get all classes assigned to a faculty member.
  Future<List<ClassModel>> getClassesForFaculty(String facultyId) async {
    final snapshot = await _classesRef
        .where('facultyId', isEqualTo: facultyId)
        // .orderBy('createdAt', descending: true) // TODO: Restore index
        .get();

    return snapshot.docs
        .map((doc) => ClassModel.fromMap(doc.id, doc.data()))
        .toList();
  }

  /// Get all classes a student is enrolled in.
  Future<List<ClassModel>> getClassesForStudent(String studentId) async {
    final snapshot = await _classesRef
        .where('studentIds', arrayContains: studentId)
        // .orderBy('createdAt', descending: true) // TODO: Restore index
        .get();

    return snapshot.docs
        .map((doc) => ClassModel.fromMap(doc.id, doc.data()))
        .toList();
  }

  /// Get a single class by ID.
  Future<ClassModel?> getClass(String classId) async {
    final doc = await _classesRef.doc(classId).get();
    if (!doc.exists) return null;
    return ClassModel.fromMap(doc.id, doc.data()!);
  }

  /// Get all classes (admin).
  Future<List<ClassModel>> getAllClasses() async {
    final snapshot = await _classesRef
        // .orderBy('createdAt', descending: true) // TODO: Restore index
        .get();
    return snapshot.docs
        .map((doc) => ClassModel.fromMap(doc.id, doc.data()))
        .toList();
  }

  // ─────────────────── UPDATE ───────────────────

  /// Enroll a student in a class. Faculty/admin only.
  Future<void> enrollStudent({
    required String classId,
    required String studentId,
    required String callerRole,
  }) async {
    if (callerRole != 'faculty' && callerRole != 'admin') {
      throw UnauthorizedRoleException('faculty');
    }

    await _classesRef.doc(classId).update({
      'studentIds': FieldValue.arrayUnion([studentId]),
    });
  }

  /// Remove a student from a class.
  Future<void> removeStudent({
    required String classId,
    required String studentId,
    required String callerRole,
  }) async {
    if (callerRole != 'faculty' && callerRole != 'admin') {
      throw UnauthorizedRoleException('faculty');
    }

    await _classesRef.doc(classId).update({
      'studentIds': FieldValue.arrayRemove([studentId]),
    });
  }

  /// Update class details.
  Future<void> updateClass({
    required String classId,
    String? name,
    String? schedule,
    String? department,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (schedule != null) updates['schedule'] = schedule;
    if (department != null) updates['department'] = department;
    if (updates.isNotEmpty) {
      await _classesRef.doc(classId).update(updates);
    }
  }

  // ─────────────────── DELETE ───────────────────

  /// Delete a class. Admin only.
  Future<void> deleteClass({
    required String classId,
    required String callerRole,
  }) async {
    if (callerRole != 'admin') {
      throw UnauthorizedRoleException('admin');
    }
    await _classesRef.doc(classId).delete();
  }
}
