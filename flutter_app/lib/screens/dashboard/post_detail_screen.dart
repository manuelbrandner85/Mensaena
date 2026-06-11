import 'dart:async';

import '../../widgets/shared/sized_avatar_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../models/post.dart';
import '../../repositories/post_interactions_repository.dart';
import '../../repositories/posts_repository.dart';
import '../../repositories/profiles_repository.dart';
import '../../services/haptics.dart';
import '../../services/share_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/layouts/dashboard_scaffold.dart';
import '../../widgets/post/post_contact_actions.dart';
import '../../widgets/posts/poll_create_sheet.dart';
import '../../widgets/posts/post_poll_widget.dart';
import '../../widgets/posts/reading_mode_toggle.dart';
import '../../widgets/posts/similar_posts_carousel.dart';
import '../../widgets/shared/post_reactions_button.dart';
import '../../widgets/shared/image_carousel.dart';
import '../../widgets/shared/post_status_badge.dart';
import '../../widgets/shared/wikipedia_box.dart';

/// SKILL: flutter-build-responsive-layout + mensaena-features
/// Post-Detail: Hero (Typ-Badge, Bilder, Titel, Beschreibung), Author,
/// Stats, Actions (Helfen/Vote/Save/Share/Report), Comments (threaded).
class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({required this.postId, super.key});

  final String postId;

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  Post? _post;
  String? _statusOverride;
  bool _loading = true;
  bool _saved = false;
  int? _myVote;
  int _score = 0;
  List<Map<String, dynamic>> _comments = const [];
  final _commentCtrl = TextEditingController();
  // Cinema: ScrollController treibt den Parallax-Hero (Bild scrollt langsamer).
  final _scrollCtrl = ScrollController();
  // Phase 5.7: optional parent for nested-reply (depth-1)
  String? _replyToParentId;
  String? _replyToAuthor;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait<dynamic>([
      PostsRepository.getById(widget.postId),
      SavedPostsRepository.isSaved(widget.postId),
      PostVotesRepository.myVote(widget.postId),
      PostVotesRepository.totalScore(widget.postId),
      PostCommentsRepository.listFor(widget.postId),
    ]);
    if (!mounted) return;
    setState(() {
      _post = results[0] as Post?;
      _saved = results[1] as bool;
      _myVote = results[2] as int?;
      _score = results[3] as int;
      _comments = results[4] as List<Map<String, dynamic>>;
      _loading = false;
    });
  }

  Future<void> _vote(int v) async {
    // Optimistic UI: sofort lokal anwenden, bei Fehler zurückrollen.
    final prevVote = _myVote;
    final prevScore = _score;
    final newVote = _myVote == v ? null : v;
    // Score-Delta lokal schätzen (alte Stimme raus, neue rein).
    final delta = (newVote ?? 0) - (prevVote ?? 0);
    Haptics.select();
    setState(() {
      _myVote = newVote;
      _score = prevScore + delta;
    });
    try {
      await PostVotesRepository.vote(postId: widget.postId, value: v);
      // Server-Score nachziehen für exakte Genauigkeit.
      final score = await PostVotesRepository.totalScore(widget.postId);
      if (mounted) setState(() => _score = score);
    } catch (_) {
      if (mounted) {
        setState(() {
          _myVote = prevVote;
          _score = prevScore;
        });
      }
    }
  }

  Future<void> _toggleSave() async {
    Haptics.tap();
    final prev = _saved;
    setState(() => _saved = !prev); // optimistic
    try {
      await SavedPostsRepository.toggle(widget.postId);
    } catch (_) {
      if (mounted) setState(() => _saved = prev); // rollback
    }
  }

  Future<void> _share() async {
    final p = _post;
    if (p == null) return;
    await ShareService.shareExternal(
      postId: p.id,
      subject: p.title,
      text: '${p.title}\n\n${ShareService.buildShareUrl(postId: p.id)}',
    );
  }

  /// F82: kopiert nur den Post-Link in die Zwischenablage + zeigt Snackbar.
  Future<void> _copyLink() async {
    final p = _post;
    if (p == null) return;
    final url = ShareService.buildShareUrl(postId: p.id);
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    Haptics.tap();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: const Duration(seconds: 2),
      backgroundColor: AppColors.surface,
      content: Text('posts.linkCopied'.tr(),
          style: AppTypography.body(size: 13, color: AppColors.ink)),
    ));
  }

  Future<void> _report() async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xF0121A28),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ReportSheet(),
    );
    if (reason == null || !mounted) return;
    final ok = await ContentReportsRepository.report(
      contentType: 'post',
      contentId: widget.postId,
      reason: reason,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'posts.reportSubmitted'.tr() : 'posts.reportFailed'.tr(),
        ),
      ),
    );
  }

  Future<void> _offerHelp() async {
    final ok = await InteractionsCreateRepository.offerHelp(
      postId: widget.postId,
    );
    if (!mounted) return;
    if (ok) {
      unawaited(Haptics.success());
    } else {
      unawaited(Haptics.error());
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'posts.helpOffered'.tr() : 'posts.helpFailed'.tr(),
        ),
      ),
    );
  }

  /// Builds depth-1 nested comment tree (1:1 to Web PostDetailPage).
  /// Roots (parent_id=null) at top, each followed by its replies indented.
  List<Widget> _buildCommentTree() {
    final currentUid = SupabaseService.currentUser?.id;
    final roots = _comments
        .where((c) => c['parent_id'] == null)
        .toList();
    final replies = <String, List<Map<String, dynamic>>>{};
    for (final c in _comments) {
      final pid = c['parent_id'] as String?;
      if (pid != null) {
        replies.putIfAbsent(pid, () => []).add(c);
      }
    }
    final tiles = <Widget>[];
    for (final root in roots) {
      final isOwn = currentUid != null && root['user_id'] == currentUid;
      tiles.add(_CommentTile(
        root,
        isOwn: isOwn,
        onReply: () => setState(() {
          _replyToParentId = root['id'] as String?;
          final profile = root['profiles'] as Map<String, dynamic>?;
          _replyToAuthor = (profile?['display_name'] ??
              profile?['name'] ??
              'common.neighbour'.tr()) as String;
        }),
        onEdit: isOwn ? () => _editComment(root) : null,
        onDelete: isOwn ? () => _deleteComment(root) : null,
      ));
      final children = replies[root['id'] as String] ?? const [];
      for (final child in children) {
        final childOwn = currentUid != null && child['user_id'] == currentUid;
        tiles.add(Padding(
          padding: const EdgeInsets.only(left: 32),
          child: _CommentTile(
            child,
            isOwn: childOwn,
            onEdit: childOwn ? () => _editComment(child) : null,
            onDelete: childOwn ? () => _deleteComment(child) : null,
          ),
        ));
      }
    }
    return tiles;
  }

  Future<void> _editComment(Map<String, dynamic> c) async {
    final id = c['id'] as String?;
    if (id == null) return;
    final ctrl = TextEditingController(text: c['content'] as String? ?? '');
    final newText = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('posts.editCommentTitle'.tr(),
            style: AppTypography.display(size: 16, color: AppColors.ink)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 4,
          style: AppTypography.body(size: 14, color: AppColors.ink),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text('common.save'.tr()),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (newText == null || newText.isEmpty || !mounted) return;
    final ok = await PostCommentsRepository.edit(
      commentId: id,
      newContent: newText,
    );
    if (!mounted) return;
    if (ok) {
      ref.invalidate(postCommentsProvider(widget.postId));
      ref.invalidate(postCommentCountProvider(widget.postId));
      final fresh = await PostCommentsRepository.listFor(widget.postId);
      if (mounted) setState(() => _comments = fresh);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text('common.error'.tr(),
            style: AppTypography.body(size: 13, color: AppColors.ink)),
      ));
    }
  }

  Future<void> _deleteComment(Map<String, dynamic> c) async {
    final id = c['id'] as String?;
    if (id == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('posts.deleteCommentTitle'.tr(),
            style: AppTypography.display(size: 16, color: AppColors.ink)),
        content: Text('posts.deleteCommentConfirm'.tr(),
            style: AppTypography.body(size: 13, color: AppColors.inkSoft)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.herzrot),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('common.delete'.tr()),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final ok = await PostCommentsRepository.deleteComment(id);
    if (!mounted) return;
    if (ok) {
      ref.invalidate(postCommentsProvider(widget.postId));
      ref.invalidate(postCommentCountProvider(widget.postId));
      final fresh = await PostCommentsRepository.listFor(widget.postId);
      if (mounted) setState(() => _comments = fresh);
    }
  }

  Future<void> _addComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    final ok = await PostCommentsRepository.add(
      postId: widget.postId,
      content: text,
      parentId: _replyToParentId,
    );
    if (!ok || !mounted) return;
    setState(() {
      _replyToParentId = null;
      _replyToAuthor = null;
    });
    _commentCtrl.clear();
    final fresh = await PostCommentsRepository.listFor(widget.postId);
    if (mounted) setState(() => _comments = fresh);
  }

  Future<void> _changeStatus(String status) async {
    if (_post == null) return;
    final ok = await PostsRepository.setStatus(widget.postId, status);
    if (!mounted) return;
    if (ok) {
      // Post hat kein copyWith → lokalen Override halten, damit das Badge
      // sofort den neuen Status zeigt ohne Voll-Reload.
      setState(() => _statusOverride = status);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('posts.statusChanged'.tr())),
      );
    }
  }

  Future<void> _deletePost() async {
    if (_post == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('posts.deleteTitle'.tr(),
            style:
                AppTypography.display(size: 18, color: AppColors.ink)),
        content: Text(
          'posts.deleteConfirm'.tr(),
          style:
              AppTypography.body(size: 13, color: AppColors.inkSoft),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('common.cancel'.tr())),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.herzrot),
            onPressed: () => Navigator.pop(context, true),
            child: Text('common.delete'.tr()),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final ok = await PostsRepository.delete(_post!.id);
    if (!mounted) return;
    if (ok) {
      context.go('/dashboard/posts');
      return;
    }
    {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text('posts.deleteFailed'.tr(),
            style:
                AppTypography.body(size: 13, color: AppColors.ink)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMyPost =
        _post != null && _post!.userId == SupabaseService.currentUser?.id;
    final myRole =
        ref.watch(myProfileProvider).asData?.value?.role ?? 'user';
    final isAdmin = myRole == 'admin' || myRole == 'moderator';
    return DashboardScaffold(
      title: 'posts.detailTitle'.tr(),
      currentRoute: '/dashboard/posts',
      fab: (isMyPost || isAdmin) && _post != null
          ? FloatingActionButton.small(
              backgroundColor: AppColors.herzrot,
              foregroundColor: AppColors.ink,
              tooltip: 'posts.deleteTooltip'.tr(),
              onPressed: _deletePost,
              child: const Icon(LucideIcons.trash2, size: 16),
            )
          : null,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          child: _loading
              ? const Center(
                  key: ValueKey('loading'),
                  child: CircularProgressIndicator(color: AppColors.amber),
                )
              : _post == null
                  ? _NotFound()
                  : Column(
                  key: const ValueKey('content'),
                    children: [
                      Expanded(
                        child: RefreshIndicator(
                          color: AppColors.amber,
                          backgroundColor: AppColors.surface,
                          onRefresh: _load,
                          child: ListView(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.all(16),
                          children: [
                            _Hero(post: _post!, scrollController: _scrollCtrl),
                            // P6 Status-Lifecycle: Badge für alle + Steuerung
                            // für den Autor.
                            if ((_statusOverride ?? _post!.status) !=
                                    'active' ||
                                isMyPost) ...[
                              const SizedBox(height: 12),
                              _StatusControl(
                                status: _statusOverride ?? _post!.status,
                                canEdit: isMyPost,
                                onChange: _changeStatus,
                              ),
                            ],
                            const SizedBox(height: 16),
                            // Mega-Contact-System (Intent-basierte CTAs)
                            PostContactActions(post: _post!),
                            const SizedBox(height: 16),
                            _ActionsBar(
                              postId: widget.postId,
                              myVote: _myVote,
                              score: _score,
                              saved: _saved,
                              onVoteUp: () => _vote(1),
                              onVoteDown: () => _vote(-1),
                              onSave: _toggleSave,
                              onShare: _share,
                              onCopyLink: _copyLink,
                              onReport: _report,
                              onHelp: _post!.userId !=
                                      SupabaseService.currentUser?.id
                                  ? _offerHelp
                                  : null,
                            ),
                            // P5: Verstärken — nicht beim eigenen Post.
                            if (_post!.userId !=
                                SupabaseService.currentUser?.id) ...[
                              const SizedBox(height: 10),
                              _RepostButton(postId: widget.postId),
                            ],
                            const SizedBox(height: 24),
                            Text(
                              'posts.commentsCount'.tr(namedArgs: {'count': '${_comments.length}'}),
                              style: AppTypography.label(size: 10),
                            ),
                            const SizedBox(height: 8),
                            if (_comments.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  'posts.noCommentsYet'.tr(),
                                  style: AppTypography.caption(),
                                ),
                              )
                            else
                              ..._buildCommentTree(),
                          ],
                        ),
                        ),
                      ),
                      if (_replyToParentId != null)
                        Container(
                          margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.bronze.withValues(alpha: 0.10),
                            border: Border.all(
                                color: AppColors.bronze
                                    .withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(LucideIcons.cornerUpLeft,
                                  size: 12, color: AppColors.bronze),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'posts.replyTo'.tr(namedArgs: {
                                    'name': _replyToAuthor ?? '...'
                                  }),
                                  style: AppTypography.body(
                                      size: 11, color: AppColors.bronze),
                                ),
                              ),
                              IconButton(
                                tooltip: 'common.close'.tr(),
                                onPressed: () => setState(() {
                                  _replyToParentId = null;
                                  _replyToAuthor = null;
                                }),
                                icon: const Icon(LucideIcons.x,
                                    size: 12, color: AppColors.mute),
                              ),
                            ],
                          ),
                        ),
                      _CommentInput(
                        ctrl: _commentCtrl,
                        onSubmit: _addComment,
                      ),
                    ],
                  ),
        ),
      ),
    );
  }
}

