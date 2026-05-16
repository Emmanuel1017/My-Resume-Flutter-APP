import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/portfolio_service.dart';
import '../theme/app_theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _service = PortfolioService();

  final _featuredCtrl = TextEditingController();
  final _greetingCtrl = TextEditingController();
  bool _textDirty     = false;

  PortfolioSettings? _current;

  @override
  void dispose() {
    _featuredCtrl.dispose();
    _greetingCtrl.dispose();
    super.dispose();
  }

  void _syncText(PortfolioSettings s) {
    if (!_textDirty) {
      _featuredCtrl.text = s.featuredMessage;
      _greetingCtrl.text = s.koriGreeting;
    }
    _current = s;
  }

  Future<void> _saveText() async {
    if (_current == null) return;
    await _service.save(_current!.copyWith(
      featuredMessage: _featuredCtrl.text,
      koriGreeting:    _greetingCtrl.text,
    ));
    setState(() => _textDirty = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saved  ✓',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.primary,
          behavior:        SnackBarBehavior.floating,
          shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin:          const EdgeInsets.all(16),
          duration:        const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: StreamBuilder<PortfolioSettings>(
        stream: _service.stream(),
        builder: (context, snap) {
          if (snap.hasData) _syncText(snap.data!);

          final s = snap.data ?? const PortfolioSettings();

          return CustomScrollView(
            slivers: [
              // ── App bar ──────────────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 110,
                pinned:         true,
                backgroundColor: AppColors.bg,
                surfaceTintColor: Colors.transparent,
                automaticallyImplyLeading: false,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(left: 20, bottom: 14),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Admin',
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w900,
                              fontSize:   18,
                              color:      AppColors.textHigh,
                            ),
                          ),
                          Text(
                            'Portfolio controls',
                            style: GoogleFonts.montserrat(
                              fontSize: 10,
                              color:    AppColors.textMid,
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 20),
                        child: GestureDetector(
                          onTap: () => FirebaseAuth.instance.signOut(),
                          child: Container(
                            padding:    const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color:        AppColors.card,
                              borderRadius: BorderRadius.circular(20),
                              border:       Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.logout_rounded,
                                    color: AppColors.textMid, size: 14),
                                const SizedBox(width: 6),
                                Text('Sign out',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 11,
                                    color:    AppColors.textMid,
                                    fontWeight: FontWeight.w600,
                                  )),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(color: AppColors.bg),
                      Positioned(
                        top:   -20,
                        right: -10,
                        child: Container(
                          width:  130,
                          height: 130,
                          decoration: BoxDecoration(
                            shape:    BoxShape.circle,
                            gradient: RadialGradient(colors: [
                              AppColors.primary.withOpacity(.15),
                              AppColors.primary.withOpacity(0),
                            ]),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),

                      // ── Status indicator ─────────────────────────────────
                      if (snap.connectionState == ConnectionState.waiting)
                        const _LoadingPulse()
                      else if (snap.hasError)
                        _ErrorCard(error: snap.error.toString()),

                      // ── Hero availability toggle ─────────────────────────
                      _HeroToggle(
                        available: s.availableForWork,
                        onTap: () => _service.toggle(
                          'available_for_work', !s.availableForWork,
                        ),
                      ).animate().fadeIn(delay: 100.ms, duration: 500.ms)
                       .slideY(begin: .06, end: 0),

                      const SizedBox(height: 24),

                      // ── Section heading ──────────────────────────────────
                      _SectionLabel('Quick Toggles'),

                      const SizedBox(height: 12),

                      // ── Toggle cards row ─────────────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: _ToggleCard(
                              icon:    Icons.mail_rounded,
                              label:   'Contact Form',
                              value:   s.contactOpen,
                              color:   AppColors.accent,
                              onToggle: (v) => _service.toggle('contact_open', v),
                            ).animate().fadeIn(delay: 200.ms).slideY(begin: .08, end: 0),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ToggleCard(
                              icon:    Icons.construction_rounded,
                              label:   'Maintenance',
                              value:   s.maintenanceMode,
                              color:   AppColors.warning,
                              onToggle: (v) => _service.toggle('maintenance_mode', v),
                            ).animate().fadeIn(delay: 280.ms).slideY(begin: .08, end: 0),
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      // ── Text fields ──────────────────────────────────────
                      _SectionLabel('Messages'),

                      const SizedBox(height: 12),

                      _TextCard(
                        icon:        Icons.campaign_rounded,
                        label:       'Featured Message',
                        hint:        'Banner shown across the portfolio…',
                        controller:  _featuredCtrl,
                        maxLines:    2,
                        onChanged:   (_) => setState(() => _textDirty = true),
                      ).animate().fadeIn(delay: 350.ms).slideY(begin: .06, end: 0),

                      const SizedBox(height: 14),

                      _TextCard(
                        icon:        Icons.chat_bubble_rounded,
                        label:       "Kori's Greeting",
                        hint:        'Opening line when Kori appears…',
                        controller:  _greetingCtrl,
                        maxLines:    2,
                        onChanged:   (_) => setState(() => _textDirty = true),
                      ).animate().fadeIn(delay: 420.ms).slideY(begin: .06, end: 0),

                      const SizedBox(height: 20),

                      if (_textDirty)
                        ElevatedButton.icon(
                          onPressed: _saveText,
                          icon:  const Icon(Icons.save_rounded, size: 18),
                          label: const Text('Save Changes'),
                        ).animate().fadeIn(duration: 300.ms).scale(begin: const Offset(.9, .9)),

                      const SizedBox(height: 40),

                      // ── Live preview ─────────────────────────────────────
                      _SectionLabel('Live Preview'),

                      const SizedBox(height: 12),

                      _PreviewCard(settings: s)
                          .animate().fadeIn(delay: 500.ms),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Hero availability toggle ────────────────────────────────────────────────

class _HeroToggle extends StatelessWidget {
  final bool     available;
  final VoidCallback onTap;
  const _HeroToggle({required this.available, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color  = available ? AppColors.primary : AppColors.danger;
    final label  = available ? 'Available for Work' : 'Not Available';
    final sublbl = available ? 'Tap to go unavailable' : 'Tap to go available';

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration:     const Duration(milliseconds: 400),
        curve:        Curves.easeOutCubic,
        padding:      const EdgeInsets.all(24),
        decoration:   BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient:     LinearGradient(
            colors: [
              color.withOpacity(.18),
              color.withOpacity(.06),
            ],
            begin: Alignment.topLeft,
            end:   Alignment.bottomRight,
          ),
          border: Border.all(color: color.withOpacity(.45), width: 1.5),
          boxShadow: [
            BoxShadow(
              color:      color.withOpacity(.2),
              blurRadius: 24,
              offset:     const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            // Animated status dot
            AnimatedContainer(
              duration:   const Duration(milliseconds: 400),
              width:  18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: [
                  BoxShadow(color: color.withOpacity(.6), blurRadius: 10),
                ],
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.montserrat(
                      fontSize:   18,
                      fontWeight: FontWeight.w800,
                      color:      AppColors.textHigh,
                    ),
                  ),
                  Text(
                    sublbl,
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      color:    AppColors.textMid,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedRotation(
              turns:    available ? 0 : .5,
              duration: const Duration(milliseconds: 400),
              child:    Icon(Icons.toggle_on_rounded, color: color, size: 42),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Toggle card ─────────────────────────────────────────────────────────────

class _ToggleCard extends StatelessWidget {
  final IconData icon;
  final String   label;
  final bool     value;
  final Color    color;
  final ValueChanged<bool> onToggle;

  const _ToggleCard({
    required this.icon,
    required this.label,
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
      child: AnimatedContainer(
        duration:   const Duration(milliseconds: 300),
        padding:    const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color:        value ? color.withOpacity(.12) : AppColors.card,
          border:       Border.all(
            color: value ? color.withOpacity(.4) : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: value ? color : AppColors.textMid, size: 22),
                Switch.adaptive(
                  value:           value,
                  activeColor:     color,
                  onChanged:       onToggle,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.montserrat(
                fontSize:   13,
                fontWeight: FontWeight.w600,
                color:      value ? color : AppColors.textMid,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Text card ───────────────────────────────────────────────────────────────

class _TextCard extends StatelessWidget {
  final IconData             icon;
  final String               label;
  final String               hint;
  final TextEditingController controller;
  final int                  maxLines;
  final ValueChanged<String> onChanged;

  const _TextCard({
    required this.icon,
    required this.label,
    required this.hint,
    required this.controller,
    required this.maxLines,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:     const EdgeInsets.all(18),
      decoration:  BoxDecoration(
        color:        AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.accent, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.montserrat(
                  fontSize:   13,
                  fontWeight: FontWeight.w700,
                  color:      AppColors.textMid,
                  letterSpacing: .5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: controller,
            maxLines:   maxLines,
            onChanged:  onChanged,
            style:      GoogleFonts.montserrat(
              color:    AppColors.textHigh,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText:    hint,
              hintStyle:   GoogleFonts.montserrat(
                color:    AppColors.textLow,
                fontSize: 13,
              ),
              border:         InputBorder.none,
              enabledBorder:  InputBorder.none,
              focusedBorder:  InputBorder.none,
              filled:         false,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Live preview card ───────────────────────────────────────────────────────

class _PreviewCard extends StatelessWidget {
  final PortfolioSettings settings;
  const _PreviewCard({required this.settings});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:     const EdgeInsets.all(20),
      decoration:  BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.preview_rounded, color: AppColors.textMid, size: 16),
              const SizedBox(width: 8),
              Text(
                'Live state',
                style: GoogleFonts.montserrat(
                  fontSize: 12, color: AppColors.textMid, fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                width:  8, height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Realtime',
                style: GoogleFonts.montserrat(fontSize: 11, color: AppColors.accent),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Row('Available for Work',
              settings.availableForWork ? 'Yes' : 'No',
              settings.availableForWork ? AppColors.primary : AppColors.danger),
          _Row('Contact Form',
              settings.contactOpen ? 'Open' : 'Closed',
              settings.contactOpen ? AppColors.accent : AppColors.warning),
          _Row('Maintenance Mode',
              settings.maintenanceMode ? 'ON' : 'Off',
              settings.maintenanceMode ? AppColors.warning : AppColors.textMid),
          if (settings.featuredMessage.isNotEmpty)
            _Row('Featured', settings.featuredMessage, AppColors.textMid),
          if (settings.koriGreeting.isNotEmpty)
            _Row('Kori says', '"${settings.koriGreeting}"', AppColors.textMid),
        ],
      ),
    );
  }

  Widget _Row(String k, String v, Color c) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(k,
            style: GoogleFonts.montserrat(fontSize: 12, color: AppColors.textMid)),
        ),
        Expanded(
          flex: 3,
          child: Text(v,
            style: GoogleFonts.montserrat(
              fontSize: 12, color: c, fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: GoogleFonts.montserrat(
      fontSize:      11,
      fontWeight:    FontWeight.w700,
      color:         AppColors.textLow,
      letterSpacing: 2,
    ),
  );
}

class _LoadingPulse extends StatelessWidget {
  const _LoadingPulse();
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child:   CircularProgressIndicator(
        strokeWidth: 2,
        color:       AppColors.primary,
      ),
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  final String error;
  const _ErrorCard({required this.error});
  @override
  Widget build(BuildContext context) => Container(
    margin:  const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color:        AppColors.danger.withOpacity(.1),
      borderRadius: BorderRadius.circular(12),
      border:       Border.all(color: AppColors.danger.withOpacity(.3)),
    ),
    child: Text(error,
      style: GoogleFonts.montserrat(fontSize: 12, color: AppColors.danger)),
  );
}
