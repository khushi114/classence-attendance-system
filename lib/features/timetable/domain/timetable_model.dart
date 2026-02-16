class TimeSlot {
  final String startTime; // "HH:mm" 24-hour format
  final String endTime; // "HH:mm" 24-hour format
  final String subject;
  final String facultyId;
  final String? roomId;

  TimeSlot({
    required this.startTime,
    required this.endTime,
    required this.subject,
    required this.facultyId,
    this.roomId,
  });

  Map<String, dynamic> toMap() {
    return {
      'startTime': startTime,
      'endTime': endTime,
      'subject': subject,
      'facultyId': facultyId,
      'roomId': roomId,
    };
  }

  factory TimeSlot.fromMap(Map<String, dynamic> map) {
    return TimeSlot(
      startTime: map['startTime'] ?? '',
      endTime: map['endTime'] ?? '',
      subject: map['subject'] ?? '',
      facultyId: map['facultyId'] ?? '',
      roomId: map['roomId'],
    );
  }

  // Helper to check if current time is within this slot
  bool isNow() {
    final now = DateTime.now();
    final startParts = startTime.split(':').map(int.parse).toList();
    final endParts = endTime.split(':').map(int.parse).toList();

    final start = DateTime(
      now.year,
      now.month,
      now.day,
      startParts[0],
      startParts[1],
    );
    final end = DateTime(
      now.year,
      now.month,
      now.day,
      endParts[0],
      endParts[1],
    );

    return now.isAfter(start) && now.isBefore(end);
  }
}

class Timetable {
  final String id;
  final String classId;
  final Map<String, List<TimeSlot>> schedule; // "Mon" -> [Slots]

  Timetable({required this.id, required this.classId, required this.schedule});

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> scheduleMap = {};
    schedule.forEach((day, slots) {
      scheduleMap[day] = slots.map((s) => s.toMap()).toList();
    });

    return {'id': id, 'classId': classId, 'schedule': scheduleMap};
  }

  factory Timetable.fromMap(Map<String, dynamic> map) {
    final Map<String, List<TimeSlot>> schedule = {};
    if (map['schedule'] != null) {
      try {
        final scheduleMap = Map<String, dynamic>.from(map['schedule'] as Map);
        scheduleMap.forEach((day, slots) {
          if (slots is List) {
            schedule[day] = slots
                .map(
                  (s) => TimeSlot.fromMap(Map<String, dynamic>.from(s as Map)),
                )
                .toList();
          }
        });
      } catch (e) {
        print('Error parsing timetable schedule: $e');
      }
    }

    return Timetable(
      id: map['id'] ?? '',
      classId: map['classId'] ?? '',
      schedule: schedule,
    );
  }
}
