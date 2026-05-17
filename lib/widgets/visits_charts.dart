// ─────────────────────────────────────────────────────────────────────────────
// Charts for the Visits page. Three views the admin actually cares about:
//
//   1. Daily trend — bar chart, last 14 days. Tap a bar to see exact count.
//   2. Source mix  — donut. web vs flutter-admin vs flutter-guest.
//   3. Top countries — horizontal bar, top 5.
//
// All three derive from the same flat List<QueryDocumentSnapshot> the page
// already has, so there's no extra Firestore read.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

// Palette — keeps the source colors consistent across the three charts.
const _kWeb       = AppColors.accent;
const _kAdmin     = AppColors.primary;
const _kGuest     = Color(0xFFF4934A);  // Kori orange — guest = consumer
const _kOther     = AppColors.textLow;
const _kBarPos    = AppColors.accent;
const _kCountries = [
  AppColors.accent,
  AppColors.primary,
  Color(0xFFF4934A),
  Color(0xFF7CB9E8),
  Color(0xFFE0A84A),
];

class VisitsCharts extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;
  const VisitsCharts({super.key, required this.docs});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ChartCard(
            title: 'Last 14 days',
            subtitle: 'Daily visits',
            child: SizedBox(
              height: 180,
              child: _DailyBarChart(docs: docs),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ChartCard(
                  title: 'Source',
                  subtitle: 'Where the visit fired',
                  child: SizedBox(
                    height: 180,
                    child: _SourceDonut(docs: docs),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ChartCard(
                  title: 'Top countries',
                  subtitle: 'By visit count',
                  child: SizedBox(
                    height: 180,
                    child: _CountryBar(docs: docs),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Card shell ──────────────────────────────────────────────────────────────
class _ChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  const _ChartCard({required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color:        AppColors.surface.withOpacity(.7),
          borderRadius: BorderRadius.circular(16),
          border:       Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(title,
                  style: GoogleFonts.montserrat(
                    fontSize: 13, fontWeight: FontWeight.w800,
                    color: AppColors.textHigh)),
              const SizedBox(width: 8),
              Text(subtitle,
                  style: GoogleFonts.montserrat(
                    fontSize: 10.5, color: AppColors.textMid)),
            ]),
            const SizedBox(height: 10),
            child,
          ],
        ),
      );
}

// ─── 1. Daily bar chart (last 14 days) ──────────────────────────────────────
class _DailyBarChart extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;
  const _DailyBarChart({required this.docs});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 13));

    // Bucket counts per day.
    final counts = List<int>.filled(14, 0);
    for (final d in docs) {
      final data = d.data() as Map<String, dynamic>;
      final ts = data['timestamp'] as Timestamp?;
      if (ts == null) continue;
      final dt = ts.toDate();
      final idx = dt.difference(start).inDays;
      if (idx >= 0 && idx < 14) counts[idx]++;
    }

    final maxY = (counts.fold<int>(0, (m, v) => v > m ? v : m).toDouble())
        .clamp(4.0, double.infinity);

    return BarChart(
      BarChartData(
        alignment:    BarChartAlignment.spaceBetween,
        maxY:         maxY * 1.2,
        minY:         0,
        gridData:     FlGridData(
          show: true,
          horizontalInterval: (maxY / 4).clamp(1, double.infinity).toDouble(),
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: AppColors.border, strokeWidth: .6, dashArray: [3, 3]),
        ),
        borderData:   FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: (maxY / 4).clamp(1, double.infinity).toDouble(),
              getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                  style: GoogleFonts.montserrat(
                    fontSize: 9, color: AppColors.textLow)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (v, _) {
                final dt = start.add(Duration(days: v.toInt()));
                // Show only every 3rd label so 14 days fits without overlap.
                if (v.toInt() % 3 != 0 && v.toInt() != 13) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('${dt.day}/${dt.month}',
                      style: GoogleFonts.montserrat(
                        fontSize: 9, color: AppColors.textLow)),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor:  (_) => AppColors.surface,
            tooltipRoundedRadius: 10,
            getTooltipItem: (group, _, rod, __) {
              final dt = start.add(Duration(days: group.x));
              return BarTooltipItem(
                '${dt.day}/${dt.month}  ·  ${rod.toY.toInt()} visit${rod.toY.toInt() == 1 ? '' : 's'}',
                GoogleFonts.montserrat(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: AppColors.textHigh),
              );
            },
          ),
        ),
        barGroups: [
          for (var i = 0; i < 14; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY:    counts[i].toDouble(),
                  width:  10,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  gradient: LinearGradient(
                    begin:  Alignment.bottomCenter,
                    end:    Alignment.topCenter,
                    colors: [
                      _kBarPos.withOpacity(.45),
                      _kBarPos,
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ─── 2. Source donut ────────────────────────────────────────────────────────
class _SourceDonut extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;
  const _SourceDonut({required this.docs});

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final d in docs) {
      final s = ((d.data() as Map<String, dynamic>)['source'] as String?) ?? 'web';
      counts[s] = (counts[s] ?? 0) + 1;
    }
    final total = counts.values.fold(0, (a, b) => a + b);
    if (total == 0) return _EmptyChart();

    Color colorFor(String s) {
      switch (s) {
        case 'web':           return _kWeb;
        case 'flutter-admin': return _kAdmin;
        case 'flutter-guest': return _kGuest;
        default:              return _kOther;
      }
    }

    String labelFor(String s) {
      switch (s) {
        case 'flutter-admin': return 'Admin';
        case 'flutter-guest': return 'Guest';
        case 'web':           return 'Web';
        default:              return s;
      }
    }

    final entries = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Row(children: [
      Expanded(
        child: PieChart(
          PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 28,
            startDegreeOffset: -90,
            sections: [
              for (final e in entries)
                PieChartSectionData(
                  value:  e.value.toDouble(),
                  color:  colorFor(e.key),
                  radius: 30,
                  showTitle: false,
                ),
            ],
          ),
        ),
      ),
      const SizedBox(width: 6),
      Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle, color: colorFor(e.key))),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(labelFor(e.key),
                        style: GoogleFonts.montserrat(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: AppColors.textHigh)),
                  ),
                  Text('${e.value}',
                      style: GoogleFonts.montserrat(
                        fontSize: 11, color: AppColors.textMid)),
                ]),
              ),
            const SizedBox(height: 4),
            Text('$total total',
                style: GoogleFonts.montserrat(
                  fontSize: 10, color: AppColors.textLow)),
          ],
        ),
      ),
    ]);
  }
}

