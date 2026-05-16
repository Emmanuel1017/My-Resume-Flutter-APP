import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class GuestContactScreen extends StatefulWidget {
  const GuestContactScreen({super.key});

  @override
  State<GuestContactScreen> createState() => _GuestContactScreenState();
}

class _GuestContactScreenState extends State<GuestContactScreen> {
  final _form    = GlobalKey<FormState>();
  final _nameCtrl    = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _messageCtrl = TextEditingController();

  bool    _loading  = false;
  bool    _sent     = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() { _loading = true; _error = null; });
    HapticFeedback.mediumImpact();

    try {
      await FirebaseFirestore.instance.collection('contacts').add({
        'name':      _nameCtrl.text.trim(),
        'email':     _emailCtrl.text.trim(),
        'message':   _messageCtrl.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'source':    'flutter-guest',
        'read':      false,
      });
      HapticFeedback.heavyImpact();
      if (mounted) { setState(() { _sent = true; _loading = false; }); }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error   = 'Could not send message. Please try again.';
          _loading = false;
        });
      }
    }
  }

  void _reset() => setState(() {
    _sent = false;
    _nameCtrl.clear();
    _emailCtrl.clear();
    _messageCtrl.clear();
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          // Background blobs
          const Positioned(top: -60,   right: -40, child: _Blob(size: 220, opacity: .12)),
          const Positioned(bottom: -40, left: -60,  child: _Blob(size: 180, opacity: .07)),

          SafeArea(
            child: _sent ? _SuccessView(onReset: _reset) : _FormView(
              top:         top,
              form:        _form,
              nameCtrl:    _nameCtrl,
              emailCtrl:   _emailCtrl,
              messageCtrl: _messageCtrl,
              loading:     _loading,
              error:       _error,
              onSubmit:    _submit,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Form view ────────────────────────────────────────────────────────────────

class _FormView extends StatelessWidget {
  final double              top;
  final GlobalKey<FormState> form;
  final TextEditingController nameCtrl, emailCtrl, messageCtrl;
  final bool    loading;
  final String? error;
  final VoidCallback onSubmit;

  const _FormView({
    required this.top,         required this.form,
    required this.nameCtrl,    required this.emailCtrl,
    required this.messageCtrl, required this.loading,
    required this.error,       required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                shape:    BoxShape.circle,
                color:    AppColors.accent.withOpacity(.12),
                border:   Border.all(color: AppColors.accent.withOpacity(.3)),
              ),
              child: const Icon(Icons.mail_rounded, color: AppColors.accent, size: 20),
            ),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Send a Message',
                  style: GoogleFonts.montserrat(
                    fontSize: 20, fontWeight: FontWeight.w900,
                    color: AppColors.textHigh)),
              Text('Emmanuel will reply within 24 hours',
                  style: GoogleFonts.montserrat(
                    fontSize: 12, color: AppColors.textMid)),
            ]),
          ]).animate().fadeIn(duration: 400.ms).slideY(begin: -.06),

          const SizedBox(height: 28),

          // Form card
          Container(
            padding:    const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color:        AppColors.card,
              borderRadius: BorderRadius.circular(24),
              border:       Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color:      Colors.black.withOpacity(.25),
                  blurRadius: 24,
                  offset:     const Offset(0, 10),
                ),
              ],
            ),
            child: Form(
              key: form,
              child: Column(children: [
                // Name
                TextFormField(
                  controller:  nameCtrl,
                  style:       const TextStyle(color: AppColors.textHigh),
                  decoration:  const InputDecoration(
                    labelText:  'Your Name',
                    prefixIcon: Icon(Icons.person_rounded,
                        color: AppColors.textMid, size: 20),
                  ),
                  validator: (v) =>
                      (v?.trim().isNotEmpty ?? false) ? null : 'Name is required',
                  textCapitalization: TextCapitalization.words,
                ).animate().fadeIn(delay: 100.ms).slideX(begin: -.06),

                const SizedBox(height: 16),

                // Email
                TextFormField(
                  controller:   emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style:        const TextStyle(color: AppColors.textHigh),
                  decoration:   const InputDecoration(
                    labelText:  'Your Email',
                    prefixIcon: Icon(Icons.email_rounded,
                        color: AppColors.textMid, size: 20),
                  ),
                  validator: (v) =>
                      (v?.contains('@') ?? false) ? null : 'Enter a valid email',
                ).animate().fadeIn(delay: 160.ms).slideX(begin: -.06),

                const SizedBox(height: 16),

                // Message
                TextFormField(
                  controller: messageCtrl,
                  style:      const TextStyle(color: AppColors.textHigh),
                  decoration: const InputDecoration(
                    labelText:   'Message',
                    prefixIcon:  Padding(
                      padding: EdgeInsets.only(bottom: 60),
                      child:   Icon(Icons.message_rounded,
                          color: AppColors.textMid, size: 20),
                    ),
                    alignLabelWithHint: true,
                  ),
                  maxLines:   5,
                  minLines:   4,
                  validator:  (v) =>
                      (v?.trim().isNotEmpty ?? false) ? null : 'Message is required',
                ).animate().fadeIn(delay: 220.ms).slideX(begin: -.06),

                // Error
                if (error != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding:    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color:        AppColors.danger.withOpacity(.12),
                      borderRadius: BorderRadius.circular(12),
                      border:       Border.all(color: AppColors.danger.withOpacity(.4)),
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
                ],

                const SizedBox(height: 24),

                ElevatedButton.icon(
                  onPressed: loading ? null : onSubmit,
                  icon: loading
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.2, color: Colors.white))
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(loading ? 'Sending…' : 'Send Message'),
                ).animate().fadeIn(delay: 280.ms),
              ]),
            ),
          ).animate().fadeIn(delay: 80.ms, duration: 500.ms).slideY(begin: .06),

          const SizedBox(height: 28),

          // Note
          Center(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.lock_rounded, size: 12, color: AppColors.textLow),
              const SizedBox(width: 6),
              Text('Delivered directly to Emmanuel',
                  style: GoogleFonts.montserrat(
                    fontSize: 11, color: AppColors.textLow)),
            ]),
          ).animate().fadeIn(delay: 350.ms),
        ],
      ),
    );
  }
}

