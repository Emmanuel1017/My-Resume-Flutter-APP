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
  bool    _showForm       = false;   // false = show choice cards; true = show login form
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
          Positioned.fill(child: _BackgroundDecor()),
          SafeArea(
            child: AnimatedSwitcher(
              duration:        const Duration(milliseconds: 320),
              switchInCurve:   Curves.easeOutCubic,
              switchOutCurve:  Curves.easeInCubic,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child:   SlideTransition(
                  position: Tween(
                    begin: const Offset(0, .04),
                    end:   Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: _showForm
                  ? _AdminForm(
                      key:            const ValueKey('form'),
                      email:          _email,
                      password:       _password,
                      formKey:        _form,
                      loading:        _loading,
                      obscure:        _obscure,
                      error:          _error,
                      showNoUserHint: _showNoUserHint,
                      onToggleObscure: () => setState(() => _obscure = !_obscure),
                      onLogin:         _login,
                      onForgot:        _forgotPassword,
                      onBack:  () => setState(() { _showForm = false; _error = null; }),
                    )
                  : _ChoiceView(
                      key:         const ValueKey('choice'),
                      onAdminTap:  () => setState(() => _showForm = true),
                      onGuestTap:  () => Navigator.of(context)
                          .pushReplacementNamed('/guest'),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Choice view — two big bold cards ────────────────────────────────────────

class _ChoiceView extends StatelessWidget {
  final VoidCallback onAdminTap;
  final VoidCallback onGuestTap;
  const _ChoiceView({super.key, required this.onAdminTap, required this.onGuestTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo + title
              const Center(child: AngularLogoGlow(size: 72))
                  .animate()
                  .scale(delay: 60.ms, duration: 600.ms,
                         curve: Curves.elasticOut),

              const SizedBox(height: 28),

              Text('Welcome',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    fontSize:      32,
                    fontWeight:    FontWeight.w900,
                    color:         AppColors.textHigh,
                    letterSpacing: 1.2,
                  )
              ).animate().fadeIn(delay: 150.ms),

              const SizedBox(height: 6),

              Text('Choose how you\'d like to continue',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    color:    AppColors.textMid,
                  )
              ).animate().fadeIn(delay: 220.ms),

              const SizedBox(height: 48),

              // ── Admin card ────────────────────────────────────────────
              _EntryCard(
                icon:        Icons.admin_panel_settings_rounded,
                title:       'Admin Login',
                subtitle:    'Full control over your portfolio settings',
                accent:      AppColors.primary,
                delay:       300,
                onTap:       onAdminTap,
              ),

              const SizedBox(height: 16),

              // ── Guest card ────────────────────────────────────────────
              _EntryCard(
                icon:        Icons.explore_rounded,
                title:       'Browse as Guest',
                subtitle:    'View portfolio · See profile · Send a message',
                accent:      AppColors.accent,
                delay:       420,
                onTap:       onGuestTap,
              ),

              const SizedBox(height: 48),

              // Create admin link
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context)
                      .pushReplacementNamed('/create-admin'),
                  child: Text(
                    'First time? Create admin account',
                    style: GoogleFonts.montserrat(
                      fontSize: 12, color: AppColors.textLow),
                  ),
                ),
              ).animate().fadeIn(delay: 540.ms),
            ],
          ),
        ),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  final IconData     icon;
  final String       title;
  final String       subtitle;
  final Color        accent;
  final int          delay;
  final VoidCallback onTap;
  const _EntryCard({
    required this.icon,    required this.title,
    required this.subtitle, required this.accent,
    required this.delay,   required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:  const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color:        accent.withOpacity(.08),
          border:       Border.all(color: accent.withOpacity(.35), width: 1.5),
          gradient: LinearGradient(
            colors: [accent.withOpacity(.13), Colors.transparent],
            begin:  Alignment.topLeft,
            end:    Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color:      accent.withOpacity(.18),
              blurRadius: 28,
              offset:     const Offset(0, 10),
            ),
          ],
        ),
        child: Row(children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              shape:  BoxShape.circle,
              color:  accent.withOpacity(.14),
              border: Border.all(color: accent.withOpacity(.35), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color:      accent.withOpacity(.25),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Icon(icon, color: accent, size: 28),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.montserrat(
                      fontSize:   20,
                      fontWeight: FontWeight.w900,
                      color:      AppColors.textHigh,
                    )),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: GoogleFonts.montserrat(
                      fontSize: 12.5,
                      color:    AppColors.textMid,
                      height:   1.45,
                    )),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Icon(Icons.arrow_forward_ios_rounded, color: accent, size: 18),
        ]),
      ),
    ).animate()
     .fadeIn(delay: Duration(milliseconds: delay), duration: 500.ms)
     .slideY(begin: .08, end: 0);
  }
}

// ─── Admin login form ─────────────────────────────────────────────────────────

