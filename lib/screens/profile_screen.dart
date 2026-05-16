import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

// ─── CV data ─────────────────────────────────────────────────────────────────

const _photoUrl =
    'https://emmanuel1017.github.io/Angular-Resume/assets/template/me_code.png';

const _summary =
    '7+ years building scalable web platforms, distributed systems and '
    'AI-driven enterprise solutions. Based in Eldoret, Kenya — working globally '
    'across healthcare, fintech and cybersecurity. Architect of microservices, '
    'RAG pipelines and real-time systems trusted by hospitals, startups and enterprises.';

const _stats = [
  _Stat('7+',  'Years Building',  Icons.bolt_rounded),
  _Stat('6',   'Companies',       Icons.business_rounded),
  _Stat('15+', 'Technologies',    Icons.build_rounded),
  _Stat('3',   'Domains',         Icons.public_rounded),
];

const _skillGroups = [
  _SkillGroup('Backend',  AppColors.primary, ['Elixir', 'Phoenix', 'Laravel', 'Go', 'Python', 'Spring Boot', '.NET']),
  _SkillGroup('Frontend', Color(0xFF2d4070),  ['Angular', 'Vue', 'React', 'TypeScript', 'Nuxt', 'LiveView', 'Blade']),
  _SkillGroup('AI & ML',  Color(0xFFc05c1a),  ['TensorFlow', 'PyTorch', 'LangChain', 'RAG', 'HuggingFace', 'LangGraph']),
  _SkillGroup('DevOps',   Color(0xFF6b4fa0),  ['Docker', 'Kubernetes', 'NGINX', 'CI/CD', 'Observability', 'IaC']),
  _SkillGroup('Data',     Color(0xFF1a7a8c),  ['PostgreSQL', 'MySQL', 'Firebase', 'ChromaDB', 'FAISS', 'MariaDB']),
  _SkillGroup('Security', Color(0xFF8c1a3e),  ['Zero Trust', 'GDPR', 'HIPAA', 'PIPEDA', 'PII Protection', 'Vault']),
];

const _timeline = [
  _Job('2025 – now', 'Senior Software Engineer',         'Value Chain Factory',        true),
  _Job('2024 – now', 'Full-Stack · AI Compliance',       'Selstan, Waterloo USA',       true),
  _Job('2024',       'ML Engineer',                      'Dunia Tech, Nairobi',         false),
  _Job('2022 – 2025','Full-Stack Developer · Healthcare', 'MTRH',                       false),
  _Job('2021 – 2022','Back-End Developer',               'ROAM Tech',                   false),
  _Job('2020 – 2021','Full-Stack Developer',             'Caribou Developers',          false),
];

const _socials = [
  _Social('GitHub',    Icons.code_rounded,           'https://github.com/Emmanuel1017'),
  _Social('LinkedIn',  Icons.work_rounded,           'https://linkedin.com/in/korir-emmanuel'),
  _Social('Email',     Icons.mail_rounded,           'mailto:koriremmanuel@rocketmail.com'),
];

const _certs = ['🔐 Cyber Security', '📡 IEEE', '⚙️ Agile / Scrum', '🐧 Linux Admin'];

