// ─────────────────────────────────────────────────────────────────────────────
// Native Flutter port of Angular's Kori AI assistant.
//
// Why this exists: the Angular Kori bundles Three.js (WebGL cat), a Web Worker
// (Transformers.js), and a multi-provider chat client — ~2 MB of JS + GPU. We
// hide it inside the WebView (via the UA marker injected by PortfolioScreen)
// and replace it with this native screen, which talks to OpenRouter over HTTP
// using a streamed SSE response so tokens appear as they arrive.
//
// Settings (API key, model) are persisted in shared_preferences. Conversation
// is kept in-memory only — clears on tab teardown, matching the "release
// everything on tab switch" memory model used by the rest of the app.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';
import '../widgets/kori_cat.dart';

// ── Kori palette (matches Angular agent.component.scss) ──────────────────────
const _kPaw       = Color(0xFFF4934A); // orange paw
const _kPawDark   = Color(0xFFD97A37);
const _kBubbleBg  = Color(0xFF1A2540); // user bubble
const _kAssistBg  = Color(0xFF161D2E); // kori bubble
const _kBorder    = Color(0xFF2A3550);

// Default OpenRouter model — must stay in lock-step with Angular's
// DEFAULT_SETTINGS.openrouterModel in agent.service.ts. The previously-shipped
// :free models are rate-limited or removed; OpenRouter returns "model not
// found" for them. `openai/gpt-4o-mini` is the canonical paid default.
const _kDefaultModel = 'openai/gpt-4o-mini';

// Models we auto-migrate to the current default. Mirrors STALE_OR_MODELS in
// the Angular agent.service.ts — if a user has any of these saved from an
// earlier build they get silently bumped onto the working default.
const _kStaleModels = <String>{
  'meta-llama/llama-3.1-8b-instruct:free',
  'google/gemma-2-9b-it:free',
  'deepseek/deepseek-chat:free',
  'meta-llama/llama-3.3-70b-instruct:free',
};

// Hard-coded system prompt mirrors agent.service.ts fallback persona.
const _kSystemPrompt =
    "You are Kori, Emmanuel Korir's AI assistant cat — curious, warm, slightly cheeky. "
    "Emmanuel is a Senior Software Engineer (7+ yrs) specialising in distributed systems, AI/ML, "
    "cloud-native backends, healthcare platforms (HL7, DICOM, HIPAA), fintech (M-Pesa), and UI/SVG animation. "
    "Backend: Elixir/Phoenix, Laravel, Go, Python, Node. Frontend: Angular, Vue, React, TypeScript. "
    "Infra: Docker, Kubernetes, Grafana, Redis, PostgreSQL. Location: Eldoret, Kenya. "
    "Reply in 1–2 short sentences, no markdown, max 55 words. Stay in character — enthusiastic, helpful cat. "
    "Occasionally use 🐾 or 😺 but not every message.";

// ── Message model ────────────────────────────────────────────────────────────
enum _Role { user, assistant }

class _Msg {
  final _Role role;
  String text;
  _Msg(this.role, this.text);
}

// ── Screen ───────────────────────────────────────────────────────────────────
class KoriScreen extends StatefulWidget {
  const KoriScreen({super.key});

  @override
  State<KoriScreen> createState() => _KoriScreenState();
}

class _KoriScreenState extends State<KoriScreen> {
  final _inputCtrl  = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_Msg> _messages = [];

  // Key resolution mirrors the Angular agent.service.ts pattern: try a local
  // user-provided override first (settings sheet), then fall back to the key
  // shipped via Firebase Remote Config (key name `openrouter_api_key`).
  String _userApiKey   = '';   // local override from settings sheet
  String _remoteApiKey = '';   // from Firebase Remote Config
  String _model        = _kDefaultModel;
  bool   _settingsLoaded = false;
  bool   _streaming      = false;
  StreamSubscription<List<int>>? _streamSub;
  http.Client? _httpClient;

