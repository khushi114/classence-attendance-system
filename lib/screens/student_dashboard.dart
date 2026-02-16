import 'package:flutter/material.dart';
import 'package:attendance_system/core/theme/app_colors.dart';
import 'package:attendance_system/widgets/dashboard_card.dart';
import 'package:attendance_system/widgets/custom_button.dart';
import 'package:attendance_system/features/auth/data/firebase_auth_service.dart';
import 'package:attendance_system/features/auth/presentation/login_screen.dart';
import 'package:attendance_system/screens/attendance_screen.dart';
import 'package:attendance_system/features/attendance/data/attendance_service.dart';
import 'package:attendance_system/features/attendance/domain/attendance_record.dart'; // For type safety

import 'package:attendance_system/features/timetable/data/timetable_service.dart';
import 'package:attendance_system/features/classes/domain/class_model.dart';
import 'package:attendance_system/features/timetable/domain/timetable_model.dart';
import 'package:intl/intl.dart';

/// Student dashboard with Mark Attendance, percentage card, and history.
class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  final _authService = FirebaseAuthService();
  final _attendanceService = AttendanceService();
  final _timetableService = TimetableService();

  String _userName = 'Student';
  bool _isLoading = true;

  // Stats
  int _weeklyAttendance = 0;
  int _monthlyAttendance = 0;
  AttendanceRecord? _todayAttendance;

  // Schedule
  List<Map<String, dynamic>> _todaySchedule = [];
  bool _isLoadingSchedule = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadTodaySchedule();
  }

  Future<void> _loadTodaySchedule() async {
    final user = _authService.currentUser;
    if (user == null) return;

    final today = DateFormat('E').format(DateTime.now());

    try {
      final schedule = await _timetableService.getDailyScheduleForStudent(
        user.uid,
        today,
      );
      if (mounted) {
        setState(() {
          _todaySchedule = schedule;
          _isLoadingSchedule = false;
        });
      }
    } catch (e) {
      print('Error loading schedule: $e');
      if (mounted) setState(() => _isLoadingSchedule = false);
    }
  }

  Future<void> _loadData() async {
    final user = _authService.currentUser;
    if (user != null && mounted) {
      try {
        // 1. User Data
        final userData = await _authService.getUserData(user.uid);

        // 2. Attendance Stats
        final weekly = await _attendanceService.getWeeklyAttendanceCount(
          user.uid,
        );
        final monthly = await _attendanceService.getMonthlyAttendanceCount(
          user.uid,
        );
        final today = await _attendanceService.getTodayAttendance(user.uid);

        if (mounted) {
          setState(() {
            _userName =
                userData?.name ??
                user.displayName ??
                user.email?.split('@')[0] ??
                'Student';
            _weeklyAttendance = weekly;
            _monthlyAttendance = monthly;
            _todayAttendance = today;
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Logout',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _navigateToAttendance() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AttendanceScreen()),
    );
    // Refresh stats when returning
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // Gradient header
                SliverToBoxAdapter(
                  child: Container(
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 16,
                      left: 24,
                      right: 24,
                      bottom: 28,
                    ),
                    decoration: const BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(28),
                        bottomRight: Radius.circular(28),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top bar
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome back,',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _userName,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            GestureDetector(
                              onTap: _handleLogout,
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.logout_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Role badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.emerald.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.school_rounded,
                                color: AppColors.emeraldLight,
                                size: 16,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'STUDENT',
                                style: TextStyle(
                                  color: AppColors.emeraldLight,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Main content
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Today's Schedule Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Today's Schedule",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            DateFormat('EEE, MMM d').format(DateTime.now()),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      if (_isLoadingSchedule)
                        const Center(child: CircularProgressIndicator())
                      else if (_todaySchedule.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.borderColor),
                          ),
                          child: const Center(
                            child: Text(
                              'No classes scheduled for today.',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                        )
                      else
                        ..._todaySchedule.map((item) {
                          final slot = item['slot'] as TimeSlot;
                          final classModel = item['class'] as ClassModel;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.royalBlue.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        slot.startTime,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.royalBlue,
                                        ),
                                      ),
                                      const Text(
                                        'to',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      Text(
                                        slot.endTime,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.royalBlue,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        classModel.name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${classModel.code} • ${slot.subject}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),

                      const SizedBox(height: 24),

                      // Mark Attendance Button
                      CustomButton(
                        text: 'Mark Attendance',
                        onPressed: _navigateToAttendance,
                        icon: Icons.fingerprint,
                        height: 64,
                        gradient: AppColors.emeraldGradient,
                      ),
                      const SizedBox(height: 24),

                      // Stats section title
                      const Text(
                        'Attendance Overview',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Attendance percentage card
                      _buildPercentageCard(),
                      const SizedBox(height: 16),

                      // Stats grid
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.25,
                        children: [
                          DashboardCard(
                            title: 'Today',
                            value: _todayAttendance != null
                                ? 'Present'
                                : 'Not Marked',
                            icon: Icons.today_outlined,
                            iconColor: _todayAttendance != null
                                ? AppColors.emerald
                                : AppColors.orange,
                            iconBgColor:
                                (_todayAttendance != null
                                        ? AppColors.emerald
                                        : AppColors.orange)
                                    .withValues(alpha: 0.12),
                            animationDelay: 100,
                          ),
                          DashboardCard(
                            title: 'This Week',
                            value: '$_weeklyAttendance Days',
                            icon: Icons.date_range_outlined,
                            iconColor: AppColors.emerald,
                            iconBgColor: AppColors.emerald.withValues(
                              alpha: 0.12,
                            ),
                            animationDelay: 200,
                          ),
                          DashboardCard(
                            title: 'This Month',
                            value: '$_monthlyAttendance Days',
                            icon: Icons.calendar_month_outlined,
                            iconColor: AppColors.royalBlue,
                            iconBgColor: AppColors.royalBlue.withValues(
                              alpha: 0.12,
                            ),
                            animationDelay: 300,
                          ),
                          // DashboardCard(
                          //   title: 'Total',
                          //   value: '0 Days',
                          //   icon: Icons.analytics_outlined,
                          //   iconColor: const Color(0xFF8B5CF6),
                          //   iconBgColor: const Color(
                          //     0xFF8B5CF6,
                          //   ).withValues(alpha: 0.12),
                          //   animationDelay: 400,
                          // ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Attendance History
                      const Text(
                        'Recent Attendance',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildHistoryPlaceholder(),
                    ]),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPercentageCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepBlue.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Circular progress
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              children: [
                CircularProgressIndicator(
                  value: 0.75, // TODO: Calculate real percentage
                  strokeWidth: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation(AppColors.emerald),
                ),
                const Center(
                  child: Text(
                    '75%', // TODO: Calculate real percentage
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Attendance Rate',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$_monthlyAttendance classes attended this month',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryPlaceholder() {
    // TODO: Implement list of actual history from AttendanceService
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          Icon(
            Icons.history_rounded,
            size: 48,
            color: AppColors.textLight.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'No recent history',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textLight,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Your attendance history will appear here',
            style: TextStyle(fontSize: 13, color: AppColors.textLight),
          ),
        ],
      ),
    );
  }
}
