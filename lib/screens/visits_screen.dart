// ─────────────────────────────────────────────────────────────────────────────
// VisitsScreen — opens from the Admin Console as a pushed full-screen route.
// Lists every entry in /visits sorted by most recent, with a summary header
// (today / 7d / 30d / total + unique IPs + top country) and an expandable
// detail panel per visit showing the full device/geo signal.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../widgets/visits_charts.dart';

class VisitsScreen extends StatefulWidget {
  const VisitsScreen({super.key});

  @override
  State<VisitsScreen> createState() => _VisitsScreenState();
}

class _VisitsScreenState extends State<VisitsScreen> {
  final _visitsQuery = FirebaseFirestore.instance
      .collection('visits')
      .orderBy('timestamp', descending: true)
      .limit(500);

  final ValueNotifier<String?> _expandedId = ValueNotifier<String?>(null);

  @override
  void dispose() {
    _expandedId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: StreamBuilder<QuerySnapshot>(
        stream: _visitsQuery.snapshots(),
        builder: (context, snap) {
          final loading = snap.connectionState == ConnectionState.waiting && !snap.hasData;
          final docs    = snap.data?.docs ?? const <QueryDocumentSnapshot>[];
          final summary = _summarize(docs);

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            cacheExtent: 800,
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: AppColors.bg.withOpacity(.96),
                surfaceTintColor: Colors.transparent,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: AppColors.textHigh, size: 18),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                title: Text('Visits',
                    style: GoogleFonts.montserrat(
                      fontSize: 20, fontWeight: FontWeight.w900,
                      color: AppColors.textHigh)),
              ),

              if (loading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.accent, strokeWidth: 2)),
                )
              else ...[
                SliverToBoxAdapter(child: _SummaryHeader(summary: summary)),
                if (docs.isNotEmpty)
                  SliverToBoxAdapter(child: VisitsCharts(docs: docs)),
                if (docs.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: _EmptyState(),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) {
                          final doc = docs[i];
                          return RepaintBoundary(
                            child: ValueListenableBuilder<String?>(
                              valueListenable: _expandedId,
                              builder: (_, id, __) => _VisitCard(
                                key:      ValueKey(doc.id),
                                doc:      doc,
                                expanded: id == doc.id,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  _expandedId.value =
                                      id == doc.id ? null : doc.id;
                                },
                              ),
                            ),
                          );
                        },
                        childCount: docs.length,
                        addAutomaticKeepAlives: false,
                        addRepaintBoundaries:   false,
                      ),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  _VisitSummary _summarize(List<QueryDocumentSnapshot> docs) {
    final now = DateTime.now();
    final today  = DateTime(now.year, now.month, now.day);
    final week   = now.subtract(const Duration(days: 7));
    final month  = now.subtract(const Duration(days: 30));

    var todayN = 0, weekN = 0, monthN = 0;
    final ips = <String>{};
    final countries = <String, int>{};
    final sources = <String, int>{};
    final cities = <String, int>{};
    final platforms = <String, int>{};

    for (final d in docs) {
      final data = d.data() as Map<String, dynamic>;
      final ts = data['timestamp'] as Timestamp?;
      if (ts != null) {
        final dt = ts.toDate();
        if (dt.isAfter(today)) todayN++;
        if (dt.isAfter(week))  weekN++;
        if (dt.isAfter(month)) monthN++;
      }
      final ip = data['ip']      as String?;
      final co = data['country'] as String?;
      final ci = data['city']    as String?;
      final so = (data['source'] as String?) ?? 'web';
      final pl = (data['platform'] as String?) ?? 'unknown';
      if (ip != null) ips.add(ip);
      if (co != null) countries[co] = (countries[co] ?? 0) + 1;
      if (ci != null) cities[ci]    = (cities[ci]    ?? 0) + 1;
      sources[so]   = (sources[so]   ?? 0) + 1;
      platforms[pl] = (platforms[pl] ?? 0) + 1;
    }

    final topCountry = _topKey(countries);
    final topCity    = _topKey(cities);
    return _VisitSummary(
      total:      docs.length,
      today:      todayN,
      week:       weekN,
      month:      monthN,
      uniqueIps:  ips.length,
      topCountry: topCountry,
      topCity:    topCity,
      sources:    sources,
      platforms:  platforms,
    );
  }

  String? _topKey(Map<String, int> m) {
    if (m.isEmpty) return null;
    final entries = m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return '${entries.first.key} · ${entries.first.value}';
  }
}

