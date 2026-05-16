import 'dart:math';
import 'package:flutter/material.dart';

/// Draws the Angular shield logo — the iconic red "A" on a shield.
class AngularLogo extends StatelessWidget {
  final double size;
  const AngularLogo({super.key, this.size = 48});

  @override
  Widget build(BuildContext context) => SizedBox(
    width:  size,
    height: size,
    child:  CustomPaint(painter: _AngularPainter()),
  );
}

class _AngularPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Shield gradient fill ──────────────────────────────────────────────────
    final shieldPath = Path();
    shieldPath.moveTo(w * .5,  0);
    shieldPath.lineTo(w,       h * .12);
    shieldPath.lineTo(w,       h * .62);
    shieldPath.quadraticBezierTo(w * .95, h * .88, w * .5, h);
    shieldPath.quadraticBezierTo(w * .05, h * .88, 0,      h * .62);
    shieldPath.lineTo(0,       h * .12);
    shieldPath.close();

    final shieldPaint = Paint()
      ..shader = LinearGradient(
        begin:  Alignment.topCenter,
        end:    Alignment.bottomCenter,
        colors: [const Color(0xFFDD0031), const Color(0xFFC3002F)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(shieldPath, shieldPaint);

    // ── White "A" ─────────────────────────────────────────────────────────────
    final textPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Outer "A" triangle
    final aPath = Path();
    final topX   = w * .50;
    final topY   = h * .18;
    final leftX  = w * .12;
    final leftY  = h * .80;
    final rightX = w * .88;
    final rightY = h * .80;
    final midY   = h * .55;

    // Left leg
    aPath.moveTo(topX,        topY);
    aPath.lineTo(w * .30,     leftY);
    aPath.lineTo(w * .42,     leftY);
    aPath.lineTo(topX,        h * .36);
    aPath.lineTo(w * .58,     h * .36);
    aPath.lineTo(w * .70,     leftY);
    aPath.lineTo(rightX,      rightY);
    aPath.lineTo(topX,        topY);
    aPath.close();

    // Crossbar cutout
    final crossbar = Path();
    crossbar.addRect(Rect.fromLTWH(w * .36, midY - h * .05, w * .28, h * .10));

    final aWithCutout = Path.combine(PathOperation.difference, aPath, crossbar);
    canvas.drawPath(aWithCutout, textPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Animated glowing version used on the splash screen.
class AngularLogoGlow extends StatefulWidget {
  final double size;
  const AngularLogoGlow({super.key, this.size = 72});

  @override
  State<AngularLogoGlow> createState() => _AngularLogoGlowState();
}

class _AngularLogoGlowState extends State<AngularLogoGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _glow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _glow = Tween<double>(begin: 8, end: 28).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glow,
      builder: (_, child) => Container(
        decoration: BoxDecoration(
          shape:      BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color:      const Color(0xFFDD0031).withOpacity(.45),
              blurRadius: _glow.value,
              spreadRadius: _glow.value * .3,
            ),
          ],
        ),
        child: child,
      ),
      child: AngularLogo(size: widget.size),
    );
  }
}