// ── Hero ─────────────────────────────────────────────────────────────────
class _Hero extends StatefulWidget {
  const _Hero({required this.post, required this.scrollController});
  final Post post;
  final ScrollController scrollController;

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> {
  double _offset = 0;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (!widget.scrollController.hasClients) return;
    final o = widget.scrollController.offset;
    if (o > 300) return; // außerhalb des Hero-Bereichs → nicht mehr updaten
    setState(() => _offset = o);
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Phase 5.6: shared ImageCarousel mit Indicator-Dots + Lightbox-Tap
        // Hero-Tag matched die PostCard-Liste (smooth fly-in beim Open).
        // Cinema: Parallax (Bild scrollt 40 % langsamer) + Bottom-Scrim für
        // filmische Tiefe.
        if (post.allImageUrls.isNotEmpty) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 240,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Transform.translate(
                    offset: Offset(0, -_offset * 0.4),
                    child: Transform.scale(
                      // Leichter Overscale, damit beim Parallax-Verschieben
                      // keine Kante sichtbar wird.
                      scale: 1.12,
                      child: Hero(
                        tag: 'post-image-${post.id}',
                        child: ImageCarousel(
                          urls: post.allImageUrls,
                          height: 240,
                          borderRadius: 14,
                        ),
                      ),
                    ),
                  ),
                  // Bottom-Scrim (cinematischer Gradient-Verlauf).
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.center,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            AppColors.voidColor.withValues(alpha: 0.55),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
        _TypeBadge(type: post.type),
        const SizedBox(height: 10),
        Text(
          post.title,
          style: AppTypography.display(
            size: 26,
            height: 1.2,
            color: AppColors.ink,
          ),
        ),
        if (post.description != null && post.description!.isNotEmpty) ...[
          const SizedBox(height: 12),
          // F81 Lese-Modus: größerer Text + mehr Line-Height wenn aktiv.
          Consumer(
            builder: (_, r, __) {
              final reading = r.watch(readingModeProvider);
              return Text(
                post.description!,
                style: AppTypography.body(
                  size: reading ? 17 : 15,
                  color: AppColors.ink,
                  height: reading ? 1.85 : 1.6,
                ),
              );
            },
          ),
          // F83: Read-Time-Chip nur ab > 60 Worten (~30s)
          if (() {
            final words = post.description!.split(RegExp(r'\s+')).length;
            return words >= 60;
          }()) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(LucideIcons.clock,
                    size: 12, color: AppColors.mute),
                const SizedBox(width: 4),
                Text(
                  'posts.readTime'.tr(namedArgs: {
                    'min': (() {
                      final words =
                          post.description!.split(RegExp(r'\s+')).length;
                      // ~200 Worte/Min Lesegeschwindigkeit
                      final mins = (words / 200).ceil().clamp(1, 60);
                      return '$mins';
                    }())
                  }),
                  style: AppTypography.caption(),
                ),
              ],
            ),
          ],
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            const Icon(
              LucideIcons.calendar,
              size: 12,
              color: AppColors.mute,
            ),
            const SizedBox(width: 6),
            Text(
              DateFormat('dd.MM.yyyy HH:mm').format(post.createdAt),
              style: AppTypography.body(size: 12, color: AppColors.mute),
            ),
            const Spacer(),
            if (post.locationText != null) ...[
              const Icon(
                LucideIcons.mapPin,
                size: 12,
                color: AppColors.mute,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  post.locationText!,
                  style: AppTypography.body(size: 12, color: AppColors.mute),
                ),
              ),
            ],
          ],
        ),
        // Phase 7: Inline-Poll (rendert nichts wenn keine poll für post)
        if (post.description != null && post.description!.length > 40)
          _TranslateButton(text: post.description!),
        PostPollWidget(postId: post.id),
        if (post.userId == SupabaseService.currentUser?.id)
          _AddPollButton(postId: post.id),
        // Wikipedia-Box: Such-Term aus erstem Tag oder Titel-Keyword.
        if (post.tags.isNotEmpty || post.type == 'animal') ...[
          const SizedBox(height: 14),
          WikipediaBox(
            term: post.tags.isNotEmpty ? post.tags.first : post.title,
          ),
        ],
        // F41: Ähnliche Beiträge — gleicher Typ + Tag-Overlap.
        SimilarPostsCarousel(
          postId: post.id,
          type: post.type,
          tags: post.tags,
        ),
        if (post.tags.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: post.tags
                .map((t) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.elevated,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '#$t',
                        style: AppTypography.body(
                          size: 11,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _TranslateButton extends StatelessWidget {
  const _TranslateButton({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () async {
          final locale = context.locale.languageCode;
          final url = Uri.https('translate.google.com', '/', {
            'sl': 'auto',
            'tl': locale,
            'text': text,
            'op': 'translate',
          });
          await launchUrl(url, mode: LaunchMode.externalApplication);
        },
        icon: const Icon(LucideIcons.languages, size: 14),
        label: Text('posts.translate'.tr()),
        style: TextButton.styleFrom(foregroundColor: AppColors.bronze),
      ),
    );
  }
}

class _AddPollButton extends ConsumerWidget {
  const _AddPollButton({required this.postId});
  final String postId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () async {
          final ok = await PollCreateSheet.show(context, postId: postId);
          if (ok == true) {
            // PostPollWidget liest via _pollProvider(postId) — neu fetchen.
            // Wir wissen den genauen Provider-Key nicht, also komplett refresh.
            ref.invalidate(postPollProvider(postId));
          }
        },
        icon: const Icon(LucideIcons.barChart3, size: 14),
        label: Text('polls.add_to_post'.tr()),
        style: TextButton.styleFrom(foregroundColor: AppColors.bronze),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});
  final String type;

  @override
  Widget build(BuildContext context) {
    final cfg = _typeMap(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cfg.color.withValues(alpha: 0.18),
        border: Border.all(color: cfg.color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(cfg.emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 6),
          Text(
            cfg.label,
            style: AppTypography.label(
              size: 10,
              color: cfg.color,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  static ({String label, String emoji, Color color}) _typeMap(String t) {
    switch (t) {
      case 'crisis':
        return (label: 'posts.typeCrisis'.tr().replaceAll('🚨 ', ''), emoji: '🚨', color: AppColors.herzrot);
      case 'help_request':
        return (label: 'posts.typeHelpRequest'.tr().replaceAll('🆘 ', ''), emoji: '🆘', color: AppColors.herzrot);
      case 'help_offered':
        return (label: 'posts.typeHelpOffered'.tr().replaceAll('💚 ', ''), emoji: '💚', color: AppColors.leben);
      case 'animal':
        return (label: 'posts.typeAnimal'.tr().replaceAll('🐾 ', ''), emoji: '🐾', color: const Color(0xFFEC4899));
      case 'housing':
        return (label: 'posts.typeHousing'.tr().replaceAll('🏡 ', ''), emoji: '🏡', color: const Color(0xFF60A5FA));
      case 'supply':
        return (label: 'posts.typeSupply'.tr().replaceAll('🌾 ', ''), emoji: '🌾', color: const Color(0xFFFACC15));
      case 'mobility':
        return (label: 'posts.typeMobility'.tr().replaceAll('🚗 ', ''), emoji: '🚗', color: const Color(0xFF818CF8));
      case 'sharing':
        return (label: 'posts.typeSharing'.tr().replaceAll('🔄 ', ''), emoji: '🔄', color: AppColors.teal);
      case 'rescue':
        return (label: 'posts.typeRescue'.tr().replaceAll('🧡 ', ''), emoji: '🧡', color: const Color(0xFFFB923C));
      default:
        return (label: 'posts.detailTitle'.tr(), emoji: '📝', color: AppColors.amber);
    }
  }
}

// ── Actions ──────────────────────────────────────────────────────────────
class _ActionsBar extends StatelessWidget {
  const _ActionsBar({
    required this.postId,
    required this.myVote,
    required this.score,
    required this.saved,
    required this.onVoteUp,
    required this.onVoteDown,
    required this.onSave,
    required this.onShare,
    required this.onCopyLink,
    required this.onReport,
    required this.onHelp,
  });

  final String postId;
  final int? myVote;
  final int score;
  final bool saved;
  final VoidCallback onVoteUp;
  final VoidCallback onVoteDown;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final VoidCallback onCopyLink;
  final VoidCallback onReport;
  final VoidCallback? onHelp;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          if (onHelp != null) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onHelp,
                icon: const Icon(LucideIcons.helpingHand, size: 18),
                label: Text('posts.ihelp'.tr()),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              _ActionIcon(
                icon: LucideIcons.thumbsUp,
                label: '$score',
                active: myVote == 1,
                onTap: onVoteUp,
              ),
              _ActionIcon(
                icon: LucideIcons.thumbsDown,
                label: '',
                active: myVote == -1,
                onTap: onVoteDown,
                tooltip: 'posts.voteDownTooltip'.tr(),
              ),
              const SizedBox(width: 8),
              // F38: Emoji-Reactions neben dem Vote-Up/Down.
              PostReactionsButton(postId: postId),
              const SizedBox(width: 8),
              // F81: Lese-Modus toggle (Book / BookOpen).
              const ReadingModeToggle(),
              const Spacer(),
              _ActionIcon(
                icon: saved ? LucideIcons.bookmark : LucideIcons.bookmark,
                label: '',
                active: saved,
                onTap: onSave,
                tooltip: 'posts.saveTooltip'.tr(),
              ),
              _ActionIcon(
                icon: LucideIcons.share2,
                label: '',
                active: false,
                onTap: onShare,
                tooltip: 'common.share'.tr(),
              ),
              _ActionIcon(
                icon: LucideIcons.link,
                label: '',
                active: false,
                onTap: onCopyLink,
                tooltip: 'events.shareLink'.tr(),
              ),
              _ActionIcon(
                icon: LucideIcons.flag,
                label: '',
                active: false,
                onTap: onReport,
                tooltip: 'profile.report'.tr(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  /// Pflicht bei label == '' (Icon-only): Screen-Reader-Label + Tooltip.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.amber : AppColors.inkSoft;
    final child = TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.0, end: active ? 1.1 : 1.0),
      duration: const Duration(milliseconds: 240),
      curve: Curves.elasticOut,
      builder: (_, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  label,
                  style: AppTypography.mono(size: 12, color: color),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (tooltip == null || tooltip!.isEmpty) return child;
    return Tooltip(
      message: tooltip!,
      child: Semantics(button: true, label: tooltip, child: child),
    );
  }
}

// ── Comments ─────────────────────────────────────────────────────────────
class _CommentTile extends StatelessWidget {
  const _CommentTile(
    this.json, {
    this.onReply,
    this.isOwn = false,
    this.onEdit,
    this.onDelete,
  });
  final Map<String, dynamic> json;
  final VoidCallback? onReply;
  final bool isOwn;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  Future<void> _showActionSheet(BuildContext context) async {
    if (!isOwn) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xF0121A28),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
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
            if (onEdit != null)
              ListTile(
                leading: const Icon(LucideIcons.edit3,
                    size: 18, color: AppColors.ink),
                title: Text('common.edit'.tr(),
                    style:
                        AppTypography.body(size: 14, color: AppColors.ink)),
                onTap: () {
                  Navigator.pop(ctx);
                  onEdit!();
                },
              ),
            if (onDelete != null)
              ListTile(
                leading: const Icon(LucideIcons.trash2,
                    size: 18, color: AppColors.herzrot),
                title: Text('common.delete'.tr(),
                    style: AppTypography.body(
                        size: 14, color: AppColors.herzrot)),
                onTap: () {
                  Navigator.pop(ctx);
                  onDelete!();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    final author = (profile?['display_name'] ??
        profile?['name'] ??
        'common.neighbour'.tr()) as String;
    final avatar = profile?['avatar_url'] as String?;
    final content = json['content'] as String? ?? '';
    final createdAt = DateTime.tryParse(json['created_at'] as String? ?? '')?.toUtc() ??
        DateTime.now();
    return GestureDetector(
      onLongPress: isOwn ? () => _showActionSheet(context) : null,
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.4),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (avatar != null)
            SizedAvatarImage(
              url: avatar,
              size: 28,
              fallbackInitial: author,
            )
          else
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.elevated,
              child: Text(
                author.substring(0, 1).toUpperCase(),
                style: AppTypography.body(
                  size: 12,
                  color: AppColors.amber,
                  weight: FontWeight.w700,
                ),
              ),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      author,
                      style: AppTypography.body(
                        size: 13,
                        color: AppColors.ink,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      DateFormat('dd.MM. HH:mm').format(createdAt),
                      style: AppTypography.body(
                        size: 11,
                        color: AppColors.mute,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: AppTypography.body(
                    size: 14,
                    color: AppColors.inkSoft,
                    height: 1.5,
                  ),
                ),
                if (onReply != null) ...[
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: onReply,
                    icon: const Icon(LucideIcons.cornerUpLeft, size: 12),
                    label: Text('posts.reply'.tr()),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.bronze,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: const Size(0, 24),
                      textStyle: AppTypography.label(size: 10),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _CommentInput extends StatelessWidget {
  const _CommentInput({required this.ctrl, required this.onSubmit});
  final TextEditingController ctrl;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: AppColors.deep,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: ctrl,
                style: AppTypography.body(size: 14, color: AppColors.ink),
                decoration: InputDecoration(
                  hintText: 'posts.replyHint'.tr(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'common.send'.tr(),
              onPressed: onSubmit,
              icon: const Icon(LucideIcons.send, color: AppColors.amber),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportSheet extends StatelessWidget {
  static List<({String value, String label})> _reasons() => [
        (value: 'Spam', label: 'posts.reasonSpam'.tr()),
        (value: 'Harassment', label: 'posts.reasonHarassment'.tr()),
        (value: 'False', label: 'posts.reasonFalse'.tr()),
        (value: 'Offensive', label: 'posts.reasonOffensive'.tr()),
        (value: 'Commercial', label: 'posts.reasonCommercial'.tr()),
        (value: 'Other', label: 'posts.reasonOther'.tr()),
      ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'posts.reportTitle'.tr(),
              style: AppTypography.display(size: 20, color: AppColors.ink),
            ),
            const SizedBox(height: 14),
            for (final r in _reasons())
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(r.label,
                    style: AppTypography.body(size: 14, color: AppColors.ink)),
                trailing: const Icon(LucideIcons.chevronRight,
                    size: 16, color: AppColors.mute),
                onTap: () => Navigator.of(context).pop(r.value),
              ),
          ],
        ),
      ),
    );
  }
}

class _NotFound extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.fileX, size: 32, color: AppColors.mute),
          const SizedBox(height: 10),
          Text(
            'posts.notFound'.tr(),
            style: AppTypography.body(color: AppColors.mute),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text('common.back'.tr()),
          ),
        ],
      ),
    );
  }
}

/// P6 Status-Lifecycle-Steuerung. Für alle sichtbar als Badge; der Autor
/// bekommt zusätzlich Buttons zum Umschalten (Offen ⇄ In Bearbeitung ⇄
/// Erledigt).
class _StatusControl extends StatelessWidget {
  const _StatusControl({
    required this.status,
    required this.canEdit,
    required this.onChange,
  });

  final String status;
  final bool canEdit;
  final ValueChanged<String> onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (status != 'active')
                PostStatusBadge(status: status)
              else
                Text('posts.statusActive'.tr(),
                    style: AppTypography.label(size: 10)),
            ],
          ),
          if (canEdit) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (status != 'active')
                  _StatusBtn(
                    icon: LucideIcons.rotateCcw,
                    label: 'posts.markActive'.tr(),
                    onTap: () => onChange('active'),
                  ),
                if (status != 'in_progress')
                  _StatusBtn(
                    icon: LucideIcons.loader,
                    label: 'posts.markInProgress'.tr(),
                    onTap: () => onChange('in_progress'),
                  ),
                if (status != 'resolved')
                  _StatusBtn(
                    icon: LucideIcons.checkCircle2,
                    label: 'posts.markResolved'.tr(),
                    onTap: () => onChange('resolved'),
                    accent: AppColors.leben,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBtn extends StatelessWidget {
  const _StatusBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent = AppColors.bronze,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14, color: accent),
      label: Text(label,
          style: AppTypography.label(size: 10, color: accent)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: accent.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}

/// P5: Verstärken-Button. Self-contained — lädt eigenen Zustand + Count,
/// toggelt optimistisch. Verstärkte Posts erscheinen im Feed der eigenen
/// Follower (get_reposted_feed-RPC).
class _RepostButton extends StatefulWidget {
  const _RepostButton({required this.postId});
  final String postId;

  @override
  State<_RepostButton> createState() => _RepostButtonState();
}

class _RepostButtonState extends State<_RepostButton> {
  bool? _did;
  int _count = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      PostsRepository.didRepost(widget.postId),
      PostsRepository.repostCount(widget.postId),
    ]);
    if (!mounted) return;
    setState(() {
      _did = results[0] as bool;
      _count = results[1] as int;
    });
  }

  Future<void> _toggle() async {
    if (_busy) return;
    setState(() => _busy = true);
    // Optimistisch.
    final prevDid = _did ?? false;
    final prevCount = _count;
    setState(() {
      _did = !prevDid;
      _count = prevCount + (prevDid ? -1 : 1);
    });
    Haptics.tap();
    final newState = await PostsRepository.toggleRepost(widget.postId);
    if (!mounted) return;
    setState(() {
      _did = newState;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final active = _did ?? false;
    final color = active ? AppColors.leben : AppColors.bronze;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _did == null ? null : _toggle,
        icon: Icon(
            active ? LucideIcons.checkCircle2 : LucideIcons.megaphone,
            size: 16,
            color: color),
        label: Text(
          _count > 0
              ? 'posts.boostedCount'
                  .tr(namedArgs: {'n': '$_count'})
              : (active
                  ? 'posts.boosted'.tr()
                  : 'posts.boost'.tr()),
          style: AppTypography.label(size: 11, color: color),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withValues(alpha: 0.5)),
          backgroundColor: active
              ? AppColors.leben.withValues(alpha: 0.08)
              : null,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}
