import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attendance_system/core/theme/app_colors.dart';
import 'package:attendance_system/features/timetable/domain/timetable_model.dart';
import 'package:attendance_system/features/timetable/data/timetable_service.dart';
import 'package:attendance_system/features/classes/domain/class_model.dart';
import 'package:attendance_system/features/classes/data/class_service.dart';

class TimetableEditorScreen extends StatefulWidget {
  const TimetableEditorScreen({super.key});

  @override
  State<TimetableEditorScreen> createState() => _TimetableEditorScreenState();
}

class _TimetableEditorScreenState extends State<TimetableEditorScreen> {
  final TimetableService _timetableService = TimetableService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ClassModel? _selectedClass;
  Timetable? _currentTimetable;
  bool _isLoading = false;

  final List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  String _selectedDay = 'Mon';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Timetable'),
        backgroundColor: AppColors.royalBlue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 1. Class Selector
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('classes').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();

                final classes = snapshot.data!.docs
                    .map(
                      (d) => ClassModel.fromMap(
                        d.id,
                        d.data() as Map<String, dynamic>,
                      ),
                    )
                    .toList();

                // Validation: ensure selected class still exists
                if (_selectedClass != null &&
                    !classes.any((c) => c.id == _selectedClass!.id)) {
                  _selectedClass = null;
                }

