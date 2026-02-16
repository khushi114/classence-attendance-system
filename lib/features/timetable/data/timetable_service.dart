import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attendance_system/features/timetable/domain/timetable_model.dart';
import 'package:attendance_system/features/classes/domain/class_model.dart';

class TimetableService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection Reference
  CollectionReference get _timetableCollection =>
      _firestore.collection('timetables');
  CollectionReference get _classesCollection =>
      _firestore.collection('classes');

  // Save or Update Timetable
  Future<void> saveTimetable(Timetable timetable) async {
    try {
      print('::: WRITING TIMETABLE DOC :::');
      await _timetableCollection.doc(timetable.classId).set(timetable.toMap());
      print('::: TIMETABLE WRITE SUCCESS :::');

      // Sync summary to class document (for easy viewing in DB/UI)
      final summary = _generateScheduleSummary(timetable);
      print('::: UPDATING CLASS SUMMARY: $summary :::');
      await _classesCollection.doc(timetable.classId).update({
        'schedule': summary,
      });
      print('::: CLASS UPDATE SUCCESS :::');
    } catch (e) {
      print('::: FATAL ERROR SAVING TIMETABLE: $e :::');
      rethrow;
    }
  }

  String _generateScheduleSummary(Timetable timetable) {
    if (timetable.schedule.isEmpty) return 'No Schedule';
    final days = timetable.schedule.keys.toList()
      ..sort((a, b) => _dayToInt(a).compareTo(_dayToInt(b)));
    return days.join(', ');
  }

  int _dayToInt(String day) {
    switch (day) {
      case 'Mon':
        return 1;
      case 'Tue':
        return 2;
      case 'Wed':
        return 3;
      case 'Thu':
        return 4;
      case 'Fri':
        return 5;
      case 'Sat':
        return 6;
      case 'Sun':
        return 7;
      default:
        return 8;
    }
  }

  // Get Timetable for a Class
  Future<Timetable?> getTimetable(String classId) async {
    try {
      final doc = await _timetableCollection.doc(classId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        print('Raw Timetable Data for $classId: $data');
        return Timetable.fromMap(data);
      }
      return null;
    } catch (e) {
      print('Error getting timetable: $e');
      rethrow; // Let the UI handle/show the error
    }
  }

  // Get Daily Schedule for Faculty
  Future<List<Map<String, dynamic>>> getDailyScheduleForFaculty(
    String facultyId,
    String dayOfWeek, // "Mon", "Tue", etc.
  ) async {
    try {
      // This query might be expensive if many timetables.
      // Ideally, we'd query by facultyId, but the structure is by ClassId.
      // For now, we fetch all timetables (assuming < 100 classes) or filter on client.
      // Optimization: Add 'facultyIds' array field to Timetable document for querying.

      // Let's iterate through classes the faculty teaches
      final classesSnapshot = await _classesCollection
          .where('facultyId', isEqualTo: facultyId)
          .get();

      List<Map<String, dynamic>> dailySlots = [];

      for (var classDoc in classesSnapshot.docs) {
        final classData = ClassModel.fromMap(
          classDoc.id,
          classDoc.data() as Map<String, dynamic>,
        );
        final timetable = await getTimetable(classData.id);

        if (timetable != null && timetable.schedule.containsKey(dayOfWeek)) {
          final slots = timetable.schedule[dayOfWeek]!;
          for (var slot in slots) {
            if (slot.facultyId == facultyId) {
              dailySlots.add({'slot': slot, 'class': classData});
            }
          }
        }
      }

      // Sort by start time
      dailySlots.sort((a, b) {
        final slotA = a['slot'] as TimeSlot;
        final slotB = b['slot'] as TimeSlot;
        return slotA.startTime.compareTo(slotB.startTime);
      });

      return dailySlots;
    } catch (e) {
      print('Error getting daily schedule: $e');
      return [];
    }
  }

  // Get Daily Schedule for Student
  Future<List<Map<String, dynamic>>> getDailyScheduleForStudent(
    String studentId,
    String dayOfWeek, // "Mon", "Tue", etc.
  ) async {
    try {
      // Find classes where student is enrolled
      final classesSnapshot = await _classesCollection
          .where('studentIds', arrayContains: studentId)
          .get();

      List<Map<String, dynamic>> dailySlots = [];

      for (var classDoc in classesSnapshot.docs) {
        final classData = ClassModel.fromMap(
          classDoc.id,
          classDoc.data() as Map<String, dynamic>,
        );
        final timetable = await getTimetable(classData.id);

        if (timetable != null && timetable.schedule.containsKey(dayOfWeek)) {
          final slots = timetable.schedule[dayOfWeek]!;
          for (var slot in slots) {
            dailySlots.add({'slot': slot, 'class': classData});
          }
        }
      }

      // Sort by start time
      dailySlots.sort((a, b) {
        final slotA = a['slot'] as TimeSlot;
        final slotB = b['slot'] as TimeSlot;
        return slotA.startTime.compareTo(slotB.startTime);
      });

      return dailySlots;
    } catch (e) {
      print('Error getting student schedule: $e');
      return [];
    }
  }
}
