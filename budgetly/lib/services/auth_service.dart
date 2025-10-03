// budgetly/lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _emailKey = 'user_email';

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Check if user is signed in
  bool get isSignedIn => currentUser != null;

  // Get user ID
  String? get userId => currentUser?.uid;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign up with email and password
  Future<AuthResult> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _saveEmail(email);

      return AuthResult.success(credential.user);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getErrorMessage(e.code));
    } catch (e) {
      return AuthResult.failure('An unexpected error occurred');
    }
  }

  // Sign in with email and password
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _saveEmail(email);

      return AuthResult.success(credential.user);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getErrorMessage(e.code));
    } catch (e) {
      return AuthResult.failure('An unexpected error occurred');
    }
  }

  // Sign in anonymously (for testing)
  Future<AuthResult> signInAnonymously() async {
    try {
      final credential = await _auth.signInAnonymously();
      return AuthResult.success(credential.user);
    } catch (e) {
      return AuthResult.failure('Anonymous sign-in failed');
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Reset password with detailed error handling
  Future<ResetPasswordResult> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);

      if (kDebugMode) {
        print('✅ Password reset email sent to: $email');
      }

      return ResetPasswordResult.success();
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('❌ Firebase Auth Error: ${e.code} - ${e.message}');
      }

      switch (e.code) {
        case 'user-not-found':
          return ResetPasswordResult.failure('No account found with this email address');
        case 'invalid-email':
          return ResetPasswordResult.failure('Invalid email address format');
        case 'missing-email':
          return ResetPasswordResult.failure('Please enter an email address');
        default:
          return ResetPasswordResult.failure('Failed to send reset email. Please try again.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ General Error: $e');
      }
      return ResetPasswordResult.failure('An error occurred. Please check your connection and try again.');
    }
  }

  // Get saved email
  Future<String?> getSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_emailKey);
  }

  Future<void> _saveEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_emailKey, email);
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'This email is already registered';
      case 'invalid-email':
        return 'Invalid email address';
      case 'weak-password':
        return 'Password is too weak';
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      default:
        return 'Authentication failed';
    }
  }
}

class AuthResult {
  final bool success;
  final User? user;
  final String? errorMessage;

  AuthResult.success(this.user)
      : success = true,
        errorMessage = null;

  AuthResult.failure(this.errorMessage)
      : success = false,
        user = null;
}

class ResetPasswordResult {
  final bool success;
  final String? errorMessage;

  ResetPasswordResult.success()
      : success = true,
        errorMessage = null;

  ResetPasswordResult.failure(this.errorMessage) : success = false;
}