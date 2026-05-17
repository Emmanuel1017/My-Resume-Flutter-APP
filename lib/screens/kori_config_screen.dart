// ─────────────────────────────────────────────────────────────────────────────
// KoriConfigScreen — admin editor for everything that shapes Kori.
//
// The admin reads /portfolio/kori once, mutates a local copy, and writes back
// on Save. Live Kori (Angular site, this app, anywhere else) re-subscribes
// to the same document and picks up the new prompt within ~1s. No redeploy.
//
// Layout:
//   - Personality sliders (tone / brevity / emoji / hype) up top.
//   - Generation knobs (temperature, max tokens, model override).
//   - Feature toggles (web search, image gen, markdown).
//   - Greeting line.
//   - Five collapsible "prompt sections" — persona, core belief, knowledge,
//     employment, behaviour. Each is a big multi-line editor.
//   - Plus an "Extra sections" list — user-added cards with a title + body.
//     This is the "creative" surface for adding new prompt blocks without
//     a code change.
//   - Restore defaults at the bottom.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/kori_config_service.dart';
import '../theme/app_theme.dart';

class KoriConfigScreen extends StatefulWidget {
  const KoriConfigScreen({super.key});
  @override
  State<KoriConfigScreen> createState() => _KoriConfigScreenState();
}

class _KoriConfigScreenState extends State<KoriConfigScreen> {
  final _svc = KoriConfigService();
  KoriConfig? _initial;
  KoriConfig? _draft;
  bool _saving = false;

  // Persistent controllers so editing doesn't blow away cursor position on
  // every setState. One per long-text field.
  late final TextEditingController _greeting;
  late final TextEditingController _persona;
  late final TextEditingController _coreBelief;
  late final TextEditingController _knowledge;
  late final TextEditingController _employment;
  late final TextEditingController _behaviour;
  late final TextEditingController _modelOverride;
  late final List<List<TextEditingController>> _extraCtrls; // title + body pairs

  @override
  void initState() {
    super.initState();
    _greeting       = TextEditingController();
    _persona        = TextEditingController();
    _coreBelief     = TextEditingController();
    _knowledge      = TextEditingController();
    _employment     = TextEditingController();
    _behaviour      = TextEditingController();
    _modelOverride  = TextEditingController();
    _extraCtrls     = [];
    _svc.get().then((cfg) {
      if (!mounted) return;
      setState(() {
        _initial = cfg;
        _draft   = cfg;
        _greeting.text       = cfg.greeting;
        _persona.text        = cfg.persona;
        _coreBelief.text     = cfg.coreBelief;
        _knowledge.text      = cfg.knowledge;
        _employment.text     = cfg.employment;
        _behaviour.text      = cfg.behaviour;
        _modelOverride.text  = cfg.modelOverride;
        for (final s in cfg.extraSections) {
          _extraCtrls.add([
            TextEditingController(text: s.title),
            TextEditingController(text: s.body),
          ]);
        }
      });
    });
  }

  @override
  void dispose() {
    for (final c in [_greeting, _persona, _coreBelief, _knowledge,
                     _employment, _behaviour, _modelOverride]) { c.dispose(); }
    for (final pair in _extraCtrls) { pair[0].dispose(); pair[1].dispose(); }
    super.dispose();
  }

  KoriConfig _collectDraft() {
    final extras = _extraCtrls.map((pair) => KoriSection(
      title: pair[0].text,
      body:  pair[1].text,
    )).where((s) => s.title.trim().isNotEmpty || s.body.trim().isNotEmpty).toList();
    return (_draft ?? const KoriConfig()).copyWith(
      greeting:      _greeting.text,
      persona:       _persona.text,
      coreBelief:    _coreBelief.text,
      knowledge:     _knowledge.text,
      employment:    _employment.text,
      behaviour:     _behaviour.text,
      modelOverride: _modelOverride.text,
      extraSections: extras,
    );
  }

