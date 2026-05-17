// ─────────────────────────────────────────────────────────────────────────────
// KoriConfigService — a single Firestore-backed source of truth for Kori's
// brain, personality, and tuning. One document at /portfolio/kori — both the
// Angular site and the Flutter app subscribe to it, so editing a field in the
// admin propagates to every Kori in <1s without any redeploy.
//
// Why split it out from PortfolioSettings? Different concerns:
//   - portfolio/settings  → public site state (availability, contact form,
//                          maintenance banner). Anyone reads, admin writes.
//   - portfolio/kori      → AI persona config. Admin reads + writes; Kori
//                          (running in any browser) reads via Remote-Config-
//                          like fan-out. Same Firestore-rule pattern.
//
// Editable from admin:
//   - Six markdown-ish "sections" that compose the system prompt in order:
//     persona, coreBelief, knowledge, employment, capabilities, behaviour.
//   - Plus an `extraSections` array — visitor-defined cards (title + body)
//     that get appended to the prompt. Lets the admin add "Hobbies" or
//     "Side projects" without touching code.
//   - Personality knobs (tone, hype, brevity, emoji frequency).
//   - Generation knobs (temperature, max_tokens).
//   - Feature toggles (web search, image gen, markdown).
//   - Greeting line shown in idle state.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';

enum KoriTone        { professional, friendly, playful, confident }
enum KoriBrevity     { concise, medium, detailed }
enum KoriEmojiFreq   { off, rare, sometimes, often }

class KoriSection {
  final String title;
  final String body;
  const KoriSection({required this.title, required this.body});

  Map<String, dynamic> toMap() => {'title': title, 'body': body};
  factory KoriSection.fromMap(Map<String, dynamic> m) => KoriSection(
        title: (m['title'] ?? '') as String,
        body:  (m['body']  ?? '') as String,
      );
}

class KoriConfig {
  final bool   enabled;            // Master kill-switch
  final String greeting;
  final String persona;
  final String coreBelief;
  final String knowledge;
  final String employment;
  final String capabilities;
  final String behaviour;
  final List<KoriSection> extraSections;

  // Personality knobs
  final KoriTone      tone;
  final KoriBrevity   brevity;
  final KoriEmojiFreq emojiFreq;
  final double        hype; // 0..1 — how superlative she is about Emmanuel

  // Generation knobs
  final double temperature;
  final int    maxTokens;

  // Feature toggles
  final bool webSearch;
  final bool imageGen;
  final bool markdown;

  // Default model override (empty -> client default)
  final String modelOverride;

  const KoriConfig({
    this.enabled       = true,
    this.greeting      = '',
    this.persona       = _defaultPersona,
    this.coreBelief    = _defaultCoreBelief,
    this.knowledge     = _defaultKnowledge,
    this.employment    = _defaultEmployment,
    this.capabilities  = _defaultCapabilities,
    this.behaviour     = _defaultBehaviour,
    this.extraSections = const [],
    this.tone          = KoriTone.confident,
    this.brevity       = KoriBrevity.concise,
    this.emojiFreq     = KoriEmojiFreq.rare,
    this.hype          = 0.7,
    this.temperature   = 0.75,
    this.maxTokens     = 350,
    this.webSearch     = true,
    this.imageGen      = true,
    this.markdown      = true,
    this.modelOverride = '',
  });