// ─── Success view ─────────────────────────────────────────────────────────────

class _SuccessView extends StatelessWidget {
  final VoidCallback onReset;
  const _SuccessView({required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                shape:    BoxShape.circle,
                color:    AppColors.accent.withOpacity(.12),
                border:   Border.all(
                    color: AppColors.accent.withOpacity(.4), width: 2),
                boxShadow: [
                  BoxShadow(
                    color:      AppColors.accent.withOpacity(.25),
                    blurRadius: 32,
                  ),
                ],
              ),
              child: const Icon(Icons.check_rounded,
                  color: AppColors.accent, size: 44),
            ).animate().scale(delay: 100.ms, curve: Curves.elasticOut, duration: 700.ms),

            const SizedBox(height: 28),

            Text('Message Sent!',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 26, fontWeight: FontWeight.w900,
                  color: AppColors.textHigh)
            ).animate().fadeIn(delay: 300.ms),

            const SizedBox(height: 10),

            Text('Emmanuel will get back to you within 24 hours.',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 14, color: AppColors.textMid, height: 1.6)
            ).animate().fadeIn(delay: 420.ms),

            const SizedBox(height: 36),

            OutlinedButton.icon(
              onPressed: onReset,
              icon:  const Icon(Icons.add_rounded, size: 18,
                  color: AppColors.accent),
              label: Text('Send Another',
                  style: GoogleFonts.montserrat(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: AppColors.accent)),
              style: OutlinedButton.styleFrom(
                side:    const BorderSide(color: AppColors.accent),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape:   RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ).animate().fadeIn(delay: 520.ms),
          ],
        ),
      ),
    );
  }
}

// ─── Decorative blob ──────────────────────────────────────────────────────────
class _Blob extends StatelessWidget {
  final double size, opacity;
  const _Blob({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: AppColors.primary.withOpacity(opacity),
    ),
  );
}
