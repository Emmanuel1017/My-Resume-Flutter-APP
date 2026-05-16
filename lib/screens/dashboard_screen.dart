import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/portfolio_service.dart';
import '../theme/app_theme.dart';

// ─── Glass card primitive ────────────────────────────────────────────────────

class _Glass extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius? radius;
  final Color? tint;
  final double blur;

  const _Glass({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius,
    this.tint,
    this.blur = 18,
  });

  @override
  Widget build(BuildContext context) {
    final br = radius ?? BorderRadius.circular(24);
    return ClipRRect(
      borderRadius: br,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: br,
            color: (tint ?? AppColors.accent).withOpacity(.05),
            border: Border.all(
              color: (tint ?? AppColors.accent).withOpacity(.18),
              width: 1,
            ),
            gradient: LinearGradient(
              colors: [
                (tint ?? AppColors.accent).withOpacity(.09),
                Colors.white.withOpacity(.02),
              ],
              begin: Alignment.topLeft,
              end:   Alignment.bottomRight,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ─── Dashboard screen ────────────────────────────────────────────────────────

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  final _service       = PortfolioService();
  final _featuredCtrl  = TextEditingController();
  final _greetingCtrl  = TextEditingController();
  bool  _textDirty     = false;
  bool  _savingText    = false;
  PortfolioSettings? _current;

  @override
  void dispose() {
    _featuredCtrl.dispose();
    _greetingCtrl.dispose();
    super.dispose();
  }

  void _syncText(PortfolioSettings s) {
    if (!_textDirty) {
      if (_featuredCtrl.text != s.featuredMessage) {
        _featuredCtrl.text = s.featuredMessage;
      }
      if (_greetingCtrl.text != s.koriGreeting) {
        _greetingCtrl.text = s.koriGreeting;
      }
    }
    _current = s;
  }

  Future<void> _saveText() async {
    if (_current == null || _savingText) return;
    setState(() => _savingText = true);
    HapticFeedback.mediumImpact();
    await _service.save(_current!.copyWith(
      featuredMessage: _featuredCtrl.text.trim(),
      koriGreeting:    _greetingCtrl.text.trim(),
    ));
    if (mounted) {
      setState(() { _textDirty = false; _savingText = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text('Changes saved', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
          ]),
          backgroundColor: AppColors.primary,
          behavior:        SnackBarBehavior.floating,
          shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin:          const EdgeInsets.all(16),
          duration:        const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _signOut() async {
    HapticFeedback.lightImpact();
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final initials = _initials(user?.email ?? 'A');

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          // ── Decorative blobs ──────────────────────────────────────────────
          Positioned(
            top: -80, right: -60,
            child: _Blob(size: 260, color: AppColors.primary.withOpacity(.18)),
          ),
          Positioned(
            top: 200, left: -80,
            child: _Blob(size: 200, color: AppColors.accent.withOpacity(.08)),
          ),
          Positioned(
            bottom: 200, right: -40,
            child: _Blob(size: 180, color: AppColors.primary.withOpacity(.12)),
          ),

          // ── Main scroll ───────────────────────────────────────────────────
          StreamBuilder<PortfolioSettings>(
            stream: _service.stream(),
            builder: (context, snap) {
              if (snap.hasData) _syncText(snap.data!);
              final s = snap.data ?? const PortfolioSettings();
              final isLive = snap.connectionState == ConnectionState.active;

              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // ── App bar ─────────────────────────────────────────────
                  SliverAppBar(
                    expandedHeight: 120,
                    pinned:          true,
                    backgroundColor: AppColors.bg.withOpacity(.85),
                    surfaceTintColor: Colors.transparent,
                    automaticallyImplyLeading: false,
                    flexibleSpace: FlexibleSpaceBar(
                      titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                      title: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Avatar
                          _GlassAvatar(initials: initials),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Admin Console',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 16, fontWeight: FontWeight.w900,
                                    color: AppColors.textHigh,
                                  )),
                                Row(children: [
                                  _LiveDot(live: isLive),
                                  const SizedBox(width: 5),
                                  Text(isLive ? 'Live' : 'Connecting…',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 10,
                                      color: isLive ? AppColors.accent : AppColors.textLow,
                                    )),
                                ]),
                              ],
                            ),
                          ),
                          // Logout
                          GestureDetector(
                            onTap: _signOut,
                            child: _Glass(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              radius: BorderRadius.circular(20),
                              tint: AppColors.danger,
                              blur: 10,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.logout_rounded,
                                      color: AppColors.danger, size: 14),
                                  const SizedBox(width: 6),
                                  Text('Sign out',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 11, color: AppColors.danger,
                                      fontWeight: FontWeight.w700,
                                    )),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          // ── Error banner ───────────────────────────────
                          if (snap.hasError) ...[
                            _Glass(
                              tint: AppColors.danger,
                              child: Row(children: [
                                const Icon(Icons.wifi_off_rounded,
                                    color: AppColors.danger, size: 18),
                                const SizedBox(width: 10),
                                Expanded(child: Text('Could not reach Firestore',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 12, color: AppColors.danger))),
                              ]),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // ── Availability hero ──────────────────────────
                          _HeroAvailability(
                            available: s.availableForWork,
                            autoOn:    s.autoOn,
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              _service.toggle('available_for_work', !s.availableForWork);
                            },
                          ).animate().fadeIn(delay: 80.ms, duration: 500.ms)
                           .slideY(begin: .05, end: 0),

                          const SizedBox(height: 28),

                          // ── Site controls ──────────────────────────────
                          _SectionHeader(
                            icon:  Icons.tune_rounded,
                            label: 'Site Controls',
                            badge: '${[s.contactOpen, !s.maintenanceMode].where((v) => v).length}/2 active',
                          ).animate().fadeIn(delay: 140.ms),

                          const SizedBox(height: 14),

                          _GlassToggleCard(
                            icon:     Icons.mail_outline_rounded,
                            label:    'Contact Form',
                            subtitle: 'Allow visitors to send you messages',
                            value:    s.contactOpen,
                            color:    AppColors.accent,
                            onToggle: (v) => _service.toggle('contact_open', v),
                          ).animate().fadeIn(delay: 180.ms).slideX(begin: -.04, end: 0),

                          const SizedBox(height: 10),

                          _GlassToggleCard(
                            icon:     Icons.construction_rounded,
                            label:    'Maintenance Mode',
                            subtitle: 'Replace entire portfolio with a holding page',
                            value:    s.maintenanceMode,
                            color:    AppColors.warning,
                            onToggle: (v) => _service.toggle('maintenance_mode', v),
                          ).animate().fadeIn(delay: 220.ms).slideX(begin: -.04, end: 0),

                          if (s.maintenanceMode) ...[
                            const SizedBox(height: 8),
                            _Glass(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              tint: AppColors.warning,
                              radius: BorderRadius.circular(14),
                              child: Row(children: [
                                const Icon(Icons.warning_amber_rounded,
                                    color: AppColors.warning, size: 16),
                                const SizedBox(width: 10),
                                Expanded(child: Text(
                                  'Portfolio is offline for visitors right now',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 12, color: AppColors.warning),
                                )),
                              ]),
                            ).animate().fadeIn(duration: 300.ms).scale(
                                begin: const Offset(.95, .95)),
                          ],

                          const SizedBox(height: 10),

                          _GlassToggleCard(
                            icon:     Icons.bolt_rounded,
                            label:    'Auto On',
                            subtitle: 'Set Available when either app is opened',
                            value:    s.autoOn,
                            color:    AppColors.primary,
                            onToggle: (v) => _service.toggle('auto_on', v),
                          ).animate().fadeIn(delay: 260.ms).slideX(begin: -.04, end: 0),

                          const SizedBox(height: 28),

                          // ── Broadcasts ─────────────────────────────────
                          _SectionHeader(
                            icon:  Icons.campaign_rounded,
                            label: 'Broadcasts',
                          ).animate().fadeIn(delay: 300.ms),

                          const SizedBox(height: 14),

                          _GlassTextField(
                            icon:       Icons.sticky_note_2_outlined,
                            label:      'Featured Banner',
                            subtitle:   'Sticky banner shown across every page — leave blank to hide',
                            hint:       'e.g. Open to freelance projects…',
                            controller: _featuredCtrl,
                            maxLines:   2,
                            maxLength:  120,
                            onChanged:  (_) => setState(() => _textDirty = true),
                          ).animate().fadeIn(delay: 340.ms).slideY(begin: .04, end: 0),

                          const SizedBox(height: 12),

                          _GlassTextField(
                            icon:       Icons.smart_toy_outlined,
                            label:      "Kori's Opening Line",
                            subtitle:   "Overrides Kori's first chat bubble on the portfolio",
                            hint:       'e.g. Hey! Ask me anything about Emmanuel…',
                            controller: _greetingCtrl,
                            maxLines:   2,
                            maxLength:  160,
                            onChanged:  (_) => setState(() => _textDirty = true),
                          ).animate().fadeIn(delay: 380.ms).slideY(begin: .04, end: 0),

                          const SizedBox(height: 16),

                          if (_textDirty)
                            _SaveButton(saving: _savingText, onSave: _saveText)
                              .animate()
                              .fadeIn(duration: 250.ms)
                              .scale(begin: const Offset(.92, .92)),

                          const SizedBox(height: 28),

                          // ── Live preview ───────────────────────────────
                          _SectionHeader(
                            icon:  Icons.preview_rounded,
                            label: 'Live State',
                          ).animate().fadeIn(delay: 420.ms),

                          const SizedBox(height: 14),

                          _LivePreview(settings: s, isLive: isLive)
                            .animate().fadeIn(delay: 460.ms),

                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _initials(String email) {
    final parts = email.split('@').first.split(RegExp(r'[._\-]'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return email.substring(0, email.length.clamp(0, 2)).toUpperCase();
  }
}

// ─── Decorative blob ─────────────────────────────────────────────────────────

class _Blob extends StatelessWidget {
  final double size;
  final Color  color;
  const _Blob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color,
    ),
  );
}

// ─── Glass avatar ─────────────────────────────────────────────────────────────

class _GlassAvatar extends StatelessWidget {
  final String initials;
  const _GlassAvatar({required this.initials});

  @override
  Widget build(BuildContext context) => ClipOval(
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.accent.withOpacity(.12),
          border: Border.all(color: AppColors.accent.withOpacity(.35), width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text(initials,
          style: GoogleFonts.montserrat(
            fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.accent)),
      ),
    ),
  );
}

// ─── Live dot ────────────────────────────────────────────────────────────────

class _LiveDot extends StatefulWidget {
  final bool live;
  const _LiveDot({required this.live});

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, __) => Container(
      width: 7, height: 7,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.live ? AppColors.accent : AppColors.textLow,
        boxShadow: widget.live ? [
          BoxShadow(
            color: AppColors.accent.withOpacity(.5 * _ctrl.value),
            blurRadius: 6,
          ),
        ] : null,
      ),
    ),
  );
}

