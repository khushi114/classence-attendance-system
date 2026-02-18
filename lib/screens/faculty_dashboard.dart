import 'package:flutter/material.dart';
import 'package:attendance_system/core/theme/app_colors.dart';
import 'package:attendance_system/widgets/dashboard_card.dart';
import 'package:attendance_system/widgets/custom_button.dart';
import 'package:attendance_system/features/auth/data/firebase_auth_service.dart';
import 'package:attendance_system/features/auth/presentation/login_screen.dart';
import 'package:attendance_system/features/sessions/presentation/start_session_sheet.dart';
import 'package:attendance_system/features/sessions/data/session_service.dart';
import 'package:attendance_system/features/sessions/domain/session_model.dart';
import 'package:attendance_system/features/classes/data/class_service.dart';
import 'package:attendance_system/features/timetable/data/timetable_service.dart';
import 'package:attendance_system/features/classes/domain/class_model.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart'; // for Clipboard
import 'package:attendance_system/core/services/beacon_advertising_service.dart';

/// Faculty dashboard with Start Session, Active Sessions, and History.
class FacultyDashboard extends StatefulWidget {
  const FacultyDashboard({super.key});

  @override
  State<FacultyDashboard> createState() => _FacultyDashboardState();
}

class _FacultyDashboardState extends State<FacultyDashboard> {
  final _authService = FirebaseAuthService();
  final _sessionService = SessionService();
  final _classService = ClassService();
  final _timetableService = TimetableService();
  final _beaconService = BeaconAdvertisingService();

