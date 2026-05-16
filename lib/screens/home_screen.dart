import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/portfolio_service.dart';
import 'portfolio_screen.dart';
import 'profile_screen.dart';
import 'dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _triggerAutoOn();
  }

  Future<void> _triggerAutoOn() async {
    final s = await PortfolioService().stream().first;
    if (s.autoOn) {
      await PortfolioService().toggle('available_for_work', true);
    }
  }

  // Keep all three pages alive so WebView doesn't reload on tab switch
  static const _pages = [
    PortfolioScreen(),
    ProfileScreen(),
    DashboardScreen(),
  ];

  void _select(int i) {
    HapticFeedback.selectionClick();
    setState(() => _tab = i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      // IndexedStack keeps all pages mounted but only shows the active one
      body: IndexedStack(index: _tab, children: _pages),
      bottomNavigationBar: _NavBar(selected: _tab, onSelect: _select),
    );
  }
}

// ─── Custom bottom nav ───────────────────────────────────────────────────────

class _NavBar extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;
  const _NavBar({required this.selected, required this.onSelect});

  static const _items = [
    _NavItem(icon: Icons.language_rounded,          label: 'Portfolio'),
    _NavItem(icon: Icons.person_rounded,            label: 'Profile'),
    _NavItem(icon: Icons.admin_panel_settings_rounded, label: 'Admin'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: .8)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56 + bottom,
          child: Row(
            children: List.generate(_items.length, (i) {
              final item    = _items[i];
              final active  = i == selected;
              final color   = active ? AppColors.accent : AppColors.textLow;

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
                              const SizedBox(width: 6),
                              Text(
                                item.label,
                                style: GoogleFonts.montserrat(
                                  fontSize:   12,
                                  fontWeight: FontWeight.w700,
                                  color:      color,
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
