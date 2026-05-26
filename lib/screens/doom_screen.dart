import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// DOOM game screen — native Kotlin DOOM engine via platform channel.
/// Atmospheric UI with CRT scanlines, blood drips, pulsing hellfire glow.
class DoomScreen extends StatefulWidget {
  const DoomScreen({super.key});

  @override
  State<DoomScreen> createState() => _DoomScreenState();
}

class _DoomScreenState extends State<DoomScreen> with TickerProviderStateMixin {
  static const _platform = MethodChannel('com.example.portfolio_admin/doom');

  bool _doom1Cached = false;
  bool _doom2Cached = false;
  bool _isCheckingCache = true;

  String _currentFact = '';
  Timer? _factTimer;
  String _glitchText = '';
  Timer? _glitchTimer;

  late AnimationController _pulseController;
  late AnimationController _flickerController;

  final List<DoomGame> _games = [
    DoomGame(
      id: 'DOOM1',
      title: 'DOOM',
      subtitle: 'Knee-Deep in the Dead',
      year: 1993,
      description:
          'The shareware episode that started it all. Fight through Phobos base against demons from Hell.',
      coverImage: 'assets/doom/doom1-cover.jpg',
    ),
    DoomGame(
      id: 'DOOM2',
      title: 'DOOM II',
      subtitle: 'Hell on Earth',
      year: 1994,
      description:
          'The demons have invaded Earth. Bigger maps, more monsters, the Super Shotgun.',
      coverImage: 'assets/doom/doom2-cover.jpg',
    ),
  ];

  final List<String> _funFacts = [
    'Doom has been ported to ATMs, pregnancy tests, and IKEA smart lamps.',
    'The original DOOM.EXE is only 730KB.',
    'John Carmack wrote the engine in just a few months.',
    'Doom runs on a calculator, a fridge, a tractor, and now... a resume.',
    'The BFG stands for "Big Friendly Gun" (sure it does).',
    'At its peak, Doom was installed on more PCs than Windows 95.',
    'id Software released the source code in 1997 — spawning thousands of ports.',
    'Doom was so popular it nearly crashed university networks.',
    'The Cyberdemon has 4000 hit points. Good luck.',
    'Kori the cat could probably speedrun E1M1 in under 9 seconds.',
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _flickerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    )..repeat(reverse: true);

