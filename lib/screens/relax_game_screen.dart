import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Simple relaxing game: tap bubbles before they disappear
class RelaxGameScreen extends StatefulWidget {
  const RelaxGameScreen({super.key});

  @override
  State<RelaxGameScreen> createState() => _RelaxGameScreenState();
}

class _RelaxGameScreenState extends State<RelaxGameScreen>
    with TickerProviderStateMixin {
  final List<Bubble> _bubbles = [];
  int _score = 0;
  int _missed = 0;
  bool _isPlaying = false;
  final math.Random _random = math.Random();

  @override
  void dispose() {
    for (var bubble in _bubbles) {
      bubble.controller.dispose();
    }
    super.dispose();
  }

  void _startGame() {
    setState(() {
      _bubbles.clear();
      _score = 0;
      _missed = 0;
      _isPlaying = true;
    });
    _spawnBubble();
  }

  void _spawnBubble() {
    if (!_isPlaying) return;

    final size = MediaQuery.of(context).size;
    final bubbleSize = 60.0 + _random.nextDouble() * 40;

    final controller = AnimationController(
      duration: Duration(milliseconds: 2000 + _random.nextInt(2000)),
      vsync: this,
    );

    final bubble = Bubble(
      id: DateTime.now().millisecondsSinceEpoch,
      x: _random.nextDouble() * (size.width - bubbleSize),
      y: size.height + bubbleSize,
      size: bubbleSize,
      color: _randomColor(),
      controller: controller,
    );

    setState(() => _bubbles.add(bubble));

    controller.forward().then((_) {
      if (_isPlaying) {
        setState(() {
          _bubbles.removeWhere((b) => b.id == bubble.id);
          _missed++;
          if (_missed >= 10) {
            _endGame();
          }
        });
      }
    });

    // Spawn next bubble
    if (_isPlaying) {
      Future.delayed(
        Duration(milliseconds: 800 + _random.nextInt(700)),
        _spawnBubble,
      );
    }
  }

  Color _randomColor() {
    final colors = [
      const Color(0xFF00BFFF), // Deep sky blue
      const Color(0xFF1E90FF), // Dodger blue
      const Color(0xFF87CEEB), // Sky blue
      const Color(0xFF4169E1), // Royal blue
      const Color(0xFF6495ED), // Cornflower blue
      const Color(0xFF7B68EE), // Medium slate blue
    ];
    return colors[_random.nextInt(colors.length)];
  }

  void _popBubble(Bubble bubble) {
    setState(() {
      _bubbles.removeWhere((b) => b.id == bubble.id);
      _score += 10;
    });
    bubble.controller.dispose();
  }

  void _endGame() {
    setState(() {
      _isPlaying = false;
      for (var bubble in _bubbles) {
        bubble.controller.dispose();
      }
      _bubbles.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1321),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B2838),
        title: const Text(
          '✨ Relax Game',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Animated gradient background
          AnimatedContainer(
            duration: const Duration(seconds: 3),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF0D1321),
                  const Color(0xFF1B2838),
                  Color.lerp(
                    const Color(0xFF0D1321),
                    const Color(0xFF1B2838),
                    (_score / 100).clamp(0.0, 1.0),
                  )!,
                ],
              ),
            ),
          ),

          // Bubbles
          if (_isPlaying)
            ...(_bubbles.map((bubble) => AnimatedBuilder(
                  animation: bubble.controller,
                  builder: (context, child) {
                    final progress = bubble.controller.value;
                    final currentY = bubble.y - (progress * (size.height + 200));

                    return Positioned(
                      left: bubble.x,
                      top: currentY,
                      child: GestureDetector(
                        onTap: () => _popBubble(bubble),
                        child: Container(
                          width: bubble.size,
                          height: bubble.size,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                bubble.color.withOpacity(0.6),
                                bubble.color.withOpacity(0.2),
                              ],
                            ),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: bubble.color.withOpacity(0.5),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Container(
                              width: bubble.size * 0.3,
                              height: bubble.size * 0.3,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.4),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ))),

          // Score overlay
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatCard('Score', _score.toString(), Icons.star, Colors.amber),
                _buildStatCard('Missed', _missed.toString(), Icons.close, Colors.redAccent),
              ],
            ),
          ),

          // Start/Game Over screen
          if (!_isPlaying)
            Center(
              child: Container(
                margin: const EdgeInsets.all(32),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B2838),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.withOpacity(0.5), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.bubble_chart_rounded,
                      size: 64,
                      color: Color(0xFF00BFFF),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _score > 0 ? 'Game Over!' : 'Relax & Pop Bubbles',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_score > 0) ...[
                      Text(
                        'Final Score: $_score',
                        style: const TextStyle(
                          fontSize: 20,
                          color: Colors.amber,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      'Tap bubbles before they float away!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _startGame,
                      icon: const Icon(Icons.play_arrow),
                      label: Text(_score > 0 ? 'Play Again' : 'Start Game'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00BFFF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2838),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class Bubble {
  final int id;
  final double x;
  final double y;
  final double size;
  final Color color;
  final AnimationController controller;

  Bubble({
    required this.id,
    required this.x,
    required this.y,
    required this.size,
    required this.color,
    required this.controller,
  });
}
