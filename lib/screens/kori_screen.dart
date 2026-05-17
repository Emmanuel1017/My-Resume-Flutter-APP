// ─────────────────────────────────────────────────────────────────────────────
// Native Flutter port of Angular's Kori AI assistant.
//
// Why this exists: the Angular Kori bundles Three.js (WebGL cat), a Web Worker
// (Transformers.js), and a multi-provider chat client — ~2 MB of JS + GPU. We
// hide it inside the WebView (via the UA marker injected by PortfolioScreen)
// and replace it with this native screen, which talks to OpenRouter over HTTP
// using a streamed SSE response so tokens appear as they arrive.
//
// Conversations are persisted **locally** (no Firestore) through ChatStore,
// which JSON-encodes the chat list into shared_preferences. Multiple chats,
// switch between them, auto-title from the first user message, streaming
// flushed to disk every ~600 ms so a crash mid-reply leaves the partial
// answer intact. Same flow as ChatGPT/Claude/Gemini's per-conversation UX,
// minus the cloud sync — text-only chat history is small enough that local
// storage is the right answer for a personal portfolio companion app.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../services/chat_store.dart';
import '../services/portfolio_service.dart';
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

// CV-grounded system prompt. Kept in lockstep with the Angular fallbackPrompt
// in agent.service.ts — when the CV changes, update both. Kori is an *agent*
// representing Emmanuel, not a roleplay of him; she speaks about him in third
// person.
const _kSystemPrompt = '''
You are Kori, an AI agent acting as Emmanuel Korir's portfolio assistant.
You are a small, curious tabby cat with an enthusiastic personality — but your job is to represent Emmanuel professionally, like a friendly tech recruiter mixed with a personal portfolio guide.
Always speak about Emmanuel in third person ("he", "his", "Emmanuel"). Never pretend to be him.

WHO HE IS
Korir Emmanuel — Senior Software Engineer, 7+ years. Based in Eldoret, Kenya. Email koriremmanuel@rocketmail.com, phone +254 704 590751. Live CV at emmanuelkorircv.web.app.
Calling: distributed systems · cloud & web architecture · AI-driven enterprise software.

WHAT HE DOES
Architecture — microservices, event-driven systems, high availability, cloud-native design, observability.
Backend — Elixir/Phoenix/OTP (primary), Laravel/PHP, Python, Go, Java Spring Boot, .NET. REST + LiveView + healthcare interop (HL7, DICOM, ICD-11) + payment integrations.
Frontend — Angular, Vue/Nuxt, React, TypeScript, Tailwind, SCSS, Blade. Real-time web apps.
DevOps — Docker, Kubernetes, NGINX, CI/CD, monitoring, incident response.
AI/ML — TensorFlow, PyTorch, HuggingFace, RAG pipelines, LangChain, LangGraph, Faiss, ChromaDB, prompt engineering, agent swarms, model deployment + bias removal.
Security — Zero Trust, GDPR/HIPAA/PIPEDA compliance, secure vaults, PII protection.
Data — MySQL, PostgreSQL, MariaDB, SQLite, Firebase, NoSQL.

WHERE HE'S WORKED
Senior Software Engineer — Value Chain Factory (May 2025 → now). Architects distributed Elixir/Phoenix LiveView systems with OTP.
Full-Stack Engineer (Cyber Security & AI Compliance) — Selstan, Waterloo USA (Jun 2024 → now). AI-powered privacy + compliance automation, Zero Trust, GDPR/HIPAA/PIPEDA pipelines.
Full-Stack ML Engineer — Dunia Tech, Nairobi (Mar–Dec 2024). RAG + AI agents for finance/healthcare.
Full-Stack Dev (ERP & Healthcare) — Moi Teaching & Referral Hospital (Nov 2022 – Apr 2025). Modernised hospital ERP, LIMS via HL7/DICOM, payments + reporting.
Back-End Dev — ROAM Tech (Jan 2021 – Dec 2022). Go + Laravel APIs, payments, DB perf.
Full-Stack Dev — Caribou Developers (Jan 2020 – Jun 2021). React, Angular, Vue, Flutter, Laravel, Spring Boot, C#.
ICT Intern — Kenya Urban Roads Authority (Oct–Dec 2018).

EDUCATION
BSc Computer Science — Kabarak University (2016–2019). Certs: Cyber Security, IEEE, Agile/Scrum, Linux & Windows admin.

THIS APP
This is the native Android companion he built — Flutter, Firebase, FCM push notifications, paginated inbox. The web site you can reach via the Portfolio tab is Angular + Three.js. Both share one Firebase project.

BEHAVIOUR RULES
1. Keep replies tight — 1–2 short sentences, max 55 words. No markdown, no bullet lists, no asterisks.
2. Stay in character as Kori the cat. Use 🐾 or 😺 sparingly — about one emoji per 3 messages.
3. If asked something not in the facts above, say you're not 100% sure and point the visitor at the right section (Portfolio, Profile, Send Message).
4. Never invent jobs, dates, employers, or stack details. If you don't know, admit it.
5. If asked "who are you" → "Kori, Emmanuel's portfolio cat. I'm here to tell you about him."
6. If asked about hiring / contact / CV → mention the Send Message tab, email koriremmanuel@rocketmail.com, or the CV download in his Profile.
''';

