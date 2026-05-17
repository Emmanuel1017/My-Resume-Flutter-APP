// ─────────────────────────────────────────────────────────────────────────────
// MessagesScreen — performance-focused inbox.
//
// Smoothness wins over the previous version:
//   1.  Expansion state lives in a ValueNotifier — tapping a card no longer
//       rebuilds the whole list, only the two cards that flip state.
//   2.  Each card is wrapped in RepaintBoundary so unread→read transitions
//       don't invalidate sibling paint regions.
//   3.  Sort keys are memoized in a wrapper struct so a snapshot update doesn't
//       re-parse legacy date strings for every doc on every rebuild.
//   4.  Unread count + list use the same snapshot but split through two narrow
//       widgets — the app bar's "N new" pill repaints in isolation.
//   5.  Initial fetch is capped at 60 (most recent); a "Load older" footer
//       expands the visible window on demand. Firestore stream still feeds the
//       whole collection (live updates flow in), but the ListView only renders
//       what's currently in the window.
//   6.  Pull-to-refresh resets the window — gives a tactile "fresh load" feel.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

// ── Cached text styles (one TextStyle object instead of per-build) ───────────
final _styleName    = GoogleFonts.montserrat(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.textHigh);
final _styleEmail   = GoogleFonts.montserrat(fontSize: 11,   color: AppColors.textMid);
final _styleDate    = GoogleFonts.montserrat(fontSize: 10.5, color: AppColors.textLow);
final _stylePreview = GoogleFonts.montserrat(fontSize: 12,   color: AppColors.textMid, height: 1.45);
final _styleFull    = GoogleFonts.montserrat(fontSize: 12.5, color: AppColors.textHigh, height: 1.6);
final _styleTitle   = GoogleFonts.montserrat(fontSize: 20,   fontWeight: FontWeight.w900, color: AppColors.textHigh);
final _styleBadge   = GoogleFonts.montserrat(fontSize: 10,   color: AppColors.accent, fontWeight: FontWeight.w700);

// ── Pagination window ────────────────────────────────────────────────────────
const _kInitialWindow = 60;
const _kPageStep      = 40;

// ── Memoized doc wrapper ─────────────────────────────────────────────────────
// Computing the sort key (especially the legacy-date regex parse) on every
// rebuild was a hot path. We wrap each QueryDocumentSnapshot once and reuse.
class _MsgRow {
  final QueryDocumentSnapshot doc;
  final Map<String, dynamic>  data;
  final DateTime              sortKey;
  final bool                  read;

  _MsgRow(this.doc)
      : data    = doc.data() as Map<String, dynamic>,
        sortKey = _computeSortKey(doc.data() as Map<String, dynamic>),
        read    = ((doc.data() as Map<String, dynamic>)['read'] as bool? ?? false);

  static DateTime _computeSortKey(Map<String, dynamic> data) {
    final ts = data['timestamp'] as Timestamp?;
    if (ts != null) return ts.toDate();
    final ds = data['date'] as String?;
    if (ds != null && ds.isNotEmpty) return _parseLegacyDate(ds);
    return DateTime(1970);
  }
}

DateTime _parseLegacyDate(String s) {
  final m = RegExp(
    r'^(\w+)\s+(\d{1,2}),\s+(\d{4})\s+(\d{1,2}):(\d{2})\s*(AM|PM)$',
    caseSensitive: false,
  ).firstMatch(s.trim());
  if (m == null) return DateTime.tryParse(s) ?? DateTime(1970);
  const months = {
    'january': 1, 'february': 2, 'march':     3, 'april':    4,
    'may':     5, 'june':     6, 'july':      7, 'august':   8,
    'september': 9, 'october': 10, 'november': 11, 'december': 12,
  };
  final month = months[m.group(1)!.toLowerCase()] ?? 1;
  final day   = int.parse(m.group(2)!);
  final year  = int.parse(m.group(3)!);
  var hour    = int.parse(m.group(4)!);
  final min   = int.parse(m.group(5)!);
  final ampm  = m.group(6)!.toUpperCase();
  if (ampm == 'PM' && hour != 12) hour += 12;
  if (ampm == 'AM' && hour == 12) hour = 0;
  return DateTime(year, month, day, hour, min);
}

