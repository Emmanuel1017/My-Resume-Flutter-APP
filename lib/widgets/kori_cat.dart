// ─────────────────────────────────────────────────────────────────────────────
// KoriCat — 2D stylized port of Angular's Three.js cat.
//
// Goal: capture the personality of the Three.js version (orange tabby, big green
// eyes, ear twitches, tail wag, idle breathing, expression changes, tap to boop)
// without dragging in a WebGL/3D dependency. Everything draws through a single
// CustomPainter against a small RepaintBoundary so the cat costs effectively
// nothing at idle.
//
// Animation budget — one master AnimationController at 60Hz driving all the
// derived timelines (breathing, tail, whiskers, ear twitches). Blink uses a
// second short controller because it's discrete. Pupils track a target offset
// updated on pointer events; expression is just an enum.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;
import 'package:flutter/material.dart';

enum KoriExpression { neutral, happy, thinking, surprised }

class KoriCat extends StatefulWidget {
  final double size;
  final KoriExpression expression;

  /// Globally normalized pointer (-1..1, -1..1). Used for pupil tracking when
  /// the parent wants to show the cat looking at the user's finger.
  final Offset? pointer;

  /// Fires when the cat is tapped.
  final VoidCallback? onTap;

  const KoriCat({
    super.key,
    this.size = 140,
    this.expression = KoriExpression.neutral,
    this.pointer,
    this.onTap,
  });

  @override
  State<KoriCat> createState() => _KoriCatState();
}

class _KoriCatState extends State<KoriCat> with TickerProviderStateMixin {
  // Master loop — drives breathing, tail, whisker drift, ear idle.
  late final AnimationController _master;
  // Blink — short, randomly retriggered.
  late final AnimationController _blink;
  // Boop reaction — short squish + surprised expression overlay.
  late final AnimationController _boop;

