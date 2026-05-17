import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

// ── Cached text styles ────────────────────────────────────────────────────────
final _styleName    = GoogleFonts.montserrat(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.textHigh);
final _styleEmail   = GoogleFonts.montserrat(fontSize: 11,   color: AppColors.textMid);
final _styleDate    = GoogleFonts.montserrat(fontSize: 10.5, color: AppColors.textLow);
final _stylePreview = GoogleFonts.montserrat(fontSize: 12,   color: AppColors.textMid, height: 1.45);
final _styleFull    = GoogleFonts.montserrat(fontSize: 12.5, color: AppColors.textHigh, height: 1.6);

// ── Firestore query ───────────────────────────────────────────────────────────
// Angular saves `date` (string) but no `timestamp`. New Angular submissions now
// include `timestamp: serverTimestamp()`. We sort by timestamp descending so
// new messages float to the top; docs without the field sort last (nulls last).
final _contactsQuery = FirebaseFirestore.instance
    .collection('contacts')
    .orderBy('timestamp', descending: true)
    .limit(100);

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  // Track which card index is expanded (-1 = none)
  int _expanded = -1;

  // Batch-mark all unread docs as read in a single Firestore write
  Future<void> _markAllRead(List<QueryDocumentSnapshot> docs) async {
    final unread = docs.where((d) {
      final data = d.data() as Map<String, dynamic>;
      return !(data['read'] as bool? ?? false);
    }).toList();
    if (unread.isEmpty) return;
    HapticFeedback.lightImpact();
    final batch = FirebaseFirestore.instance.batch();
    for (final d in unread) {
      batch.update(d.reference, {'read': true});
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      // StreamBuilder gives real-time updates: any new web/app submission
      // triggers a Firestore snapshot → UI rebuilds automatically.
      body: StreamBuilder<QuerySnapshot>(
        stream: _contactsQuery.snapshots(),
        builder: (context, snap) {
          // While connecting show spinner in the list area (not full screen)
          final loading = snap.connectionState == ConnectionState.waiting && !snap.hasData;
          final docs    = snap.data?.docs ?? [];
          final unread  = docs.where((d) {
            return !(((d.data() as Map<String, dynamic>)['read']) as bool? ?? false);
          }).length;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [

              // ── App bar ────────────────────────────────────────────────────
              SliverAppBar(
                pinned:           true,
                backgroundColor:  AppColors.bg.withOpacity(.95),
                surfaceTintColor: Colors.transparent,
                automaticallyImplyLeading: false,
                title: Row(children: [
                  Text('Messages',
                      style: GoogleFonts.montserrat(
                        fontSize: 20, fontWeight: FontWeight.w900,
                        color: AppColors.textHigh)),
                  if (unread > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color:        AppColors.accent.withOpacity(.14),
                        borderRadius: BorderRadius.circular(20),
                        border:       Border.all(color: AppColors.accent.withOpacity(.3)),
                      ),
                      child: Text('$unread new',
                          style: GoogleFonts.montserrat(
                            fontSize: 10, color: AppColors.accent,
                            fontWeight: FontWeight.w700)),
                    ),
                  ],
                ]),
                actions: [
                  if (unread > 0)
                    GestureDetector(
                      onTap: () => _markAllRead(docs),
                      child: Container(
                        margin: const EdgeInsets.only(right: 16),
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
              ),

              // ── Loading ────────────────────────────────────────────────────
              if (loading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2),
                  ),
                )

              // ── Error ──────────────────────────────────────────────────────
              else if (snap.hasError)
                SliverFillRemaining(
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
                        Text('${snap.error}',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.montserrat(
                              fontSize: 11, color: AppColors.textLow)),
                      ]),
                    ),
                  ),
                )

              // ── Empty ──────────────────────────────────────────────────────
              else if (docs.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.inbox_outlined, color: AppColors.textLow, size: 52),
                      const SizedBox(height: 14),
                      Text('No messages yet',
                          style: GoogleFonts.montserrat(
                            fontSize: 16, color: AppColors.textMid,
                            fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(
                        'Messages from your portfolio contact form will appear here',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.montserrat(
                          fontSize: 12, color: AppColors.textLow),
                      ),
                    ]),
                  ),
                )

              // ── Message list ───────────────────────────────────────────────
              // SliverList.builder is lazy: only visible cards are built.
              // New Firestore snapshots insert the new card at index 0 and
              // animate it in via the AnimatedContainer inside _MessageCard.
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                  sliver: SliverList.builder(
                    itemCount: docs.length,
                    itemBuilder: (_, i) {
                      final doc  = docs[i];
                      final data = doc.data() as Map<String, dynamic>;
                      return _MessageCard(
                        key:      ValueKey(doc.id),
                        doc:      doc,
                        data:     data,
                        expanded: _expanded == i,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _expanded = _expanded == i ? -1 : i);
                          // Auto-mark as read when expanded
                          if (!(data['read'] as bool? ?? false)) {
                            doc.reference.update({'read': true});
                          }
                        },
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ── Message card ──────────────────────────────────────────────────────────────
class _MessageCard extends StatelessWidget {
  final QueryDocumentSnapshot   doc;
  final Map<String, dynamic>    data;
  final bool                    expanded;
  final VoidCallback            onTap;

  const _MessageCard({
    super.key,
    required this.doc,
    required this.data,
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

  // Handles both new docs (Firestore Timestamp) and legacy docs (date string)
  String _resolveDate() {
    final ts      = data['timestamp'] as Timestamp?;
    final dateStr = data['date']      as String?;

    if (ts != null) return _formatDateTime(ts.toDate());
    if (dateStr != null && dateStr.isNotEmpty) return dateStr; // legacy string as-is
    return '—';
  }

  String _formatDateTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60)  return 'just now';
    if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24)  return '${diff.inHours}h ago';
    if (diff.inDays    < 7)   return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final name    = data['name']    as String? ?? 'Anonymous';
    final email   = data['email']   as String? ?? '';
    final message = data['message'] as String? ?? '';
    final source  = data['source']  as String? ?? '';
    final read    = data['read']    as bool?   ?? false;
    final date    = _resolveDate();
    final accent  = _avatarColor(name);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
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
              // Initials avatar, color-coded by first letter
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
                      // Unread blue dot
                      if (!read)
                        Container(
                          width: 7, height: 7,
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
                      // Source badge: 'web' for Angular, 'app' for Flutter guest
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
                        duration: const Duration(milliseconds: 250),
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
              duration:       const Duration(milliseconds: 260),
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
                    _ActionBtn(
                      icon:  Icons.reply_rounded,
                      label: 'Copy email to reply',
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

// ── Action button ─────────────────────────────────────────────────────────────
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