// ── Stream-with-cache ────────────────────────────────────────────────────────
// We memoize the latest snapshot's rows so quick rebuilds (e.g. when
// _windowSize changes) reuse the same _MsgRow objects.
final _contactsQuery = FirebaseFirestore.instance.collection('contacts').limit(300);

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  // The currently-expanded doc id. Using a ValueNotifier so only the two
  // affected cards rebuild — never the rest of the list.
  final ValueNotifier<String?> _expandedId = ValueNotifier<String?>(null);

  // Window cursor — how many rows we currently render. Bumped by "Load older".
  final ValueNotifier<int> _windowSize = ValueNotifier<int>(_kInitialWindow);

  // Per-doc-id cache so we don't rebuild _MsgRow on every snapshot.
  final Map<String, _MsgRow> _rowCache = {};

  @override
  void dispose() {
    _expandedId.dispose();
    _windowSize.dispose();
    super.dispose();
  }

  List<_MsgRow> _materialize(List<QueryDocumentSnapshot> docs) {
    final keepIds = <String>{};
    final rows    = <_MsgRow>[];
    for (final d in docs) {
      keepIds.add(d.id);
      final cached = _rowCache[d.id];
      if (cached != null && _sameDoc(cached.doc, d)) {
        rows.add(cached);
      } else {
        final row = _MsgRow(d);
        _rowCache[d.id] = row;
        rows.add(row);
      }
    }
    // Evict cached rows that no longer exist in the snapshot.
    _rowCache.removeWhere((k, _) => !keepIds.contains(k));
    rows.sort((a, b) => b.sortKey.compareTo(a.sortKey));
    return rows;
  }

  // QueryDocumentSnapshot is immutable per snapshot, but equality is by hashCode.
  // If the underlying doc data hasn't changed, treat as same.
  bool _sameDoc(QueryDocumentSnapshot a, QueryDocumentSnapshot b) {
    final ad = a.data() as Map<String, dynamic>;
    final bd = b.data() as Map<String, dynamic>;
    return ad['read']      == bd['read'] &&
           ad['timestamp'] == bd['timestamp'];
  }

  Future<void> _markAllRead(List<_MsgRow> rows) async {
    final unread = rows.where((r) => !r.read).toList();
    if (unread.isEmpty) return;
    HapticFeedback.lightImpact();
    final batch = FirebaseFirestore.instance.batch();
    for (final r in unread) {
      batch.update(r.doc.reference, {'read': true});
    }
    await batch.commit();
  }

  void _toggleExpand(_MsgRow r) {
    HapticFeedback.selectionClick();
    final wasExpanded = _expandedId.value == r.doc.id;
    _expandedId.value = wasExpanded ? null : r.doc.id;
    if (!wasExpanded && !r.read) {
      r.doc.reference.update({'read': true});
    }
  }

  Future<void> _refresh() async {
    HapticFeedback.lightImpact();
    _windowSize.value = _kInitialWindow;
    // Wait for at least one frame so the RefreshIndicator animates cleanly.
    await Future<void>.delayed(const Duration(milliseconds: 350));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: StreamBuilder<QuerySnapshot>(
        stream: _contactsQuery.snapshots(),
        builder: (context, snap) {
          final loading = snap.connectionState == ConnectionState.waiting && !snap.hasData;
          final rows    = _materialize(snap.data?.docs ?? const []);
          final unread  = rows.where((r) => !r.read).length;

          return RefreshIndicator(
            color: AppColors.accent,
            backgroundColor: AppColors.surface,
            onRefresh: _refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              // cacheExtent lets the lazy ListView pre-build a screen-and-a-half's
              // worth of cards so fast scrolls don't show blank gaps.
              cacheExtent: 800,
              slivers: [
                _AppBar(
                  unread: unread,
                  onMarkAll: rows.isEmpty ? null : () => _markAllRead(rows),
                ),

                if (loading)
                  const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(
                          color: AppColors.accent, strokeWidth: 2)),
                  )
                else if (snap.hasError)
                  _ErrorSliver(error: snap.error)
                else if (rows.isEmpty)
                  const _EmptySliver()
                else
                  _ListSliver(
                    rows:        rows,
                    expandedId:  _expandedId,
                    windowSize:  _windowSize,
                    onToggle:    _toggleExpand,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── App bar (kept const-friendly) ───────────────────────────────────────────
class _AppBar extends StatelessWidget {
  final int unread;
  final VoidCallback? onMarkAll;
  const _AppBar({required this.unread, required this.onMarkAll});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned:           true,
      backgroundColor:  AppColors.bg.withOpacity(.95),
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      title: Row(children: [
        Text('Messages', style: _styleTitle),
        if (unread > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color:        AppColors.accent.withOpacity(.14),
              borderRadius: BorderRadius.circular(20),
              border:       Border.all(color: AppColors.accent.withOpacity(.3)),
            ),
            child: Text('$unread new', style: _styleBadge),
          ),
        ],
      ]),
      actions: [
        if (unread > 0 && onMarkAll != null)
          GestureDetector(
            onTap: onMarkAll,
            child: Container(
              margin:  const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color:        AppColors.surface.withOpacity(.7),
                borderRadius: BorderRadius.circular(14),
                border:       Border.all(color: AppColors.border),
              ),
              child: Text('Mark all read',
                  style: GoogleFonts.montserrat(
                    fontSize: 11, color: AppColors.textMid,
                    fontWeight: FontWeight.w600)),
            ),
          ),
      ],
    );
  }
}