    _rotateFact();
    _factTimer = Timer.periodic(const Duration(seconds: 6), (_) => _rotateFact());
    _startGlitch();
    _checkCachedWads();
  }

  @override
  void dispose() {
    _factTimer?.cancel();
    _glitchTimer?.cancel();
    _pulseController.dispose();
    _flickerController.dispose();
    super.dispose();
  }

  void _rotateFact() {
    if (mounted) {
      setState(() {
        _currentFact = _funFacts[math.Random().nextInt(_funFacts.length)];
      });
    }
  }

  void _startGlitch() {
    const chars = '!@#\$%^&*()_+-=[]{}|;:,.<>?/~`0123456789ABCDEF';
    _glitchTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (mounted) {
        setState(() {
          _glitchText = List.generate(
            5 + math.Random().nextInt(4),
            (_) => chars[math.Random().nextInt(chars.length)],
          ).join();
        });
      }
    });
  }

  Future<void> _checkCachedWads() async {
    try {
      final doom1 = await _platform.invokeMethod('isWadCached', {'game': 'DOOM1'});
      final doom2 = await _platform.invokeMethod('isWadCached', {'game': 'DOOM2'});
      if (mounted) {
        setState(() {
          _doom1Cached = doom1 as bool;
          _doom2Cached = doom2 as bool;
          _isCheckingCache = false;
        });
      }
    } catch (e) {
      debugPrint('[DOOM] Error checking cache: $e');
      if (mounted) setState(() => _isCheckingCache = false);
    }
  }

  Future<void> _launchGame(DoomGame game) async {
    HapticFeedback.mediumImpact();
    try {
      await _platform.invokeMethod('launchDoom', {'game': game.id});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error launching DOOM: $e'),
            backgroundColor: const Color(0xFFc41e1e),
          ),
        );
      }
    }
  }

  bool _isCached(DoomGame game) =>
      game.id == 'DOOM1' ? _doom1Cached : _doom2Cached;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Stack(
        children: [
          // Hellfire ambient glow — pulsing red from bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 300,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.bottomCenter,
                      radius: 1.2,
                      colors: [
                        const Color(0xFFc41e1e).withOpacity(0.08 + _pulseController.value * 0.06),
                        Colors.transparent,
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // CRT scanlines overlay
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _ScanlinePainter()),
            ),
          ),

          // Faint background pattern
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/branding/icon.png'),
                    fit: BoxFit.none,
                    opacity: 0.015,
                    repeat: ImageRepeat.repeat,
                  ),
                ),
              ),
            ),
          ),

          // Blood drip accents (top edge)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 60,
              child: CustomPaint(painter: _BloodDripPainter()),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildGameSelection()),
                _buildFooter(),
              ],
            ),
          ),

          // Vignette overlay
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.5),
                    ],
                    radius: 1.1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a0a0a),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      builder: (context) => const _DoomSettingsSheet(),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        children: [
          // Glitch text decoration left
          Row(
            children: [
              AnimatedBuilder(
                animation: _flickerController,
                builder: (context, child) {
                  return Opacity(
                    opacity: 0.3 + _flickerController.value * 0.5,
                    child: Text(
                      _glitchText,
                      style: GoogleFonts.sourceCodePro(
                        fontSize: 10,
                        color: const Color(0xFF00ff41),
                        letterSpacing: 1,
                      ),
                    ),
                  );
                },
              ),
              const Spacer(),
              // Settings gear
              GestureDetector(
                onTap: _showSettings,
                child: Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFF00ff41).withOpacity(0.4),
                    ),
                    color: const Color(0xFF00ff41).withOpacity(0.05),
                  ),
                  child: const Icon(
                    Icons.settings,
                    color: Color(0xFF00ff41),
                    size: 18,
                  ),
                ),
              ),
              // Doomguy face easter egg
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFc41e1e).withOpacity(0.4),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Image.asset(
                    'assets/doom/doomguy-face.jpg',
                    fit: BoxFit.cover,
                  ),
                ),
              ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                    duration: 2000.ms,
                    begin: const Offset(1, 1),
                    end: const Offset(1.05, 1.05),
                  ),
            ],
          ),

          const SizedBox(height: 12),

          // Main title with layered glitch effect
          Stack(
            children: [
              // Red offset layer (glitch)
              Transform.translate(
                offset: const Offset(2, 0),
                child: Text(
                  'CAN IT RUN DOOM?',
                  style: GoogleFonts.sourceCodePro(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFc41e1e).withOpacity(0.3),
                    letterSpacing: 2,
                  ),
                ),
              ),
              // Cyan offset layer (glitch)
              Transform.translate(
                offset: const Offset(-2, 0),
                child: Text(
                  'CAN IT RUN DOOM?',
                  style: GoogleFonts.sourceCodePro(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF00BFFF).withOpacity(0.15),
                    letterSpacing: 2,
                  ),
                ),
              ),
              // Stroke outline
              Text(
                'CAN IT RUN DOOM?',
                style: GoogleFonts.sourceCodePro(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 2
                    ..color = const Color(0xFFc41e1e).withOpacity(0.5),
                  letterSpacing: 2,
                ),
              ),
              // Main text
              Text(
                'CAN IT RUN DOOM?',
                style: GoogleFonts.sourceCodePro(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFc41e1e),
                  letterSpacing: 2,
                  shadows: [
                    Shadow(
                      color: const Color(0xFFc41e1e).withOpacity(0.9),
                      blurRadius: 12,
                    ),
                    Shadow(
                      color: const Color(0xFFc41e1e).withOpacity(0.4),
                      blurRadius: 40,
                    ),
                  ],
                ),
              ),
            ],
          ).animate(onPlay: (c) => c.repeat()).shimmer(
                duration: 3000.ms,
                color: const Color(0xFFff6b00).withOpacity(0.3),
              ),

          const SizedBox(height: 10),

          // Subtitle with typewriter feel
          Text(
            'Doom runs on calculators, fridges, pregnancy tests...',
            textAlign: TextAlign.center,
            style: GoogleFonts.sourceCodePro(
              fontSize: 11,
              color: Colors.white54,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '...and now, here. Because why not?',
            textAlign: TextAlign.center,
            style: GoogleFonts.sourceCodePro(
              fontSize: 11,
              color: const Color(0xFFff6b00),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),

          const SizedBox(height: 8),

          // Native Kotlin badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: const Color(0xFF7F52FF).withOpacity(0.6),
              ),
              color: const Color(0xFF7F52FF).withOpacity(0.1),
            ),
            child: Text(
              'NATIVE KOTLIN PORT • NO EMULATION • FULL SOURCE PORT',
              style: GoogleFonts.sourceCodePro(
                fontSize: 9,
                color: const Color(0xFF7F52FF),
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Terminal-style divider
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  const Color(0xFFc41e1e).withOpacity(0.6),
                  const Color(0xFF00ff41).withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: -0.15);
  }

  Widget _buildFactTicker() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0d0d0d),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1a1a1a)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00ff41).withOpacity(0.05),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF00ff41),
              borderRadius: BorderRadius.circular(2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00ff41).withOpacity(0.5),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '// FUN_FACT.log',
                  style: GoogleFonts.sourceCodePro(
                    fontSize: 9,
                    color: const Color(0xFF00ff41).withOpacity(0.7),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _currentFact,
                  style: GoogleFonts.montserrat(
                    fontSize: 11,
                    color: Colors.white70,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate(key: ValueKey(_currentFact)).fadeIn(duration: 400.ms);
  }

  Widget _buildGameSelection() {
    if (_isCheckingCache) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFFc41e1e)),
            const SizedBox(height: 16),
            Text(
              'SCANNING HELL PORTAL...',
              style: GoogleFonts.sourceCodePro(
                fontSize: 12,
                color: const Color(0xFF00ff41),
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _buildFactTicker(),
          const SizedBox(height: 4),
          ..._games.asMap().entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildGameCard(entry.value, entry.key),
              )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildGameCard(DoomGame game, int index) {
    final cached = _isCached(game);

    return GestureDetector(
      onTap: () => _launchGame(game),
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0f0f0f),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFc41e1e).withOpacity(0.2 + _pulseController.value * 0.1),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFc41e1e).withOpacity(0.05 + _pulseController.value * 0.04),
                  blurRadius: 16,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: child,
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image with hellfire gradient
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Image.asset(
                    game.coverImage,
                    height: 170,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                // Dark overlay with red tint
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.5, 1.0],
                        colors: [
                          const Color(0xFFc41e1e).withOpacity(0.1),
                          Colors.transparent,
                          const Color(0xFF0f0f0f),
                        ],
                      ),
                    ),
                  ),
                ),
                // Cached badge
                if (cached)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF00ff41).withOpacity(0.8),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00ff41).withOpacity(0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, size: 12, color: const Color(0xFF00ff41)),
                          const SizedBox(width: 4),
                          Text(
                            'CACHED',
                            style: GoogleFonts.sourceCodePro(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF00ff41),
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Year badge top-left
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFF00ff41).withOpacity(0.4),
                      ),
                    ),
                    child: Text(
                      '${game.year}',
                      style: GoogleFonts.sourceCodePro(
                        fontSize: 10,
                        color: const Color(0xFF00ff41),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Content section
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title with glow
                  Text(
                    game.title,
                    style: GoogleFonts.sourceCodePro(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFc41e1e),
                      letterSpacing: 1,
                      shadows: [
                        Shadow(
                          color: const Color(0xFFc41e1e).withOpacity(0.6),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    game.subtitle,
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      color: const Color(0xFFff6b00),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    game.description,
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      color: Colors.white54,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Action button
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFc41e1e).withOpacity(0.2),
                          const Color(0xFF1a1a1a),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFc41e1e).withOpacity(0.6),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          cached ? Icons.play_arrow_rounded : Icons.download_rounded,
                          color: const Color(0xFFc41e1e),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          cached ? 'RIP AND TEAR' : 'DOWNLOAD & RUN',
                          style: GoogleFonts.sourceCodePro(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate(delay: (150 + index * 100).ms).fadeIn().slideY(begin: 0.1);
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        children: [
          Container(
            height: 1,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  const Color(0xFFc41e1e).withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Text(
            '"If it has a processor, it can run Doom."',
            textAlign: TextAlign.center,
            style: GoogleFonts.sourceCodePro(
              fontSize: 10,
              color: Colors.white30,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '— Ancient Internet Proverb',
            textAlign: TextAlign.center,
            style: GoogleFonts.sourceCodePro(
              fontSize: 9,
              color: const Color(0xFFc41e1e).withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'NATIVE KOTLIN ENGINE • FULL C++ PORT • EMMANUEL1017',
            textAlign: TextAlign.center,
            style: GoogleFonts.sourceCodePro(
              fontSize: 8,
              color: Colors.white.withOpacity(0.2),
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 600.ms);
  }
}

/// CRT scanlines — subtle horizontal lines across the entire screen.
class _ScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.08)
      ..strokeWidth = 1;

    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Blood drip accents along the top edge.
class _BloodDripPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFc41e1e).withOpacity(0.6)
      ..style = PaintingStyle.fill;

    final random = math.Random(42);
    for (int i = 0; i < 12; i++) {
      final x = random.nextDouble() * size.width;
      final dripHeight = 8.0 + random.nextDouble() * 35;
      final width = 2.0 + random.nextDouble() * 3;

      final path = Path()
        ..moveTo(x - width / 2, 0)
        ..lineTo(x + width / 2, 0)
        ..lineTo(x + width / 3, dripHeight - 4)
        ..quadraticBezierTo(x, dripHeight, x - width / 3, dripHeight - 4)
        ..close();

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class DoomGame {
  final String id;
  final String title;
  final String subtitle;
  final int year;
  final String description;
  final String coverImage;

  DoomGame({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.year,
    required this.description,
    required this.coverImage,
  });
}

class _DoomSettingsSheet extends StatefulWidget {
  const _DoomSettingsSheet();

  @override
  State<_DoomSettingsSheet> createState() => _DoomSettingsSheetState();
}

class _DoomSettingsSheetState extends State<_DoomSettingsSheet> {
  bool _vsync = true;
  int _frameRate = 60;
  String _renderer = 'vulkan';
  bool _parallelRender = false;
  String _colorDepth = 'truecolor';
  int _gamma = 0;
  bool _smoothScaling = true;
  bool _showFps = false;
  String _screenSize = 'full';
  bool _sfxEnabled = true;
  bool _musicEnabled = true;
  int _swipeSensitivity = 8;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _vsync = prefs.getBool('doom_vsync') ?? true;
      _frameRate = prefs.getInt('doom_framerate') ?? 60;
      _renderer = prefs.getString('doom_renderer') ?? 'vulkan';
      _parallelRender = prefs.getBool('doom_parallel') ?? false;
      _colorDepth = prefs.getString('doom_colordepth') ?? 'truecolor';
      _gamma = prefs.getInt('doom_gamma') ?? 0;
      _smoothScaling = prefs.getBool('doom_smooth') ?? true;
      _showFps = prefs.getBool('doom_showfps') ?? false;
      _screenSize = prefs.getString('doom_screensize') ?? 'full';
      _sfxEnabled = prefs.getBool('doom_sfx') ?? true;
      _musicEnabled = prefs.getBool('doom_music') ?? true;
      _swipeSensitivity = prefs.getInt('doom_swipe_sensitivity') ?? 8;
    });
  }

  Future<void> _save(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) prefs.setBool(key, value);
    if (value is int) prefs.setInt(key, value);
    if (value is String) prefs.setString(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFc41e1e).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'ENGINE SETTINGS',
              style: GoogleFonts.sourceCodePro(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: const Color(0xFFc41e1e),
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Native Kotlin DOOM engine configuration',
              style: GoogleFonts.sourceCodePro(
                fontSize: 10,
                color: Colors.white38,
              ),
            ),
            const SizedBox(height: 20),

            // --- DISPLAY ---
            _sectionHeader('DISPLAY'),
            const SizedBox(height: 10),

            _settingRow(
              'V-SYNC',
              'Lock framerate to display refresh',
              trailing: Switch(
                value: _vsync,
                activeColor: const Color(0xFF00ff41),
                onChanged: (v) {
                  setState(() => _vsync = v);
                  _save('doom_vsync', v);
                },
              ),
            ),
            const SizedBox(height: 10),

            _settingRow(
              'FRAME RATE',
              '$_frameRate FPS target',
              trailing: DropdownButton<int>(
                value: _frameRate,
                dropdownColor: const Color(0xFF1a0a0a),
                style: GoogleFonts.sourceCodePro(fontSize: 12, color: const Color(0xFF00ff41)),
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 30, child: Text('30')),
                  DropdownMenuItem(value: 35, child: Text('35')),
                  DropdownMenuItem(value: 60, child: Text('60')),
                  DropdownMenuItem(value: 120, child: Text('120')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _frameRate = v);
                  _save('doom_framerate', v);
                },
              ),
            ),
            const SizedBox(height: 10),

            _settingRow(
              'SHOW FPS',
              'Display frame counter overlay',
              trailing: Switch(
                value: _showFps,
                activeColor: const Color(0xFF00ff41),
                onChanged: (v) {
                  setState(() => _showFps = v);
                  _save('doom_showfps', v);
                },
              ),
            ),
            const SizedBox(height: 10),

            _settingRow(
              'SCREEN SIZE',
              _screenSize == 'full' ? 'Fullscreen (no HUD border)' : 'Classic (with border)',
              trailing: DropdownButton<String>(
                value: _screenSize,
                dropdownColor: const Color(0xFF1a0a0a),
                style: GoogleFonts.sourceCodePro(fontSize: 12, color: const Color(0xFF00ff41)),
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'full', child: Text('Full')),
                  DropdownMenuItem(value: 'classic', child: Text('Classic')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _screenSize = v);
                  _save('doom_screensize', v);
                },
              ),
            ),
            const SizedBox(height: 16),

            // --- GRAPHICS ---
            _sectionHeader('GRAPHICS'),
            const SizedBox(height: 10),

            _settingRow(
              'RENDERER',
              _renderer == 'vulkan' ? 'Vulkan (preferred)' : 'OpenGL ES',
              trailing: DropdownButton<String>(
                value: _renderer,
                dropdownColor: const Color(0xFF1a0a0a),
                style: GoogleFonts.sourceCodePro(fontSize: 12, color: const Color(0xFF00ff41)),
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'vulkan', child: Text('Vulkan')),
                  DropdownMenuItem(value: 'opengl', child: Text('OpenGL ES')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _renderer = v);
                  _save('doom_renderer', v);
                },
              ),
            ),
            const SizedBox(height: 10),

            _settingRow(
              'COLOR DEPTH',
              {'indexed': '8-bit Indexed', 'hicolor': '16-bit HiColor', 'truecolor': '32-bit TrueColor'}[_colorDepth] ?? '32-bit',
              trailing: DropdownButton<String>(
                value: _colorDepth,
                dropdownColor: const Color(0xFF1a0a0a),
                style: GoogleFonts.sourceCodePro(fontSize: 12, color: const Color(0xFF00ff41)),
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'indexed', child: Text('8-bit')),
                  DropdownMenuItem(value: 'hicolor', child: Text('16-bit')),
                  DropdownMenuItem(value: 'truecolor', child: Text('32-bit')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _colorDepth = v);
                  _save('doom_colordepth', v);
                },
              ),
            ),
            const SizedBox(height: 10),

            _settingRow(
              'GAMMA',
              'Brightness correction: $_gamma',
              trailing: SizedBox(
                width: 120,
                child: Slider(
                  value: _gamma.toDouble(),
                  min: 0,
                  max: 4,
                  divisions: 4,
                  activeColor: const Color(0xFF00ff41),
                  onChanged: (v) {
                    setState(() => _gamma = v.toInt());
                    _save('doom_gamma', v.toInt());
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),

            _settingRow(
              'SMOOTH SCALING',
              'Bilinear filter on upscale',
              trailing: Switch(
                value: _smoothScaling,
                activeColor: const Color(0xFF00ff41),
                onChanged: (v) {
                  setState(() => _smoothScaling = v);
                  _save('doom_smooth', v);
                },
              ),
            ),
            const SizedBox(height: 10),

            _settingRow(
              'PARALLEL RENDER',
              'Multi-threaded scene drawing',
              trailing: Switch(
                value: _parallelRender,
                activeColor: const Color(0xFF00ff41),
                onChanged: (v) {
                  setState(() => _parallelRender = v);
                  _save('doom_parallel', v);
                },
              ),
            ),
            const SizedBox(height: 16),

            // --- CONTROLS ---
            _sectionHeader('CONTROLS'),
            const SizedBox(height: 10),

            _settingRow(
              'SWIPE SENSITIVITY',
              'Turn speed: ${_swipeSensitivity}px threshold (lower = faster)',
              trailing: SizedBox(
                width: 120,
                child: Slider(
                  value: _swipeSensitivity.toDouble(),
                  min: 2,
                  max: 20,
                  divisions: 9,
                  activeColor: const Color(0xFF00ff41),
                  onChanged: (v) {
                    setState(() => _swipeSensitivity = v.toInt());
                    _save('doom_swipe_sensitivity', v.toInt());
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // --- AUDIO ---
            _sectionHeader('AUDIO'),
            const SizedBox(height: 10),

            _settingRow(
              'SOUND EFFECTS',
              'In-game SFX playback',
              trailing: Switch(
                value: _sfxEnabled,
                activeColor: const Color(0xFF00ff41),
                onChanged: (v) {
                  setState(() => _sfxEnabled = v);
                  _save('doom_sfx', v);
                },
              ),
            ),
            const SizedBox(height: 10),

            _settingRow(
              'MUSIC',
              'MIDI music playback',
              trailing: Switch(
                value: _musicEnabled,
                activeColor: const Color(0xFF00ff41),
                onChanged: (v) {
                  setState(() => _musicEnabled = v);
                  _save('doom_music', v);
                },
              ),
            ),

            const SizedBox(height: 20),
            Center(
              child: Text(
                'Settings apply on next game launch',
                style: GoogleFonts.sourceCodePro(
                  fontSize: 9,
                  color: Colors.white24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: const Color(0xFFc41e1e).withOpacity(0.7),
            width: 3,
          ),
        ),
      ),
      child: Text(
        title,
        style: GoogleFonts.sourceCodePro(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: const Color(0xFFc41e1e).withOpacity(0.8),
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _settingRow(String title, String subtitle, {required Widget trailing}) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.sourceCodePro(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white70,
                  letterSpacing: 1,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.sourceCodePro(
                  fontSize: 9,
                  color: Colors.white30,
                ),
              ),
            ],
          ),
        ),
        trailing,
      ],
    );
  }
}
