import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/doom_cache_service.dart';

/// DOOM game screen - downloads WAD from GitHub, caches, and runs via js-dos
class DoomScreen extends StatefulWidget {
  const DoomScreen({super.key});

  @override
  State<DoomScreen> createState() => _DoomScreenState();
}

class _DoomScreenState extends State<DoomScreen> with TickerProviderStateMixin {
  final _cacheService = DoomCacheService();
  WebViewController? _controller;
  DoomGame? _selectedGame;
  bool _isDownloading = false;
  bool _isInitializing = false;
  bool _isPlaying = false;
  String _errorMessage = '';
  double _downloadProgress = 0;
  String? _cachedWadPath;

  String _currentFact = '';
  Timer? _factTimer;
  String _glitchText = '';
  Timer? _glitchTimer;

  final List<DoomGame> _games = [
    DoomGame(
      id: 'doom1',
      title: 'DOOM',
      subtitle: 'Knee-Deep in the Dead',
      wadFilename: 'doom.jsdos',
      year: 1993,
      description: 'The shareware episode that started it all. Fight through Phobos base against demons from Hell.',
      coverImage: 'assets/doom/doom1-cover.jpg',
      sizeBytes: 5539791,
    ),
    DoomGame(
      id: 'doom2',
      title: 'DOOM II',
      subtitle: 'Hell on Earth',
      wadFilename: 'doom2.jsdos',
      year: 1994,
      description: 'The demons have invaded Earth. Bigger maps, more monsters, the Super Shotgun.',
      coverImage: 'assets/doom/doom2-cover.jpg',
      sizeBytes: 6975802,
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
    _rotateFact();
    _factTimer = Timer.periodic(const Duration(seconds: 6), (_) => _rotateFact());
    _startGlitch();
  }

  @override
  void dispose() {
    _factTimer?.cancel();
    _glitchTimer?.cancel();
    // Restore portrait mode when leaving
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
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
    _glitchTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) {
        setState(() {
          _glitchText = List.generate(
            3,
            (_) => chars[math.Random().nextInt(chars.length)],
          ).join();
        });
      }
    });
  }

  String get _progressPercent => (_downloadProgress * 100).toStringAsFixed(1);

  void _selectGame(DoomGame game) {
    setState(() {
      _selectedGame = game;
      _errorMessage = '';
      _isDownloading = false;
      _isPlaying = false;
      _cachedWadPath = null;
      _downloadProgress = 0;
    });

    _loadGame(game);
  }

  Future<void> _loadGame(DoomGame game) async {
    // Enable landscape mode for gameplay
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    try {
      debugPrint('[DOOM] Loading game: ${game.title}');
      debugPrint('[DOOM] WAD filename: ${game.wadFilename}');

      setState(() {
        _isDownloading = true;
        _downloadProgress = 0;
      });

      // Step 1: Cache js-dos library if not already cached
      final isJsDosCached = await _cacheService.isJsDosCached();
      debugPrint('[DOOM] js-dos library cached: $isJsDosCached');

      if (!isJsDosCached) {
        debugPrint('[DOOM] Downloading js-dos library from GitHub...');
        final success = await _cacheService.cacheJsDosLibrary(
          onProgress: (filename, progress) {
            debugPrint('[DOOM] Downloading $filename: ${(progress * 100).toStringAsFixed(1)}%');
            if (mounted) {
              setState(() {
                _downloadProgress = progress * 0.5; // First 50% for js-dos
              });
            }
          },
        );

        if (!success) {
          throw Exception('Failed to download js-dos library from GitHub. Check internet connection.');
        }
        debugPrint('[DOOM] js-dos library cached successfully');
      }

      // Step 2: Check if WAD is already cached
      final isCached = await _cacheService.isCached(game.wadFilename);
      debugPrint('[DOOM] WAD cached: $isCached');

      String? cachedPath;
      if (isCached) {
        debugPrint('[DOOM] Using cached WAD file');
        cachedPath = await _cacheService.getCachedWadFile(game.wadFilename);
        debugPrint('[DOOM] Cached WAD path: $cachedPath');
      }

      // Step 3: Download WAD if not cached
      if (cachedPath == null) {
        debugPrint('[DOOM] Downloading WAD from GitHub');
        cachedPath = await _cacheService.getCachedWadFile(
          game.wadFilename,
          onProgress: (progress) {
            debugPrint('[DOOM] WAD download progress: ${(progress * 100).toStringAsFixed(1)}%');
            if (mounted) {
              setState(() {
                // 50-100% for WAD download
                _downloadProgress = 0.5 + (progress * 0.5);
              });
            }
          },
        );

        debugPrint('[DOOM] WAD download complete. Path: $cachedPath');

        if (cachedPath == null) {
          throw Exception('Failed to download WAD file from GitHub. Check internet connection and GitHub URL.');
        }
      }

      setState(() {
        _isDownloading = false;
        _cachedWadPath = cachedPath;
      });

      await _initJsDos(game, cachedPath!);
    } catch (e, stackTrace) {
      debugPrint('[DOOM] Error loading game: $e');
      debugPrint('[DOOM] Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading game: $e\n\nMake sure you have internet connection and GitHub is accessible.';
          _isDownloading = false;
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _initJsDos(DoomGame game, String wadPath) async {
    debugPrint('[DOOM] Initializing js-dos with WAD: $wadPath');
    setState(() {
      _isInitializing = true;
    });

    try {
      // Read WAD file as base64
      debugPrint('[DOOM] Reading WAD file...');
      final wadFile = File(wadPath);
      final wadBytes = await wadFile.readAsBytes();
      debugPrint('[DOOM] WAD file size: ${wadBytes.length} bytes');

      debugPrint('[DOOM] Encoding WAD to base64...');
      final wadBase64 = base64Encode(wadBytes);
      debugPrint('[DOOM] WAD Base64 length: ${wadBase64.length} characters');

      // Read js-dos library files to inline in HTML
      debugPrint('[DOOM] Reading js-dos library files...');
      final jsDosPath = await _cacheService.getJsDosFilePath('js-dos.js');
      final wdosboxJsPath = await _cacheService.getJsDosFilePath('wdosbox.js');

      if (jsDosPath == null || wdosboxJsPath == null) {
        throw Exception('js-dos library files not found in cache');
      }

      final jsDosCode = await File(jsDosPath).readAsString();
      final wdosboxJsCode = await File(wdosboxJsPath).readAsString();

      debugPrint('[DOOM] js-dos.js: ${jsDosCode.length} chars');
      debugPrint('[DOOM] wdosbox.js: ${wdosboxJsCode.length} chars');

      // Create controller first
      debugPrint('[DOOM] Creating WebViewController...');
      final controller = WebViewController();

      // Set it to state so callbacks can access it
      if (mounted) {
        setState(() {
          _controller = controller;
        });
      }

      // Create HTML with inline js-dos scripts
      debugPrint('[DOOM] Creating HTML with inline scripts...');

      final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>DOOM</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body, canvas { width: 100%; height: 100%; margin: 0; padding: 0; }
    body { background: #000; overflow: hidden; touch-action: none; }
    canvas { display: block; user-select: none; }
    .loading { position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); text-align: center; color: #00ff41; font-size: 1.1rem; padding: 2rem; z-index: 10; text-shadow: 0 0 10px #00ff41; }
    .error { color: #c41e1e; }
    .spinner { border: 4px solid #333; border-top: 4px solid #00ff41; border-radius: 50%; width: 40px; height: 40px; animation: spin 1s linear infinite; margin: 20px auto; }
    @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
  </style>
</head>
<body>
  <div class="loading" id="loading"><div class="spinner"></div><div>INITIALIZING...</div></div>
  <canvas id="jsdos" style="display:none;"></canvas>

  <script>
    // Inline js-dos library
    $jsDosCode
  </script>

  <script>
    // Inline wdosbox
    $wdosboxJsCode
  </script>

  <script>
    const loading = document.getElementById('loading');
    const canvas = document.getElementById('jsdos');

    function updateLoading(msg, isError) {
      loading.innerHTML = isError ? '<div class="error">' + msg + '</div>' : '<div class="spinner"></div><div>' + msg + '</div>';
    }

    function base64ToArrayBuffer(base64) {
      const bin = atob(base64);
      const len = bin.length;
      const bytes = new Uint8Array(len);
      for (let i = 0; i < len; i++) bytes[i] = bin.charCodeAt(i);
      return bytes;
    }

    console.log('[DOOM] typeof Dos:', typeof Dos);

    if (typeof Dos !== 'function') {
      updateLoading('ERROR: js-dos not loaded', true);
    } else {
      updateLoading('CONVERTING BUNDLE...');

      const wadData = base64ToArrayBuffer("$wadBase64");
      const blob = new Blob([wadData], { type: 'application/octet-stream' });
      const blobUrl = URL.createObjectURL(blob);

      console.log('[DOOM] Blob created, size:', blob.size);

      updateLoading('INITIALIZING...');

      try {
        // js-dos v8 API: pass bundleUrl in constructor options
        console.log('[DOOM] Creating Dos with bundleUrl:', blobUrl);

        updateLoading('LOADING BUNDLE...');

        // Show canvas immediately
        canvas.style.display = 'block';

        const dosInstance = Dos(canvas, {
          bundleUrl: blobUrl,
          onprogress: function(stage, total, loaded) {
            console.log('[DOOM] Progress:', stage, loaded + '/' + total);
            if (stage === 'Extracting') {
              updateLoading('EXTRACTING...');
            } else if (stage === 'Starting') {
              updateLoading('STARTING ${game.title}...');
            }
          }
        });

        console.log('[DOOM] Dos instance created');
        window.dosInstance = dosInstance;

        // Wait a bit then hide loading
        setTimeout(function() {
          console.log('[DOOM] Hiding loading overlay');
          loading.style.display = 'none';
        }, 3000);
      } catch (err) {
        console.error('[DOOM] Initialization error:', err);
        updateLoading('ERROR: ' + err.message, true);
      }
    }
  </script>
</body>
</html>
''';

      // Configure controller
      debugPrint('[DOOM] Configuring WebViewController...');
      controller
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0xFF000000));

      // Load HTML string with inline scripts
      debugPrint('[DOOM] Loading HTML with inline scripts...');
      await controller.loadHtmlString(html, baseUrl: 'http://localhost/');
      debugPrint('[DOOM] HTML loaded');

      if (mounted) {
        setState(() {
          _isInitializing = false;
          _isPlaying = true;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('[DOOM] Error initializing js-dos: $e');
      debugPrint('[DOOM] Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _errorMessage = 'Error initializing game: $e';
          _isInitializing = false;
        });
      }
    }
  }


  void _backToMenu() {
    // Restore portrait mode
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    setState(() {
      _selectedGame = null;
      _controller = null;
      _errorMessage = '';
      _downloadProgress = 0;
      _isPlaying = false;
      _isDownloading = false;
      _isInitializing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0a0a),
      body: Stack(
        children: [
          // Scanlines overlay
          if (_selectedGame == null)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: const AssetImage('assets/branding/icon.png'),
                      fit: BoxFit.none,
                      opacity: 0.02,
                      repeat: ImageRepeat.repeat,
                    ),
                  ),
                ),
              ),
            ),

          SafeArea(
            child: Column(
              children: [
                // Header (only in menu)
                if (_selectedGame == null) _buildHeader(),

                // Content
                Expanded(
                  child: _selectedGame == null
                      ? _buildGameSelection()
                      : _buildGamePlayer(),
                ),

                // Footer (only in menu)
                if (_selectedGame == null) _buildFooter(),
              ],
            ),
          ),

          // Back button overlay when playing
          if (_selectedGame != null)
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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Glitch title
          Stack(
            children: [
              Text(
                'CAN IT RUN DOOM?',
                style: GoogleFonts.sourceCodePro(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 2
                    ..color = const Color(0xFFc41e1e).withOpacity(0.5),
                  letterSpacing: 2,
                ),
              ),
              Text(
                'CAN IT RUN DOOM?',
                style: GoogleFonts.sourceCodePro(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFc41e1e),
                  letterSpacing: 2,
                  shadows: [
                    Shadow(
                      color: const Color(0xFFc41e1e).withOpacity(0.8),
                      blurRadius: 10,
                    ),
                    Shadow(
                      color: const Color(0xFFc41e1e).withOpacity(0.4),
                      blurRadius: 40,
                    ),
                  ],
                ),
              ),
              Positioned(
                left: -30,
                top: 0,
                child: Text(
                  _glitchText,
                  style: GoogleFonts.sourceCodePro(
                    fontSize: 12,
                    color: const Color(0xFF00ff41).withOpacity(0.6),
                  ),
                ),
              ),
            ],
          ).animate(onPlay: (c) => c.repeat()).shimmer(
                duration: 3000.ms,
                color: const Color(0xFFc41e1e).withOpacity(0.3),
              ),

          const SizedBox(height: 12),

          // Subtitle
          Text(
            'Doom runs on calculators, fridges, pregnancy tests...',
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              fontSize: 12,
              color: Colors.white60,
            ),
          ),
          Text(
            '...and now, here. Because why not?',
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              fontSize: 12,
              color: const Color(0xFFff6b00),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: -0.2);
  }

  Widget _buildFactTicker() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a1a),
        borderRadius: BorderRadius.circular(8),
        border: const Border(
          left: BorderSide(color: Color(0xFF00ff41), width: 4),
        ),
      ),
      child: Row(
        children: [
          Text(
            '// FUN FACT: ',
            style: GoogleFonts.sourceCodePro(
              fontSize: 11,
              color: const Color(0xFF00ff41),
              fontWeight: FontWeight.w700,
            ),
          ),
          Expanded(
            child: Text(
              _currentFact,
              style: GoogleFonts.montserrat(
                fontSize: 11,
                color: Colors.white70,
              ),
            ),
          ),
        ],
      ),
    ).animate(key: ValueKey(_currentFact)).fadeIn();
  }

  Widget _buildGameSelection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _buildFactTicker(),
          const SizedBox(height: 8),
          ..._games.map((game) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildGameCard(game),
              )),
        ],
      ),
    );
  }

  Widget _buildGameCard(DoomGame game) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        _selectGame(game);
      },
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
                    game.coverImage,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
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
                    game.year.toString(),
                    style: GoogleFonts.sourceCodePro(
                      fontSize: 10,
                      color: const Color(0xFF00ff41),
                      letterSpacing: 2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    game.title,
                    style: GoogleFonts.sourceCodePro(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFc41e1e),
                      shadows: [
                        Shadow(
                          color: const Color(0xFFc41e1e).withOpacity(0.4),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    game.subtitle,
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      color: const Color(0xFFff6b00),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    game.description,
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      color: Colors.white60,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'CAN IT RUN ?',
                          style: GoogleFonts.sourceCodePro(
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
    ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95));
  }

  Widget _buildGamePlayer() {
    if (_isDownloading) {
      return _buildDownloadingScreen();
    }

    if (_isInitializing) {
      return _buildInitializingScreen();
    }

    if (_errorMessage.isNotEmpty) {
      return _buildErrorScreen();
    }

    if (_controller == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFc41e1e)),
      );
    }

    return WebViewWidget(controller: _controller!);
  }

  Widget _buildDownloadingScreen() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/doom/doomguy-face.jpg',
              width: 100,
              height: 100,
            ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                  duration: 1500.ms,
                  begin: const Offset(1, 1),
                  end: const Offset(1.08, 1.08),
                ),

            const SizedBox(height: 24),

            Text(
              'DOWNLOADING FROM GITHUB...',
              style: GoogleFonts.sourceCodePro(
                fontSize: 16,
                color: const Color(0xFF00ff41),
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              _selectedGame!.title,
              style: GoogleFonts.montserrat(
                fontSize: 14,
                color: const Color(0xFFff6b00),
              ),
            ),

            const SizedBox(height: 24),

            // Progress bar
            Container(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Progress',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          color: Colors.white54,
                        ),
                      ),
                      Text(
                        '$_progressPercent%',
                        style: GoogleFonts.sourceCodePro(
                          fontSize: 13,
                          color: const Color(0xFFff6b00),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFF222222),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF333333)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: _downloadProgress,
                        backgroundColor: Colors.transparent,
                        valueColor: const AlwaysStoppedAnimation(Color(0xFFc41e1e)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'Downloading WAD file from GitHub...\nThis only happens once, then it\'s cached',
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                fontSize: 11,
                color: Colors.white38,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitializingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFFc41e1e)),
          const SizedBox(height: 16),
          Text(
            'INITIALIZING ${_selectedGame!.title}...',
            style: GoogleFonts.sourceCodePro(
              fontSize: 14,
              color: const Color(0xFF00ff41),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Loading from cache',
            style: GoogleFonts.montserrat(
              fontSize: 11,
              color: Colors.white54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Color(0xFFc41e1e),
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                fontSize: 13,
                color: const Color(0xFFc41e1e),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Make sure you have internet connection',
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                fontSize: 11,
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _selectGame(_selectedGame!),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFc41e1e),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: Text(
                'RETRY',
                style: GoogleFonts.sourceCodePro(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            '"If it has a processor, it can run Doom." — Ancient Internet Proverb',
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              fontSize: 10,
              color: Colors.white38,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'WADs from GitHub • Cached locally • js-dos • Built with ❤️ Emmanuel1017',
            textAlign: TextAlign.center,
            style: GoogleFonts.sourceCodePro(
              fontSize: 9,
              color: Colors.white24,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 500.ms);
  }
}

class DoomGame {
  final String id;
  final String title;
  final String subtitle;
  final String wadFilename;
  final int year;
  final String description;
  final String coverImage;
  final int sizeBytes;

  DoomGame({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.wadFilename,
    required this.year,
    required this.description,
    required this.coverImage,
    required this.sizeBytes,
  });
}