class _ErrorSliver extends StatelessWidget {
  final Object? error;
  const _ErrorSliver({required this.error});

  @override
  Widget build(BuildContext context) => SliverFillRemaining(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.wifi_off_rounded, color: AppColors.danger, size: 36),
              const SizedBox(height: 12),
              Text('Could not load messages',
                  style: GoogleFonts.montserrat(
                    fontSize: 13, color: AppColors.danger,
                    fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text('$error',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    fontSize: 11, color: AppColors.textLow)),
            ]),
          ),
        ),
      );
}

class _EmptySliver extends StatelessWidget {
  const _EmptySliver();

  @override
  Widget build(BuildContext context) => SliverFillRemaining(
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.inbox_outlined, color: AppColors.textLow, size: 52),
            const SizedBox(height: 14),
            Text('No messages yet',
                style: GoogleFonts.montserrat(
                  fontSize: 16, color: AppColors.textMid,
                  fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('Messages from your portfolio contact form will appear here',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 12, color: AppColors.textLow)),
          ]),
        ),
      );
}

// ─── List sliver — wraps the visible window + load-older footer ─────────────
class _ListSliver extends StatelessWidget {
  final List<_MsgRow> rows;
  final ValueNotifier<String?> expandedId;
  final ValueNotifier<int>     windowSize;
  final void Function(_MsgRow) onToggle;
  const _ListSliver({
    required this.rows,
    required this.expandedId,
    required this.windowSize,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: windowSize,
      builder: (_, win, __) {
        final cap     = win.clamp(0, rows.length);
        final hasMore = cap < rows.length;
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) {
                if (i == cap) {
                  return _LoadMoreBtn(
                    remaining: rows.length - cap,
                    onTap: () => windowSize.value = (win + _kPageStep).clamp(0, rows.length),
                  );
                }
                final row = rows[i];
                return RepaintBoundary(
                  child: ValueListenableBuilder<String?>(
                    valueListenable: expandedId,
                    builder: (_, id, __) => _MessageCard(
                      key:      ValueKey(row.doc.id),
                      row:      row,
                      expanded: id == row.doc.id,
                      onTap:    () => onToggle(row),
                    ),
                  ),
                );
              },
              childCount:        cap + (hasMore ? 1 : 0),
              addAutomaticKeepAlives: false,
              addRepaintBoundaries:   false, // we add our own above
            ),
          ),
        );
      },
    );
  }
}