  String _userName = 'Faculty';
  List<SessionModel> _activeSessions = [];
  Map<String, String> _classNames = {};
  List<Map<String, dynamic>> _todaySchedule = [];
  bool _isLoading = true;
  bool _isLoadingSchedule = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadTodaySchedule();
  }

  Future<void> _loadData() async {
    final user = _authService.currentUser;
    if (user != null && mounted) {
      try {
        // 1. User Data
        final userData = await _authService.getUserData(user.uid);

        // 2. Active Sessions
        final sessions = await _sessionService.getActiveSessionsForFaculty(
          user.uid,
        );

        // 3. All Classes (to map IDs to Names)
        final classes = await _classService.getClassesForFaculty(user.uid);
        final classNames = <String, String>{};
        for (var c in classes) {
          classNames[c.id] = '${c.name} (${c.code})';
        }

        if (mounted) {
          setState(() {
            _userName =
                userData?.name ??
                user.displayName ??
                user.email?.split('@')[0] ??
                'Faculty';
            _activeSessions = sessions;
            _classNames = classNames;
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _loadTodaySchedule() async {
    final user = _authService.currentUser;
    if (user == null) return;

    // Get current day abbreviation (Mon, Tue, etc.)
    final today = DateFormat('E').format(DateTime.now());

    try {
      final schedule = await _timetableService.getDailyScheduleForFaculty(
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

  Future<void> _endSession(String sessionId) async {
    try {
      // Stop BLE advertising first
      await _beaconService.stopAdvertising();
      await _sessionService.endSession(sessionId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session ended'),
            backgroundColor: AppColors.textPrimary,
          ),
        );
        _loadData();
        setState(() {}); // Refresh BLE status indicator
      }
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _copyContext(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Copied to clipboard'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _startSession(ClassModel? classModel) async {
    final result = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StartSessionSheet(preSelectedClass: classModel),
    );
    if (result != null && mounted) {
      // Start BLE advertising with the session's beacon UUID
      if (result.bluetoothBeaconId != null &&
          result.bluetoothBeaconId!.isNotEmpty) {
        await _beaconService.startAdvertising(result.bluetoothBeaconId!);
      }
      _loadData();
      setState(() {}); // Refresh BLE status indicator
    }
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
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF059669), Color(0xFF047857)],
                      ),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(28),
                        bottomRight: Radius.circular(28),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.work_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'FACULTY',
                                style: TextStyle(
                                  color: Colors.white,
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

                // Content
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
                          final slot = item['slot'];
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
                                    color: AppColors.emerald.withValues(
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
                                          color: AppColors.emerald,
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
                                          color: AppColors.emerald,
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
                                ElevatedButton(
                                  onPressed: () => _startSession(classModel),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.emerald,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 0,
                                    ),
                                  ),
                                  child: const Text('Start'),
                                ),
                              ],
                            ),
                          );
                        }),

                      const SizedBox(height: 24),

                      if (_activeSessions.isNotEmpty) ...[
                        const Text(
                          'Live Sessions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ..._activeSessions.map((session) {
                          final className =
                              _classNames[session.classId] ?? 'Unknown Class';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.emerald),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.emerald.withValues(
                                    alpha: 0.1,
                                  ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        className,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.emerald.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'ACTIVE',
                                        style: TextStyle(
                                          color: AppColors.emerald,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // BLE Broadcasting Status
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _beaconService.isAdvertising
                                        ? const Color(
                                            0xFF059669,
                                          ).withValues(alpha: 0.08)
                                        : Colors.grey.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _beaconService.isAdvertising
                                          ? const Color(
                                              0xFF059669,
                                            ).withValues(alpha: 0.3)
                                          : Colors.grey.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: _beaconService.isAdvertising
                                              ? const Color(0xFF059669)
                                              : Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _beaconService.isAdvertising
                                            ? '📡 BLE Broadcasting: Active'
                                            : '📡 BLE Broadcasting: Inactive',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: _beaconService.isAdvertising
                                              ? const Color(0xFF059669)
                                              : Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Session Code',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                GestureDetector(
                                  onTap: () =>
                                      _copyContext(session.sessionToken),
                                  child: Row(
                                    children: [
                                      Text(
                                        session.sessionToken,
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.5,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        Icons.copy_rounded,
                                        size: 18,
                                        color: AppColors.textLight,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () => _endSession(session.id),
                                    icon: const Icon(
                                      Icons.stop_circle_outlined,
                                    ),
                                    label: const Text('End Session'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.error,
                                      side: const BorderSide(
                                        color: AppColors.error,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 24),
                      ],

                      // Start Session Button
                      CustomButton(
                        text: 'Start New Session',
                        onPressed: () async {
                          final result = await showModalBottomSheet<dynamic>(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => const StartSessionSheet(),
                          );

                          if (result != null && mounted) {
                            // Start BLE advertising with the session's beacon UUID
                            if (result.bluetoothBeaconId != null &&
                                result.bluetoothBeaconId!.isNotEmpty) {
                              await _beaconService.startAdvertising(
                                result.bluetoothBeaconId!,
                              );
                            }
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    _beaconService.isAdvertising
                                        ? '✅ Session started! 📡 BLE beacon broadcasting'
                                        : '✅ Session started!',
                                  ),
                                  backgroundColor: AppColors.success,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              );
                              _loadData();
                              setState(() {}); // Refresh BLE status indicator
                            }
                          }
                        },
                        icon: Icons.play_circle_filled_rounded,
                        height: 64,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF059669), Color(0xFF047857)],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Quick Stats
                      const Text(
                        'Quick Stats',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          // TODO: Fetch real stats
                        ),
                      ),
                      const SizedBox(height: 14),

                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.25,
                        children: [
                          DashboardCard(
                            title: 'Active Sessions',
                            value: _activeSessions.length.toString(),
                            icon: Icons.meeting_room_rounded,
                            iconColor: AppColors.emerald,
                            iconBgColor: AppColors.emerald.withValues(
                              alpha: 0.12,
                            ),
                            animationDelay: 100,
                          ),
                          DashboardCard(
                            title: 'Total Classes',
                            value: _classNames.length.toString(),
                            icon: Icons.class_rounded,
                            iconColor: AppColors.royalBlue,
                            iconBgColor: AppColors.royalBlue.withValues(
                              alpha: 0.12,
                            ),
                            animationDelay: 200,
                          ),
                          DashboardCard(
                            title: 'Students Present',
                            value: '0', // TODO: Fetch from AnalyticsService
                            icon: Icons.people_rounded,
                            iconColor: AppColors.orange,
                            iconBgColor: AppColors.orange.withValues(
                              alpha: 0.12,
                            ),
                            animationDelay: 300,
                          ),
                          DashboardCard(
                            title: 'Avg Attendance',
                            value: '0%', // TODO: Fetch from AnalyticsService
                            icon: Icons.trending_up_rounded,
                            iconColor: const Color(0xFF8B5CF6),
                            iconBgColor: const Color(
                              0xFF8B5CF6,
                            ).withValues(alpha: 0.12),
                            animationDelay: 400,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Attendance History Card
                      const Text(
                        'Attendance History',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildHistoryCard(),
                    ]),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHistoryCard() {
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
            'No sessions yet',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textLight,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your session history will appear here',
            style: TextStyle(fontSize: 13, color: AppColors.textLight),
          ),
        ],
      ),
    );
  }
}
