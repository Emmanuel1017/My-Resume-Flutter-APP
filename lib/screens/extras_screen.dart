import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'doom_screen_simple.dart';
import 'relax_game_screen.dart';

/// Extras screen containing games and fun interactive elements
class ExtrasScreen extends StatelessWidget {
  const ExtrasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0a0a),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFFc41e1e).withOpacity(0.2),
                                const Color(0xFF00BFFF).withOpacity(0.2),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          child: const Icon(
                            Icons.extension_rounded,
                            color: Color(0xFF00ff41),
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'EXTRAS',
                                style: GoogleFonts.sourceCodePro(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF00ff41),
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Games & Interactive Elements',
                                style: GoogleFonts.montserrat(
                                  fontSize: 13,
                                  color: Colors.white60,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 100.ms).slideY(begin: -0.1),
            ),

            // Scanline divider
            SliverToBoxAdapter(
              child: Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      const Color(0xFF00ff41).withOpacity(0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Games Grid
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _GameCard(
                    title: 'CAN IT RUN DOOM?',
                    subtitle: 'Classic FPS • 1993/1994',
                    description: 'Doom runs on calculators, fridges, pregnancy tests...\nand now, your resume.',
                    color: const Color(0xFFc41e1e),
                    icon: Icons.videogame_asset_outlined,
                    coverAsset: 'assets/doom/doom1-cover.jpg',
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const DoomScreenSimple(game: 'doom1')),
                      );
                    },
                  ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.1),

                  const SizedBox(height: 16),

                  _GameCard(
                    title: 'RELAX GAME',
                    subtitle: 'Casual • Zen Mode',
                    description: 'Pop bubbles, chill out, and watch your score rise.\nPerfect for stress relief.',
                    color: const Color(0xFF00BFFF),
                    icon: Icons.bubble_chart_rounded,
                    coverAsset: null, // Will use gradient
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const RelaxGameScreen()),
                      );
                    },
                  ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.1),
                ]),
              ),
            ),

            // Footer
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  '"If it has a processor, it can run Doom."\n— Ancient Internet Proverb',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.sourceCodePro(
                    fontSize: 11,
                    color: Colors.white30,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ).animate().fadeIn(delay: 400.ms),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String description;
  final Color color;
  final IconData icon;
  final String? coverAsset;
  final VoidCallback onTap;

  const _GameCard({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.color,
    required this.icon,
    required this.coverAsset,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1a1a1a),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 20,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Image or Gradient
            Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                image: coverAsset != null
                    ? DecorationImage(
                        image: AssetImage(coverAsset!),
                        fit: BoxFit.cover,
                      )
                    : null,
                gradient: coverAsset == null
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          color.withOpacity(0.3),
                          color.withOpacity(0.1),
                          Colors.black,
                        ],
                      )
                    : null,
              ),
              child: Stack(
                children: [
                  // Overlay gradient
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            const Color(0xFF1a1a1a),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Icon badge
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: color.withOpacity(0.5),
                          width: 2,
                        ),
                      ),
                      child: Icon(icon, color: color, size: 28),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.sourceCodePro(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: color,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      color: Colors.white60,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    description,
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: color.withOpacity(0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.play_arrow_rounded, color: color, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'LAUNCH',
                          style: GoogleFonts.sourceCodePro(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: color,
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
    );
  }
}
