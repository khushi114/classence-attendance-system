import 'package:attendance_system/features/auth/domain/entities/app_user.dart';

/// Mock authentication service for testing UI without Firebase
/// Replace with FirebaseAuthService after Firebase is configured
class MockAuthService {
  AppUser? _currentUser;

  // Mock sign in
  Future<AppUser?> signInWithEmail(String email, String password) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    // Mock validation
    if (email.isEmpty || password.isEmpty) {
      throw 'Please fill in all fields';
    }

    if (!email.contains('@')) {
      throw 'Invalid email address';
    }

    // Create mock user
    _currentUser = AppUser(
      id: '123',
      email: email,
      name: email.split('@')[0],
      createdAt: DateTime.now(),
    );

    return _currentUser;
  }

  // Mock registration
  Future<AppUser?> registerWithEmail(
    String email,
    String password,
    String name,
  ) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    // Mock validation
    if (email.isEmpty || password.isEmpty || name.isEmpty) {
      throw 'Please fill in all fields';
    }

    if (!email.contains('@')) {
      throw 'Invalid email address';
    }

    if (password.length < 6) {
      throw 'Password must be at least 6 characters';
    }

    // Create mock user
    _currentUser = AppUser(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      email: email,
      name: name,
      createdAt: DateTime.now(),
    );

    return _currentUser;
  }

  // Mock sign out
  Future<void> signOut() async {
    _currentUser = null;
  }

  // Get current user
  AppUser? get currentUser => _currentUser;

  // Mock getUserData
  Future<AppUser?> getUserData(String uid) async {
    return _currentUser;
  }
}
