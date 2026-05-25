import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Simplified DOOM screen - embedded WebView
class DoomScreenSimple extends StatefulWidget {
  const DoomScreenSimple({super.key});

  @override
  State<DoomScreenSimple> createState() => _DoomScreenSimpleState();
}

class _DoomScreenSimpleState extends State<DoomScreenSimple> {
  String? _selectedGame;
  WebViewController? _controller;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Start in portrait menu mode
  }

  @override
  void dispose() {
    // Restore portrait when leaving
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _loadGame(String game) {
    // Set landscape immediately
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    setState(() {
      _selectedGame = game;
      _isLoading = true;
    });

    final url = game == 'doom1'
        ? 'https://emmanuel1017.github.io/Angular-Resume/doom'
        : 'https://emmanuel1017.github.io/Angular-Resume/doom?game=doom2';

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) async {
            if (mounted) {
              debugPrint('[DOOM] Page loaded, waiting for game...');

              // Wait for page to settle
              await Future.delayed(const Duration(milliseconds: 2000));

              // Inject CSS to hide Angular UI and force fullscreen canvas
              await _controller?.runJavaScript('''
                (function() {
                  console.log('[Flutter] Hiding Angular UI...');

                  // Hide Angular-specific UI elements
                  const style = document.createElement('style');
                  style.textContent = `
                    /* Hide Angular page elements */
                    .back-to-cv,
                    .back-btn,
                    .player-header,
                    .doom-header,
                    .doom-footer,
                    .fact-ticker,
                    .controls-hint,
                    .scanlines,
                    .loading-screen {
                      display: none !important;
                    }

                    /* Hide any overlays or sidebars */
                    .sidebar,
                    .controls-panel,
                    [class*="overlay"] {
                      display: none !important;
                    }

                    /* Make dos-container fullscreen */
                    .dos-container,
                    #jsdos {
                      position: fixed !important;
                      top: 0 !important;
                      left: 0 !important;
                      width: 100vw !important;
                      height: 100vh !important;
                      z-index: 9999 !important;
                    }

                    /* Canvas fills container - maintain aspect ratio */
                    .dos-container canvas,
                    #jsdos canvas,
                    canvas {
                      width: 100% !important;
                      height: 100% !important;
                      display: block !important;
                      object-fit: contain !important;
                    }

                    /* Remove any padding/margins from containers */
                    .dos-container,
                    #jsdos,
                    .dos-wrapper {
                      padding: 0 !important;
                      margin: 0 !important;
                    }

                    /* Hide body scrolling */
                    html, body {
                      overflow: hidden !important;
                      margin: 0 !important;
                      padding: 0 !important;
                    }
                  `;
                  document.head.appendChild(style);

                  console.log('[Flutter] UI hidden, game should auto-start via Angular');
                })();
              ''');

              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
              }
            }
          },
          onWebResourceError: (error) {
            debugPrint('[DOOM] Error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(url));

    setState(() {
      _controller = controller;
    });
  }

  void _backToMenu() {
    // Restore portrait and system UI
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    setState(() {
      _selectedGame = null;
      _controller = null;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedGame != null && _controller != null) {
      // Show WebView with game
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Game WebView - fullscreen
            Positioned.fill(
              child: WebViewWidget(controller: _controller!),
            ),

            // Loading/Tap to start overlay
            if (_isLoading)
              GestureDetector(
                onTap: () async {
                  // User tap triggers the game start
                  await _controller?.runJavaScript('''
                    // On user tap, click play button and hide UI
                    (function() {
                      console.log('[Flutter] User tapped, starting game...');

                      // Click any visible button
                      const buttons = document.querySelectorAll('button, a, [role="button"]');
                      buttons.forEach(btn => {
                        if (btn.offsetParent !== null) {
                          btn.click();
                          console.log('[Flutter] Clicked:', btn);
                        }
                      });

                      // Click canvas
                      const canvas = document.querySelector('canvas');
                      if (canvas) {
                        canvas.click();
                      }

                      // Press Enter
                      document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', keyCode: 13 }));

                      // Request fullscreen (works now because of user gesture)
                      setTimeout(() => {
                        const elem = document.documentElement;
                        if (elem.requestFullscreen) {
                          elem.requestFullscreen();
                        }
                      }, 100);
                    })();
                  ''');

                  setState(() {
                    _isLoading = false;
                  });
                },
                child: Container(
                  color: Colors.black87,
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.touch_app,
                          color: Color(0xFFc41e1e),
                          size: 64,
                        ),
                        SizedBox(height: 20),
                        Text(
                          'TAP TO START',
                          style: TextStyle(
                            color: Color(0xFFc41e1e),
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Loading game assets...',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Virtual Controls (only visible when playing)
            if (!_isLoading)
              Positioned.fill(
                child: _VirtualControls(controller: _controller),
              ),

            // Back button (only visible when playing)
            if (!_isLoading)
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.transparent,
                  child: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFc41e1e).withOpacity(0.5),
                        ),
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Color(0xFF00ff41),
                      ),
                    ),
                    onPressed: _backToMenu,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    // Show game selection menu
    return Scaffold(
      backgroundColor: const Color(0xFF0a0a0a),
      appBar: AppBar(
        title: const Text(
          'CAN IT RUN DOOM?',
          style: TextStyle(
            color: Color(0xFFc41e1e),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Color(0xFF00ff41)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // DOOM 1 Card
            _GameCard(
              title: 'DOOM',
              subtitle: 'Knee-Deep in the Dead • 1993',
              description: 'The shareware episode that started it all.\nFight through Phobos base against demons from Hell.',
              coverImage: 'assets/doom/doom1-cover.jpg',
              onTap: () => _loadGame('doom1'),
            ),

            const SizedBox(height: 20),

            // DOOM 2 Card
            _GameCard(
              title: 'DOOM II',
              subtitle: 'Hell on Earth • 1994',
              description: 'The demons have invaded Earth.\nBigger maps, more monsters, the Super Shotgun.',
              coverImage: 'assets/doom/doom2-cover.jpg',
              onTap: () => _loadGame('doom2'),
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
  final String coverImage;
  final VoidCallback onTap;

  const _GameCard({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.coverImage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1a1a1a),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF333333),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Image.asset(
                    coverImage,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        color: const Color(0xFF2a2a2a),
                        child: const Center(
                          child: Icon(
                            Icons.image_not_supported,
                            color: Color(0xFF666666),
                            size: 48,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
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
              ],
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFc41e1e),
                      shadows: [
                        Shadow(
                          color: Color(0xFFc41e1e),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFFff6b00),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white60,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF333333),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFc41e1e),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'PLAY NOW',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 1.2,
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

// Virtual game controls overlay
class _VirtualControls extends StatelessWidget {
  final WebViewController? controller;

  const _VirtualControls({required this.controller});

  Future<void> _sendKey(String key) async {
    await controller?.runJavaScript('''
      document.dispatchEvent(new KeyboardEvent('keydown', {
        key: '$key',
        code: 'Key${key.toUpperCase()}',
        keyCode: ${_getKeyCode(key)},
        bubbles: true
      }));
      setTimeout(() => {
        document.dispatchEvent(new KeyboardEvent('keyup', {
          key: '$key',
          code: 'Key${key.toUpperCase()}',
          keyCode: ${_getKeyCode(key)},
          bubbles: true
        }));
      }, 100);
    ''');
  }

  int _getKeyCode(String key) {
    final codes = {
      'ArrowUp': 38, 'ArrowDown': 40, 'ArrowLeft': 37, 'ArrowRight': 39,
      'Control': 17, ' ': 32, 'Enter': 13, 'Shift': 16,
      '1': 49, '2': 50, '3': 51, '4': 52, '5': 53, '6': 54, '7': 55,
    };
    return codes[key] ?? 65;
  }

  Widget _buildButton({
    required IconData icon,
    required String key,
    String? label,
    double size = 60,
  }) {
    return GestureDetector(
      onTapDown: (_) => _sendKey(key),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFc41e1e).withOpacity(0.6),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white70, size: size * 0.4),
            if (label != null)
              Text(
                label,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: size * 0.15,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // D-Pad (Left side)
        Positioned(
          left: 20,
          bottom: 20,
          child: SizedBox(
            width: 180,
            height: 180,
            child: Stack(
              children: [
                Positioned(top: 0, left: 60, child: _buildButton(icon: Icons.arrow_drop_up, key: 'ArrowUp')),
                Positioned(bottom: 0, left: 60, child: _buildButton(icon: Icons.arrow_drop_down, key: 'ArrowDown')),
                Positioned(left: 0, top: 60, child: _buildButton(icon: Icons.arrow_left, key: 'ArrowLeft')),
                Positioned(right: 0, top: 60, child: _buildButton(icon: Icons.arrow_right, key: 'ArrowRight')),
              ],
            ),
          ),
        ),

        // Action buttons (Right side)
        Positioned(
          right: 20,
          bottom: 80,
          child: Column(
            children: [
              Row(
                children: [
                  _buildButton(icon: Icons.radio_button_checked, key: 'Control', label: 'FIRE', size: 70),
                  const SizedBox(width: 12),
                  _buildButton(icon: Icons.touch_app, key: ' ', label: 'USE', size: 70),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildButton(icon: Icons.swap_horiz, key: 'Shift', label: 'RUN', size: 55),
                  const SizedBox(width: 8),
                  _buildButton(icon: Icons.menu, key: 'Enter', label: 'MENU', size: 55),
                ],
              ),
            ],
          ),
        ),

        // Weapon select (Top right)
        Positioned(
          top: 60,
          right: 20,
          child: Row(
            children: List.generate(7, (i) {
              return Padding(
                padding: const EdgeInsets.only(left: 4),
                child: _buildButton(icon: Icons.looks_one, key: '${i + 1}', size: 40),
              );
            }),
          ),
        ),
      ],
    );
  }
}
