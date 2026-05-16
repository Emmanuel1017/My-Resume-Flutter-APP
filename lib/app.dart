import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/create_admin_screen.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

class PortfolioAdminApp extends StatelessWidget {
  const PortfolioAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title:                      'Portfolio Admin',
      debugShowCheckedModeBanner: false,
      theme:                      AppTheme.dark,
      initialRoute:               '/splash',
      routes: {
        '/splash':        (_) => const SplashScreen(nextRoute: '/auth'),
        '/auth':          (_) => const _AuthGate(),
        '/login':         (_) => const LoginScreen(),
        '/create-admin':  (_) => const CreateAdminScreen(),
        '/home':          (_) => const HomeScreen(),
      },
    );
  }
}

/// Checks auth state AND whether an admin account has been created yet.
/// - Not signed in + no admin → /create-admin (first-time setup)
/// - Not signed in + admin exists → /login
/// - Signed in → /home
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  Future<bool> _adminInitialized() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('portfolio')
          .doc('meta')
          .get();
      return doc.data()?['admin_initialized'] == true;
    } catch (_) {
      return false; // network error → assume not initialized, show create screen
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.bg,
            body: Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2),
            ),
          );
        }

        if (snap.data != null) {
          // Already signed in
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacementNamed('/home');
          });
          return const Scaffold(backgroundColor: AppColors.bg);
        }

        // Not signed in — check whether any admin account exists
        return FutureBuilder<bool>(
          future: _adminInitialized(),
          builder: (context, initSnap) {
            if (!initSnap.hasData) {
              return const Scaffold(
                backgroundColor: AppColors.bg,
                body: Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 2),
                ),
              );
            }

            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context).pushReplacementNamed(
                initSnap.data! ? '/login' : '/create-admin',
              );
            });

            return const Scaffold(backgroundColor: AppColors.bg);
          },
        );
      },
    );
  }
}