  // Effective key: user-provided wins, then remote, then empty.
  String get _apiKey => _userApiKey.isNotEmpty ? _userApiKey : _remoteApiKey;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    _httpClient?.close();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final p = await SharedPreferences.getInstance();
    // Auto-migrate users who saved a now-broken model id in a previous build.
    var savedModel = p.getString('kori_model');
    if (savedModel != null && _kStaleModels.contains(savedModel)) {
      savedModel = null;
      await p.remove('kori_model');
    }
    if (!mounted) return;
    setState(() {
      _userApiKey     = p.getString('kori_openrouter_key') ?? '';
      _model          = savedModel ?? _kDefaultModel;
      _settingsLoaded = true;
    });
    // Fetch Remote Config key in the background — same pattern as Angular's
    // fetchRemoteKey(): non-blocking, silent on failure. If it succeeds before
    // the user sends a message they don't need to paste anything.
    _fetchRemoteKey();
  }

  Future<void> _fetchRemoteKey() async {
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout:      const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ));
      await rc.setDefaults(const {'openrouter_api_key': ''});
      await rc.fetchAndActivate();
      final key = rc.getString('openrouter_api_key');
      if (key.isNotEmpty && mounted) {
        setState(() => _remoteApiKey = key);
      }
    } catch (_) {
      // Remote Config unavailable — fall back to user-provided key via ⚙️.
    }
  }

  Future<void> _saveSettings(String key, String model) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('kori_openrouter_key', key.trim());
    await p.setString('kori_model', model.trim().isEmpty ? _kDefaultModel : model.trim());
    if (!mounted) return;
    setState(() {
      _userApiKey = key.trim();
      _model      = model.trim().isEmpty ? _kDefaultModel : model.trim();
    });
  }

  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent + 200,
        duration: const Duration(milliseconds: 220),
        curve:    Curves.easeOutCubic,
      );
    });
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _streaming) return;

    if (_apiKey.isEmpty) {
      _openSettings(missingKey: true);
      return;
    }

    HapticFeedback.lightImpact();
    setState(() {
      _messages.add(_Msg(_Role.user,      text));
      _messages.add(_Msg(_Role.assistant, '')); // placeholder for streamed reply
      _inputCtrl.clear();
      _streaming = true;
    });
    _scrollToBottom();

    try {
      await _streamReply();
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.last.text = '⚠ ${_friendlyError(e)}';
          _streaming = false;
        });
      }
    }
  }

  String _friendlyError(Object e) {
    final s = e.toString();
    if (s.contains('401') || s.contains('Unauthorized')) return 'Invalid API key — tap ⚙ to fix.';
    if (s.contains('429')) return 'Rate limited — slow down a bit, friend.';
    if (s.contains('SocketException') || s.contains('Failed host')) return 'No internet.';
    return 'Something went wrong: $s';
  }

  // OpenRouter SSE streaming — POST /chat/completions with stream:true, then
  // parse `data: {...}\n\n` chunks. Append each delta to the placeholder msg.
  Future<void> _streamReply() async {
    _httpClient?.close();
    _httpClient = http.Client();

    final history = _messages
        .take(_messages.length - 1) // exclude empty placeholder
        .map((m) => {
              'role':    m.role == _Role.user ? 'user' : 'assistant',
              'content': m.text,
            })
        .toList();

    final req = http.Request(
      'POST',
      Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
    );
    req.headers.addAll({
      'Authorization':  'Bearer $_apiKey',
      'Content-Type':   'application/json',
      'HTTP-Referer':   'https://emmanuel1017.github.io/Angular-Resume/',
      // HTTP header values must be US-ASCII. "Portfolio Admin — Kori" (em-dash
      // at byte 17) makes Dart's HttpClient throw `invalid http header field
      // value`. Use a plain hyphen.
      'X-Title':        'Portfolio Admin - Kori',
    });
    req.body = jsonEncode({
      'model':    _model,
      'stream':   true,
      'messages': [
        {'role': 'system', 'content': _kSystemPrompt},
        ...history,
      ],
    });

    final res = await _httpClient!.send(req);
    if (res.statusCode >= 400) {
      final body = await res.stream.bytesToString();
      throw Exception('${res.statusCode} $body');
    }

    final completer = Completer<void>();
    var buf = '';

    _streamSub = res.stream.listen(
      (bytes) {
        buf += utf8.decode(bytes, allowMalformed: true);
        while (true) {
          final idx = buf.indexOf('\n');
          if (idx < 0) break;
          final line = buf.substring(0, idx).trim();
          buf = buf.substring(idx + 1);
          if (line.isEmpty || !line.startsWith('data:')) continue;
          final data = line.substring(5).trim();
          if (data == '[DONE]') continue;
          try {
            final obj   = jsonDecode(data) as Map<String, dynamic>;
            final delta = (obj['choices'] as List?)?[0]?['delta']?['content'] as String?;
            if (delta == null || delta.isEmpty) continue;
            if (!mounted) return;
            setState(() => _messages.last.text += delta);
            _scrollToBottom();
          } catch (_) {/* keep streaming */}
        }
      },
      onDone: () {
        if (mounted) setState(() => _streaming = false);
        completer.complete();
      },
      onError: (e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
      cancelOnError: true,
    );

    return completer.future;
  }

  void _stopStream() {
    HapticFeedback.mediumImpact();
    _streamSub?.cancel();
    _httpClient?.close();
    if (mounted) setState(() => _streaming = false);
  }

  void _clearChat() {
    HapticFeedback.selectionClick();
    _stopStream();
    setState(_messages.clear);
  }

  void _openSettings({bool missingKey = false}) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _SettingsSheet(
        initialKey:    _userApiKey,
        initialModel:  _model,
        hasRemoteKey:  _remoteApiKey.isNotEmpty,
        warnMissingKey: missingKey,
        onSave: (k, m) {
          _saveSettings(k, m);
          Navigator.pop(context);
        },
      ),
    );
  }

  // ── UI ──────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (!_settingsLoaded) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator(color: _kPaw, strokeWidth: 2)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _KoriHeader(
              streaming:   _streaming,
              hasMessages: _messages.isNotEmpty,
              onSettings:  () => _openSettings(),
              onClear:     _clearChat,
            ),
            Expanded(
              child: _messages.isEmpty
                  ? _EmptyState(
                      apiKeyMissing: _apiKey.isEmpty,
                      streaming:     _streaming,
                      onSettings:    () => _openSettings())
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding:    const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount:  _messages.length,
                      itemBuilder: (_, i) {
                        final m       = _messages[i];
                        final isLast  = i == _messages.length - 1;
                        final pending = _streaming && isLast && m.role == _Role.assistant && m.text.isEmpty;
                        return _Bubble(message: m, thinking: pending);
                      },
                    ),
            ),
            _Composer(
              controller: _inputCtrl,
              streaming:  _streaming,
              onSend:     _send,
              onStop:     _stopStream,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────
class _KoriHeader extends StatelessWidget {
  final bool streaming;
  final bool hasMessages;
  final VoidCallback onSettings;
  final VoidCallback onClear;

  const _KoriHeader({
    required this.streaming,
    required this.hasMessages,
    required this.onSettings,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(children: [
        KoriCat(
          size: 44,
          expression: streaming ? KoriExpression.thinking : KoriExpression.happy,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Kori',
                  style: GoogleFonts.montserrat(
                    fontSize: 18, fontWeight: FontWeight.w900,
                    color: AppColors.textHigh)),
              Row(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 7, height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: streaming ? _kPaw : AppColors.accent,
                  ),
                ),
                const SizedBox(width: 6),
                Text(streaming ? 'thinking…' : 'ready to chat',
                    style: GoogleFonts.montserrat(
                      fontSize: 11.5, color: AppColors.textMid)),
              ]),
            ],
          ),
        ),
        if (hasMessages)
          _RoundBtn(icon: Icons.delete_sweep_outlined, onTap: onClear, tooltip: 'Clear chat'),
        const SizedBox(width: 6),
        _RoundBtn(icon: Icons.settings_rounded, onTap: onSettings, tooltip: 'Settings'),
      ]),
    );
  }
}