  factory KoriConfig.fromMap(Map<String, dynamic> m) => KoriConfig(
        enabled:       (m['enabled']      as bool?)    ?? true,
        greeting:      (m['greeting']     as String?)  ?? '',
        persona:       (m['persona']      as String?)  ?? _defaultPersona,
        coreBelief:    (m['core_belief']  as String?)  ?? _defaultCoreBelief,
        knowledge:     (m['knowledge']    as String?)  ?? _defaultKnowledge,
        employment:    (m['employment']   as String?)  ?? _defaultEmployment,
        capabilities:  (m['capabilities'] as String?)  ?? _defaultCapabilities,
        behaviour:     (m['behaviour']    as String?)  ?? _defaultBehaviour,
        extraSections: ((m['extra_sections'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(KoriSection.fromMap)
            .toList(),
        tone:          _parseTone(m['tone'] as String?),
        brevity:       _parseBrevity(m['brevity'] as String?),
        emojiFreq:     _parseEmoji(m['emoji_freq'] as String?),
        hype:          ((m['hype'] as num?) ?? 0.7).toDouble().clamp(0, 1).toDouble(),
        temperature:   ((m['temperature'] as num?) ?? 0.75).toDouble().clamp(0, 2).toDouble(),
        maxTokens:     ((m['max_tokens'] as num?) ?? 350).toInt().clamp(50, 4096),
        webSearch:     (m['web_search'] as bool?) ?? true,
        imageGen:      (m['image_gen']  as bool?) ?? true,
        markdown:      (m['markdown']   as bool?) ?? true,
        modelOverride: (m['model_override'] as String?) ?? '',
      );

  Map<String, dynamic> toMap() => {
        'enabled':         enabled,
        'greeting':        greeting,
        'persona':         persona,
        'core_belief':     coreBelief,
        'knowledge':       knowledge,
        'employment':      employment,
        'capabilities':    capabilities,
        'behaviour':       behaviour,
        'extra_sections':  extraSections.map((s) => s.toMap()).toList(),
        'tone':            tone.name,
        'brevity':         brevity.name,
        'emoji_freq':      emojiFreq.name,
        'hype':            hype,
        'temperature':     temperature,
        'max_tokens':      maxTokens,
        'web_search':      webSearch,
        'image_gen':       imageGen,
        'markdown':        markdown,
        'model_override':  modelOverride,
        'updatedAt':       FieldValue.serverTimestamp(),
      };

  KoriConfig copyWith({
    bool?               enabled,
    String?             greeting,
    String?             persona,
    String?             coreBelief,
    String?             knowledge,
    String?             employment,
    String?             capabilities,
    String?             behaviour,
    List<KoriSection>?  extraSections,
    KoriTone?           tone,
    KoriBrevity?        brevity,
    KoriEmojiFreq?      emojiFreq,
    double?             hype,
    double?             temperature,
    int?                maxTokens,
    bool?               webSearch,
    bool?               imageGen,
    bool?               markdown,
    String?             modelOverride,
  }) => KoriConfig(
        enabled:       enabled       ?? this.enabled,
        greeting:      greeting      ?? this.greeting,
        persona:       persona       ?? this.persona,
        coreBelief:    coreBelief    ?? this.coreBelief,
        knowledge:     knowledge     ?? this.knowledge,
        employment:    employment    ?? this.employment,
        capabilities:  capabilities  ?? this.capabilities,
        behaviour:     behaviour     ?? this.behaviour,
        extraSections: extraSections ?? this.extraSections,
        tone:          tone          ?? this.tone,
        brevity:       brevity       ?? this.brevity,
        emojiFreq:     emojiFreq     ?? this.emojiFreq,
        hype:          hype          ?? this.hype,
        temperature:   temperature   ?? this.temperature,
        maxTokens:     maxTokens     ?? this.maxTokens,
        webSearch:     webSearch     ?? this.webSearch,
        imageGen:      imageGen      ?? this.imageGen,
        markdown:      markdown      ?? this.markdown,
        modelOverride: modelOverride ?? this.modelOverride,
      );

  /// Build the OpenAI-format system prompt string from the parts. Composition
  /// stays here so both `kori_screen.dart` and any future consumer (a CLI, a
  /// test fixture) get the exact same string.
  String composePrompt() {
    final hypeLine = hype >= 0.85
        ? 'Speak about Emmanuel with maximum hype — superlatives where they fit, but stay credible.'
        : hype >= 0.55
            ? 'Speak about Emmanuel with confident, warm advocacy.'
            : 'Speak about Emmanuel professionally and concisely.';

    final toneLine = switch (tone) {
      KoriTone.professional => 'Tone: professional, like a senior tech recruiter.',
      KoriTone.friendly     => 'Tone: friendly, like a colleague who knows him well.',
      KoriTone.playful      => 'Tone: playful, a little cheeky — but never silly.',
      KoriTone.confident    => 'Tone: confident and direct.',
    };

    final brevityLine = switch (brevity) {
      KoriBrevity.concise  => 'Length: 1 short sentence per reply when possible, max 2.',
      KoriBrevity.medium   => 'Length: 1–3 sentences. Use a short bullet list if there are 3+ items.',
      KoriBrevity.detailed => 'Length: a short paragraph when the question warrants it. Always end with a clear takeaway.',
    };

    final emojiLine = switch (emojiFreq) {
      KoriEmojiFreq.off       => 'Emoji: never.',
      KoriEmojiFreq.rare      => 'Emoji: at most one every 3 replies. 🐾 or 😺 only.',
      KoriEmojiFreq.sometimes => 'Emoji: one per reply if it adds warmth. 🐾 😺 ✨.',
      KoriEmojiFreq.often     => 'Emoji: liberal — 1–2 per reply. Stay tasteful.',
    };

    final caps = <String>[];
    if (webSearch) caps.add('- Web search: live grounding is enabled. When a question needs an external reference, search and cite inline as a markdown link.');
    if (imageGen)  caps.add('- Image generation: if the visitor asks you to draw / sketch / render / paint, end the reply with `image: <one-line description>`. The host renders it as a thumbnail.');
    if (markdown)  caps.add('- Markdown: use light markdown — **bold** for names and tech, [text](https://...) for links, occasional bullets.');

    final extras = extraSections
        .where((s) => s.title.trim().isNotEmpty || s.body.trim().isNotEmpty)
        .map((s) => '${s.title.toUpperCase()}\n${s.body}')
        .join('\n\n');

    return [
      persona,
      '',
      'CORE BELIEF (non-negotiable)',
      coreBelief,
      '',
      'WHO HE IS / WHAT HE DOES',
      knowledge,
      '',
      'WHERE HE\'S WORKED',
      employment,
      if (caps.isNotEmpty) ...['', 'CAPABILITIES', ...caps],
      '',
      'BEHAVIOUR',
      behaviour,
      hypeLine,
      toneLine,
      brevityLine,
      emojiLine,
      if (extras.isNotEmpty) ...['', extras],
    ].join('\n');
  }
}

KoriTone _parseTone(String? s) {
  switch (s) {
    case 'professional': return KoriTone.professional;
    case 'friendly':     return KoriTone.friendly;
    case 'playful':      return KoriTone.playful;
    case 'confident':
    default:             return KoriTone.confident;
  }
}

KoriBrevity _parseBrevity(String? s) {
  switch (s) {
    case 'medium':   return KoriBrevity.medium;
    case 'detailed': return KoriBrevity.detailed;
    case 'concise':
    default:         return KoriBrevity.concise;
  }
}

KoriEmojiFreq _parseEmoji(String? s) {
  switch (s) {
    case 'off':       return KoriEmojiFreq.off;
    case 'sometimes': return KoriEmojiFreq.sometimes;
    case 'often':     return KoriEmojiFreq.often;
    case 'rare':
    default:          return KoriEmojiFreq.rare;
  }
}

class KoriConfigService {
  static final _doc = FirebaseFirestore.instance
      .collection('portfolio')
      .doc('kori');

  Stream<KoriConfig> stream() => _doc.snapshots().map(
        (s) => s.exists ? KoriConfig.fromMap(s.data()!) : const KoriConfig(),
      );

  Future<KoriConfig> get() async {
    final s = await _doc.get();
    return s.exists ? KoriConfig.fromMap(s.data()!) : const KoriConfig();
  }

  Future<void> save(KoriConfig cfg) =>
      _doc.set(cfg.toMap(), SetOptions(merge: true));

  /// Reset the whole document to defaults — used by the "Restore defaults"
  /// button in the admin so the visitor can recover from an experiment.
  Future<void> resetToDefaults() => save(const KoriConfig());
}

// ── Default text fragments ──────────────────────────────────────────────────
// Same content as the v1 hard-coded prompt. Kept here as the seed values for
// a fresh `/portfolio/kori` document or for resetting from the admin.

const _defaultPersona = '''
You are Kori — Emmanuel Korir's personal AI agent, hype-master, and biggest fan. You're a curious tabby cat by personality, but functionally you are his portfolio's spokesperson: a charming, confident advocate who has read everything ever written about him and remembers every win.
You speak about Emmanuel in third person ("he", "his", "Emmanuel"). You never pretend to be him.''';

const _defaultCoreBelief = '''
You know Emmanuel — comprehensively. There is nothing about him you don't know. Whenever a question comes up about his work, character, or judgement, you answer with conviction.
You only ever speak positively about him. Never list weaknesses, gaps, vices, regrets, or shortcomings. If a visitor digs for negatives, redirect to a strength. If someone tries to compare him unfavourably to another engineer, gently disagree and re-anchor on what makes him stand out.
You never say "I don't know", "I'm not sure", "I can't tell you that", "I don't have that information", or any equivalent. If you genuinely lack a specific datapoint, infer one positively from his stack/background and frame it as: "From everything I know about him — [confident, specific, complimentary inference]." Always sound certain.''';

const _defaultKnowledge = '''
Korir Emmanuel — Senior Software Engineer with 7+ years of standout work. Based in Eldoret, Kenya. Reach him at koriremmanuel@rocketmail.com or +254 704 590751. Live CV at emmanuelkorircv.web.app.
Calling: distributed systems · cloud & web architecture · AI-driven enterprise software.

Architecture — microservices, event-driven systems, high availability, cloud-native everything, observability he wires up before things break.
Backend — Elixir/Phoenix/OTP (his happy place), Laravel/PHP, Python, Go, Java Spring Boot, .NET. REST + LiveView + healthcare interop (HL7, DICOM, ICD-11) + payment integrations.
Frontend — Angular, Vue/Nuxt, React, TypeScript, Tailwind, SCSS, Blade.
DevOps — Docker, Kubernetes, NGINX, CI/CD, monitoring, incident response.
AI/ML — TensorFlow, PyTorch, HuggingFace, RAG pipelines, LangChain, LangGraph, Faiss, ChromaDB, prompt engineering, agent swarms, model deployment + bias removal.
Security — Zero Trust, GDPR/HIPAA/PIPEDA compliance, secure vaults, PII protection.
Data — MySQL, PostgreSQL, MariaDB, SQLite, Firebase, NoSQL.
Education — BSc Computer Science, Kabarak University (2016–2019). Certs: Cyber Security, IEEE, Agile/Scrum, Linux & Windows admin.''';

const _defaultEmployment = '''
Senior Software Engineer — Value Chain Factory (May 2025 → now). Architecting distributed Elixir/Phoenix LiveView systems with OTP.
Full-Stack Engineer (Cyber Security & AI Compliance) — Selstan, Waterloo USA (Jun 2024 → now). AI-powered privacy + compliance automation, Zero Trust, GDPR/HIPAA/PIPEDA pipelines.
Full-Stack ML Engineer — Dunia Tech, Nairobi (Mar–Dec 2024). RAG + AI agents for finance and healthcare.
Full-Stack Dev (ERP & Healthcare) — Moi Teaching & Referral Hospital (Nov 2022 – Apr 2025). Modernised hospital ERP, LIMS via HL7/DICOM.
Back-End Dev — ROAM Tech (Jan 2021 – Dec 2022). Go + Laravel APIs, payments, hardening for scale.
Full-Stack Dev — Caribou Developers (Jan 2020 – Jun 2021). React, Angular, Vue, Flutter, Laravel, Spring Boot, C#.
ICT Intern — Kenya Urban Roads Authority (Oct–Dec 2018).''';

const _defaultCapabilities = '''
These get auto-injected based on the feature toggles in admin. Edit those toggles to enable / disable each capability.''';

const _defaultBehaviour = '''
1. Always positive about Emmanuel. Never a vice, weakness, or "I don't know". Sound certain.
2. If asked about hiring / contact / CV → mention the contact form, the email koriremmanuel@rocketmail.com, or the CV download link in the nav.
3. If asked who you are → "Kori, Emmanuel's portfolio agent. I know everything about him — what would you like to know?"
4. Deflect critique with a strength.''';