// ─── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String?  badge;
  const _SectionHeader({required this.icon, required this.label, this.badge});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: AppColors.accent, size: 16),
      const SizedBox(width: 8),
      Text(label.toUpperCase(),
        style: GoogleFonts.montserrat(
          fontSize: 11, fontWeight: FontWeight.w800,
          color: AppColors.textMid, letterSpacing: 1.8,
        )),
      if (badge != null) ...[
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.accent.withOpacity(.2)),
          ),
          child: Text(badge!,
            style: GoogleFonts.montserrat(
              fontSize: 10, color: AppColors.accent, fontWeight: FontWeight.w600)),
        ),
      ],
    ],
  );
}

// ─── Hero availability card ───────────────────────────────────────────────────

class _HeroAvailability extends StatelessWidget {
  final bool         available;
  final bool         autoOn;
  final VoidCallback onTap;
  const _HeroAvailability({
    required this.available,
    required this.autoOn,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color  = available ? AppColors.primary : AppColors.danger;
    final label  = available ? 'Available for Work' : 'Not Available';
    final sub    = available
        ? 'Visible as available on your portfolio'
        : 'Portfolio shows you as unavailable';

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            curve:    Curves.easeOutCubic,
            padding:  const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                colors: [
                  color.withOpacity(.18),
                  color.withOpacity(.05),
                  AppColors.surface.withOpacity(.6),
                ],
                begin: Alignment.topLeft,
                end:   Alignment.bottomRight,
              ),
              border: Border.all(color: color.withOpacity(.4), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color:      color.withOpacity(.25),
                  blurRadius: 32,
                  offset:     const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              children: [
                // Pulsing dot
                _PulsingDot(color: color),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                        style: GoogleFonts.montserrat(
                          fontSize: 20, fontWeight: FontWeight.w900,
                          color: AppColors.textHigh,
                        )),
                      const SizedBox(height: 4),
                      Text(sub,
                        style: GoogleFonts.montserrat(
                          fontSize: 12, color: AppColors.textMid)),
                      if (autoOn) ...[
                        const SizedBox(height: 6),
                        Row(children: [
                          Icon(Icons.bolt_rounded, size: 12, color: color),
                          const SizedBox(width: 4),
                          Text('Auto On active',
                            style: GoogleFonts.montserrat(
                              fontSize: 11, color: color,
                              fontWeight: FontWeight.w600)),
                        ]),
                      ],
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns:    available ? 0 : .5,
                  duration: const Duration(milliseconds: 500),
                  child:    Icon(Icons.toggle_on_rounded, color: color, size: 48),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Pulsing dot ─────────────────────────────────────────────────────────────

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, __) => Container(
      width: 20, height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.color,
        boxShadow: [
          BoxShadow(
            color:      widget.color.withOpacity(.6 * _ctrl.value),
            blurRadius: 14 * _ctrl.value,
            spreadRadius: 2 * _ctrl.value,
          ),
        ],
      ),
    ),
  );
}