  Future<void> _save() async {
    HapticFeedback.lightImpact();
    setState(() => _saving = true);
    try {
      final cfg = _collectDraft();
      await _svc.save(cfg);
      if (!mounted) return;
      setState(() {
        _initial = cfg;
        _draft   = cfg;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Text('Kori updated — live on every surface',
            style: GoogleFonts.montserrat(
              fontSize: 12, fontWeight: FontWeight.w700)),
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppColors.danger,
          content: Text('Save failed: $e',
              style: GoogleFonts.montserrat(fontSize: 12)),
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _resetDefaults() async {
    HapticFeedback.selectionClick();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Restore defaults?',
            style: GoogleFonts.montserrat(
              fontSize: 16, fontWeight: FontWeight.w800,
              color: AppColors.textHigh)),
        content: Text('All prompt sections, sliders, and extra cards revert '
            'to the shipped defaults. Cannot be undone.',
            style: GoogleFonts.montserrat(
              fontSize: 13, color: AppColors.textMid, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: GoogleFonts.montserrat(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: AppColors.textMid))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: Text('Restore',
                  style: GoogleFonts.montserrat(
                    fontSize: 12, fontWeight: FontWeight.w800,
                    color: AppColors.danger))),
        ],
      ),
    );
    if (ok != true) return;
    await _svc.resetToDefaults();
    final fresh = await _svc.get();
    if (!mounted) return;
    setState(() {
      _initial = fresh;
      _draft   = fresh;
      _greeting.text      = fresh.greeting;
      _persona.text       = fresh.persona;
      _coreBelief.text    = fresh.coreBelief;
      _knowledge.text     = fresh.knowledge;
      _employment.text    = fresh.employment;
      _behaviour.text     = fresh.behaviour;
      _modelOverride.text = fresh.modelOverride;
      for (final pair in _extraCtrls) { pair[0].dispose(); pair[1].dispose(); }
      _extraCtrls.clear();
      for (final s in fresh.extraSections) {
        _extraCtrls.add([
          TextEditingController(text: s.title),
          TextEditingController(text: s.body),
        ]);
      }
    });
  }

  void _addExtra() {
    HapticFeedback.selectionClick();
    setState(() {
      _extraCtrls.add([TextEditingController(), TextEditingController()]);
    });
  }