class _AdminForm extends StatelessWidget {
  final TextEditingController email, password;
  final GlobalKey<FormState>  formKey;
  final bool    loading, obscure, showNoUserHint;
  final String? error;
  final VoidCallback onToggleObscure, onLogin, onForgot, onBack;

  const _AdminForm({
    super.key,
    required this.email,         required this.password,
    required this.formKey,       required this.loading,
    required this.obscure,       required this.error,
    required this.showNoUserHint,
    required this.onToggleObscure, required this.onLogin,
    required this.onForgot,        required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Back + logo row
                Row(children: [
                  GestureDetector(
                    onTap: onBack,
                    child: Container(
                      padding:    const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color:        AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border:       Border.all(color: AppColors.border),
                      ),
                      child: const Icon(Icons.arrow_back_rounded,
                          color: AppColors.textMid, size: 20),
                    ),
                  ),
                  const Spacer(),
                  const AngularLogoGlow(size: 48),
                  const Spacer(),
                  const SizedBox(width: 36),
                ]).animate().fadeIn(delay: 60.ms),

                const SizedBox(height: 24),

                Text('Admin Access',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      fontSize:   26,
                      fontWeight: FontWeight.w900,
                      color:      AppColors.textHigh,
                      letterSpacing: 1.5,
                    )
                ).animate().fadeIn(delay: 100.ms),

                const SizedBox(height: 6),

                Text('Portfolio control panel',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      fontSize: 13, color: AppColors.textMid)
                ).animate().fadeIn(delay: 160.ms),

                const SizedBox(height: 36),

                // Card
                Container(
                  padding:    const EdgeInsets.all(28),
                  decoration: BoxDecoration(
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
                  child: Column(children: [
                    TextFormField(
                      controller:   email,
                      keyboardType: TextInputType.emailAddress,
                      style:        const TextStyle(color: AppColors.textHigh),
                      decoration:   const InputDecoration(
                        labelText:  'Email',
                        prefixIcon: Icon(Icons.email_rounded,
                            color: AppColors.textMid, size: 20),
                      ),
                      validator: (v) =>
                          (v?.contains('@') ?? false) ? null : 'Enter a valid email',
                    ).animate().fadeIn(delay: 200.ms).slideX(begin: -.1, end: 0),

                    const SizedBox(height: 16),

                    TextFormField(
                      controller:  password,
                      obscureText: obscure,
                      style:       const TextStyle(color: AppColors.textHigh),
                      decoration:  InputDecoration(
                        labelText:  'Password',
                        prefixIcon: const Icon(Icons.lock_rounded,
                            color: AppColors.textMid, size: 20),
                        suffixIcon: GestureDetector(
                          onTap: onToggleObscure,
                          child: Icon(
                            obscure ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                            color: AppColors.textMid, size: 20),
                        ),
                      ),
                      onFieldSubmitted: (_) => onLogin(),
                      validator: (v) =>
                          (v?.length ?? 0) >= 6 ? null
                              : 'Password must be 6+ characters',
                    ).animate().fadeIn(delay: 260.ms).slideX(begin: -.1, end: 0),

                    if (error != null) ...[
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
                        child: Row(children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: AppColors.danger, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text(error!,
                              style: GoogleFonts.montserrat(
                                fontSize: 12, color: AppColors.danger))),
                        ]),
                      ).animate().shakeX(duration: 400.ms),

                      if (showNoUserHint) ...[
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => Navigator.of(context)
                              .pushReplacementNamed('/create-admin'),
                          child: Text('Set up the admin account instead →',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.montserrat(
                                fontSize: 12, color: AppColors.accent,
                                decoration: TextDecoration.underline,
                                decorationColor: AppColors.accent)),
                        ),
                      ],
                    ],

                    const SizedBox(height: 24),

                    ElevatedButton(
                      onPressed: loading ? null : onLogin,
                      child: loading
                          ? const SizedBox(
                              height: 22, width: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white))
                          : const Text('Sign In'),
                    ).animate().fadeIn(delay: 320.ms),

                    const SizedBox(height: 8),

                    TextButton(
                      onPressed: loading ? null : onForgot,
                      style: TextButton.styleFrom(
                        padding:       EdgeInsets.zero,
                        minimumSize:   Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text('Forgot password?',
                          style: GoogleFonts.montserrat(
                            fontSize: 12, color: AppColors.textMid)),
                    ),
                  ]),
                ).animate().fadeIn(delay: 140.ms, duration: 500.ms)
                 .slideY(begin: .06, end: 0),

                const SizedBox(height: 20),

                TextButton(
                  onPressed: () => Navigator.of(context)
                      .pushReplacementNamed('/create-admin'),
                  child: Text('First time? Create admin account',
                      style: GoogleFonts.montserrat(
                        fontSize: 13, color: AppColors.textMid)),
                ).animate().fadeIn(delay: 400.ms),
              ],
            ),
          ),
        ),
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
