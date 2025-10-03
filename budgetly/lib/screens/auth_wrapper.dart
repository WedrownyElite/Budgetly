// budgetly/lib/screens/auth_wrapper.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/cloud_sync_service.dart';
import 'login_screen.dart';
import 'home_screen.dart';

/// Wrapper that shows login screen or home screen based on auth state
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final CloudSyncService _syncService = CloudSyncService();
  bool _isInitialized = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // If user is authenticated
        if (snapshot.hasData && snapshot.data != null) {
          // Initialize sync service if not already initialized
          if (!_isInitialized) {
            _syncService.initialize(snapshot.data!.uid).then((_) {
              if (mounted) {
                setState(() => _isInitialized = true);
              }
            });
          }

          return const HomeScreen();
        }

        // Reset initialization flag when signed out
        if (_isInitialized) {
          _isInitialized = false;
        }

        // Show login screen if not authenticated
        return const LoginScreen();
      },
    );
  }
}