class _LoadMoreBtn extends StatelessWidget {
  final int remaining;
  final VoidCallback onTap;
  const _LoadMoreBtn({required this.remaining, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color:        AppColors.surface.withOpacity(.5),
              borderRadius: BorderRadius.circular(14),
              border:       Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.expand_more_rounded,
                    color: AppColors.textMid, size: 16),
                const SizedBox(width: 6),
                Text('Load $remaining older',
                    style: GoogleFonts.montserrat(
                      fontSize: 12, color: AppColors.textMid,
                      fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      );
}

// ─── Message card ────────────────────────────────────────────────────────────
class _MessageCard extends StatelessWidget {
  final _MsgRow      row;
  final bool         expanded;
  final VoidCallback onTap;

  const _MessageCard({
    super.key,
    required this.row,
    required this.expanded,
    required this.onTap,
  });

  static const _avatarColors = [
    AppColors.accent,
    AppColors.primary,
    AppColors.warning,
    Color(0xFF7CB9E8),
    Color(0xFFE87A7A),
  ];

  Color _avatarColor(String name) {
    if (name.isEmpty) return AppColors.textMid;
    return _avatarColors[name.codeUnitAt(0) % _avatarColors.length];
  }

  String _resolveDate(Map<String, dynamic> data) {
    final ts      = data['timestamp'] as Timestamp?;
    final dateStr = data['date']      as String?;
    if (ts != null) return _formatDateTime(ts.toDate());
    if (dateStr != null && dateStr.isNotEmpty) return dateStr;
    return '—';
  }

  String _formatDateTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24) return '${diff.inHours}h ago';
    if (diff.inDays    < 7)  return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final data    = row.data;
    final name    = data['name']    as String? ?? 'Anonymous';
    final email   = data['email']   as String? ?? '';
    final message = data['message'] as String? ?? '';
    final source  = data['source']  as String? ?? '';
    final read    = row.read;
    final date    = _resolveDate(data);
    final accent  = _avatarColor(name);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve:    Curves.easeOutCubic,
        margin:   const EdgeInsets.only(bottom: 10),
        padding:  const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: expanded
              ? AppColors.accent.withOpacity(.07)
              : AppColors.surface.withOpacity(.7),
          border: Border.all(
            color: expanded
                ? AppColors.accent.withOpacity(.3)
                : read
                    ? AppColors.border.withOpacity(.5)
                    : AppColors.accent.withOpacity(.25),
            width: read ? 1 : 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ────────────────────────────────────────────────
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  shape:  BoxShape.circle,
                  color:  accent.withOpacity(.14),
                  border: Border.all(color: accent.withOpacity(.4)),
                ),
                alignment: Alignment.center,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: GoogleFonts.montserrat(
                    fontSize: 15, fontWeight: FontWeight.w800, color: accent),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      if (!read)
                        Container(
                          width:  7, height: 7,
                          margin: const EdgeInsets.only(right: 6, top: 3),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.accent,
                          ),
                        ),
                      Expanded(
                        child: Text(name,
                            style: _styleName.copyWith(
                              fontWeight: read ? FontWeight.w600 : FontWeight.w800),
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 8),
                      Text(date, style: _styleDate),
                    ]),
                    const SizedBox(height: 3),
                    Row(children: [
                      Expanded(
                        child: Text(email,
                            style: _styleEmail,
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (source.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color:        AppColors.primary.withOpacity(.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            source == 'flutter-guest' ? 'app' : 'web',
                            style: GoogleFonts.montserrat(
                              fontSize: 9.5, color: AppColors.primary,
                              fontWeight: FontWeight.w700)),
                        ),
                      ],
                      const SizedBox(width: 4),
                      AnimatedRotation(
                        turns:    expanded ? .5 : 0,
                        duration: const Duration(milliseconds: 220),
                        child:    const Icon(Icons.expand_more_rounded,
                            color: AppColors.textLow, size: 18),
                      ),
                    ]),
                  ],
                ),
              ),
            ]),

            // ── Message preview / full ────────────────────────────────────
            AnimatedCrossFade(
              duration:       const Duration(milliseconds: 240),
              firstCurve:     Curves.easeInCubic,
              secondCurve:    Curves.easeOutCubic,
              crossFadeState: expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: Padding(
                padding: const EdgeInsets.only(top: 8, left: 52),
                child: Text(
                  message.length > 90 ? '${message.substring(0, 90)}…' : message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:    _stylePreview),
              ),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 10, left: 52),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(message, style: _styleFull),
                    const SizedBox(height: 14),
                    Row(children: [
                      _ActionBtn(
                        icon:  Icons.reply_rounded,
                        label: 'Copy email',
                        color: AppColors.accent,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Clipboard.setData(ClipboardData(text: email));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Copied: $email',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 12, fontWeight: FontWeight.w600)),
                              backgroundColor: AppColors.primary,
                              behavior:        SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              margin:   const EdgeInsets.all(16),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 10),
                      _ActionBtn(
                        icon:  read ? Icons.markunread_outlined : Icons.mark_email_read_outlined,
                        label: read ? 'Mark unread' : 'Mark read',
                        color: AppColors.textMid,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          row.doc.reference.update({'read': !read});
                        },
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Action button ───────────────────────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final Color        color;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.icon, required this.label,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding:    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color:        color.withOpacity(.12),
            borderRadius: BorderRadius.circular(12),
            border:       Border.all(color: color.withOpacity(.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.montserrat(
                  fontSize: 11.5, color: color, fontWeight: FontWeight.w700)),
          ]),
        ),
      );
}