class _VisitSummary {
  final int total, today, week, month, uniqueIps;
  final String? topCountry;
  final String? topCity;
  final Map<String, int> sources;
  final Map<String, int> platforms;
  const _VisitSummary({
    required this.total,
    required this.today,
    required this.week,
    required this.month,
    required this.uniqueIps,
    required this.topCountry,
    required this.topCity,
    required this.sources,
    required this.platforms,
  });
}

// ─── Summary header ──────────────────────────────────────────────────────────
class _SummaryHeader extends StatelessWidget {
  final _VisitSummary summary;
  const _SummaryHeader({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: _MetricTile(label: 'Today', value: '${summary.today}',  accent: AppColors.accent)),
            const SizedBox(width: 10),
            Expanded(child: _MetricTile(label: '7 days', value: '${summary.week}',  accent: AppColors.primary)),
            const SizedBox(width: 10),
            Expanded(child: _MetricTile(label: '30 days', value: '${summary.month}', accent: AppColors.warning)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _MetricTile(label: 'All time', value: '${summary.total}',     accent: AppColors.textHigh)),
            const SizedBox(width: 10),
            Expanded(child: _MetricTile(label: 'Unique IPs', value: '${summary.uniqueIps}', accent: AppColors.accent)),
          ]),
          if (summary.topCountry != null || summary.topCity != null) ...[
            const SizedBox(height: 14),
            _ChipRow(items: [
              if (summary.topCountry != null) 'Top country  ${summary.topCountry}',
              if (summary.topCity != null)    'Top city  ${summary.topCity}',
              ...summary.sources.entries.map((e) => '${e.key}  ${e.value}'),
            ]),
          ],
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label, value;
  final Color accent;
  const _MetricTile({required this.label, required this.value, required this.accent});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color:        AppColors.surface.withOpacity(.7),
          borderRadius: BorderRadius.circular(16),
          border:       Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: GoogleFonts.montserrat(
                  fontSize: 10, color: AppColors.textMid,
                  fontWeight: FontWeight.w700, letterSpacing: .8)),
            const SizedBox(height: 4),
            Text(value,
                style: GoogleFonts.montserrat(
                  fontSize: 22, fontWeight: FontWeight.w900,
                  color: accent)),
          ],
        ),
      );
}

class _ChipRow extends StatelessWidget {
  final List<String> items;
  const _ChipRow({required this.items});

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items.map((s) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color:        AppColors.primary.withOpacity(.12),
            borderRadius: BorderRadius.circular(20),
            border:       Border.all(color: AppColors.primary.withOpacity(.3)),
          ),
          child: Text(s,
              style: GoogleFonts.montserrat(
                fontSize: 11, color: AppColors.textHigh,
                fontWeight: FontWeight.w600)),
        )).toList(),
      );
}

