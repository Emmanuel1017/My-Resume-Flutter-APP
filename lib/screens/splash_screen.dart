import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/angular_logo.dart';

// Profile photos hosted on GitHub Pages
const _photos = [
  'https://emmanuel1017.github.io/Angular-Resume/assets/template/me_code.png',
  'https://emmanuel1017.github.io/Angular-Resume/assets/template/me_cyber.png',
  'https://emmanuel1017.github.io/Angular-Resume/assets/template/me_cyber_2.png',
  'https://emmanuel1017.github.io/Angular-Resume/assets/template/me_tricycle.png',
];

class SplashScreen extends StatefulWidget {
  final String nextRoute;
  const SplashScreen({super.key, required this.nextRoute});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _progressCtrl;
  late final AnimationController _orbitCtrl;

  @override
  void initState() {
    super.initState();

    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..forward();

    _orbitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    Future.delayed(const Duration(milliseconds: 3200), () {
      if (mounted) Navigator.of(context).pushReplacementNamed(widget.nextRoute);
    });
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    _orbitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          // ── Subtle grid background ────────────────────────────────────────
          Positioned.fill(child: _GridPainter()),

          // ── Orbiting photo bubbles ─────────────────────────────────────────
          Center(
            child: AnimatedBuilder(
              animation: _orbitCtrl,
              builder: (_, __) {
                return SizedBox(
                  width: 280,
                  height: 280,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Angular logo at centre
                      AngularLogoGlow(size: 72),

                      // Four orbiting photos
                      for (int i = 0; i < _photos.length; i++)
                        _OrbitingPhoto(
                          imageUrl:  _photos[i],
                          angle:     _orbitCtrl.value * 2 * pi + (i * pi / 2),
                          radius:    108,
                          size:      52 + (i % 2 == 0 ? 8.0 : 0.0),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),

          // ── Name + tagline ─────────────────────────────────────────────────
          Align(
            alignment: const Alignment(0, 0.35),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'KORIR EMMANUEL',
                  style: GoogleFonts.montserrat(
                    fontSize:      28,
                    fontWeight:    FontWeight.w900,
                    color:         AppColors.textHigh,
                    letterSpacing: 6,
                    shadows: [
                      Shadow(color: AppColors.primary.withOpacity(.7),  blurRadius: 12),
                      Shadow(color: AppColors.primary.withOpacity(.3),  blurRadius: 30),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(delay: 400.ms, duration: 700.ms)
                    .slideY(begin: .15, end: 0),

                const SizedBox(height: 8),

                Text(
                  'Portfolio Admin',
                  style: GoogleFonts.montserrat(
                    fontSize:      13,
                    fontWeight:    FontWeight.w500,
                    color:         AppColors.accent,
                    letterSpacing: 3,
                  ),
                )
                    .animate()
                    .fadeIn(delay: 700.ms, duration: 600.ms),
              ],
            ),
          ),

          // ── Progress bar ──────────────────────────────────────────────────
          Align(
            alignment: const Alignment(0, .72),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 56),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _progressCtrl,
                    builder: (_, __) => ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value:           CurvedAnimation(
                          parent: _progressCtrl,
                          curve:  Curves.easeInOut,
                        ).value,
                        backgroundColor: AppColors.border,
                        valueColor:      const AlwaysStoppedAnimation(AppColors.accent),
                        minHeight:       3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Connecting to Firebase…',
                    style: GoogleFonts.montserrat(
                      fontSize:   11,
                      color:      AppColors.textMid,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 600.ms),
        ],
      ),
    );
  }
}

// ─── Orbiting photo widget ──────────────────────────────────────────────────

class _OrbitingPhoto extends StatelessWidget {
  final String imageUrl;
  final double angle;
  final double radius;
  final double size;

  const _OrbitingPhoto({
    required this.imageUrl,
    required this.angle,
    required this.radius,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final x = cos(angle) * radius;
    final y = sin(angle) * radius;

    return Transform.translate(
      offset: Offset(x, y),
      child: Container(
        width:  size,
        height: size,
        decoration: BoxDecoration(
          shape:  BoxShape.circle,
          border: Border.all(color: AppColors.primary.withOpacity(.6), width: 2),
          boxShadow: [
            BoxShadow(
              color:      AppColors.accent.withOpacity(.15),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipOval(
          child: Image.network(
            imageUrl,
            fit:         BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: AppColors.card,
              child: const Icon(Icons.person, color: AppColors.textMid, size: 24),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Subtle dot-grid background ─────────────────────────────────────────────

class _GridPainter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _DotGridPainter());
  }
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color  = AppColors.border.withOpacity(.35)
      ..style  = PaintingStyle.fill;

    const gap = 28.0;
    for (double x = 0; x < size.width; x += gap) {
      for (double y = 0; y < size.height; y += gap) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
