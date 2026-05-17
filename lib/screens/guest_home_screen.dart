import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/portfolio_service.dart';
import '../services/visit_tracker.dart';
import '../theme/app_theme.dart';
import '../widgets/marquee_label.dart';
import 'portfolio_screen.dart';
import 'profile_screen.dart';
import 'guest_contact_screen.dart';
import 'kori_screen.dart';

class GuestHomeScreen extends StatefulWidget {
  const GuestHomeScreen({super.key});

  @override
  State<GuestHomeScreen> createState() => _GuestHomeScreenState();
}

class _GuestHomeScreenState extends State<GuestHomeScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _triggerAutoOn();
  }

  Future<void> _triggerAutoOn() => PortfolioService().maybeFireAutoOn();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    VisitTracker.track(source: 'flutter-guest');
  }

  void _select(int i) {
    if (_tab == i) return;
    HapticFeedback.selectionClick();
    setState(() => _tab = i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_tab == 0) const PortfolioScreen(),
          if (_tab == 1) const KoriScreen(),
          if (_tab == 2) const ProfileScreen(),
          if (_tab == 3) const GuestContactScreen(),
        ],
      ),
      bottomNavigationBar: _GuestNavBar(selected: _tab, onSelect: _select),
    );
  }
}

// ─── Custom bottom nav ───────────────────────────────────────────────────────

class _GuestNavBar extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;
  const _GuestNavBar({required this.selected, required this.onSelect});

  static const _items = [
    _NavItem(icon: Icons.language_rounded,     label: 'Portfolio'),
    _NavItem(icon: Icons.auto_awesome_rounded, label: 'Kori'),
    _NavItem(icon: Icons.person_rounded,       label: 'Profile'),
    _NavItem(icon: Icons.mail_outline_rounded, label: 'Message'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(14, 0, 14, 10 + bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.border, width: .8),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withOpacity(.32),
              blurRadius: 22,
              offset:     const Offset(0, 6),
            ),
          ],
        ),
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(_items.length, (i) {
              final item   = _items[i];
              final active = i == selected;
              final color  = active ? AppColors.accent : AppColors.textLow;

              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap:    () => onSelect(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve:    Curves.easeOutCubic,
                        padding:  EdgeInsets.symmetric(
                          horizontal: active ? 18 : 0,
                          vertical:   4,
                        ),
                        decoration: BoxDecoration(
                          color:        active
                              ? AppColors.primary.withOpacity(.18)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(item.icon, color: color, size: 22),
                            if (active) ...[
                              const SizedBox(width: 5),
                              Flexible(
                                child: MarqueeLabel(
                                  text:  item.label,
                                  style: GoogleFonts.montserrat(
                                    fontSize:   12,
                                    fontWeight: FontWeight.w700,
                                    color:      color),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String   label;
  const _NavItem({required this.icon, required this.label});
}