// ─── Paw avatar (SVG-shape via CustomPaint to avoid extra deps) ──────────────
class _PawAvatar extends StatelessWidget {
  final double size;
  const _PawAvatar({required this.size});

  @override
  Widget build(BuildContext context) => Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [_kPaw, _kPawDark],
            begin:  Alignment.topLeft,
            end:    Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color:      _kPaw.withOpacity(.4),
              blurRadius: 18,
              spreadRadius: 1,
            ),
          ],
        ),
        child: CustomPaint(painter: _PawPainter()),
      );
}

class _PawPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(.95);
    final w = size.width, h = size.height;
    // Main pad (ellipse, lower-center)
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * .5, h * .62), width: w * .42, height: h * .34),
      paint,
    );
    // Three toes
    final toeR = w * .085;
    canvas.drawCircle(Offset(w * .32, h * .34), toeR, paint);
    canvas.drawCircle(Offset(w * .50, h * .27), toeR, paint);
    canvas.drawCircle(Offset(w * .68, h * .34), toeR, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─── Round icon button ───────────────────────────────────────────────────────
class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  const _RoundBtn({required this.icon, required this.onTap, required this.tooltip});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color:  AppColors.surface,
              shape:  BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, color: AppColors.textMid, size: 17),
          ),
        ),
      );
}

