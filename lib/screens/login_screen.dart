import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/angular_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email    = TextEditingController();
  final _password = TextEditingController();
  final _form     = GlobalKey<FormState>();

  bool    _loading        = false;
  bool    _obscure        = true;
  bool    _argsLoaded     = false;
  bool    _showNoUserHint = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsLoaded) return;
    _argsLoaded = true;

    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      if (args['email'] != null)    _email.text    = args['email']    as String;
      if (args['password'] != null) _password.text = args['password'] as String;
    }

    // Already authenticated (just created account) → go straight to home
    if (FirebaseAuth.instance.currentUser != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pushReplacementNamed('/home');
      });
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() { _loading = true; _error = null; _showNoUserHint = false; });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email:    _email.text.trim(),
        password: _password.text,
      );
      if (mounted) Navigator.of(context).pushReplacementNamed('/home');
    } on FirebaseAuthException catch (e) {
      final noUser = e.code == 'user-not-found' || e.code == 'invalid-credential';
      setState(() {
        _showNoUserHint = noUser;
        _error = switch (e.code) {
          'user-not-found'     => 'No account found for that email.',
          'invalid-credential' => 'Incorrect email or password.',
          'wrong-password'     => 'Incorrect password.',
          'invalid-email'      => 'Please enter a valid email address.',
          'too-many-requests'  => 'Too many attempts. Try again later.',
          _                    => e.message ?? 'Authentication failed.',
        };
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter your email address above, then tap Forgot Password.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Reset link sent to $email'),
          backgroundColor: const Color(0xFF1A4731),
        ));
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? 'Could not send reset email.');
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
          // Background grid
          Positioned.fill(child: _BackgroundDecor()),

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
                        // ── Angular logo ────────────────────────────────────
                        const Center(child: AngularLogoGlow(size: 72))
                            .animate()
                            .scale(delay: 100.ms, duration: 600.ms,
                                   curve: Curves.elasticOut),

                        const SizedBox(height: 28),

                        // ── Heading ─────────────────────────────────────────
                        Text(
                          'Admin Access',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.montserrat(
                            fontSize:   26,
                            fontWeight: FontWeight.w900,
                            color:      AppColors.textHigh,
                            letterSpacing: 1.5,
                          ),
                        ).animate().fadeIn(delay: 200.ms, duration: 500.ms),

                        const SizedBox(height: 6),

                        Text(
                          'Portfolio control panel',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.montserrat(
                            fontSize: 13,
                            color:    AppColors.textMid,
                          ),
                        ).animate().fadeIn(delay: 300.ms, duration: 500.ms),

                        const SizedBox(height: 40),

                        // ── Card ────────────────────────────────────────────
                        Container(
                          padding:     const EdgeInsets.all(28),
                          decoration:  BoxDecoration(
                            color:        AppColors.card,
                            borderRadius: BorderRadius.circular(24),
                            border:       Border.all(color: AppColors.border),
                            boxShadow: [
                              BoxShadow(
                                color:      Colors.black.withOpacity(.3),
                                blurRadius: 30,
                                offset:     const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Email
                              TextFormField(
                                controller:  _email,
                                keyboardType: TextInputType.emailAddress,
                                style:       const TextStyle(color: AppColors.textHigh),
                                decoration:  const InputDecoration(
                                  labelText:  'Email',
                                  prefixIcon: Icon(Icons.email_rounded, color: AppColors.textMid, size: 20),
                                ),
                                validator: (v) =>
                                    (v?.contains('@') ?? false) ? null : 'Enter a valid email',
                              ).animate().fadeIn(delay: 350.ms).slideX(begin: -.1, end: 0),

                              const SizedBox(height: 16),

                              // Password
                              TextFormField(
                                controller:  _password,
                                obscureText: _obscure,
                                style:       const TextStyle(color: AppColors.textHigh),
                                decoration:  InputDecoration(
                                  labelText:  'Password',
                                  prefixIcon: const Icon(Icons.lock_rounded, color: AppColors.textMid, size: 20),
                                  suffixIcon: GestureDetector(
                                    onTap: () => setState(() => _obscure = !_obscure),
                                    child: Icon(
                                      _obscure
                                          ? Icons.visibility_off_rounded
                                          : Icons.visibility_rounded,
                                      color: AppColors.textMid,
                                      size:  20,
                                    ),
                                  ),
                                ),
                                onFieldSubmitted: (_) => _login(),
                                validator: (v) =>
                                    (v?.length ?? 0) >= 6 ? null : 'Password must be 6+ characters',
                              ).animate().fadeIn(delay: 450.ms).slideX(begin: -.1, end: 0),

                              // Error message
                              if (_error != null) ...[
                                const SizedBox(height: 14),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color:        AppColors.danger.withOpacity(.12),
                                    borderRadius: BorderRadius.circular(10),
                                    border:       Border.all(
                                        color: AppColors.danger.withOpacity(.4)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.warning_amber_rounded,
                                          color: AppColors.danger, size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _error!,
                                          style: GoogleFonts.montserrat(
                                            fontSize: 12,
                                            color:    AppColors.danger,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ).animate().shakeX(duration: 400.ms),

                                // "No account found" → offer create-admin link
                                if (_showNoUserHint) ...[
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onTap: () => Navigator.of(context)
                                        .pushReplacementNamed('/create-admin'),
                                    child: Text(
                                      'Set up the admin account instead →',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.montserrat(
                                        fontSize: 12,
                                        color: AppColors.accent,
                                        decoration: TextDecoration.underline,
                                        decorationColor: AppColors.accent,
                                      ),
                                    ),
                                  ),
                                ],
                              ],

                              const SizedBox(height: 24),

                              // Login button
                              ElevatedButton(
                                onPressed: _loading ? null : _login,
                                child: _loading
                                    ? const SizedBox(
                                        height: 22,
                                        width:  22,
                                        child:  CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Sign In'),
                              ).animate().fadeIn(delay: 550.ms),

                              // Forgot password
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: _loading ? null : _forgotPassword,
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'Forgot password?',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 12,
                                    color:    AppColors.textMid,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 250.ms, duration: 600.ms).slideY(begin: .08, end: 0),

                        const SizedBox(height: 20),

                        TextButton(
                          onPressed: () => Navigator.of(context)
                              .pushReplacementNamed('/create-admin'),
                          child: Text(
                            'First time? Create admin account',
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

// ─── Background decoration ───────────────────────────────────────────────────

class _BackgroundDecor extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Glow blobs
        Positioned(
          top:   -80,
          right: -60,
          child: Container(
            width:  240,
            height: 240,
            decoration: BoxDecoration(
              shape:    BoxShape.circle,
              gradient: RadialGradient(colors: [
                AppColors.primary.withOpacity(.18),
                AppColors.primary.withOpacity(0),
              ]),
            ),
          ),
        ),
        Positioned(
          bottom: -60,
          left:   -80,
          child: Container(
            width:  200,
            height: 200,
            decoration: BoxDecoration(
              shape:    BoxShape.circle,
              gradient: RadialGradient(colors: [
                AppColors.accent.withOpacity(.10),
                AppColors.accent.withOpacity(0),
              ]),
            ),
          ),
        ),
      ],
    );
  }
}
