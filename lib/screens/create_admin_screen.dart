import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/angular_logo.dart';

class CreateAdminScreen extends StatefulWidget {
  const CreateAdminScreen({super.key});

  @override
  State<CreateAdminScreen> createState() => _CreateAdminScreenState();
}

class _CreateAdminScreenState extends State<CreateAdminScreen> {
  final _email    = TextEditingController();
  final _password = TextEditingController();
  final _confirm  = TextEditingController();
  final _form     = GlobalKey<FormState>();

  bool    _loading = false;
  bool    _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() { _loading = true; _error = null; });

    try {
      // Create the Firebase Auth user
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email:    _email.text.trim(),
        password: _password.text,
      );

      // Mark setup as complete in Firestore so this screen won't show again
      await FirebaseFirestore.instance
          .collection('portfolio')
          .doc('meta')
          .set({'admin_initialized': true, 'admin_uid': cred.user!.uid},
               SetOptions(merge: true));

      // Navigate to login with credentials pre-filled; login screen will
      // detect the existing session and proceed directly to /home.
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login', arguments: {
          'email':    _email.text.trim(),
          'password': _password.text,
        });
      }

    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        // Account already exists — go straight to login with email pre-filled
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login', arguments: {
            'email': _email.text.trim(),
          });
        }
        return;
      }
      setState(() {
        _error = switch (e.code) {
          'weak-password'           => 'Password must be at least 6 characters.',
          'invalid-email'           => 'Please enter a valid email address.',
          'operation-not-allowed'   => 'Email/password sign-in is not enabled.\n'
              'Go to Firebase Console → Authentication → Sign-in method and enable Email/Password.',
          'configuration-not-found' => 'Firebase Auth is not configured.\n'
              'Enable Email/Password in Firebase Console → Authentication → Sign-in method.',
          _                         => '[${e.code}] ${e.message ?? 'Could not create account.'}',
        };
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          // Glow blobs
          Positioned(
            top: -60, left: -60,
            child: _Blob(color: const Color(0xFFDD0031), size: 220),
          ),
          Positioned(
            bottom: -40, right: -40,
            child: _Blob(color: AppColors.primary, size: 180),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Angular logo
                        const Center(child: AngularLogoGlow(size: 64))
                            .animate()
                            .scale(delay: 100.ms, duration: 700.ms,
                                   curve: Curves.elasticOut),

                        const SizedBox(height: 24),

                        Text(
                          'First-Time Setup',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.montserrat(
                            fontSize:   24,
                            fontWeight: FontWeight.w900,
                            color:      AppColors.textHigh,
                            letterSpacing: 1,
                          ),
                        ).animate().fadeIn(delay: 200.ms),

                        const SizedBox(height: 6),

                        Text(
                          'Create your admin account to manage the portfolio.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.montserrat(
                            fontSize: 13,
                            color:    AppColors.textMid,
                            height:   1.5,
                          ),
                        ).animate().fadeIn(delay: 300.ms),

                        const SizedBox(height: 32),

                        // Card
                        Container(
                          padding:    const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color:        AppColors.card,
                            borderRadius: BorderRadius.circular(24),
                            border:       Border.all(color: AppColors.border),
                            boxShadow: [
                              BoxShadow(
                                color:      Colors.black.withOpacity(.25),
                                blurRadius: 28,
                                offset:     const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Email
                              TextFormField(
                                controller:   _email,
                                keyboardType: TextInputType.emailAddress,
                                style: const TextStyle(color: AppColors.textHigh),
                                decoration: const InputDecoration(
                                  labelText:  'Admin email',
                                  prefixIcon: Icon(Icons.email_rounded,
                                      color: AppColors.textMid, size: 20),
                                ),
                                validator: (v) =>
                                    (v?.contains('@') ?? false) ? null : 'Enter a valid email',
                              ).animate().fadeIn(delay: 350.ms).slideX(begin: -.08),

                              const SizedBox(height: 14),

                              // Password
                              TextFormField(
                                controller:  _password,
                                obscureText: _obscure,
                                style: const TextStyle(color: AppColors.textHigh),
                                decoration: InputDecoration(
                                  labelText:  'Password',
                                  prefixIcon: const Icon(Icons.lock_rounded,
                                      color: AppColors.textMid, size: 20),
                                  suffixIcon: GestureDetector(
                                    onTap: () => setState(() => _obscure = !_obscure),
                                    child: Icon(
                                      _obscure
                                          ? Icons.visibility_off_rounded
                                          : Icons.visibility_rounded,
                                      color: AppColors.textMid, size: 20,
                                    ),
                                  ),
                                ),
                                validator: (v) =>
                                    (v?.length ?? 0) >= 6 ? null : 'At least 6 characters',
                              ).animate().fadeIn(delay: 420.ms).slideX(begin: -.08),

                              const SizedBox(height: 14),

                              // Confirm password
                              TextFormField(
                                controller:  _confirm,
                                obscureText: _obscure,
                                style: const TextStyle(color: AppColors.textHigh),
                                decoration: const InputDecoration(
                                  labelText:  'Confirm password',
                                  prefixIcon: Icon(Icons.lock_outline_rounded,
                                      color: AppColors.textMid, size: 20),
                                ),
                                validator: (v) =>
                                    v == _password.text ? null : 'Passwords do not match',
                                onFieldSubmitted: (_) => _create(),
                              ).animate().fadeIn(delay: 490.ms).slideX(begin: -.08),

                              if (_error != null) ...[
                                const SizedBox(height: 14),
                                _ErrorBanner(message: _error!),
                              ],

                              const SizedBox(height: 24),

                              ElevatedButton(
                                onPressed: _loading ? null : _create,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFDD0031),
                                ),
                                child: _loading
                                    ? const SizedBox(
                                        height: 22, width: 22,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2.5, color: Colors.white),
                                      )
                                    : const Text('Create Admin Account'),
                              ).animate().fadeIn(delay: 560.ms),
                            ],
                          ),
                        ).animate().fadeIn(delay: 250.ms).slideY(begin: .06),

                        const SizedBox(height: 20),

                        TextButton(
                          onPressed: () => Navigator.of(context)
                              .pushReplacementNamed('/login'),
                          child: Text(
                            'Already have an account? Sign in',
                            style: GoogleFonts.montserrat(
                              fontSize: 13,
                              color:    AppColors.textMid,
                            ),
                          ),
                        ).animate().fadeIn(delay: 620.ms),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final Color color;
  final double size;
  const _Blob({required this.color, required this.size});
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape:    BoxShape.circle,
      gradient: RadialGradient(colors: [
        color.withOpacity(.18),
        color.withOpacity(0),
      ]),
    ),
  );
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});
  @override
  Widget build(BuildContext context) => Container(
    padding:    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color:        AppColors.danger.withOpacity(.12),
      borderRadius: BorderRadius.circular(10),
      border:       Border.all(color: AppColors.danger.withOpacity(.4)),
    ),
    child: Row(children: [
      const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 16),
      const SizedBox(width: 8),
      Expanded(
        child: Text(message,
          style: GoogleFonts.montserrat(fontSize: 12, color: AppColors.danger)),
      ),
    ]),
  ).animate().shakeX(duration: 400.ms);
}