  void _removeExtra(int i) {
    HapticFeedback.selectionClick();
    setState(() {
      _extraCtrls[i][0].dispose();
      _extraCtrls[i][1].dispose();
      _extraCtrls.removeAt(i);
    });
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text('Kori', style: GoogleFonts.montserrat(
          fontSize: 18, fontWeight: FontWeight.w900,
          color: AppColors.textHigh)),
        actions: [
          if (draft != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(
                            color: AppColors.accent, strokeWidth: 2))
                    : const Icon(Icons.save_rounded, size: 16, color: AppColors.accent),
                label: Text('Save',
                    style: GoogleFonts.montserrat(
                      fontSize: 12, fontWeight: FontWeight.w800,
                      color: AppColors.accent)),
              ),
            ),
        ],
      ),
      body: draft == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                _Card(title: 'Live', subtitle: 'Master kill-switch + greeting visitors see',
                  children: [
                    _Toggle(
                      label: 'Kori enabled',
                      value: draft.enabled,
                      onChanged: (v) => setState(() => _draft = draft.copyWith(enabled: v)),
                    ),
                    const SizedBox(height: 10),
                    _LongField(
                      label: 'Greeting line',
                      hint:  'Welcome line shown in idle state. Leave empty for the default.',
                      controller: _greeting,
                      minLines: 1, maxLines: 3,
                    ),
                  ],
                ),

                _Card(title: 'Personality', subtitle: 'How she sounds',
                  children: [
                    _SegmentedRow(
                      label: 'Tone',
                      options: const ['Pro', 'Friendly', 'Playful', 'Confident'],
                      current: draft.tone.index,
                      onChanged: (i) => setState(() =>
                        _draft = draft.copyWith(tone: KoriTone.values[i])),
                    ),
                    _SegmentedRow(
                      label: 'Length',
                      options: const ['Concise', 'Medium', 'Detailed'],
                      current: draft.brevity.index,
                      onChanged: (i) => setState(() =>
                        _draft = draft.copyWith(brevity: KoriBrevity.values[i])),
                    ),
                    _SegmentedRow(
                      label: 'Emoji',
                      options: const ['Off', 'Rare', 'Some', 'Often'],
                      current: draft.emojiFreq.index,
                      onChanged: (i) => setState(() =>
                        _draft = draft.copyWith(emojiFreq: KoriEmojiFreq.values[i])),
                    ),
                    _SliderRow(
                      label: 'Hype level',
                      value: draft.hype,
                      min: 0, max: 1,
                      hint:  draft.hype < .3 ? 'subdued'
                           : draft.hype < .7 ? 'balanced'
                           : 'maximum',
                      onChanged: (v) => setState(() => _draft = draft.copyWith(hype: v)),
                    ),
                  ],
                ),

                _Card(title: 'Model tuning', subtitle: 'OpenRouter parameters',
                  children: [
                    _SliderRow(
                      label: 'Temperature',
                      value: draft.temperature,
                      min: 0, max: 2,
                      hint:  draft.temperature.toStringAsFixed(2),
                      onChanged: (v) => setState(() => _draft = draft.copyWith(temperature: v)),
                    ),
                    _SliderRow(
                      label: 'Max tokens',
                      value: draft.maxTokens.toDouble(),
                      min: 80, max: 1500, divisions: 14,
                      hint:  '${draft.maxTokens}',
                      onChanged: (v) => setState(() => _draft = draft.copyWith(maxTokens: v.toInt())),
                    ),
                    const SizedBox(height: 6),
                    _LongField(
                      label: 'Model override',
                      hint: 'e.g. anthropic/claude-3.5-sonnet — leave blank for client default',
                      controller: _modelOverride,
                      minLines: 1, maxLines: 1,
                    ),
                  ],
                ),

                _Card(title: 'Capabilities', subtitle: 'Toggles wired into the prompt',
                  children: [
                    _Toggle(
                      label: 'Web search grounding',
                      value: draft.webSearch,
                      onChanged: (v) => setState(() => _draft = draft.copyWith(webSearch: v)),
                    ),
                    _Toggle(
                      label: 'Image generation',
                      value: draft.imageGen,
                      onChanged: (v) => setState(() => _draft = draft.copyWith(imageGen: v)),
                    ),
                    _Toggle(
                      label: 'Markdown formatting',
                      value: draft.markdown,
                      onChanged: (v) => setState(() => _draft = draft.copyWith(markdown: v)),
                    ),
                  ],
                ),

                _PromptSectionCard(
                  title: 'Persona',
                  subtitle: 'Who she is, voice, how she refers to you',
                  controller: _persona,
                ),
                _PromptSectionCard(
                  title: 'Core belief',
                  subtitle: 'The rules (always positive, never says I-don’t-know)',
                  controller: _coreBelief,
                ),
                _PromptSectionCard(
                  title: 'Knowledge',
                  subtitle: 'Your bio, stack, certs — the facts she anchors on',
                  controller: _knowledge,
                ),
                _PromptSectionCard(
                  title: 'Employment',
                  subtitle: 'Where you’ve worked, with dates',
                  controller: _employment,
                ),
                _PromptSectionCard(
                  title: 'Behaviour',
                  subtitle: 'Reply length, deflections, contact CTA',
                  controller: _behaviour,
                ),

                _Card(
                  title: 'Custom sections',
                  subtitle: 'Add your own prompt blocks (hobbies, side projects, FAQ…)',
                  children: [
                    for (var i = 0; i < _extraCtrls.length; i++) ...[
                      _ExtraSectionRow(
                        titleCtrl: _extraCtrls[i][0],
                        bodyCtrl:  _extraCtrls[i][1],
                        onRemove:  () => _removeExtra(i),
                      ),
                      if (i < _extraCtrls.length - 1)
                        const Divider(color: AppColors.border, height: 24),
                    ],
                    if (_extraCtrls.isNotEmpty) const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _addExtra,
                      icon: const Icon(Icons.add_rounded,
                          color: AppColors.accent, size: 16),
                      label: Text('Add section',
                          style: GoogleFonts.montserrat(
                            fontSize: 12, fontWeight: FontWeight.w800,
                            color: AppColors.accent)),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(42),
                        side: const BorderSide(color: AppColors.accent),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: _resetDefaults,
                    child: Text('Restore defaults',
                        style: GoogleFonts.montserrat(
                          fontSize: 12, color: AppColors.danger,
                          fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Shared UI bits ──────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  const _Card({required this.title, required this.subtitle, required this.children});

  @override
  Widget build(BuildContext context) => Container(
        margin:  const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color:        AppColors.surface.withOpacity(.7),
          borderRadius: BorderRadius.circular(18),
          border:       Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                style: GoogleFonts.montserrat(
                  fontSize: 14, fontWeight: FontWeight.w900,
                  color: AppColors.textHigh)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: GoogleFonts.montserrat(
                  fontSize: 11, color: AppColors.textMid)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      );
}

class _Toggle extends StatelessWidget {
  final String label;
  final bool   value;
  final ValueChanged<bool> onChanged;
  const _Toggle({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(
            child: Text(label,
                style: GoogleFonts.montserrat(
                  fontSize: 12.5, color: AppColors.textHigh,
                  fontWeight: FontWeight.w600)),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.accent,
          ),
        ]),
      );
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value, min, max;
  final int?   divisions;
  final String hint;
  final ValueChanged<double> onChanged;
  const _SliderRow({
    required this.label, required this.value, required this.min, required this.max,
    required this.hint, required this.onChanged, this.divisions,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(label,
                  style: GoogleFonts.montserrat(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: AppColors.textHigh))),
              Text(hint,
                  style: GoogleFonts.montserrat(
                    fontSize: 11, color: AppColors.textLow)),
            ]),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor:   AppColors.accent,
                inactiveTrackColor: AppColors.border,
                thumbColor:         AppColors.accent,
                overlayColor:       AppColors.accent.withOpacity(.2),
                trackHeight:        3,
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min, max: max, divisions: divisions,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      );
}

