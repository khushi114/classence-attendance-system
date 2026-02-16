import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'package:attendance_system/core/theme/app_theme.dart';
import 'package:attendance_system/features/auth/data/firebase_auth_service.dart';
import 'package:attendance_system/features/auth/presentation/login_screen.dart';
import 'package:attendance_system/screens/splash_screen.dart';
import 'package:attendance_system/screens/student_dashboard.dart';
import 'package:attendance_system/screens/faculty_dashboard.dart';
import 'package:attendance_system/screens/admin_dashboard.dart';
import 'package:attendance_system/features/auth/domain/entities/app_user.dart';
import 'package:attendance_system/screens/pending_verification_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const AttendanceApp());
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Attendance System',
      theme: AppTheme.lightTheme,
      home: SplashScreen(nextScreen: const AuthWrapper()),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = FirebaseAuthService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final firebaseUser = snapshot.data;
        if (firebaseUser != null) {
          // Delegated to a StatefulWidget to handle async user data fetching & auto-creation
          return UserDataWrapper(
            firebaseUser: firebaseUser,
            authService: authService,
          );
        }

        return const LoginScreen();
      },
    );
  }
}

class UserDataWrapper extends StatefulWidget {
  final User firebaseUser;
  final FirebaseAuthService authService;

  const UserDataWrapper({
    super.key,
    required this.firebaseUser,
    required this.authService,
  });

  @override
  State<UserDataWrapper> createState() => _UserDataWrapperState();
}

class _UserDataWrapperState extends State<UserDataWrapper> {
  AppUser? _appUser;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 1. Fetch user data
      var user = await widget.authService.getUserData(widget.firebaseUser.uid);

      if (user == null) {
        // 2. Data missing? Auto-create default profile
        print(
          'User data missing for ${widget.firebaseUser.email}, creating default...',
        );
        await widget.authService.createUserDocument(
          uid: widget.firebaseUser.uid,
          email: widget.firebaseUser.email ?? '',
          name: widget.firebaseUser.displayName ?? 'New User',
          role: 'student',
        );
        // 3. Retry fetch
        user = await widget.authService.getUserData(widget.firebaseUser.uid);
      }

      if (mounted) {
        setState(() {
          _appUser = user;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading/creating user: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Setting up profile...'),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: $_error', textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loadUser,
                  child: const Text('Retry'),
                ),
                TextButton(
                  onPressed: () => widget.authService.signOut(),
                  child: const Text('Sign Out'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_appUser == null) {
      // Should not happen if logic is correct, but safe fallback
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Profile could not be loaded.'),
              ElevatedButton(onPressed: _loadUser, child: const Text('Retry')),
              TextButton(
                onPressed: () => widget.authService.signOut(),
                child: const Text('Sign Out'),
              ),
            ],
          ),
        ),
      );
    }

    // Check verification status
    if (!_appUser!.isVerified) {
      return const PendingVerificationScreen();
    }

    // Routing
    switch (_appUser!.role) {
      case 'admin':
        return const AdminDashboard();
      case 'faculty':
        return const FacultyDashboard();
      case 'student':
      default:
        return const StudentDashboard();
    }
  }
}