// ─── Empty state ─────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final bool apiKeyMissing;
  final bool streaming;
  final VoidCallback onSettings;
  const _EmptyState({
    required this.apiKeyMissing,
    required this.streaming,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            KoriCat(
              size: 160,
              expression: streaming
                  ? KoriExpression.thinking
                  : (apiKeyMissing
                      ? KoriExpression.neutral
                      : KoriExpression.happy),
            ),
            const SizedBox(height: 20),
            Text("Hey, I'm Kori 🐾",
                style: GoogleFonts.montserrat(
                  fontSize: 22, fontWeight: FontWeight.w900,
                  color: AppColors.textHigh)),
            const SizedBox(height: 8),
            Text(
              apiKeyMissing
                  ? "Drop in an OpenRouter key and we can chat."
                  : "Ask me anything about Emmanuel — his work, stack,\nor that one healthcare project.",
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                fontSize: 13, color: AppColors.textMid, height: 1.6),
            ),
            if (apiKeyMissing) ...[
              const SizedBox(height: 24),
              GestureDetector(
                onTap: onSettings,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_kPaw, _kPawDark]),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(color: _kPaw.withOpacity(.4), blurRadius: 16),
                    ],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.vpn_key_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Text('Add API key',
                        style: GoogleFonts.montserrat(
                          fontSize: 13, fontWeight: FontWeight.w800,
                          color: Colors.white)),
                  ]),
                ),
              ),
            ],
          ]),
        ),
      );
}

// ─── Chat bubble ─────────────────────────────────────────────────────────────
class _Bubble extends StatelessWidget {
  final _Msg  message;
  final bool  thinking;
  const _Bubble({required this.message, required this.thinking});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == _Role.user;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:  isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            const _PawAvatar(size: 28),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .76),
              padding:     const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color:  isUser ? _kBubbleBg : _kAssistBg,
                borderRadius: BorderRadius.only(
                  topLeft:     const Radius.circular(16),
                  topRight:    const Radius.circular(16),
                  bottomLeft:  Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: Border.all(
                  color: isUser
                      ? AppColors.primary.withOpacity(.35)
                      : _kBorder,
                ),
              ),
              child: thinking
                  ? const _ThinkingDots()
                  : Text(message.text,
                      style: GoogleFonts.montserrat(
                        fontSize: 13.5,
                        height:   1.5,
                        color:    AppColors.textHigh,
                      )),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Thinking dots (animated, three pulsing dots) ────────────────────────────
class _ThinkingDots extends StatefulWidget {
  const _ThinkingDots();
  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final t = (_c.value + i * .25) % 1.0;
            final s = (t < .5 ? t * 2 : (1 - t) * 2);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              child: Container(
                width: 7, height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kPaw.withOpacity(.4 + s * .6),
                ),
              ),
            );
          }),
        ),
      );
}

