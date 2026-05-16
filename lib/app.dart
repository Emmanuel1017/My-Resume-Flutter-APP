import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
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
        '/splash': (_) => const SplashScreen(nextRoute: '/auth'),
        '/auth':   (_) => const _AuthGate(),
        '/login':  (_) => const LoginScreen(),
        '/home':   (_) => const HomeScreen(),
      },
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

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

        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context).pushReplacementNamed(
            snap.data != null ? '/home' : '/login',
          );
        });

        return const Scaffold(backgroundColor: AppColors.bg);
      },
    );
  }
}