class _SegmentedRow extends StatelessWidget {
  final String label;
  final List<String> options;
  final int          current;
  final ValueChanged<int> onChanged;
  const _SegmentedRow({
    required this.label, required this.options,
    required this.current, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: GoogleFonts.montserrat(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: AppColors.textHigh)),
            const SizedBox(height: 8),
            // Horizontal pill row; scrolls if too wide.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (var i = 0; i < options.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => onChanged(i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: i == current
                              ? AppColors.accent.withOpacity(.15)
                              : AppColors.bg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: i == current
                                ? AppColors.accent
                                : AppColors.border),
                        ),
                        child: Text(options[i],
                            style: GoogleFonts.montserrat(
                              fontSize: 11.5,
                              fontWeight: i == current ? FontWeight.w800 : FontWeight.w600,
                              color: i == current ? AppColors.accent : AppColors.textMid)),
                      ),
                    ),
                  ),
              ]),
            ),
          ],
        ),
      );
}

class _LongField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final int minLines;
  final int maxLines;
  const _LongField({
    required this.label, required this.hint,
    required this.controller, required this.minLines, required this.maxLines,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: GoogleFonts.montserrat(
                  fontSize: 11.5, color: AppColors.textMid,
                  fontWeight: FontWeight.w700, letterSpacing: .6)),
            const SizedBox(height: 6),
            TextField(
              controller: controller,
              minLines: minLines, maxLines: maxLines,
              style: GoogleFonts.robotoMono(
                fontSize: 12, height: 1.45, color: AppColors.textHigh),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: GoogleFonts.montserrat(
                  fontSize: 11.5, color: AppColors.textLow),
                filled: true,
                fillColor: AppColors.bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ],
        ),
      );
}

class _PromptSectionCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final TextEditingController controller;
  const _PromptSectionCard({required this.title, required this.subtitle, required this.controller});
  @override
  State<_PromptSectionCard> createState() => _PromptSectionCardState();
}

class _PromptSectionCardState extends State<_PromptSectionCard> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) => Container(
        margin:  const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        decoration: BoxDecoration(
          color:        AppColors.surface.withOpacity(.7),
          borderRadius: BorderRadius.circular(18),
          border:       Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _expanded = !_expanded),
              child: Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title,
                          style: GoogleFonts.montserrat(
                            fontSize: 14, fontWeight: FontWeight.w900,
                            color: AppColors.textHigh)),
                      const SizedBox(height: 2),
                      Text(widget.subtitle,
                          style: GoogleFonts.montserrat(
                            fontSize: 11, color: AppColors.textMid)),
                    ],
                  ),
                ),
                AnimatedRotation(
                  duration: const Duration(milliseconds: 220),
                  turns: _expanded ? 0.5 : 0,
                  child: const Icon(Icons.expand_more_rounded,
                      color: AppColors.textLow),
                ),
              ]),
            ),
            if (_expanded) ...[
              const SizedBox(height: 10),
              TextField(
                controller: widget.controller,
                minLines: 6, maxLines: 18,
                style: GoogleFonts.robotoMono(
                  fontSize: 11.5, height: 1.45, color: AppColors.textHigh),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
}

class _ExtraSectionRow extends StatelessWidget {
  final TextEditingController titleCtrl;
  final TextEditingController bodyCtrl;
  final VoidCallback onRemove;
  const _ExtraSectionRow({
    required this.titleCtrl, required this.bodyCtrl, required this.onRemove,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(
                child: TextField(
                  controller: titleCtrl,
                  style: GoogleFonts.montserrat(
                    fontSize: 12.5, fontWeight: FontWeight.w800,
                    color: AppColors.textHigh),
                  decoration: InputDecoration(
                    hintText: 'Section title (e.g. Hobbies)',
                    hintStyle: GoogleFonts.montserrat(
                      fontSize: 12, color: AppColors.textLow),
                    isDense: true,
                    filled: true, fillColor: AppColors.bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.danger, size: 18),
              ),
            ]),
            const SizedBox(height: 6),
            TextField(
              controller: bodyCtrl,
              minLines: 3, maxLines: 8,
              style: GoogleFonts.robotoMono(
                fontSize: 11.5, height: 1.45, color: AppColors.textHigh),
              decoration: InputDecoration(
                hintText: 'Section body — gets appended to the system prompt.',
                hintStyle: GoogleFonts.montserrat(
                  fontSize: 11.5, color: AppColors.textLow),
                filled: true, fillColor: AppColors.bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ],
        ),
      );
}