// ─── Glass toggle card ────────────────────────────────────────────────────────

class _GlassToggleCard extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   subtitle;
  final bool     value;
  final Color    color;
  final ValueChanged<bool> onToggle;

  const _GlassToggleCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.color,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onToggle(!value);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve:    Curves.easeOutCubic,
            padding:  const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: value
                  ? color.withOpacity(.1)
                  : AppColors.surface.withOpacity(.55),
              border: Border.all(
                color: value ? color.withOpacity(.35) : AppColors.border.withOpacity(.6),
                width: 1,
              ),
              gradient: value ? LinearGradient(colors: [
                color.withOpacity(.12),
                color.withOpacity(.03),
              ]) : null,
            ),
            child: Row(
              children: [
                // Icon container
                AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    color: value
                        ? color.withOpacity(.2)
                        : AppColors.card.withOpacity(.8),
                    border: Border.all(
                      color: value ? color.withOpacity(.4) : AppColors.border,
                    ),
                  ),
                  child: Icon(icon,
                    color: value ? color : AppColors.textMid,
                    size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                        style: GoogleFonts.montserrat(
                          fontSize: 14, fontWeight: FontWeight.w700,
                          color: value ? AppColors.textHigh : AppColors.textMid,
                        )),
                      const SizedBox(height: 2),
                      Text(subtitle,
                        style: GoogleFonts.montserrat(
                          fontSize: 11, color: AppColors.textLow)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Switch.adaptive(
                  value:        value,
                  activeColor:  color,
                  onChanged:    onToggle,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Glass text field card ────────────────────────────────────────────────────

class _GlassTextField extends StatefulWidget {
  final IconData             icon;
  final String               label;
  final String               subtitle;
  final String               hint;
  final TextEditingController controller;
  final int                  maxLines;
  final int                  maxLength;
  final ValueChanged<String> onChanged;

  const _GlassTextField({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.hint,
    required this.controller,
    required this.maxLines,
    required this.maxLength,
    required this.onChanged,
  });

  @override
  State<_GlassTextField> createState() => _GlassTextFieldState();
}

class _GlassTextFieldState extends State<_GlassTextField> {
  late FocusNode _focus;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus = FocusNode()
      ..addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() { _focus.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final charCount = widget.controller.text.length;
    final pct       = charCount / widget.maxLength;
    final overLimit = pct > .85;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: AppColors.surface.withOpacity(.55),
            border: Border.all(
              color: _focused
                  ? AppColors.accent.withOpacity(.5)
                  : AppColors.border.withOpacity(.6),
              width: _focused ? 1.5 : 1,
            ),
            gradient: _focused ? LinearGradient(colors: [
              AppColors.accent.withOpacity(.07),
              Colors.transparent,
            ]) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(widget.icon, color: AppColors.accent, size: 17),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.label,
                        style: GoogleFonts.montserrat(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: AppColors.textMid)),
                      Text(widget.subtitle,
                        style: GoogleFonts.montserrat(
                          fontSize: 10, color: AppColors.textLow)),
                    ],
                  ),
                ),
                // Char count pill
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: overLimit
                        ? AppColors.warning.withOpacity(.15)
                        : AppColors.card.withOpacity(.8),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: overLimit
                          ? AppColors.warning.withOpacity(.3)
                          : AppColors.border,
                    ),
                  ),
                  child: Text('$charCount/${widget.maxLength}',
                    style: GoogleFonts.montserrat(
                      fontSize: 10,
                      color: overLimit ? AppColors.warning : AppColors.textLow,
                      fontWeight: FontWeight.w600,
                    )),
                ),
              ]),
              const SizedBox(height: 12),
              TextFormField(
                controller: widget.controller,
                focusNode:  _focus,
                maxLines:   widget.maxLines,
                onChanged:  (v) {
                  setState(() {});
                  widget.onChanged(v);
                },
                style: GoogleFonts.montserrat(
                  color: AppColors.textHigh, fontSize: 14),
                decoration: InputDecoration(
                  hintText:       widget.hint,
                  hintStyle:      GoogleFonts.montserrat(
                    color: AppColors.textLow, fontSize: 13),
                  border:         InputBorder.none,
                  enabledBorder:  InputBorder.none,
                  focusedBorder:  InputBorder.none,
                  filled:         false,
                  isDense:        true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Save button ──────────────────────────────────────────────────────────────

class _SaveButton extends StatelessWidget {
  final bool         saving;
  final VoidCallback onSave;
  const _SaveButton({required this.saving, required this.onSave});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: saving ? null : onSave,
            borderRadius: BorderRadius.circular(16),
            splashColor: AppColors.accent.withOpacity(.2),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(colors: [
                  AppColors.primary.withOpacity(saving ? .4 : .9),
                  AppColors.primary.withOpacity(saving ? .2 : .6),
                ]),
                border: Border.all(
                    color: AppColors.accent.withOpacity(.3), width: 1),
                boxShadow: [
                  BoxShadow(
                    color:      AppColors.primary.withOpacity(.35),
                    blurRadius: 20,
                    offset:     const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (saving)
                    const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                    )
                  else
                    const Icon(Icons.save_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 10),
                  Text(saving ? 'Saving…' : 'Save Changes',
                    style: GoogleFonts.montserrat(
                      fontSize: 14, fontWeight: FontWeight.w800,
                      color: Colors.white)),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

// ─── Live preview ─────────────────────────────────────────────────────────────

class _LivePreview extends StatelessWidget {
  final PortfolioSettings settings;
  final bool isLive;
  const _LivePreview({required this.settings, required this.isLive});

  @override
  Widget build(BuildContext context) => _Glass(
    padding: const EdgeInsets.all(22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.radio_button_checked,
              color: AppColors.accent, size: 14),
          const SizedBox(width: 8),
          Text('Firestore snapshot',
            style: GoogleFonts.montserrat(
              fontSize: 11, color: AppColors.textMid,
              fontWeight: FontWeight.w700, letterSpacing: .5)),
          const Spacer(),
          _LiveDot(live: isLive),
          const SizedBox(width: 5),
          Text(isLive ? 'Live' : '—',
            style: GoogleFonts.montserrat(
              fontSize: 10, color: AppColors.accent)),
        ]),
        const SizedBox(height: 16),
        Divider(color: AppColors.border.withOpacity(.5), height: 1),
        const SizedBox(height: 14),
        _Row('available_for_work',
            settings.availableForWork ? 'true' : 'false',
            settings.availableForWork ? AppColors.primary : AppColors.danger),
        _Row('contact_open',
            settings.contactOpen ? 'true' : 'false',
            settings.contactOpen ? AppColors.accent : AppColors.warning),
        _Row('maintenance_mode',
            settings.maintenanceMode ? 'true' : 'false',
            settings.maintenanceMode ? AppColors.warning : AppColors.textLow),
        _Row('auto_on',
            settings.autoOn ? 'true' : 'false',
            settings.autoOn ? AppColors.primary : AppColors.textLow),
        if (settings.featuredMessage.isNotEmpty)
          _Row('featured_message',
              '"${settings.featuredMessage}"', AppColors.textMid),
        if (settings.koriGreeting.isNotEmpty)
          _Row('kori_greeting',
              '"${settings.koriGreeting}"', AppColors.textMid),
      ],
    ),
  );

  Widget _Row(String k, String v, Color c) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$k: ',
          style: GoogleFonts.sourceCodePro(
            fontSize: 12, color: AppColors.textLow)),
        Expanded(
          child: Text(v,
            style: GoogleFonts.sourceCodePro(
              fontSize: 12, color: c, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}