                return DropdownButtonFormField<String>(
                  value: _selectedClass?.id,
                  decoration: const InputDecoration(
                    labelText: 'Select Class',
                    border: OutlineInputBorder(),
                  ),
                  items: classes.map((c) {
                    return DropdownMenuItem(value: c.id, child: Text(c.name));
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      if (val != null) {
                        _selectedClass = classes.firstWhere((c) => c.id == val);
                      } else {
                        _selectedClass = null;
                      }
                      _currentTimetable = null;
                    });
                    if (val != null) _loadTimetable(val);
                  },
                );
              },
            ),
          ),

          if (_isLoading) const LinearProgressIndicator(),

          if (_selectedClass != null && !_isLoading) ...[
            // 2. Day Selector
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: _days.map((day) {
                  final isSelected = day == _selectedDay;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(day),
                      selected: isSelected,
                      selectedColor: AppColors.royalBlue,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black,
                      ),
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedDay = day);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

            const Divider(),

            // 3. Slots List
            Expanded(child: _buildSlotsList()),
          ],
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'create_class',
            onPressed: _showCreateClassDialog,
            label: const Text('Create Class'),
            icon: const Icon(Icons.class_),
            backgroundColor: AppColors.emerald,
          ),
          const SizedBox(height: 16),
          if (_selectedClass != null)
            FloatingActionButton.extended(
              heroTag: 'add_slot',
              onPressed: _addSlotDialog,
              label: const Text('Add Slot'),
              icon: const Icon(Icons.add),
              backgroundColor: AppColors.royalBlue,
            ),
        ],
      ),
    );
  }

  Future<void> _showCreateClassDialog() async {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final deptController = TextEditingController();
    String? selectedFacultyId;
    bool isLoading = false;

    // Fetch faculty list
    final facultySnapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'faculty')
        .get();

    final facultyList = facultySnapshot.docs.map((doc) {
      return {
        'id': doc.id,
        'name': doc['name'] as String,
        'email': doc['email'] as String,
      };
    }).toList();

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            scrollable: true,
            title: const Text('Create New Class'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Class Name (e.g., Intro to CS)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(
                    labelText: 'Course Code (e.g., CS101)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: deptController,
                  decoration: const InputDecoration(
                    labelText: 'Department (e.g., Computer Science)',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedFacultyId,
                  decoration: const InputDecoration(
                    labelText: 'Assign Faculty',
                    border: OutlineInputBorder(),
                  ),
                  items: facultyList.map((f) {
                    return DropdownMenuItem(
                      value: f['id'],
                      child: SizedBox(
                        width:
                            200, // Constrain width to prevent dialog expansion
                        child: Text(
                          '${f['name']} (${f['email']})',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => selectedFacultyId = val),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        if (nameController.text.isEmpty ||
                            codeController.text.isEmpty ||
                            selectedFacultyId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please fill all fields'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                          return;
                        }

                        setState(() => isLoading = true);

                        try {
                          await ClassService().createClass(
                            name: nameController.text.trim(),
                            code: codeController.text.trim(),
                            facultyId: selectedFacultyId!,
                            department: deptController.text.trim(),
                            callerRole: 'admin',
                          );
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Class Created Successfully!'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                            setState(() => isLoading = false);
                          }
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSlotsList() {
    final slots = _currentTimetable?.schedule[_selectedDay] ?? [];

    if (slots.isEmpty) {
      return const Center(child: Text('No slots for this day. Add one!'));
    }

    return ListView.builder(
      itemCount: slots.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final slot = slots[index];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.access_time, color: AppColors.royalBlue),
            title: Text('${slot.startTime} - ${slot.endTime}'),
            subtitle: Text('${slot.subject} (Faculty ID: ${slot.facultyId})'),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _removeSlot(index),
            ),
          ),
        );
      },
    );
  }

  Future<void> _loadTimetable(String classId) async {
    setState(() => _isLoading = true);
    try {
      final t = await _timetableService.getTimetable(classId);
      setState(() {
        _currentTimetable =
            t ??
            Timetable(
              id: classId, // Using classId as document ID for simplicity
              classId: classId,
              schedule: <String, List<TimeSlot>>{},
            );
      });
    } catch (e) {
      print('Error loading timetable: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading timetable: $e')));
      // Initialize empty timetable on error to prevent null pointer exceptions
      setState(() {
        _currentTimetable = Timetable(
          id: classId,
          classId: classId,
          schedule: <String, List<TimeSlot>>{},
        );
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveTimetable() async {
    if (_currentTimetable == null) return;
    try {
      await _timetableService.saveTimetable(_currentTimetable!);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  Future<void> _addSlotDialog() async {
    final subjectController = TextEditingController();
    final facultyController = TextEditingController();
    TimeOfDay? startTime;
    TimeOfDay? endTime;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            scrollable: true,
            title: Text('Add Slot to $_selectedDay'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(
                    startTime == null
                        ? 'Select Start Time'
                        : 'Start: ${startTime!.format(context)}',
                  ),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: const TimeOfDay(hour: 9, minute: 0),
                    );
                    if (t != null) setDialogState(() => startTime = t);
                  },
                ),
                ListTile(
                  title: Text(
                    endTime == null
                        ? 'Select End Time'
                        : 'End: ${endTime!.format(context)}',
                  ),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: const TimeOfDay(hour: 10, minute: 0),
                    );
                    if (t != null) setDialogState(() => endTime = t);
                  },
                ),
                TextField(
                  controller: subjectController,
                  decoration: const InputDecoration(labelText: 'Subject'),
                ),
                TextField(
                  controller: facultyController,
                  decoration: const InputDecoration(labelText: 'Faculty ID'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (startTime == null ||
                      endTime == null ||
                      subjectController.text.isEmpty ||
                      facultyController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please fill all fields')),
                    );
                    return;
                  }

                  // Convert to HH:mm for storage
                  final startString =
                      '${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}';
                  final endString =
                      '${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}';

                  final newSlot = TimeSlot(
                    startTime: startString,
                    endTime: endString,
                    subject: subjectController.text,
                    facultyId: facultyController.text,
                  );

                  setState(() {
                    if (_currentTimetable!.schedule[_selectedDay] == null) {
                      _currentTimetable!.schedule[_selectedDay] = <TimeSlot>[];
                    }
                    _currentTimetable!.schedule[_selectedDay]!.add(newSlot);
                  });

                  try {
                    await _saveTimetable();
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Slot added to database!'),
                        ),
                      );
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      showDialog(
                        context: ctx,
                        builder: (c) => AlertDialog(
                          title: const Text('Save Failed'),
                          content: SingleChildScrollView(
                            child: Text('Detailed Error:\n$e'),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                    }
                  }
                },
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _removeSlot(int index) {
    setState(() {
      _currentTimetable!.schedule[_selectedDay]!.removeAt(index);
    });
    _saveTimetable();
  }
}
