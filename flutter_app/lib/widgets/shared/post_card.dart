import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../models/post.dart';
import '../../models/post_intent.dart';
import '../../services/haptics.dart';
import 'post_reactions_button.dart';
import '../../repositories/post_interactions_repository.dart'
    hide ContentReportsRepository;
import '../../repositories/posts_repository.dart';
import '../../repositories/user_blocks_repository.dart';
import '../../repositories/content_reports_repository.dart';
import 'glass_card.dart';
import 'image_carousel.dart';
import 'pressable.dart';

/// SKILL: mensaena-design + mensaena-features
/// PostCard fuer Listen-Ansichten. Zeigt Typ-Badge, Titel,
/// Beschreibung, Standort, Zeit. Tippen → Detail-Seite.
/// 1:1 Action-Parität zu Web PostCard.tsx: Save / Share / Menü
/// (Blocken, Melden).
class PostCard extends ConsumerStatefulWidget {
  const PostCard({required this.post, super.key});

  final Post post;

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard> {
  bool _saved = false;
  bool _savedKnown = false;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final s = await PostsRepository.isSaved(widget.post.id);
    if (!mounted) return;
    setState(() {
      _saved = s;
      _savedKnown = true;
    });
  }

  Future<void> _toggleSave() async {
    // Optimistic: Icon sofort umschalten, Server im Hintergrund.
    final prev = _saved;
    Haptics.tap();
    setState(() => _saved = !prev);
    final next = await PostsRepository.toggleSave(widget.post.id);
    if (!mounted) return;
    // Server-Wahrheit übernehmen (falls abweichend).
    if (next != !prev) setState(() => _saved = next);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.surface,
      duration: const Duration(seconds: 2),
      content: Text(
        next ? '✓ Beitrag gespeichert.' : '✗ Aus Lesezeichen entfernt.',
        style: AppTypography.body(size: 13, color: AppColors.ink),
      ),
    ));
  }

  Future<void> _share() async {
    final url = 'https://www.mensaena.de/dashboard/posts/${widget.post.id}';
    await Share.share(
      '${widget.post.title}\n$url',
      subject: widget.post.title,
    );
  }

  Future<void> _openMenu() async {
    GlassSheet.show<void>(
      context,
      (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            _MenuTile(
              icon: _saved ? LucideIcons.bookmarkMinus : LucideIcons.bookmark,
              label: _saved ? 'Aus Lesezeichen entfernen' : 'Speichern',
              onTap: () {
                Navigator.pop(sheetCtx);
                _toggleSave();
              },
            ),
            _MenuTile(
              icon: LucideIcons.share2,
              label: 'Teilen',
              onTap: () {
                Navigator.pop(sheetCtx);
                _share();
              },
            ),
            const Divider(color: AppColors.line, height: 1),
            _MenuTile(
              icon: LucideIcons.userX,
              label: 'Nutzer:in blockieren',
              color: AppColors.herzrotWarm,
              onTap: () async {
                Navigator.pop(sheetCtx);
                await _confirmBlock();
              },
            ),
            _MenuTile(
              icon: LucideIcons.flag,
              label: 'Beitrag melden',
              color: AppColors.herzrotWarm,
              onTap: () async {
                Navigator.pop(sheetCtx);
                await _showReportDialog();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmBlock() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('posts.blockUserTitle'.tr(),
            style: AppTypography.body(
                size: 15, color: AppColors.ink, weight: FontWeight.w700)),
        content: Text(
            'posts.blockUserConfirm'.tr(),
            style: AppTypography.body(size: 13, color: AppColors.inkSoft)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.herzrot),
            child: Text('posts.blockButton'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await UserBlocksRepository.block(widget.post.userId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.surface,
      content: Text(ok ? 'Nutzer:in blockiert.' : 'Fehler beim Blockieren.',
          style: AppTypography.body(size: 13, color: AppColors.ink)),
    ));
  }

  Future<void> _showReportDialog() async {
    const reasons = <String>[
      'Spam',
      'Belästigung',
      'Hass / Diskriminierung',
      'Gewalt',
      'Falsche Informationen',
      'Anstößige Inhalte',
      'Anderer Grund',
    ];
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('posts.reportTitle'.tr(),
            style: AppTypography.body(
                size: 15, color: AppColors.ink, weight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('posts.chooseReason'.tr(),
                style: AppTypography.body(
                    size: 13, color: AppColors.inkSoft)),
            const SizedBox(height: 10),
            for (final r in reasons)
              ListTile(
                dense: true,
                title: Text(r,
                    style: AppTypography.body(
                        size: 13, color: AppColors.ink)),
                onTap: () => Navigator.pop(ctx, r),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('common.cancel'.tr()),
          ),
        ],
      ),
    );
    if (selected == null) return;
    final ok = await ContentReportsRepository.report(
      contentType: 'post',
      contentId: widget.post.id,
      reason: selected,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.surface,
      content: Text(
        ok ? 'Meldung übermittelt. Danke.' : 'Meldung fehlgeschlagen.',
        style: AppTypography.body(size: 13, color: AppColors.ink),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final cfg = _typeConfig(post.type);
    // F30: Swipe-Gesten — Left → Save toggeln, Right → Meldung-Sheet öffnen.
    return Dismissible(
      key: ValueKey('postcard-${post.id}'),
      direction: DismissDirection.horizontal,
      confirmDismiss: (dir) async {
        Haptics.tap();
        if (dir == DismissDirection.endToStart) {
          await _toggleSave();
        } else if (dir == DismissDirection.startToEnd) {
          _openMenu();
        }
        return false; // nie wirklich dismissen, nur Action triggern
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: AppColors.herzrot.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(LucideIcons.flag,
            color: AppColors.herzrot, size: 22),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: AppColors.amber.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          _saved ? LucideIcons.bookmarkMinus : LucideIcons.bookmark,
          color: AppColors.amber,
          size: 22,
        ),
      ),
      child: Pressable(
      onTap: () => context.push('/dashboard/posts/${post.id}'),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.5),
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: cfg.color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                    border:
                        Border.all(color: cfg.color.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(cfg.emoji, style: const TextStyle(fontSize: 11)),
                      const SizedBox(width: 4),
                      Text(
                        cfg.label,
                        style: AppTypography.label(
                          size: 9,
                          color: cfg.color,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  _relativeTime(post.createdAt),
                  style: AppTypography.body(
                    size: 11,
                    color: AppColors.mute,
                  ),
                ),
                IconButton(
                  // A11y: Tooltip + groesseres Hit-Target (44x44 Material-Spec)
                  // Tooltip wird vom Screen-Reader als Label vorgelesen.
                  tooltip: 'posts.openMenu'.tr(),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                      minWidth: 44, minHeight: 44),
                  onPressed: _openMenu,
                  icon: const Icon(LucideIcons.moreVertical,
                      size: 16, color: AppColors.mute),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              post.title,
              style: AppTypography.body(
                size: 15,
                color: AppColors.ink,
                weight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            if (post.description != null && post.description!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                post.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body(
                  size: 13,
                  color: AppColors.inkSoft,
                  height: 1.45,
                ),
              ),
            ],
            // Phase 5.6: Multi-Image-Carousel mit Indicator-Dots
            // Hero-Tag verbindet List-Image mit PostDetail-Image (smooth fly-in).
            if (post.allImageUrls.isNotEmpty) ...[
              const SizedBox(height: 10),
              Hero(
                tag: 'post-image-${post.id}',
                child: ImageCarousel(
                  urls: post.allImageUrls,
                  height: 180,
                  borderRadius: 10,
                ),
              ),
            ],
            if (post.locationText != null && post.locationText!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    LucideIcons.mapPin,
                    size: 12,
                    color: AppColors.mute,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      post.locationText!,
                      style: AppTypography.body(
                        size: 11,
                        color: AppColors.mute,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            // H1: Intent-aware CTA-Bar — User sieht sofort was zu tun ist.
            // helpNeeded → "Ich helfe" (Leben-Grün)
            // helpOffered + itemOffered → "Ich frage an" (Bronze)
            // sonst → "Antworten" (Bronze, neutral)
            const SizedBox(height: 12),
            _IntentCta(post: post),
            // Action-Bar (Like, Vote, Comment, Save, Share)
            const SizedBox(height: 10),
            Divider(
              height: 1,
              color: Colors.white.withValues(alpha: 0.04),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                // F38: Reactions-Button mit Emoji-Picker (Long-Press).
                PostReactionsButton(postId: post.id),
                const SizedBox(width: 14),
                _VoteBadge(postId: post.id),
                const SizedBox(width: 14),
                _CommentBadge(postId: post.id),
                const SizedBox(width: 14),
                InkWell(
                  onTap: _savedKnown ? _toggleSave : null,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 2),
                    child: Icon(
                      _saved
                          ? LucideIcons.bookmarkPlus
                          : LucideIcons.bookmark,
                      size: 14,
                      color: _saved ? AppColors.bronze : AppColors.mute,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: _share,
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: 4, vertical: 2),
                    child: Icon(LucideIcons.share2,
                        size: 14, color: AppColors.mute),
                  ),
                ),
                const Spacer(),
                if (post.urgencyLevel >= 3)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.herzrot.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.alertTriangle,
                            size: 9, color: AppColors.herzrotWarm),
                        const SizedBox(width: 4),
                        Text('DRINGEND',
                            style: AppTypography.label(
                                size: 7, color: AppColors.herzrotWarm)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }

  static String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return 'gerade eben';
    if (diff.inMinutes < 60) return 'vor ${diff.inMinutes} Min.';
    if (diff.inHours < 24) return 'vor ${diff.inHours} Std.';
    if (diff.inDays == 1) return 'gestern';
    if (diff.inDays < 7) return 'vor ${diff.inDays} Tagen';
    return DateFormat('dd.MM.yyyy').format(t);
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.ink;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 16, color: c),
            const SizedBox(width: 12),
            Text(label,
                style: AppTypography.body(
                    size: 14, color: c, weight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _PostCardAction extends StatelessWidget {
  const _PostCardAction({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        if (label.isNotEmpty) ...[
          const SizedBox(width: 4),
          Text(label,
              style: AppTypography.body(size: 11, color: AppColors.inkSoft)),
        ],
      ],
    );
  }
}

({String label, String emoji, Color color}) _typeConfig(String type) {
  switch (type) {
    case 'help_request':
      return (label: 'Hilfe gesucht', emoji: '🙋', color: AppColors.herzrotWarm);
    case 'help_offered':
      return (label: 'Hilfe da', emoji: '🤝', color: AppColors.lebenSoft);
    case 'sharing':
      return (label: 'Teilen', emoji: '🌱', color: AppColors.leben);
    case 'event':
      return (label: 'Event', emoji: '📅', color: AppColors.bronze);
    case 'item':
      return (label: 'Ding', emoji: '📦', color: AppColors.amber);
    case 'animal':
      return (label: 'Tier', emoji: '🐾', color: AppColors.bronzeSoft);
    case 'housing':
      return (label: 'Wohnen', emoji: '🏠', color: AppColors.tealSoft);
    case 'mobility':
      return (label: 'Mobilität', emoji: '🚗', color: AppColors.amber);
    case 'harvest':
      return (label: 'Ernte', emoji: '🌾', color: AppColors.leben);
    case 'skill':
      return (label: 'Skill', emoji: '🧠', color: AppColors.bronze);
    case 'crisis':
      return (label: 'Krise', emoji: '🚨', color: AppColors.herzrot);
    case 'mental':
      return (label: 'Mental', emoji: '💚', color: AppColors.leben);
    default:
      return (label: 'Post', emoji: '📝', color: AppColors.bronze);
  }
}

// Isolierte Badge-Widgets: rebuilden nur wenn ihr Provider feuert,
// nicht die ganze PostCard. RepaintBoundary kapselt Paint-Cache.
class _VoteBadge extends ConsumerWidget {
  const _VoteBadge({required this.postId});
  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final score = ref.watch(postVoteScoreProvider(postId));
    return RepaintBoundary(
      child: _PostCardAction(
        icon: LucideIcons.arrowUp,
        label: score.when(
          loading: () => '…',
          data: (v) => '$v',
          error: (_, __) => '?',
        ),
        color: AppColors.amber,
      ),
    );
  }
}

class _CommentBadge extends ConsumerWidget {
  const _CommentBadge({required this.postId});
  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(postCommentCountProvider(postId));
    return RepaintBoundary(
      child: _PostCardAction(
        icon: LucideIcons.messageCircle,
        label: count.when(
          loading: () => '…',
          data: (v) => '$v',
          error: (_, __) => '?',
        ),
        color: AppColors.tealSoft,
      ),
    );
  }
}

/// H1: Intent-aware Call-To-Action auf jeder PostCard.
/// Direkt sichtbar was der User tun kann — vorher musste man erst in
/// den Post-Detail navigieren um die Aktion zu sehen.
class _IntentCta extends StatelessWidget {
  const _IntentCta({required this.post});
  final Post post;

  @override
  Widget build(BuildContext context) {
    final intent = post.postIntent;
    // Skip CTA für reine Info-Posts (info_share, social, general) wo
    // keine direkte Aktion erwartet wird — würde nur verwirren.
    if (intent == PostIntent.infoShare ||
        intent == PostIntent.social ||
        intent == PostIntent.general) {
      return const SizedBox.shrink();
    }
    final (label, color) = switch (intent) {
      PostIntent.helpNeeded => ('Ich helfe', AppColors.leben),
      PostIntent.helpOffered => ('Ich nehme an', AppColors.bronze),
      PostIntent.itemOffered => ('Ich nehme', AppColors.bronze),
      PostIntent.itemWanted => ('Ich biete an', AppColors.bronze),
      PostIntent.eventInvite => ('Dabei sein', AppColors.amber),
      PostIntent.warning => ('Mehr erfahren', AppColors.herzrotWarm),
      PostIntent.lostFound => ('Ich helfe suchen', AppColors.leben),
      _ => ('Antworten', AppColors.bronze),
    };
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () => context.push('/dashboard/posts/${post.id}'),
        icon: const Icon(LucideIcons.messageCircle, size: 14),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.18),
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.45)),
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}
