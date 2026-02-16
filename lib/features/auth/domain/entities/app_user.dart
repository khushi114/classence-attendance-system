import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String id;
  final String email;
  final String name;
  final String role; // 'student', 'faculty', or 'admin'
  final bool isVerified;
  final List<double>? faceEmbedding;
  final DateTime createdAt;

  AppUser({
    required this.id,
    required this.email,
    required this.name,
    this.role = 'student',
    this.isVerified = false,
    this.faceEmbedding,
    required this.createdAt,
  });

  /// Whether this user is a student.
  bool get isStudent => role == 'student';

  /// Whether this user is a faculty member.
  bool get isFaculty => role == 'faculty';

  /// Whether this user is an admin.
  bool get isAdmin => role == 'admin';

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role,
      'isVerified': isVerified,
      'faceEmbedding': faceEmbedding,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Create from Firestore document
  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      role: map['role'] ?? 'student',
      isVerified: map['isVerified'] ?? false,
      faceEmbedding: map['faceEmbedding'] != null
          ? List<double>.from(map['faceEmbedding'])
          : null,
      createdAt: _parseDateTime(map['createdAt']),
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    } else if (value is String) {
      return DateTime.parse(value);
    }
    return DateTime.now(); // Fallback
  }
}