  final _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _master = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
    _boop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _scheduleBlink();
  }

  void _scheduleBlink() {
    // Re-blink every 2.5–5.5s. Cancelled implicitly on dispose.
    final ms = 2500 + _rng.nextInt(3000);
    Future.delayed(Duration(milliseconds: ms), () async {
      if (!mounted) return;
      await _blink.forward(from: 0).then((_) => _blink.reverse());
      if (mounted) _scheduleBlink();
    });
  }

  @override
  void dispose() {
    _master.dispose();
    _blink.dispose();
    _boop.dispose();
    super.dispose();
  }

  void _handleTap() {
    _boop.forward(from: 0);
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: RepaintBoundary(
        child: SizedBox(
          width:  widget.size,
          height: widget.size,
          child: AnimatedBuilder(
            // Combine the three controllers — one rebuild per frame for all three.
            animation: Listenable.merge([_master, _blink, _boop]),
            builder: (_, __) {
              // Pseudo-3D head turn: gentle yaw/pitch driven by the master
              // sine plus a stronger boop component. Wrapping the painter in
              // a Matrix4 perspective transform reads as a 3D headshot
              // without the cost of a real WebGL/Impeller 3D rig — exactly
              // the trade-off the rest of the app is built around.
              final yaw   = math.sin(_master.value * math.pi * 2 * 0.6) * 0.10
                          + (widget.pointer?.dx ?? 0) * 0.18;
              final pitch = math.sin(_master.value * math.pi * 2 * 0.4 + 1.2) * 0.05
                          + (widget.pointer?.dy ?? 0) * 0.10
                          - _boop.value * 0.12;
              return Transform(
                alignment: Alignment.center,
                // 0.0015 = subtle perspective depth — about a 350mm focal
                // length feel. Anything higher and the cat warps cartoonishly.
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0015)
                  ..rotateY(yaw)
                  ..rotateX(pitch),
                child: CustomPaint(
                  painter: _KoriPainter(
                    t:          _master.value,
                    blink:      _blink.value,
                    boop:       _boop.value,
                    pointer:    widget.pointer,
                    expression: widget.expression,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─── Painter ─────────────────────────────────────────────────────────────────
// Coordinates use the 0..1 box; we scale to the actual canvas size in paint().
class _KoriPainter extends CustomPainter {
  final double t;        // master loop 0..1
  final double blink;    // 0..1 (0 = open, 1 = closed)
  final double boop;     // 0..1 boop reaction progress
  final Offset? pointer; // global pointer normalized -1..1
  final KoriExpression expression;

  _KoriPainter({
    required this.t,
    required this.blink,
    required this.boop,
    required this.pointer,
    required this.expression,
  });

  // ── Palette ──────────────────────────────────────────────────────────────
  // Mirrors Angular Kori's tabby palette so the brand reads identical.
  static const _furBase  = Color(0xFFF4934A); // primary orange
  static const _furDark  = Color(0xFFD97A37); // tabby stripe
  static const _furLight = Color(0xFFFFB67A); // belly / cheek highlight
  static const _stripe   = Color(0xFF8A4A1F); // deep rust marking
  static const _eyeIris  = Color(0xFF7EC8A0); // mint-green iris
  static const _eyeRim   = Color(0xFF143D28); // limbal ring
  static const _ink      = Color(0xFF0D0810); // pupil / outlines
  static const _pink     = Color(0xFFEA6F90); // nose / inner ear
  static const _shadow   = Color(0x44000000);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;
    final r  = math.min(w, h) / 2;

    // Breathing — gentle 4s sine, scales body 0.98..1.02
    final breath = 1.0 + math.sin(t * math.pi * 2) * 0.02;

    // Boop squish — quick down-up
    final boopSquish = boop > 0
        ? math.sin(boop * math.pi) * 0.08
        : 0.0;

    // Tail wag — fast 2 Hz sine
    final tailWag = math.sin(t * math.pi * 4) * 0.35;

    // Ear twitch — independent, occasional flick on each ear
    final earL = math.sin(t * math.pi * 2 + 0.7) * 0.06;
    final earR = math.sin(t * math.pi * 2 + 2.4) * 0.06;

    // Pupil offset — track pointer if given, else slow drift
    final px = pointer?.dx.clamp(-1.0, 1.0) ??
        math.sin(t * math.pi * 2 * 0.4) * 0.35;
    final py = pointer?.dy.clamp(-1.0, 1.0) ??
        math.sin(t * math.pi * 2 * 0.3 + 1.3) * 0.25;

    // Surprised expression briefly forces wider eyes during boop
    final isSurprised =
        expression == KoriExpression.surprised || boop > 0;
    final isHappy    = expression == KoriExpression.happy;
    final isThinking = expression == KoriExpression.thinking;

    // ─── Tail (behind body) ──────────────────────────────────────────────
    canvas.save();
    canvas.translate(cx + r * 0.55, cy + r * 0.15);
    canvas.rotate(tailWag);
    _drawTail(canvas, r * 0.42);
    canvas.restore();

    // ─── Body shadow ─────────────────────────────────────────────────────
    final shadow = Paint()..color = _shadow;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy + r * 0.78),
        width:  r * 1.3,
        height: r * 0.18,
      ),
      shadow,
    );

    // ─── Body (oval) ─────────────────────────────────────────────────────
    canvas.save();
    canvas.translate(cx, cy + r * 0.4 + boopSquish * r);
    canvas.scale(breath, breath - boopSquish);
    _drawBody(canvas, r);
    canvas.restore();

    // ─── Head ────────────────────────────────────────────────────────────
    canvas.save();
    canvas.translate(cx, cy - r * 0.05 + boopSquish * r * 0.5);
    canvas.scale(breath, breath);
    _drawHead(canvas, r, earL, earR, isSurprised, isHappy, isThinking,
        px, py, blink);
    canvas.restore();
  }

  // ─── Tail — curling teardrop ────────────────────────────────────────────
  void _drawTail(Canvas canvas, double len) {
    final tail = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(len * 0.6, -len * 0.4, len * 0.9, -len * 0.9)
      ..quadraticBezierTo(len * 1.05, -len * 1.1, len * 0.95, -len * 1.25)
      ..quadraticBezierTo(len * 0.7, -len * 1.1, len * 0.55, -len * 0.7)
      ..quadraticBezierTo(len * 0.3, -len * 0.2, 0, len * 0.05)
      ..close();
    canvas.drawPath(
      tail,
      Paint()
        ..shader = const LinearGradient(
          colors: [_furBase, _furDark],
          begin:  Alignment.bottomLeft,
          end:    Alignment.topRight,
        ).createShader(Rect.fromLTWH(0, -len * 1.3, len, len * 1.3)),
    );
    // Tip lighter
    canvas.drawCircle(
      Offset(len * 0.93, -len * 1.18),
      len * 0.08,
      Paint()..color = _furLight,
    );
  }

  // ─── Body — round chest with white belly + stripes ──────────────────────
  void _drawBody(Canvas canvas, double r) {
    final body = Paint()
      ..shader = const RadialGradient(
        colors: [_furLight, _furBase, _furDark],
        stops:  [0.0, 0.55, 1.0],
        center: Alignment(-0.2, -0.3),
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: r));
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: r * 1.3, height: r * 1.1),
      body,
    );

    // Belly patch
    final belly = Paint()..color = Colors.white.withOpacity(.85);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, r * 0.18),
        width:  r * 0.55,
        height: r * 0.55,
      ),
      belly,
    );

    // Tabby stripes (3 curved arcs)
    final stripePaint = Paint()
      ..color = _stripe.withOpacity(.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.05
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final y  = -r * 0.2 + i * r * 0.18;
      final x0 = -r * 0.42;
      final x1 = -r * 0.05;
      final path = Path()
        ..moveTo(x0, y)
        ..quadraticBezierTo(-r * 0.22, y - r * 0.08, x1, y);
      canvas.drawPath(path, stripePaint);
    }

    // Front paws — two small ovals at base
    final paw = Paint()..color = _furBase;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-r * 0.25, r * 0.5),
        width: r * 0.22, height: r * 0.18),
      paw,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(r * 0.25, r * 0.5),
        width: r * 0.22, height: r * 0.18),
      paw,
    );
  }

  // ─── Head — circle + ears + face features ───────────────────────────────
  void _drawHead(Canvas canvas, double r, double earLTwitch, double earRTwitch,
      bool isSurprised, bool isHappy, bool isThinking,
      double pupilX, double pupilY, double blink) {
    // Ears (drawn before head fill so triangles read clean against head edge)
    _drawEar(canvas, r, isLeft: true,  twitch: earLTwitch);
    _drawEar(canvas, r, isLeft: false, twitch: earRTwitch);

    // Head circle
    final head = Paint()
      ..shader = const RadialGradient(
        colors: [_furLight, _furBase, _furDark],
        stops:  [0.0, 0.6, 1.0],
        center: Alignment(-0.25, -0.35),
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: r * 0.65));
    canvas.drawCircle(Offset.zero, r * 0.65, head);

    // Cheek tufts (lighter)
    final tuft = Paint()..color = _furLight.withOpacity(.55);
    canvas.drawCircle(Offset(-r * 0.48, r * 0.18), r * 0.13, tuft);
    canvas.drawCircle(Offset( r * 0.48, r * 0.18), r * 0.13, tuft);

    // Forehead M marking (signature tabby)
    final mPaint = Paint()
      ..color = _stripe.withOpacity(.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.045
      ..strokeCap = StrokeCap.round;
    final m = Path()
      ..moveTo(-r * 0.18, -r * 0.55)
      ..lineTo(-r * 0.09, -r * 0.40)
      ..lineTo(0,           -r * 0.55)
      ..lineTo( r * 0.09, -r * 0.40)
      ..lineTo( r * 0.18, -r * 0.55);
    canvas.drawPath(m, mPaint);

    // Eyes
    _drawEye(canvas, r, dx: -r * 0.22, pupilX: pupilX, pupilY: pupilY,
        blink: blink, isSurprised: isSurprised, isHappy: isHappy,
        isThinking: isThinking);
    _drawEye(canvas, r, dx:  r * 0.22, pupilX: pupilX, pupilY: pupilY,
        blink: blink, isSurprised: isSurprised, isHappy: isHappy,
        isThinking: isThinking);

    // Nose — pink triangle
    final nose = Path()
      ..moveTo(-r * 0.06, r * 0.10)
      ..lineTo( r * 0.06, r * 0.10)
      ..lineTo( 0,         r * 0.18)
      ..close();
    canvas.drawPath(nose, Paint()..color = _pink);

    // Mouth — depends on expression
    _drawMouth(canvas, r, isHappy, isSurprised, isThinking);

    // Whiskers — three each side, with subtle drift
    final whiskerPaint = Paint()
      ..color = Colors.white.withOpacity(.9)
      ..strokeWidth = r * 0.012
      ..strokeCap = StrokeCap.round;
    for (var i = -1; i <= 1; i++) {
      final yL = r * 0.18 + i * r * 0.05;
      final yR = r * 0.18 + i * r * 0.05;
      canvas.drawLine(
        Offset(-r * 0.18, yL),
        Offset(-r * 0.55, yL + i * r * 0.04),
        whiskerPaint,
      );
      canvas.drawLine(
        Offset(r * 0.18, yR),
        Offset(r * 0.55, yR + i * r * 0.04),
        whiskerPaint,
      );
    }
  }

  void _drawEar(Canvas canvas, double r,
      {required bool isLeft, required double twitch}) {
    canvas.save();
    final sign = isLeft ? -1.0 : 1.0;
    canvas.translate(sign * r * 0.42, -r * 0.48);
    canvas.rotate(sign * (0.15 + twitch));
    final outer = Path()
      ..moveTo(0, 0)
      ..lineTo(sign * r * 0.05, -r * 0.4)
      ..lineTo(sign * r * 0.3,  -r * 0.08)
      ..close();
    canvas.drawPath(outer, Paint()..color = _furBase);
    // Inner pink
    final inner = Path()
      ..moveTo(sign * r * 0.04, -r * 0.05)
      ..lineTo(sign * r * 0.07, -r * 0.30)
      ..lineTo(sign * r * 0.22, -r * 0.10)
      ..close();
    canvas.drawPath(inner, Paint()..color = _pink.withOpacity(.7));
    canvas.restore();
  }

  void _drawEye(Canvas canvas, double r,
      {required double dx,
      required double pupilX,
      required double pupilY,
      required double blink,
      required bool isSurprised,
      required bool isHappy,
      required bool isThinking}) {
    final eyeR = r * 0.13 * (isSurprised ? 1.18 : 1.0);
    final eyeC = Offset(dx, -r * 0.05);

    if (isHappy) {
      // Closed-arc happy eyes (^‿^)
      final arcPaint = Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.025
        ..strokeCap = StrokeCap.round;
      final rect = Rect.fromCenter(
          center: eyeC, width: eyeR * 2.2, height: eyeR * 2.0);
      canvas.drawArc(rect, math.pi, math.pi, false, arcPaint);
      return;
    }

    // White sclera (subtle — most of eye is iris but white peeks at top corners)
    canvas.drawCircle(
      eyeC,
      eyeR,
      Paint()..color = Colors.white,
    );

    // Iris
    canvas.drawCircle(
      eyeC,
      eyeR * 0.95,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFC6F0D8), _eyeIris, Color(0xFF4A9A70)],
          stops:  [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: eyeC, radius: eyeR)),
    );

    // Limbal ring
    canvas.drawCircle(
      eyeC,
      eyeR * 0.95,
      Paint()
        ..color = _eyeRim
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.015,
    );

    // Pupil — slit when thinking, wide when surprised, normal otherwise.
    final pupilOffset = Offset(pupilX * eyeR * 0.35, pupilY * eyeR * 0.35);
    final pupilCenter = eyeC + pupilOffset;
    final pw = eyeR * (isSurprised ? 0.55 : (isThinking ? 0.22 : 0.38));
    final ph = eyeR * (isThinking ? 0.78 : (isSurprised ? 0.55 : 0.65));
    canvas.drawOval(
      Rect.fromCenter(center: pupilCenter, width: pw * 2, height: ph * 2),
      Paint()..color = _ink,
    );

    // Catchlight — small white highlight upper-right
    canvas.drawOval(
      Rect.fromCenter(
        center: pupilCenter + Offset(pw * 0.6, -ph * 0.5),
        width:  eyeR * 0.18,
        height: eyeR * 0.16,
      ),
      Paint()..color = Colors.white.withOpacity(.95),
    );

    // Blink — overlay an orange "lid" sliding down based on blink progress.
    if (blink > 0.01) {
      final lidH = eyeR * 2.1 * blink;
      canvas.drawRect(
        Rect.fromLTWH(eyeC.dx - eyeR * 1.1, eyeC.dy - eyeR * 1.1,
            eyeR * 2.2, lidH),
        Paint()..color = _furBase,
      );
    }
  }

  void _drawMouth(Canvas canvas, double r,
      bool isHappy, bool isSurprised, bool isThinking) {
    final p = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.022
      ..strokeCap = StrokeCap.round;

    if (isSurprised) {
      // Small o
      canvas.drawCircle(
        Offset(0, r * 0.28),
        r * 0.045,
        Paint()..color = _ink,
      );
      return;
    }

    if (isThinking) {
      // Slight off-center smirk
      final mouth = Path()
        ..moveTo(-r * 0.05, r * 0.26)
        ..quadraticBezierTo(r * 0.02, r * 0.30, r * 0.08, r * 0.25);
      canvas.drawPath(mouth, p);
      return;
    }

    // Default w-mouth (happy or neutral, slightly more upturned when happy)
    final lift = isHappy ? r * 0.04 : 0.0;
    final mouth = Path()
      ..moveTo(0, r * 0.18)
      ..lineTo(0, r * 0.24)
      ..moveTo(0, r * 0.24)
      ..quadraticBezierTo(-r * 0.05, r * 0.30 + lift, -r * 0.10, r * 0.25)
      ..moveTo(0, r * 0.24)
      ..quadraticBezierTo( r * 0.05, r * 0.30 + lift,  r * 0.10, r * 0.25);
    canvas.drawPath(mouth, p);
  }

  @override
  bool shouldRepaint(_KoriPainter old) =>
      old.t          != t ||
      old.blink      != blink ||
      old.boop       != boop ||
      old.expression != expression ||
      old.pointer    != pointer;
}