// ─── Screen ──────────────────────────────────────────────────────────────────

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  int     _activeGroup   = 0;
  int     _expandedJob   = -1;
  double  _mx = 0, _my = 0; // normalised mouse/pointer for name parallax

  late final AnimationController _cycleCtrl;

  @override
  void initState() {
    super.initState();
    // Auto-cycle skill tabs every 2.8 s
    _cycleCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 2800),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          setState(() => _activeGroup = (_activeGroup + 1) % _skillGroups.length);
          _cycleCtrl.forward(from: 0);
        }
      });
    _cycleCtrl.forward();
  }

  @override
  void dispose() {
    _cycleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Collapsing header ─────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 220,
            pinned:         true,
            backgroundColor: AppColors.bg,
            surfaceTintColor: Colors.transparent,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background:   _HeroHeader(
                paddingTop: top,
                mx:         _mx,
                my:         _my,
                onPointerMove: (mx, my) => setState(() { _mx = mx; _my = my; }),
              ),
              title: Text(
                'Korir Emmanuel',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w800,
                  fontSize:   15,
                  color:      AppColors.textHigh,
                ),
              ),
            ),
          ),

          // ── Body ──────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),

                  // Title chips
                  Wrap(
                    spacing: 6,
                    children: const [
                      _Chip('Senior Software Engineer', AppColors.primary),
                      _Chip('Distributed Systems',     AppColors.textLow),
                      _Chip('Cloud & AI',              AppColors.textLow),
                    ],
                  ).animate().fadeIn(delay: 100.ms),

                  const SizedBox(height: 18),

                  // Summary
                  _SectionLabel('About'),
                  const SizedBox(height: 8),
                  Text(
                    _summary,
                    style: GoogleFonts.montserrat(
                      fontSize:  13.5,
                      height:    1.65,
                      color:     AppColors.textMid,
                    ),
                  ).animate().fadeIn(delay: 150.ms),

                  const SizedBox(height: 24),

                  // Socials
                  Row(
                    children: _socials.map((s) => Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child:   _SocialBtn(social: s),
                    )).toList(),
                  ).animate().fadeIn(delay: 200.ms),

                  const SizedBox(height: 28),

                  // Stats row
                  _SectionLabel('By the Numbers'),
                  const SizedBox(height: 12),
                  Row(
                    children: _stats.asMap().entries.map((e) => Expanded(
                      child: _StatCard(stat: e.value)
                          .animate()
                          .fadeIn(delay: Duration(milliseconds: 260 + e.key * 80))
                          .slideY(begin: .12, end: 0),
                    )).toList(),
                  ),

                  const SizedBox(height: 28),

                  // Skills
                  _SectionLabel('Skills'),
                  const SizedBox(height: 12),
                  _SkillSection(
                    activeGroup:  _activeGroup,
                    onSelectGroup: (i) {
                      HapticFeedback.selectionClick();
                      _cycleCtrl.stop();
                      setState(() => _activeGroup = i);
                      Future.delayed(const Duration(seconds: 8), () {
                        if (mounted) _cycleCtrl.forward(from: 0);
                      });
                    },
                  ).animate().fadeIn(delay: 300.ms),

                  const SizedBox(height: 28),

                  // Experience timeline
                  _SectionLabel('Experience'),
                  const SizedBox(height: 12),
                  ..._timeline.asMap().entries.map((e) => _TimelineItem(
                    job:       e.value,
                    index:     e.key,
                    expanded:  _expandedJob == e.key,
                    onTap:     () => setState(() =>
                        _expandedJob = _expandedJob == e.key ? -1 : e.key),
                  )),

                  const SizedBox(height: 28),

                  // Education
                  _SectionLabel('Education'),
                  const SizedBox(height: 12),
                  Container(
                    padding:    const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color:        AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border:       Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Text('🎓', style: const TextStyle(fontSize: 28)),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('BSc Computer Science',
                              style: GoogleFonts.montserrat(
                                fontSize:   14,
                                fontWeight: FontWeight.w700,
                                color:      AppColors.textHigh,
                              )),
                            Text('Kabarak University · 2016 – 2019',
                              style: GoogleFonts.montserrat(
                                fontSize: 12, color: AppColors.textMid)),
                          ],
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 350.ms),

                  const SizedBox(height: 20),

                  // Certifications
                  _SectionLabel('Certifications'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _certs.map((c) => Container(
                      padding:    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color:        AppColors.card,
                        borderRadius: BorderRadius.circular(20),
                        border:       Border.all(color: AppColors.border),
                      ),
                      child: Text(c,
                        style: GoogleFonts.montserrat(
                          fontSize:   12.5,
                          color:      AppColors.textMid,
                          fontWeight: FontWeight.w600,
                        )),
                    )).toList(),
                  ).animate().fadeIn(delay: 380.ms),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Hero header with parallax 3-D name ──────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  final double paddingTop;
  final double mx, my;
  final void Function(double mx, double my) onPointerMove;

  const _HeroHeader({
    required this.paddingTop,
    required this.mx,
    required this.my,
    required this.onPointerMove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D1321), Color(0xFF0F1E17)],
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
        ),
      ),
      child: Listener(
        onPointerMove: (e) {
          final size = context.size ?? const Size(400, 220);
          onPointerMove(
            (e.localPosition.dx / size.width  - .5) * 2,
            (e.localPosition.dy / size.height - .5) * 2,
          );
        },
        child: Padding(
          padding: EdgeInsets.only(top: paddingTop + 12, left: 20, right: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Photo
              Container(
                width:  72,
                height: 72,
                decoration: BoxDecoration(
                  shape:  BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color:      AppColors.primary.withOpacity(.35),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.network(
                    _photoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.card,
                      child: const Icon(Icons.person, color: AppColors.textMid),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 18),

              // 3-D parallax name
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ParallaxName(name: 'KORIR',    mx: mx, my: my),
                    const SizedBox(height: 2),
                    _ParallaxName(name: 'EMMANUEL', mx: mx, my: my),
                    const SizedBox(height: 6),
                    Text(
                      'Eldoret, Kenya · Working globally',
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        color:    AppColors.textMid,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParallaxName extends StatelessWidget {
  final String name;
  final double mx, my;
  const _ParallaxName({required this.name, required this.mx, required this.my});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: name.split('').asMap().entries.map((e) {
        final i     = e.key;
        final total = name.length;
        final pos   = total > 1 ? (i / (total - 1) - .5) * 2 : 0.0;
        final rx    = my * -8;
        final ry    = (mx + pos * .25) * 12;
        final tz    = (mx * pos).abs() * 14;

        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateX(rx * pi / 180)
            ..rotateY(ry * pi / 180)
            ..translate(0.0, 0.0, tz),
          alignment: FractionalOffset.center,
          child: Text(
            e.value,
            style: GoogleFonts.montserrat(
              fontSize:   22,
              fontWeight: FontWeight.w900,
              color:      AppColors.textHigh,
              shadows: [
                Shadow(color: AppColors.primary.withOpacity(.8), blurRadius: 2,
                    offset: const Offset(1, 1)),
                Shadow(color: AppColors.primary.withOpacity(.5), blurRadius: 4,
                    offset: const Offset(2, 2)),
                Shadow(color: AppColors.primary.withOpacity(.25), blurRadius: 8,
                    offset: const Offset(3, 3)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Skill section ────────────────────────────────────────────────────────────

class _SkillSection extends StatelessWidget {
  final int    activeGroup;
  final ValueChanged<int> onSelectGroup;
  const _SkillSection({required this.activeGroup, required this.onSelectGroup});

  @override
  Widget build(BuildContext context) {
    final group = _skillGroups[activeGroup];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tab row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _skillGroups.asMap().entries.map((e) {
              final active = e.key == activeGroup;
              final color  = e.value.color;
              return GestureDetector(
                onTap: () => onSelectGroup(e.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin:  const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color:        active
                        ? color.withOpacity(.22)
                        : AppColors.card,
                    borderRadius: BorderRadius.circular(20),
                    border:       Border.all(
                      color: active ? color.withOpacity(.6) : AppColors.border,
                    ),
                  ),
                  child: Text(
                    e.value.name,
                    style: GoogleFonts.montserrat(
                      fontSize:   12,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color:      active ? color : AppColors.textMid,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 12),

        // Pill area — fixed height so nothing below jumps
        SizedBox(
          height: 88,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: group.skills.asMap().entries.map((e) =>
              Text(
                e.value,
                style: GoogleFonts.montserrat(
                  fontSize:   12,
                  fontWeight: FontWeight.w600,
                  color:      group.color,
                ),
              ).animate(key: ValueKey('${activeGroup}-${e.key}'))
               .fadeIn(delay: Duration(milliseconds: e.key * 50), duration: 300.ms)
               .then()
               .custom(
                builder: (_, __, child) => Container(
                  padding:    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color:        group.color.withOpacity(.1),
                    borderRadius: BorderRadius.circular(14),
                    border:       Border.all(color: group.color.withOpacity(.35)),
                  ),
                  child: child,
                ),
              ),
            ).toList(),
          ),
        ),
      ],
    );
  }
}

// ─── Timeline item ────────────────────────────────────────────────────────────

class _TimelineItem extends StatelessWidget {
  final _Job     job;
  final int      index;
  final bool     expanded;
  final VoidCallback onTap;
  const _TimelineItem({
    required this.job,
    required this.index,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCurrent = job.current;
    return GestureDetector(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dot + line
          Column(
            children: [
              Container(
                width:  14,
                height: 14,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCurrent ? AppColors.accent : AppColors.border,
                  boxShadow: isCurrent ? [
                    BoxShadow(
                      color:      AppColors.accent.withOpacity(.4),
                      blurRadius: 8,
                    ),
                  ] : [],
                ),
              ),
              Container(
                width:  1.5,
                height: expanded ? 64 : 40,
                color:  AppColors.border.withOpacity(.4),
              ),
            ],
          ),

          const SizedBox(width: 14),

          // Content
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin:   const EdgeInsets.only(bottom: 4),
              padding:  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color:        expanded
                    ? AppColors.card.withOpacity(.8)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                border:       expanded
                    ? Border.all(color: AppColors.border)
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job.year,
                    style: GoogleFonts.montserrat(
                      fontSize:   10.5,
                      color:      isCurrent ? AppColors.accent : AppColors.textLow,
                      fontWeight: FontWeight.w600,
                      letterSpacing: .5,
                    ),
                  ),
                  Text(
                    job.role,
                    style: GoogleFonts.montserrat(
                      fontSize:   13.5,
                      fontWeight: FontWeight.w700,
                      color:      AppColors.textHigh,
                    ),
                  ),
                  if (expanded)
                    Text(
                      job.company,
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        color:    AppColors.textMid,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate()
     .fadeIn(delay: Duration(milliseconds: 200 + index * 60), duration: 400.ms)
     .slideX(begin: -.05, end: 0);
  }
}

// ─── Small reusable widgets ───────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final _Stat stat;
  const _StatCard({required this.stat});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:  const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color:        AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(stat.icon, color: AppColors.accent, size: 18),
          const SizedBox(height: 4),
          Text(
            stat.value,
            style: GoogleFonts.montserrat(
              fontSize:   18,
              fontWeight: FontWeight.w900,
              color:      AppColors.textHigh,
            ),
          ),
          Text(
            stat.label,
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              fontSize: 9,
              color:    AppColors.textMid,
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final Color  color;
  const _Chip(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding:    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color:        color.withOpacity(.15),
      borderRadius: BorderRadius.circular(12),
      border:       Border.all(color: color.withOpacity(.35)),
    ),
    child: Text(
      text,
      style: GoogleFonts.montserrat(
        fontSize:   11,
        color:      color == AppColors.textLow ? AppColors.textMid : color,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _SocialBtn extends StatelessWidget {
  final _Social social;
  const _SocialBtn({required this.social});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => launchUrl(Uri.parse(social.url),
          mode: LaunchMode.externalApplication),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color:        AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border:       Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(social.icon, color: AppColors.accent, size: 14),
            const SizedBox(width: 6),
            Text(
              social.label,
              style: GoogleFonts.montserrat(
                fontSize:   11.5,
                fontWeight: FontWeight.w600,
                color:      AppColors.textMid,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: GoogleFonts.montserrat(
      fontSize:      10.5,
      fontWeight:    FontWeight.w700,
      color:         AppColors.textLow,
      letterSpacing: 2.2,
    ),
  );
}

// ─── Data classes ─────────────────────────────────────────────────────────────

class _Stat {
  final String   value, label;
  final IconData icon;
  const _Stat(this.value, this.label, this.icon);
}

class _SkillGroup {
  final String      name;
  final Color       color;
  final List<String> skills;
  const _SkillGroup(this.name, this.color, this.skills);
}

class _Job {
  final String year, role, company;
  final bool   current;
  const _Job(this.year, this.role, this.company, this.current);
}

class _Social {
  final String   label;
  final IconData icon;
  final String   url;
  const _Social(this.label, this.icon, this.url);
}
