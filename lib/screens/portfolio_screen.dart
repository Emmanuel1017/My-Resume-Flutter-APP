import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../theme/app_theme.dart';

const _portfolioUrl = 'https://emmanuel1017.github.io/Angular-Resume/';

// ── JS injected once on page-finished ────────────────────────────────────────
// Hides the Angular nav, kills scrollbars, removes overscroll bounce.
const _injectCss = '''
(function() {
  var s = document.createElement('style');
  s.textContent = `
    ::-webkit-scrollbar { display: none !important; }
    * { -webkit-tap-highlight-color: transparent; }
    app-navbar, nav.navbar, .navbar, header.site-header { display:none!important; }
    body { padding-top:0!important; margin-top:0!important; overscroll-behavior:none; }
    section { scroll-margin-top:0!important; }
    html, body { -webkit-overflow-scrolling: touch; }
    img, video, canvas, svg { transform: translateZ(0); }
    .avatar-scene, .avatar-float, .planet-orbits { will-change: transform; }
  `;
  document.head.appendChild(s);
})();
''';

// Section IDs — keep in sync with the Angular site
const _sections      = ['#home','#about','#skills','#my-work','#experience','#contact'];
const _sectionLabels = ['Home','About','Skills','Work','Exp','Contact'];

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  late final WebViewController _ctrl;

  // ValueNotifiers so only the small indicator widgets rebuild — never the WebViewWidget
  final _progress       = ValueNotifier<int>(0);
  final _loaded         = ValueNotifier<bool>(false);
  final _canGoBack      = ValueNotifier<bool>(false);
  final _activeSection  = ValueNotifier<int>(0);
  final _showSections   = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();

    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.bg)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          _progress.value = 0;
          _loaded.value   = false;
        },
        // Only update the ValueNotifier — zero setState, zero rebuilds
        onProgress: (p) => _progress.value = p,
        onPageFinished: (_) async {
          await _ctrl.runJavaScript(_injectCss);
          await _ctrl.runJavaScript(_buildScrollListener());
          _canGoBack.value = await _ctrl.canGoBack();
          _loaded.value    = true;
        },
        onNavigationRequest: (req) {
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
          if (idx != null && _activeSection.value != idx) {
            _activeSection.value = idx;
          }
        },
      )
      ..loadRequest(Uri.parse(_portfolioUrl));

    if (Platform.isAndroid) {
      final androidCtrl = _ctrl.platform as AndroidWebViewController;
      androidCtrl
        ..setAlgorithmicDarkeningAllowed(false)
        ..setMediaPlaybackRequiresUserGesture(false)
        ..setTextZoom(100);
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    _loaded.dispose();
    _canGoBack.dispose();
    _activeSection.dispose();
    _showSections.dispose();
    super.dispose();
  }

  // Throttled scroll observer: fires at most every 150 ms so the platform
  // channel isn't hammered on every pixel scroll.
  String _buildScrollListener() {
    final ids = _sections
        .map((s) => s.replaceFirst('#', ''))
        .map((id) => '"$id"')
        .join(',');
    return '''
(function() {
  var ids = [$ids], timer = null;
  function compute() {
    var best = 0, bestVis = -1;
    ids.forEach(function(id, i) {
      var el = document.getElementById(id);
      if (!el) return;
      var r = el.getBoundingClientRect();
      var v = Math.max(0, Math.min(r.bottom, window.innerHeight) - Math.max(r.top, 0));
      if (v > bestVis) { bestVis = v; best = i; }
    });
    FlutterSection.postMessage(String(best));
  }
  window.addEventListener('scroll', function() {
    if (timer) return;
    timer = setTimeout(function() { timer = null; compute(); }, 150);
  }, { passive: true });
  compute();
})();
''';
  }

  Future<void> _scrollTo(String anchor) async {
    HapticFeedback.selectionClick();
    await _ctrl.runJavaScript(
      'document.querySelector("$anchor")?.scrollIntoView({behavior:"smooth"});',
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          // WebViewWidget never rebuilds — it sits outside all ValueListenableBuilders
          WebViewWidget(
            controller: _ctrl,
            // Isolate the WebView from any ancestor repaints
            key: const ValueKey('portfolio-webview'),
          ),

          // Top chrome: progress bar updates independently of WebView
          Positioned(
            top: 0, left: 0, right: 0,
            child: RepaintBoundary(
              child: _TopChrome(
                paddingTop:    top,
                progressNotifier: _progress,
                loadedNotifier:   _loaded,
                canGoBackNotifier: _canGoBack,
                onBack:   () => _ctrl.goBack(),
                onReload: () { HapticFeedback.mediumImpact(); _ctrl.reload(); },
                onSections: () =>
                    _showSections.value = !_showSections.value,
              ),
            ),
          ),

          // Section bar: only rebuilds when activeSection or showSections changes
          Positioned(
            bottom: 8, left: 16, right: 16,
            child: RepaintBoundary(
              child: ValueListenableBuilder<bool>(
                valueListenable: _loaded,
                builder: (_, loaded, __) {
                  if (!loaded) return const SizedBox.shrink();
                  return ValueListenableBuilder<bool>(
                    valueListenable: _showSections,
                    builder: (_, show, __) => ValueListenableBuilder<int>(
                      valueListenable: _activeSection,
                      builder: (_, active, __) => _SectionBar(
                        visible:       show,
                        activeSection: active,
                        onTap: (i) => _scrollTo(_sections[i]),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Loading overlay: disappears once loaded, no cost after that
          RepaintBoundary(
            child: ValueListenableBuilder<bool>(
              valueListenable: _loaded,
              builder: (_, loaded, __) {
                if (loaded) return const SizedBox.shrink();
                return Positioned.fill(
                  child: ValueListenableBuilder<int>(
                    valueListenable: _progress,
                    builder: (_, prog, __) => _LoadingOverlay(progress: prog),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Top chrome ───────────────────────────────────────────────────────────────
// Uses ValueListenableBuilder internally — only the progress bar and back button
// repaint when their notifiers change.

class _TopChrome extends StatelessWidget {
  final double              paddingTop;
  final ValueNotifier<int>  progressNotifier;
  final ValueNotifier<bool> loadedNotifier;
  final ValueNotifier<bool> canGoBackNotifier;
  final VoidCallback        onBack;
  final VoidCallback        onReload;
  final VoidCallback        onSections;

  const _TopChrome({
    required this.paddingTop,
    required this.progressNotifier,
    required this.loadedNotifier,
    required this.canGoBackNotifier,
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
          colors: [AppColors.bg, AppColors.bg.withOpacity(0)],
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
                // Back button — only repaints when canGoBack changes
                ValueListenableBuilder<bool>(
                  valueListenable: canGoBackNotifier,
                  builder: (_, canBack, __) => AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity:  canBack ? 1.0 : 0.0,
                    child: _ChromeBtn(icon: Icons.arrow_back_ios_new_rounded, onTap: onBack),
                  ),
                ),
                const SizedBox(width: 6),
                // URL pill — static, never rebuilds
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
                    child: Row(children: [
                      const Icon(Icons.lock_rounded, color: AppColors.accent, size: 11),
                      const SizedBox(width: 6),
                      Text('emmanuel1017.github.io',
                        style: GoogleFonts.montserrat(
                          fontSize: 11.5, color: AppColors.textMid,
                          fontWeight: FontWeight.w500)),
                    ]),
                  ),
                ),
                const SizedBox(width: 6),
                _ChromeBtn(icon: Icons.menu_rounded,    onTap: onSections),
                const SizedBox(width: 4),
                // Reload/stop icon — repaints when loaded changes
                ValueListenableBuilder<bool>(
                  valueListenable: loadedNotifier,
                  builder: (_, loaded, __) => _ChromeBtn(
                    icon:  loaded ? Icons.refresh_rounded : Icons.close_rounded,
                    onTap: onReload,
                  ),
                ),
              ],
            ),
          ),
          // Progress bar — repaints on every progress tick, but only this widget
          ValueListenableBuilder<bool>(
            valueListenable: loadedNotifier,
            builder: (_, loaded, __) {
              if (loaded) return const SizedBox.shrink();
              return ValueListenableBuilder<int>(
                valueListenable: progressNotifier,
                builder: (_, prog, __) => SizedBox(
                  height: 2,
                  child:  LinearProgressIndicator(
                    value:           prog / 100,
                    backgroundColor: Colors.transparent,
                    valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ChromeBtn extends StatelessWidget {
  final IconData     icon;
  final VoidCallback onTap;
  const _ChromeBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color:  AppColors.surface.withOpacity(.92),
        shape:  BoxShape.circle,
        border: Border.all(color: AppColors.border),
      ),
      child: Icon(icon, color: AppColors.textMid, size: 16),
    ),
  );
}

// ─── Section pill strip ───────────────────────────────────────────────────────

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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color:        AppColors.surface.withOpacity(.96),
            borderRadius: BorderRadius.circular(28),
            border:       Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color:      Colors.black.withOpacity(.3),
                blurRadius: 16, offset: const Offset(0, 4)),
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
                      horizontal: active ? 12 : 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.primary.withOpacity(.25)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: active
                        ? Border.all(color: AppColors.primary.withOpacity(.5))
                        : null,
                  ),
                  child: Text(_sectionLabels[i],
                    style: GoogleFonts.montserrat(
                      fontSize:   11,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color:      active ? AppColors.accent : AppColors.textMid,
                    )),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ─── Loading overlay ──────────────────────────────────────────────────────────

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
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.accent],
                  begin:  Alignment.topLeft,
                  end:    Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color:      AppColors.primary.withOpacity(.4),
                    blurRadius: 24),
                ],
              ),
              child: const Icon(Icons.language_rounded, color: Colors.white, size: 30),
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
                  valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                  minHeight: 3,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text('Loading portfolio…',
              style: GoogleFonts.montserrat(
                fontSize: 12, color: AppColors.textMid)),
          ],
        ),
      ),
    );
  }
}
