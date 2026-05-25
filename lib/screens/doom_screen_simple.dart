import 'package:flutter/material.dart';
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
          onPageFinished: (url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
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
    setState(() {
      _selectedGame = null;
      _controller = null;
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

            // Loading indicator
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFc41e1e),
                ),
              ),

            // Back button
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
        title: const Text('DOOM'),
        backgroundColor: Colors.black,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'CAN IT RUN DOOM?',
              style: TextStyle(
                color: Color(0xFFc41e1e),
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => _loadGame('doom1'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFc41e1e),
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              ),
              child: const Text(
                'PLAY DOOM',
                style: TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _loadGame('doom2'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFc41e1e),
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              ),
              child: const Text(
                'PLAY DOOM II',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