// ─── Composer ────────────────────────────────────────────────────────────────
class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool         streaming;
  final VoidCallback onSend;
  final VoidCallback onStop;
  const _Composer({
    required this.controller,
    required this.streaming,
    required this.onSend,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 12 + bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
        decoration: BoxDecoration(
          color:        AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border:       Border.all(color: AppColors.border),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines:   1,
              maxLines:   4,
              enabled:    !streaming,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              style: GoogleFonts.montserrat(
                fontSize: 14, color: AppColors.textHigh),
              decoration: InputDecoration(
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: InputBorder.none,
                hintText: streaming ? 'Kori is replying…' : 'Ask about Emmanuel…',
                hintStyle: GoogleFonts.montserrat(
                  fontSize: 13.5, color: AppColors.textLow),
                filled: false,
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: streaming ? onStop : onSend,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: streaming
                      ? [AppColors.danger, AppColors.danger.withOpacity(.85)]
                      : const [_kPaw, _kPawDark],
                ),
                boxShadow: [
                  BoxShadow(
                    color: (streaming ? AppColors.danger : _kPaw).withOpacity(.4),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Icon(
                streaming ? Icons.stop_rounded : Icons.arrow_upward_rounded,
                color: Colors.white, size: 19,
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Settings sheet ──────────────────────────────────────────────────────────
class _SettingsSheet extends StatefulWidget {
  final String initialKey;
  final String initialModel;
  final bool   hasRemoteKey;
  final bool   warnMissingKey;
  final void Function(String key, String model) onSave;
  const _SettingsSheet({
    required this.initialKey,
    required this.initialModel,
    required this.hasRemoteKey,
    required this.warnMissingKey,
    required this.onSave,
  });
  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late final TextEditingController _keyCtrl   = TextEditingController(text: widget.initialKey);
  late final TextEditingController _modelCtrl = TextEditingController(text: widget.initialModel);
  bool _obscure = true;

  @override
  void dispose() {
    _keyCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Drag handle
        Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
            color:        AppColors.border,
            borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 18),
        Row(children: [
          const _PawAvatar(size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kori Settings',
                    style: GoogleFonts.montserrat(
                      fontSize: 17, fontWeight: FontWeight.w900,
                      color: AppColors.textHigh)),
                Text('OpenRouter — one key, every model',
                    style: GoogleFonts.montserrat(
                      fontSize: 11.5, color: AppColors.textMid)),
              ],
            ),
          ),
        ]),
        if (widget.hasRemoteKey) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:  AppColors.accent.withOpacity(.10),
              border: Border.all(color: AppColors.accent.withOpacity(.35)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              const Icon(Icons.cloud_done_rounded, color: AppColors.accent, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Using shared key from Firebase Remote Config — leave blank '
                  'to keep using it, or paste your own to override.',
                  style: GoogleFonts.montserrat(
                    fontSize: 12, color: AppColors.textHigh, height: 1.4)),
              ),
            ]),
          ),
        ] else if (widget.warnMissingKey) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:  _kPaw.withOpacity(.12),
              border: Border.all(color: _kPaw.withOpacity(.4)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded, color: _kPaw, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'No shared key found — paste your own OpenRouter key to chat.',
                  style: GoogleFonts.montserrat(
                    fontSize: 12, color: AppColors.textHigh)),
              ),
            ]),
          ),
        ],
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerLeft,
          child: Text('API key',
              style: GoogleFonts.montserrat(
                fontSize: 11.5, color: AppColors.textMid,
                fontWeight: FontWeight.w700, letterSpacing: .8)),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _keyCtrl,
          obscureText: _obscure,
          style: GoogleFonts.robotoMono(fontSize: 13, color: AppColors.textHigh),
          decoration: InputDecoration(
            hintText: 'sk-or-v1-…',
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppColors.textMid, size: 18),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: Text('Model',
              style: GoogleFonts.montserrat(
                fontSize: 11.5, color: AppColors.textMid,
                fontWeight: FontWeight.w700, letterSpacing: .8)),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _modelCtrl,
          style: GoogleFonts.robotoMono(fontSize: 13, color: AppColors.textHigh),
          decoration: const InputDecoration(hintText: _kDefaultModel),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Anything on openrouter.ai/models works. Default matches the web '
            'Kori — openai/gpt-4o-mini.',
            style: GoogleFonts.montserrat(
              fontSize: 11, color: AppColors.textLow, height: 1.5),
          ),
        ),
        const SizedBox(height: 22),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('Cancel',
                  style: GoogleFonts.montserrat(
                    fontSize: 13, color: AppColors.textMid,
                    fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () => widget.onSave(_keyCtrl.text, _modelCtrl.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPaw,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('Save',
                  style: GoogleFonts.montserrat(
                    fontSize: 13, fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      ]),
    );
  }
}