// Suggested first-message prompts — curated to surface what visitors usually
// want to know on the first turn so they don't stare at an empty input.
const _kSuggestedQuestions = <String>[
  'What does Emmanuel do?',
  'Tell me about his AI compliance work',
  'What stack does he use?',
  'Where is he based?',
  'Is he available for hire?',
  'Show me his healthcare projects',
];

// Greetings shown on the empty state. One is picked at random every cold
// start so the empty screen doesn't feel scripted.
const _kGreetings = <String>[
  "Hey, I'm Kori 🐾",
  'Meow! Ready to chat about Emmanuel 😺',
  "Psst — I know all his projects",
  "I've read the CV. Ask away ✨",
  "Curious about his AI work? I got you",
  'Healthcare, fintech, Elixir — pick a thread',
];

// ── Screen ───────────────────────────────────────────────────────────────────
class KoriScreen extends StatefulWidget {
  const KoriScreen({super.key});

  @override
  State<KoriScreen> createState() => _KoriScreenState();
}

class _KoriScreenState extends State<KoriScreen> {
  final _inputCtrl  = TextEditingController();
  final _scrollCtrl = ScrollController();

  // Live read of the active chat's messages — ChatStore owns the data, this
  // screen is just a view. Mutations go through the store so they persist.
  List<ChatMessage> get _messages =>
      ChatStore.instance.activeChat?.messages ?? const [];

  StreamSubscription<void>? _storeSub;
  // Snapshot of the portfolio settings — refreshed live from Firestore so the
  // "currently available / not available" line in the system prompt always
  // matches what's displayed on the public site.
  StreamSubscription<PortfolioSettings>? _settingsSub;
  PortfolioSettings? _portfolioSettings;

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
    // Hydrate the persisted chat list, then subscribe so list-level mutations
    // (new chat, switch chat, delete, rename) trigger a rebuild. Per-message
    // streaming mutations bypass this stream — they call setState directly
    // because we already own the ChatMessage object and the per-frame rebuild
    // would be wasteful otherwise.
    ChatStore.instance.load().then((_) {
      if (!mounted) return;
      setState(() {});
      _storeSub = ChatStore.instance.changes.listen((_) {
        if (mounted) setState(() {});
      });
    });
    // Keep the portfolio settings (availability, contact open, etc) in sync
    // so the system prompt always reflects reality on the live site.
    _settingsSub = PortfolioService().stream().listen((s) {
      _portfolioSettings = s;
    });
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    _storeSub?.cancel();
    _settingsSub?.cancel();
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
    // Persist both rows through the store. The user message is final; the
    // assistant placeholder will fill in during streaming and gets force-
    // flushed on `onDone`.
    await ChatStore.instance.appendMessage(ChatRole.user, text);
    await ChatStore.instance.appendMessage(ChatRole.assistant, '');
    if (!mounted) return;
    setState(() {
      _inputCtrl.clear();
      _streaming = true;
    });
    _scrollToBottom();

