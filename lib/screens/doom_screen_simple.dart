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
              // Set landscape and fullscreen when page loads
              SystemChrome.setPreferredOrientations([
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ]);
              SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

              // Wait a bit for page to initialize
              await Future.delayed(const Duration(milliseconds: 1000));

              // Monitor loading and auto-start game
              await _controller?.runJavaScript('''
                // Monitor and auto-start
                (function() {
                  console.log('[Flutter] Initializing auto-start...');

                  // Hide UI elements
                  const style = document.createElement('style');
                  style.textContent = `
                    /* Hide sidebar and controls */
                    .dos-zone-sidebar,
                    .dos-zone-controls,
                    .sidebar,
                    .controls,
                    canvas:not(.dos-canvas),
                    [class*="sidebar"],
                    [class*="control"],
                    [id*="sidebar"],
                    [id*="control"] {
                      display: none !important;
                    }

                    /* Hide purple/black overlays */
                    div[style*="position: absolute"],
                    div[style*="z-index"] {
                      background: transparent !important;
                      border: none !important;
                    }

                    /* Make canvas fullscreen */
                    canvas, .dos-canvas, #jsdos {
                      width: 100vw !important;
                      height: 100vh !important;
                      position: fixed !important;
                      top: 0 !important;
                      left: 0 !important;
                      z-index: 9999 !important;
                    }

                    /* Hide everything except canvas */
                    body > *:not(canvas):not(script):not(style) {
                      display: none !important;
                    }
                  `;
                  document.head.appendChild(style);

                  // Monitor for game ready and auto-click
                  let clickAttempts = 0;
                  const maxAttempts = 20;

                  function tryAutoStart() {
                    clickAttempts++;
                    console.log('[Flutter] Auto-start attempt:', clickAttempts);

                    // Check if game is loaded
                    const canvas = document.querySelector('canvas');
                    if (canvas && canvas.width > 0) {
                      console.log('[Flutter] Canvas found, game loading...');
                    }

                    // Try multiple selectors for play button
                    const selectors = [
                      'button[class*="play"]',
                      'button[class*="start"]',
                      'button[class*="Play"]',
                      'button[class*="Start"]',
                      '.play-button',
                      '.start-button',
                      'button',
                      '.dos-ci-play-button',
                      '[onclick*="play"]',
                      '[onclick*="start"]'
                    ];

                    let clicked = false;
                    for (const selector of selectors) {
                      const buttons = document.querySelectorAll(selector);
                      buttons.forEach(btn => {
                        if (btn && btn.offsetParent !== null && !clicked) {
                          const text = btn.textContent.toLowerCase();
                          if (text.includes('play') || text.includes('start') || text.includes('run')) {
                            console.log('[Flutter] Clicking button:', text, btn);
                            btn.click();
                            clicked = true;
                          }
                        }
                      });
                      if (clicked) break;
                    }

                    // Try clicking canvas
                    if (!clicked && canvas) {
                      console.log('[Flutter] Clicking canvas');
                      canvas.click();
                      clicked = true;
                    }

                    // Try pressing Enter key
                    if (!clicked) {
                      console.log('[Flutter] Pressing Enter');
                      document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', keyCode: 13 }));
                    }

                    // Request fullscreen
                    const elem = document.documentElement;
                    if (elem.requestFullscreen) {
                      elem.requestFullscreen().catch(e => {});
                    }

                    // Keep trying if not successful
                    if (clickAttempts < maxAttempts) {
                      setTimeout(tryAutoStart, 500);
                    } else {
                      console.log('[Flutter] Auto-start completed after', clickAttempts, 'attempts');
                    }
                  }

                  // Start attempting after page is ready
                  setTimeout(tryAutoStart, 500);
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
            WebViewWidget(controller: _controller!),

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

            // Back button (only visible when playing)
            if (!_isLoading)
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 8,
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
                        Icons.arrow_back,
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