// ─── Visit card ──────────────────────────────────────────────────────────────
class _VisitCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final bool expanded;
  final VoidCallback onTap;

  const _VisitCard({
    super.key,
    required this.doc,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final d = doc.data() as Map<String, dynamic>;
    final ts        = d['timestamp'] as Timestamp?;
    final country   = d['country']   as String?;
    final city      = d['city']      as String?;
    final ip        = d['ip']        as String?;
    final isp       = d['isp']       as String?;
    final source    = (d['source']   as String?) ?? 'web';
    final platform  = d['platform']  as String?;
    final flag      = _countryEmoji(d['countryCode'] as String?);

    final dateStr = ts != null ? _relative(ts.toDate()) : '—';
    final location = [city, country].whereType<String>().where((s) => s.isNotEmpty).join(', ');

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve:    Curves.easeOutCubic,
        margin:   const EdgeInsets.only(bottom: 10),
        padding:  const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: expanded
              ? AppColors.accent.withOpacity(.06)
              : AppColors.surface.withOpacity(.6),
          border: Border.all(
            color: expanded
                ? AppColors.accent.withOpacity(.3)
                : AppColors.border.withOpacity(.6),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 38, height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(.14),
                  border: Border.all(color: AppColors.primary.withOpacity(.4)),
                ),
                child: Text(flag ?? '🌐',
                    style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      location.isEmpty ? (ip ?? 'Unknown visitor') : location,
                      style: GoogleFonts.montserrat(
                        fontSize: 13.5, fontWeight: FontWeight.w800,
                        color: AppColors.textHigh),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [isp, dateStr].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
                      style: GoogleFonts.montserrat(
                        fontSize: 10.5, color: AppColors.textMid),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color:        AppColors.primary.withOpacity(.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_sourceShort(source, platform),
                    style: GoogleFonts.montserrat(
                      fontSize: 9.5, color: AppColors.primary,
                      fontWeight: FontWeight.w800)),
              ),
            ]),
            if (expanded) ...[
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 10),
              _DetailGrid(data: d),
            ],
          ],
        ),
      ),
    );
  }

  static String _relative(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24) return '${diff.inHours}h ago';
    if (diff.inDays    < 7)  return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  static String _sourceShort(String source, String? platform) {
    switch (source) {
      case 'flutter-admin': return 'admin';
      case 'flutter-guest': return 'app';
      case 'web':           return 'web';
      default:              return (platform ?? source).toUpperCase();
    }
  }

  // Convert country code to flag emoji via regional indicator surrogates.
  static String? _countryEmoji(String? code) {
    if (code == null || code.length != 2) return null;
    final cc = code.toUpperCase();
    return String.fromCharCodes([cc.codeUnitAt(0) + 0x1F1A5, cc.codeUnitAt(1) + 0x1F1A5]);
  }
}

// ─── Detail grid (expanded card) ────────────────────────────────────────────
class _DetailGrid extends StatelessWidget {
  final Map<String, dynamic> data;
  const _DetailGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    final screen = data['screen'] as Map<String, dynamic>?;
    final conn   = data['connection'] as Map<String, dynamic>?;
    final rows = <List<String>>[
      ['IP',          (data['ip'] ?? '—').toString()],
      ['ISP',         (data['isp'] ?? '—').toString()],
      ['ASN',         (data['asn'] ?? '—').toString()],
      ['Country',     '${data['country'] ?? '—'} (${data['countryCode'] ?? '—'})'],
      ['City',        '${data['city'] ?? '—'}${data['region'] != null ? ', ${data['region']}' : ''}'],
      ['Postal',      (data['postal'] ?? '—').toString()],
      ['Lat / Long',  '${data['latitude'] ?? '—'} / ${data['longitude'] ?? '—'}'],
      ['Timezone',    (data['ipapiTimezone'] ?? data['timezone'] ?? '—').toString()],
      ['Language',    (data['language'] ?? data['locale'] ?? '—').toString()],
      ['Platform',    (data['platform'] ?? '—').toString()],
      ['OS version',  (data['osVersion'] ?? '—').toString()],
      ['User agent',  (data['userAgent'] ?? '—').toString()],
      ['Referrer',    (data['referrer'] ?? '—').toString()],
      ['Path',        (data['path'] ?? '—').toString()],
      if (screen != null)
        ['Screen', '${screen['width']?.toStringAsFixed(0)}×${screen['height']?.toStringAsFixed(0)} '
                   '@ ${screen['pixelRatio']?.toString()}x'],
      if (conn != null && conn['effectiveType'] != null)
        ['Connection', '${conn['effectiveType']} · ${conn['downlink']} Mbps · RTT ${conn['rtt']}ms'],
      if (data['adminEmail'] != null) ['Signed in as', data['adminEmail'].toString()],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows.where((r) => r[1] != '—' && r[1] != 'null').map((r) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 100,
                child: Text(r[0],
                    style: GoogleFonts.montserrat(
                      fontSize: 10.5, color: AppColors.textMid,
                      fontWeight: FontWeight.w700, letterSpacing: .5)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SelectableText(r[1],
                    style: GoogleFonts.robotoMono(
                      fontSize: 11, color: AppColors.textHigh, height: 1.45)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─── Empty state ─────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.analytics_outlined,
                color: AppColors.textLow, size: 48),
            const SizedBox(height: 14),
            Text('No visits yet',
                style: GoogleFonts.montserrat(
                  fontSize: 15, color: AppColors.textMid,
                  fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'New entries appear here in real time as visitors open the site or app.',
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                fontSize: 12, color: AppColors.textLow),
            ),
          ],
        ),
      );
}