// ─── 3. Top countries horizontal bar ────────────────────────────────────────
class _CountryBar extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;
  const _CountryBar({required this.docs});

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    final codes  = <String, String>{};
    for (final d in docs) {
      final data = d.data() as Map<String, dynamic>;
      final co = data['country'] as String?;
      final cc = data['countryCode'] as String?;
      if (co == null || co.isEmpty) continue;
      counts[co] = (counts[co] ?? 0) + 1;
      if (cc != null) codes[co] = cc;
    }
    if (counts.isEmpty) return _EmptyChart();

    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.take(5).toList();
    final maxV = top.first.value.toDouble().clamp(1, double.infinity).toDouble();

    String flag(String? cc) {
      if (cc == null || cc.length != 2) return '🌐';
      final c = cc.toUpperCase();
      return String.fromCharCodes(
          [c.codeUnitAt(0) + 0x1F1A5, c.codeUnitAt(1) + 0x1F1A5]);
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (var i = 0; i < top.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              SizedBox(
                width: 18,
                child: Text(flag(codes[top[i].key]),
                    style: const TextStyle(fontSize: 14))),
              const SizedBox(width: 6),
              SizedBox(
                width: 60,
                child: Text(top[i].key,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.montserrat(
                      fontSize: 10.5, fontWeight: FontWeight.w700,
                      color: AppColors.textHigh)),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: top[i].value / maxV,
                    minHeight: 8,
                    backgroundColor: AppColors.border.withOpacity(.5),
                    valueColor: AlwaysStoppedAnimation(
                        _kCountries[i % _kCountries.length]),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 20,
                child: Text('${top[i].value}',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.montserrat(
                      fontSize: 10.5, color: AppColors.textMid,
                      fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
      ],
    );
  }
}

// ─── Shared empty state ──────────────────────────────────────────────────────
class _EmptyChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
        child: Text('Not enough data yet',
            style: GoogleFonts.montserrat(
              fontSize: 11, color: AppColors.textLow)),
      );
}
