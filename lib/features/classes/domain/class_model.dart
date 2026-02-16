import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a class/course in the attendance system.
class ClassModel {
  final String id;
  final String name;
  final String code;
  final String facultyId;
  final String department;
  final List<String> studentIds;
  final String schedule; // e.g. "Mon/Wed/Fri 10:00-11:00"
  final DateTime createdAt;

  ClassModel({
    required this.id,
    required this.name,
    required this.code,
    required this.facultyId,
    required this.department,
    this.studentIds = const [],
    this.schedule = '',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'code': code,
      'facultyId': facultyId,
      'department': department,
      'studentIds': studentIds,
      'schedule': schedule,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory ClassModel.fromMap(String id, Map<String, dynamic> map) {
    return ClassModel(
      id: id,
      name: map['name'] ?? '',
      code: map['code'] ?? '',
      facultyId: map['facultyId'] ?? '',
      department: map['department'] ?? '',
      studentIds: List<String>.from(map['studentIds'] ?? []),
      schedule: map['schedule'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  ClassModel copyWith({
    String? name,
    String? code,
    String? department,
    List<String>? studentIds,
    String? schedule,
  }) {
    return ClassModel(
      id: id,
      name: name ?? this.name,
      code: code ?? this.code,
      facultyId: facultyId,
      department: department ?? this.department,
      studentIds: studentIds ?? this.studentIds,
      schedule: schedule ?? this.schedule,
      createdAt: createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ClassModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
