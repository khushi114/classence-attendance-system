import 'package:flutter/material.dart';
import 'package:attendance_system/core/theme/app_colors.dart';
import 'package:attendance_system/widgets/custom_button.dart';
import 'package:attendance_system/features/classes/data/class_service.dart';
import 'package:attendance_system/features/classes/domain/class_model.dart';
import 'package:attendance_system/features/sessions/data/session_service.dart';
import 'package:attendance_system/features/auth/data/firebase_auth_service.dart';

class StartSessionSheet extends StatefulWidget {
  final ClassModel? preSelectedClass;
  const StartSessionSheet({super.key, this.preSelectedClass});

  @override
  State<StartSessionSheet> createState() => _StartSessionSheetState();
}

class _StartSessionSheetState extends State<StartSessionSheet> {
  final _classService = ClassService();
  final _sessionService = SessionService();
  final _authService = FirebaseAuthService();

  List<ClassModel> _classes = [];
  String? _selectedClassId;
  bool _isLoading = true;
  double _durationMinutes = 45;
  bool _useGeoFence = false;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    final user = _authService.currentUser;
    if (user != null) {
      try {
        final classes = await _classService.getClassesForFaculty(user.uid);
        if (mounted) {
          setState(() {
            _classes = classes;
            _isLoading = false;
            // Auto-select pre-selected class or first available
            if (widget.preSelectedClass != null) {
              _selectedClassId = widget.preSelectedClass!.id;
            } else if (classes.isNotEmpty) {
              _selectedClassId = classes.first.id;
            }
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          // Handle error (e.g. permission denied if rules not propagated yet)
        }
      }
    }
  }

  Future<void> _startSession() async {
    if (_selectedClassId == null) return;
    final user = _authService.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final session = await _sessionService.startSession(
        classId: _selectedClassId!,
        facultyId: user.uid,
        durationMinutes: _durationMinutes.round(),
        radiusMeters: _useGeoFence ? 50.0 : 0.0,
      );

      if (mounted) {
        Navigator.pop(context, session);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: ${e.toString().replaceAll("Exception: ", "")}',
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Title
          const Text(
            'Start New Session',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),

          if (_isLoading && _classes.isEmpty)
            const Center(child: CircularProgressIndicator())
          else if (_classes.isEmpty)
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.class_outlined,
                    size: 48,
                    color: AppColors.textLight,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No classes found',
                    style: TextStyle(color: AppColors.textLight),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create a class first to start a session',
                    style: TextStyle(fontSize: 12, color: AppColors.textLight),
                  ),
                ],
              ),
            )
          else ...[
            // Class Selector
            const Text(
              'Select Class',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedClassId,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  items: _classes.map((c) {
                    return DropdownMenuItem(
                      value: c.id,
                      child: Text(
                        '${c.name} (${c.code})',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() => _selectedClassId = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Duration Slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Duration',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  '${_durationMinutes.round()} min',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.royalBlue,
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.royalBlue,
                inactiveTrackColor: AppColors.border,
                thumbColor: AppColors.royalBlue,
                overlayColor: AppColors.royalBlue.withValues(alpha: 0.1),
              ),
              child: Slider(
                value: _durationMinutes,
                min: 15,
                max: 180,
                divisions: 11,
                label: '${_durationMinutes.round()} min',
                onChanged: (val) => setState(() => _durationMinutes = val),
              ),
            ),

            // Options
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Enforce Geofence',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle: Text(
                'Students must be within 50m',
                style: TextStyle(fontSize: 12, color: AppColors.textLight),
              ),
              value: _useGeoFence,
              activeColor: AppColors.royalBlue,
              onChanged: (val) => setState(() => _useGeoFence = val),
            ),
            const SizedBox(height: 24),

            // Start Button
            CustomButton(
              text: 'Start Session',
              onPressed: _isLoading ? null : _startSession,
              isLoading: _isLoading,
              gradient: const LinearGradient(
                colors: [Color(0xFF059669), Color(0xFF047857)],
              ),
            ),
          ],
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}