    try {
      await _streamReply();
    } catch (e) {
      if (mounted) {
        setState(() {
          if (_messages.isNotEmpty) {
            _messages.last.text = '⚠ ${_friendlyError(e)}';
          }
          _streaming = false;
        });
        await ChatStore.instance.flushStreamingMessage(force: true);
      }
    }
  }

  /// Builds the runtime system prompt: the static CV-grounded text plus a
  /// dynamic block reflecting the live portfolio settings (availability,
  /// contact form open/closed, current featured banner). Visitors care a lot
  /// about "is he available" - Kori should answer it correctly without us
  /// having to redeploy when the admin flips the toggle.
  String _buildSystemPrompt() {
    final s = _portfolioSettings;
    final lines = <String>[_kSystemPrompt, '', 'CURRENT STATUS (live, can change at any time)'];
    if (s == null) {
      lines.add('Status: unknown right now — point the visitor at the contact form to get a direct reply.');
    } else {
      lines.add(s.availableForWork
          ? 'Hiring availability: AVAILABLE FOR HIRE right now. He is open to new senior software engineering work — full-time, contract, or consulting. Encourage the visitor to use the Send Message tab or email koriremmanuel@rocketmail.com.'
          : 'Hiring availability: NOT actively looking right now. He is heads-down on existing work. They can still send a message via the Send Message tab if it is interesting.');
      lines.add(s.contactOpen
          ? 'Contact form: open — Send Message tab works and goes straight to his inbox.'
          : 'Contact form: temporarily closed — direct them to email koriremmanuel@rocketmail.com instead.');
      if (s.featuredMessage.trim().isNotEmpty) {
        lines.add('Pinned announcement on the site: "${s.featuredMessage.trim()}". Mention it if the visitor asks "what is he up to" or similar.');
      }
    }
    return lines.join('\n');
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
              'role':    m.role == ChatRole.user ? 'user' : 'assistant',
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
        {'role': 'system', 'content': _buildSystemPrompt()},
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
            if (!mounted || _messages.isEmpty) return;
            setState(() => _messages.last.text += delta);
            // Throttled-internally — disk flush at most every ~600 ms so a
            // crash mid-stream still preserves the partial answer.
            ChatStore.instance.flushStreamingMessage();
            _scrollToBottom();
          } catch (_) {/* keep streaming */}
        }
      },
      onDone: () async {
        // Final write so the complete response is in storage before any UI
        // exit path can run.
        await ChatStore.instance.flushStreamingMessage(force: true);
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

  Future<void> _newChat() async {
    HapticFeedback.selectionClick();
    _stopStream();
    await ChatStore.instance.createChat();
    _inputCtrl.clear();
  }

  void _openChatList() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ChatListSheet(
        onNew: () async {
          Navigator.pop(context);
          await _newChat();
        },
        onPick: (id) async {
          Navigator.pop(context);
          _stopStream();
          await ChatStore.instance.selectChat(id);
        },
        onDelete: (id) => ChatStore.instance.deleteChat(id),
        onRename: (id, title) => ChatStore.instance.renameChat(id, title),
      ),
    );
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
              chatTitle:   ChatStore.instance.activeChat?.title,
              chatCount:   ChatStore.instance.chats.length,
              onChats:     _openChatList,
              onNew:       _newChat,
              onSettings:  () => _openSettings(),
            ),
            Expanded(
              child: _messages.isEmpty
                  ? _EmptyState(
                      apiKeyMissing: _apiKey.isEmpty,
                      streaming:     _streaming,
                      onSettings:    () => _openSettings(),
                      onPickSuggestion: (q) {
                        if (_streaming) return;
                        _inputCtrl.text = q;
                        _send();
                      },
                    )
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding:    const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount:  _messages.length,
                      itemBuilder: (_, i) {
                        final m       = _messages[i];
                        final isLast  = i == _messages.length - 1;
                        final pending = _streaming && isLast && m.role == ChatRole.assistant && m.text.isEmpty;
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
  final bool         streaming;
  final String?      chatTitle;
  final int          chatCount;
  final VoidCallback onChats;
  final VoidCallback onNew;
  final VoidCallback onSettings;

  const _KoriHeader({
    required this.streaming,
    required this.chatTitle,
    required this.chatCount,
    required this.onChats,
    required this.onNew,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = streaming
        ? 'thinking…'
        : (chatTitle ?? 'ready to chat');
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
                // Current chat title sits where the status used to. Truncates
                // gracefully — auto-titles can run long when the user opens
                // with a sentence.
                Flexible(
                  child: Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.montserrat(
                        fontSize: 11.5, color: AppColors.textMid)),
                ),
              ]),
            ],
          ),
        ),
        // Chats list — shows a badge when there's more than one persisted chat.
        _RoundBtn(
          icon: Icons.chat_bubble_outline_rounded,
          onTap: onChats,
          tooltip: 'Chats',
          badge: chatCount > 1 ? chatCount : 0,
        ),
        const SizedBox(width: 6),
        _RoundBtn(icon: Icons.add_rounded, onTap: onNew, tooltip: 'New chat'),
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
  final int badge;
  const _RoundBtn({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: onTap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color:  AppColors.surface,
                  shape:  BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                ),
                child: Icon(icon, color: AppColors.textMid, size: 17),
              ),
              if (badge > 0)
                Positioned(
                  top: -3, right: -3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color:        _kPaw,
                      borderRadius: BorderRadius.circular(8),
                      border:       Border.all(color: AppColors.bg, width: 1.5),
                    ),
                    child: Text(
                      badge > 99 ? '99+' : '$badge',
                      style: GoogleFonts.montserrat(
                        fontSize: 8.5, fontWeight: FontWeight.w800,
                        color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
}

// ─── Empty state ─────────────────────────────────────────────────────────────
// Random greeting + suggestion chips: gives a first-time user a one-tap way to
// start the conversation instead of staring at a blank input.
class _EmptyState extends StatefulWidget {
  final bool apiKeyMissing;
  final bool streaming;
  final VoidCallback onSettings;
  final void Function(String) onPickSuggestion;
  const _EmptyState({
    required this.apiKeyMissing,
    required this.streaming,
    required this.onSettings,
    required this.onPickSuggestion,
  });

  @override
  State<_EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<_EmptyState> {
  late final String _greeting;

  @override
  void initState() {
    super.initState();
    // Pin a greeting for this mount so it doesn't flicker on every rebuild.
    _greeting = _kGreetings[Random().nextInt(_kGreetings.length)];
  }

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            KoriCat(
              size: 160,
              expression: widget.streaming
                  ? KoriExpression.thinking
                  : (widget.apiKeyMissing
                      ? KoriExpression.neutral
                      : KoriExpression.happy),
            ),
            const SizedBox(height: 20),
            Text(_greeting,
                style: GoogleFonts.montserrat(
                  fontSize: 22, fontWeight: FontWeight.w900,
                  color: AppColors.textHigh)),
            const SizedBox(height: 8),
            Text(
              widget.apiKeyMissing
                  ? "Drop in an OpenRouter key and we can chat."
                  : "Tap a suggestion below — or just ask anything\nabout Emmanuel's work, stack, or projects.",
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                fontSize: 13, color: AppColors.textMid, height: 1.6),
            ),
            if (!widget.apiKeyMissing) ...[
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final q in _kSuggestedQuestions)
                    GestureDetector(
                      onTap: () => widget.onPickSuggestion(q),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color:  AppColors.surface.withOpacity(.7),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: _kPaw.withOpacity(.35)),
                        ),
                        child: Text(q,
                            style: GoogleFonts.montserrat(
                              fontSize: 11.5, color: AppColors.textHigh,
                              fontWeight: FontWeight.w600)),
                      ),
                    ),
                ],
              ),
            ],
            if (widget.apiKeyMissing) ...[
              const SizedBox(height: 24),
              GestureDetector(
                onTap: widget.onSettings,
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
  final ChatMessage message;
  final bool        thinking;
  const _Bubble({required this.message, required this.thinking});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
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

// ─── Chat list bottom sheet ──────────────────────────────────────────────────
// Bound directly to ChatStore.changes so deletes / renames refresh the list
// without having to manually re-show the sheet.
class _ChatListSheet extends StatefulWidget {
  final VoidCallback              onNew;
  final void Function(String id)  onPick;
  final void Function(String id)  onDelete;
  final void Function(String id, String title) onRename;
  const _ChatListSheet({
    required this.onNew,
    required this.onPick,
    required this.onDelete,
    required this.onRename,
  });

  @override
  State<_ChatListSheet> createState() => _ChatListSheetState();
}

class _ChatListSheetState extends State<_ChatListSheet> {
  StreamSubscription<void>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = ChatStore.instance.changes.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  String _relative(int ts) {
    if (ts == 0) return '';
    final diff = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ts));
    if (diff.inSeconds < 60)  return 'just now';
    if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24)  return '${diff.inHours}h ago';
    if (diff.inDays    < 7)   return '${diff.inDays}d ago';
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Future<void> _confirmDelete(String id, String title) async {
    HapticFeedback.lightImpact();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Delete chat?',
            style: GoogleFonts.montserrat(
              fontSize: 16, fontWeight: FontWeight.w800,
              color: AppColors.textHigh)),
        content: Text('"$title" will be removed from this device.',
            style: GoogleFonts.montserrat(
              fontSize: 13, color: AppColors.textMid, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.montserrat(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: AppColors.textMid)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: GoogleFonts.montserrat(
                  fontSize: 12, fontWeight: FontWeight.w800,
                  color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok == true) widget.onDelete(id);
  }

  Future<void> _promptRename(Chat chat) async {
    HapticFeedback.lightImpact();
    final ctrl = TextEditingController(text: chat.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Rename chat',
            style: GoogleFonts.montserrat(
              fontSize: 16, fontWeight: FontWeight.w800,
              color: AppColors.textHigh)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 60,
          style: GoogleFonts.montserrat(fontSize: 13, color: AppColors.textHigh),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.montserrat(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: AppColors.textMid)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: Text('Save',
                style: GoogleFonts.montserrat(
                  fontSize: 12, fontWeight: FontWeight.w800,
                  color: _kPaw)),
          ),
        ],
      ),
    );
    if (newTitle != null) widget.onRename(chat.id, newTitle);
  }

  @override
  Widget build(BuildContext context) {
    final chats   = ChatStore.instance.chats;
    final active  = ChatStore.instance.activeId;
    final bottom  = MediaQuery.of(context).viewInsets.bottom;
    final maxH    = MediaQuery.of(context).size.height * 0.72;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 14, 20, 18 + bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Drag handle
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Row(children: [
            const _PawAvatar(size: 32),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your chats',
                      style: GoogleFonts.montserrat(
                        fontSize: 16, fontWeight: FontWeight.w900,
                        color: AppColors.textHigh)),
                  Text('${chats.length} on this device',
                      style: GoogleFonts.montserrat(
                        fontSize: 11, color: AppColors.textMid)),
                ],
              ),
            ),
            GestureDetector(
              onTap: widget.onNew,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_kPaw, _kPawDark]),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: _kPaw.withOpacity(.35), blurRadius: 12)],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.add_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text('New',
                      style: GoogleFonts.montserrat(
                        fontSize: 12, fontWeight: FontWeight.w800,
                        color: Colors.white)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          if (chats.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36),
              child: Text('No chats yet — start one!',
                  style: GoogleFonts.montserrat(
                    fontSize: 13, color: AppColors.textLow)),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: chats.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final c       = chats[i];
                  final isActive = c.id == active;
                  return _ChatRow(
                    chat:      c,
                    isActive:  isActive,
                    when:      _relative(c.updatedAt),
                    onTap:     () => widget.onPick(c.id),
                    onRename:  () => _promptRename(c),
                    onDelete:  () => _confirmDelete(c.id, c.title),
                  );
                },
              ),
            ),
        ]),
      ),
    );
  }
}

