import 'package:flutter/material.dart';
import 'package:attendance_system/core/theme/app_colors.dart';
import 'package:attendance_system/widgets/dashboard_card.dart';
import 'package:attendance_system/screens/user_management_screen.dart';
import 'package:attendance_system/screens/timetable_editor_screen.dart';
import 'package:attendance_system/features/auth/data/firebase_auth_service.dart';
import 'package:attendance_system/features/auth/presentation/login_screen.dart';
import 'package:attendance_system/screens/analytics_screen.dart';

/// Admin dashboard with grid cards for statistics and management.
class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _authService = FirebaseAuthService();
  String _userName = 'Admin';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _authService.currentUser;
    if (user != null && mounted) {
      final userData = await _authService.getUserData(user.uid);
      setState(() {
        _userName =
            userData?.name ??
            user.displayName ??
            user.email?.split('@')[0] ??
            'Admin';
      });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: CustomScrollView(
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
                  colors: [Color(0xFF1E3A8A), Color(0xFF0F172A)],
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
                      color: AppColors.orange.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.admin_panel_settings_rounded,
                          color: AppColors.orangeLight,
                          size: 16,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'ADMINISTRATOR',
                          style: TextStyle(
                            color: AppColors.orangeLight,
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
                const Text(
                  'System Overview',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),

                // Stats Grid
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.25,
                  children: [
                    DashboardCard(
                      title: 'Total Students',
                      value: '0',
                      icon: Icons.people_rounded,
                      iconColor: AppColors.royalBlue,
                      iconBgColor: AppColors.royalBlue.withValues(alpha: 0.12),
                      animationDelay: 100,
                    ),
                    DashboardCard(
                      title: 'Classes',
                      value: '0',
                      icon: Icons.class_rounded,
                      iconColor: AppColors.emerald,
                      iconBgColor: AppColors.emerald.withValues(alpha: 0.12),
                      animationDelay: 200,
                    ),
                    DashboardCard(
                      title: 'Attendance %',
                      value: '0%',
                      icon: Icons.pie_chart_rounded,
                      iconColor: AppColors.orange,
                      iconBgColor: AppColors.orange.withValues(alpha: 0.12),
                      animationDelay: 300,
                    ),
                    DashboardCard(
                      title: 'Analytics',
                      value: 'View',
                      icon: Icons.insights_rounded,
                      iconColor: const Color(0xFF8B5CF6),
                      iconBgColor: const Color(
                        0xFF8B5CF6,
                      ).withValues(alpha: 0.12),
                      animationDelay: 400,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AnalyticsScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Management Section
                const Text(
                  'Management',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
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
                      title: 'Manage Users',
                      value: 'Users',
                      icon: Icons.manage_accounts_rounded,
                      iconColor: const Color(0xFFEC4899),
                      iconBgColor: const Color(
                        0xFFEC4899,
                      ).withValues(alpha: 0.12),
                      animationDelay: 500,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const UserManagementScreen(),
                          ),
                        );
                      },
                    ),
                    DashboardCard(
                      title: 'Manage Timetable',
                      value: 'Timetables',
                      icon: Icons.calendar_month_rounded,
                      iconColor: const Color(0xFFF59E0B),
                      iconBgColor: const Color(
                        0xFFF59E0B,
                      ).withValues(alpha: 0.12),
                      animationDelay: 600,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TimetableEditorScreen(),
                          ),
                        );
                      },
                    ),
                    DashboardCard(
                      title: 'Reports',
                      value: 'Generate',
                      icon: Icons.description_rounded,
                      iconColor: const Color(0xFF06B6D4),
                      iconBgColor: const Color(
                        0xFF06B6D4,
                      ).withValues(alpha: 0.12),
                      animationDelay: 700,
                      onTap: () {
                        // ...
                      },
                    ),
                  ],
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
