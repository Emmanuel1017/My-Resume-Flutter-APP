import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../theme/app_theme.dart';

const _portfolioUrl = 'https://emmanuel1017.github.io/Angular-Resume/';

// CSS injected to make the site feel native inside the app:
// — hides the Angular sticky top nav (we provide our own in Flutter)
// — kills scrollbars
// — adjusts font rendering
const _injectCss = '''
(function() {
  var style = document.createElement('style');
  style.textContent = `
    ::-webkit-scrollbar { display: none !important; }
    * { -webkit-tap-highlight-color: transparent; }
    app-navbar, nav.navbar, .navbar, header.site-header {
      display: none !important;
    }
    body {
      padding-top: 0 !important;
      margin-top:  0 !important;
      overscroll-behavior: none;
    }
    section { scroll-margin-top: 0 !important; }
  `;
  document.head.appendChild(style);
})();
''';

// Sections in the portfolio (for the bottom pill selector)
const _sections = ['#home', '#about', '#skills', '#my-work', '#experience', '#contact'];
const _sectionLabels = ['Home', 'About', 'Skills', 'Work', 'Exp', 'Contact'];

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  late final WebViewController _ctrl;

  int     _loadProgress  = 0;
  bool    _loaded        = false;
  bool    _canGoBack     = false;
  int     _activeSection = 0;
  bool    _showSections  = false;

  @override
  void initState() {
    super.initState();

    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.bg)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() {
          _loadProgress = 0;
          _loaded       = false;
        }),
        onProgress: (p) => setState(() => _loadProgress = p),
        onPageFinished: (_) async {
          await _ctrl.runJavaScript(_injectCss);
          await _ctrl.runJavaScript(_buildScrollListener());
          final canBack = await _ctrl.canGoBack();
          setState(() {
            _loaded   = true;
            _canGoBack = canBack;
          });
        },
        onNavigationRequest: (req) {
          // Open external links in the system browser, keep portfolio in WebView
          if (!req.url.startsWith('https://emmanuel1017.github.io')) {
            launchUrl(Uri.parse(req.url), mode: LaunchMode.externalApplication);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..addJavaScriptChannel(
        'FlutterSection',
        onMessageReceived: (msg) {
          final idx = int.tryParse(msg.message);
          if (idx != null && mounted) {
            setState(() => _activeSection = idx);
          }
        },
      )
      ..loadRequest(Uri.parse(_portfolioUrl));
  }

  // Injects a scroll listener that tells Flutter which section is in view
  String _buildScrollListener() {
    final ids = _sections
        .map((s) => s.replaceFirst('#', ''))
        .map((id) => '"$id"')
        .join(',');
    return '''
(function() {
  var ids = [$ids];
  function update() {
    var best = 0, bestVis = -1;
    ids.forEach(function(id, i) {
      var el = document.getElementById(id);
      if (!el) return;
      var rect = el.getBoundingClientRect();
      var vis = Math.max(0, Math.min(rect.bottom, window.innerHeight) - Math.max(rect.top, 0));
      if (vis > bestVis) { bestVis = vis; best = i; }
    });
    FlutterSection.postMessage(String(best));
  }
  window.addEventListener('scroll', update, { passive: true });
  update();
})();
''';
  }

  Future<void> _scrollTo(String anchor) async {
    HapticFeedback.selectionClick();
    await _ctrl.runJavaScript(
      'document.querySelector("$anchor")?.scrollIntoView({behavior:"smooth"});',
    );
  }

  Future<void> _reload() async {
    HapticFeedback.mediumImpact();
    await _ctrl.reload();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          // ── WebView ────────────────────────────────────────────────────────
          WebViewWidget(controller: _ctrl),

          // ── Top chrome ────────────────────────────────────────────────────
          Positioned(
            top:   0,
            left:  0,
            right: 0,
            child: _TopChrome(
              paddingTop:   top,
              progress:     _loadProgress,
              loaded:       _loaded,
              canGoBack:    _canGoBack,
              onBack:       () => _ctrl.goBack(),
              onReload:     _reload,
              onSections:   () => setState(() => _showSections = !_showSections),
            ),
          ),

          // ── Section pill strip ─────────────────────────────────────────────
          if (_loaded)
            Positioned(
              bottom: 8,
              left:   16,
              right:  16,
              child: _SectionBar(
                visible:       _showSections,
                activeSection: _activeSection,
                onTap:         (i) => _scrollTo(_sections[i]),
              ),
            ),

          // ── Initial loading overlay ────────────────────────────────────────
          if (!_loaded)
            Positioned.fill(
              child: _LoadingOverlay(progress: _loadProgress),
            ),
        ],
      ),
    );
  }
}

// ─── Top chrome ──────────────────────────────────────────────────────────────