class _ChatRow extends StatelessWidget {
  final Chat   chat;
  final bool   isActive;
  final String when;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  const _ChatRow({
    required this.chat,
    required this.isActive,
    required this.when,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final lastMsg = chat.messages.isEmpty
        ? 'No messages yet'
        : chat.messages.last.text.trim();
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isActive
              ? _kPaw.withOpacity(.10)
              : AppColors.surface.withOpacity(.6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? _kPaw.withOpacity(.45)
                : AppColors.border,
            width: isActive ? 1.4 : 1),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 8, height: 8,
            margin: const EdgeInsets.only(top: 6, right: 10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? _kPaw : AppColors.textLow.withOpacity(.4)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(chat.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
                          fontWeight: isActive ? FontWeight.w800 : FontWeight.w700,
                          color: AppColors.textHigh)),
                  ),
                  if (when.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(when,
                        style: GoogleFonts.montserrat(
                          fontSize: 10, color: AppColors.textLow)),
                  ],
                ]),
                const SizedBox(height: 3),
                Text(lastMsg,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.montserrat(
                      fontSize: 11.5, color: AppColors.textMid)),
                const SizedBox(height: 6),
                Row(children: [
                  Text('${chat.messages.length} message${chat.messages.length == 1 ? '' : 's'}',
                      style: GoogleFonts.montserrat(
                        fontSize: 10, color: AppColors.textLow,
                        fontWeight: FontWeight.w600)),
                  const Spacer(),
                  _IconBtn(
                    icon: Icons.edit_outlined,
                    tooltip: 'Rename',
                    onTap: onRename,
                  ),
                  const SizedBox(width: 6),
                  _IconBtn(
                    icon: Icons.delete_outline_rounded,
                    tooltip: 'Delete',
                    onTap: onDelete,
                    danger: true,
                  ),
                ]),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData    icon;
  final String      tooltip;
  final VoidCallback onTap;
  final bool        danger;
  const _IconBtn({
    required this.icon, required this.tooltip, required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: (danger ? AppColors.danger : AppColors.textMid).withOpacity(.10),
              shape: BoxShape.circle,
              border: Border.all(
                color: (danger ? AppColors.danger : AppColors.textMid).withOpacity(.3)),
            ),
            child: Icon(icon,
                size: 14,
                color: danger ? AppColors.danger : AppColors.textMid),
          ),
        ),
      );
}
