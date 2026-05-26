import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/portfolio_service.dart';
import '../services/fcm_service.dart';
import '../services/visit_tracker.dart';
import '../main.dart' show pendingHomeTab;
import '../widgets/marquee_label.dart';
import 'portfolio_screen.dart';
import 'profile_screen.dart';
import 'dashboard_screen.dart';
import 'messages_screen.dart';
import 'kori_screen.dart';
import 'extras_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  // Unread count lives at this level so only the bottom nav badge rebuilds —
  // the tab body widgets are completely unaffected.
  late final Stream<int> _unreadStream = FirebaseFirestore.instance
      .collection('contacts')
      .where('read', isEqualTo: false)
      .snapshots()
      .map((s) => s.docs.length);

  @override
  void initState() {
    super.initState();
    _triggerAutoOn();
    // Consume any FCM-tap-requested tab (e.g. tap a "new message" push from
    // terminated state → land directly on Messages).
    final requested = pendingHomeTab.value;
    if (requested != null) {
      _tab = requested.clamp(0, 5);
      pendingHomeTab.value = null;
    }
    // Update the tap-target callback (already-initialised init() will only
    // refresh `onOpenMessages`) and explicitly persist the FCM token now
    // that we know the user is signed in — covers the case where init
    // fired in main.dart before auth restored.
    FcmService.instance.init(
      onOpen: () => mounted ? setState(() => _tab = 5) : null,
    );
    FcmService.instance.ensureTokenSaved();
    VisitTracker.track(source: 'flutter-admin');
    // Reactively listen for taps while we're already on HomeScreen.
    pendingHomeTab.addListener(_onPendingTabChange);
  }

  void _onPendingTabChange() {
    final t = pendingHomeTab.value;
    if (t != null && mounted) {
      setState(() => _tab = t.clamp(0, 5));
      pendingHomeTab.value = null;
    }
  }

  @override
  void dispose() {
    pendingHomeTab.removeListener(_onPendingTabChange);
    super.dispose();
  }

  Future<void> _triggerAutoOn() => PortfolioService().maybeFireAutoOn();

  void _select(int i) {
    if (_tab == i) return; // guard: no setState if already on this tab
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
          // All tabs destroyed on leave — the GPU surface, Firestore streams,
          // and WebView Chromium instance are fully released.  The Android HTTP
          // disk cache serves the Angular site in ~300 ms on return (far cheaper
          // than keeping a live WebView surface pinned in GPU memory at all times).
          if (_tab == 0) const PortfolioScreen(),
          if (_tab == 1) const KoriScreen(),
          if (_tab == 2) const ProfileScreen(),
          if (_tab == 3) const ExtrasScreen(),
          if (_tab == 4) const DashboardScreen(),
          if (_tab == 5) const MessagesScreen(),
        ],
      ),
      // RepaintBoundary isolates the nav bar so unread-count updates never
      // trigger repaints elsewhere on screen.
      bottomNavigationBar: RepaintBoundary(
        child: StreamBuilder<int>(
          stream: _unreadStream,
          builder: (_, snap) => _NavBar(
            selected:    _tab,
            onSelect:    _select,
            unreadCount: snap.data ?? 0,
          ),
        ),
      ),
    );
  }
}

// ─── Custom bottom nav ────────────────────────────────────────────────────────

class _NavBar extends StatelessWidget {
  final int               selected;
  final ValueChanged<int> onSelect;
  final int               unreadCount;
  const _NavBar({
    required this.selected,
    required this.onSelect,
    required this.unreadCount,
  });

  static const _items = [
    _NavItem(icon: Icons.language_rounded,             label: 'Portfolio'),
    _NavItem(icon: Icons.auto_awesome_rounded,         label: 'Kori'),
    _NavItem(icon: Icons.person_rounded,               label: 'Profile'),
    _NavItem(icon: Icons.extension_rounded,            label: 'Extras'),
    _NavItem(icon: Icons.admin_panel_settings_rounded, label: 'Admin'),
    _NavItem(icon: Icons.inbox_rounded,                label: 'Messages'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom; // sizeOf avoids full MediaQuery rebuild
    // Floating pill: insets from screen edges, rounded corners, soft shadow.
    // SafeArea bottom inset is added as outer padding so the pill clears the
    // gesture bar instead of getting docked to it.
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
              final badge  = (i == 5 && unreadCount > 0 && !active)
                  ? unreadCount : 0;

              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap:    () => onSelect(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        curve:    Curves.easeOutCubic,
                        padding:  EdgeInsets.symmetric(
                          horizontal: active ? 10 : 0,
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
                            badge > 0
                                ? Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Icon(item.icon, color: color, size: 22),
                                      Positioned(
                                        top: -4, right: -6,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: AppColors.accent,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            badge > 99 ? '99+' : '$badge',
                                            style: const TextStyle(
                                              fontSize: 8,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.black),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : i == 3
                                    ? Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Icon(item.icon, color: color, size: 22),
                                          Positioned(
                                            top: -5, right: -7,
                                            child: Container(
                                              width: 14,
                                              height: 14,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(3),
                                                border: Border.all(
                                                  color: const Color(0xFFc41e1e),
                                                  width: 1,
                                                ),
                                              ),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(2),
                                                child: Image.asset(
                                                  'assets/doom/doomguy-face.jpg',
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    : Icon(item.icon, color: color, size: 22),

                            if (active) ...[
                              const SizedBox(width: 5),
                              // Flexible + _MarqueeLabel: text gets all remaining
                              // space in the row; marquee activates only when the
                              // label is genuinely wider than that space.
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