class _TopChrome extends StatelessWidget {
  final double paddingTop;
  final int    progress;
  final bool   loaded;
  final bool   canGoBack;
  final VoidCallback onBack;
  final VoidCallback onReload;
  final VoidCallback onSections;

  const _TopChrome({
    required this.paddingTop,
    required this.progress,
    required this.loaded,
    required this.canGoBack,
    required this.onBack,
    required this.onReload,
    required this.onSections,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: paddingTop),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end:   Alignment.bottomCenter,
          colors: [
            AppColors.bg,
            AppColors.bg.withOpacity(.0),
          ],
          stops: const [.72, 1.0],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                // Back button (only shown when WebView can go back)
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity:  canGoBack ? 1 : 0,
                  child: _ChromeBtn(
                    icon:  Icons.arrow_back_ios_new_rounded,
                    onTap: onBack,
                  ),
                ),
                const SizedBox(width: 6),

                // URL pill
                Expanded(
                  child: Container(
                    height:     34,
                    padding:    const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color:        AppColors.surface.withOpacity(.92),
                      borderRadius: BorderRadius.circular(20),
                      border:       Border.all(color: AppColors.border),
                    ),
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        Icon(Icons.lock_rounded,
                            color: AppColors.accent, size: 11),
                        const SizedBox(width: 6),
                        Text(
                          'emmanuel1017.github.io',
                          style: GoogleFonts.montserrat(
                            fontSize: 11.5,
                            color:    AppColors.textMid,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 6),
                _ChromeBtn(
                  icon:  Icons.menu_rounded,
                  onTap: onSections,
                ),
                const SizedBox(width: 4),
                _ChromeBtn(
                  icon:  loaded
                      ? Icons.refresh_rounded
                      : Icons.close_rounded,
                  onTap: onReload,
                ),
              ],
            ),
          ),

          // Thin progress bar
          if (!loaded)
            SizedBox(
              height: 2,
              child:  LinearProgressIndicator(
                value:           progress / 100,
                backgroundColor: Colors.transparent,
                valueColor:      const AlwaysStoppedAnimation(AppColors.accent),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChromeBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ChromeBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width:      36,
        height:     36,
        decoration: BoxDecoration(
          color:        AppColors.surface.withOpacity(.92),
          shape:        BoxShape.circle,
          border:       Border.all(color: AppColors.border),
        ),
        child: Icon(icon, color: AppColors.textMid, size: 16),
      ),
    );
  }
}

// ─── Section pill strip ──────────────────────────────────────────────────────

class _SectionBar extends StatelessWidget {
  final bool    visible;
  final int     activeSection;
  final ValueChanged<int> onTap;
  const _SectionBar({
    required this.visible,
    required this.activeSection,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 300),
      curve:    Curves.easeOutCubic,
      offset:   visible ? Offset.zero : const Offset(0, 1.5),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity:  visible ? 1.0 : 0.0,
        child: Container(
          padding:    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color:        AppColors.surface.withOpacity(.96),
            borderRadius: BorderRadius.circular(28),
            border:       Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color:      Colors.black.withOpacity(.3),
                blurRadius: 16,
                offset:     const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(_sectionLabels.length, (i) {
              final active = i == activeSection;
              return GestureDetector(
                onTap: () => onTap(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding:  EdgeInsets.symmetric(
                    horizontal: active ? 12 : 8,
                    vertical:   5,
                  ),
                  decoration: BoxDecoration(
                    color:        active
                        ? AppColors.primary.withOpacity(.25)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border:       active
                        ? Border.all(color: AppColors.primary.withOpacity(.5))
                        : null,
                  ),
                  child: Text(
                    _sectionLabels[i],
                    style: GoogleFonts.montserrat(
                      fontSize:   11,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color:      active ? AppColors.accent : AppColors.textMid,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ─── Loading overlay ─────────────────────────────────────────────────────────

class _LoadingOverlay extends StatelessWidget {
  final int progress;
  const _LoadingOverlay({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bg,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated logo
            Container(
              width:  64,
              height: 64,
              decoration: BoxDecoration(
                shape:    BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.accent],
                  begin:  Alignment.topLeft,
                  end:    Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color:      AppColors.primary.withOpacity(.4),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: const Icon(Icons.language_rounded,
                  color: Colors.white, size: 30),
            )
                .animate(onPlay: (c) => c.repeat())
                .shimmer(duration: 1200.ms, color: AppColors.accent.withOpacity(.4)),

            const SizedBox(height: 28),

            SizedBox(
              width: 180,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value:           progress / 100,
                  backgroundColor: AppColors.border,
                  valueColor:      const AlwaysStoppedAnimation(AppColors.accent),
                  minHeight:       3,
                ),
              ),
            ),

            const SizedBox(height: 14),
            Text(
              'Loading portfolio…',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                color:    AppColors.textMid,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
