import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/atmosphere/cinema_scaffold.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/dimensions.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/cinema_appbar.dart';
import '../../core/widgets/cinema_avatar.dart';
import '../../core/widgets/cinema_empty_state.dart';
import '../../core/widgets/cinema_input.dart';
import '../../core/widgets/cinema_loading_skeleton.dart';
import '../../core/widgets/cinema_sheet.dart';
import '../../core/widgets/cinema_toast.dart';
import '../../core/widgets/glow_button.dart';
import '../../core/widgets/nachbarschaft_card.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/supabase/supabase_service.dart';

final _boardPostsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return supabase.client
      .from('board_posts')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false);
});

final _pinnedProvider = FutureProvider<Set<String>>((ref) async {
  final res = await supabase.client.from('board_pins').select('post_id');
  return {for (final r in res as List) r['post_id'] as String};
});

final _commentsProvider = StreamProvider.family<List<Map<String, dynamic>>, String>(
  (ref, postId) {
    return supabase.client
        .from('board_comments')
        .stream(primaryKey: ['id'])
        .eq('board_post_id', postId)
        .order('created_at');
  },
);

class BoardScreen extends ConsumerWidget {
  const BoardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posts = ref.watch(_boardPostsProvider);
    final pinned = ref.watch(_pinnedProvider).asData?.value ?? const <String>{};
    final profile = ref.watch(currentProfileProvider).asData?.value;
    final isAdmin = profile?['is_admin'] == true;

    return CinemaScaffold(
      appBar: const CinemaAppBar(title: 'SCHWARZES BRETT'),
      floatingActionButton: FloatingActionButton(
        backgroundColor: MnColors.amber,
        foregroundColor: MnColors.voidColor,
        onPressed: () => _showCreate(context, ref),
        child: const Icon(LucideIcons.plus),
      ),
      body: SafeArea(
        child: posts.when(
          loading: () => const CinemaLoadingSkeleton(variant: SkeletonVariant.list),
          error: (e, _) => CinemaEmptyState(
            icon: LucideIcons.alertCircle,
            title: 'Fehler',
            message: e.toString(),
          ),
          data: (list) {
            if (list.isEmpty) {
              return const CinemaEmptyState(
                icon: LucideIcons.fileText,
                title: 'Noch keine Aushaenge.',
                message: 'Sei die*der Erste am schwarzen Brett.',
              );
            }
            final sorted = [...list]..sort((a, b) {
              final aP = pinned.contains(a['id']);
              final bP = pinned.contains(b['id']);
              if (aP != bP) return bP ? 1 : -1;
              return 0;
            });
            return ListView.builder(
              itemCount: sorted.length,
              itemBuilder: (_, i) {
                final p = sorted[i];
                final isPinned = pinned.contains(p['id']);
                return GestureDetector(
                  onTap: () => _openDetail(context, ref, p, isAdmin),
                  child: Container(
                    decoration: isPinned
                        ? BoxDecoration(
                            color: MnColors.amber.withValues(alpha: 0.05),
                            border: Border.all(
                              color: MnColors.amber.withValues(alpha: 0.2),
                            ),
                            borderRadius:
                                BorderRadius.circular(MnDimensions.radiusCard),
                          )
                        : null,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    child: Stack(
                      children: [
                        NachbarschaftCard(
                          timeAgo: (p['created_at'] as String?) ?? '',
                          content: (p['content'] as String?) ?? '',
                          authorName: p['author_name'] as String?,
                        ),
                        if (isPinned)
                          const Positioned(
                            top: 16,
                            right: 28,
                            child: Icon(
                              LucideIcons.pin,
                              color: MnColors.amber,
                              size: 16,
                            ),
                          ),
                        if (isAdmin)
                          Positioned(
                            top: 12,
                            right: 64,
                            child: IconButton(
                              icon: Icon(
                                isPinned ? LucideIcons.pinOff : LucideIcons.pin,
                                size: 16,
                                color: isPinned ? MnColors.amber : MnColors.mute,
                              ),
                              tooltip:
                                  isPinned ? 'Anpinnen aufheben' : 'Anpinnen',
                              onPressed: () =>
                                  _togglePin(ref, context, p['id'] as String, isPinned),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showCreate(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    CinemaSheet.show<void>(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Neuer Aushang', style: MnTypography.display(size: 22)),
          const SizedBox(height: 16),
          CinemaInput(controller: titleCtrl, label: 'TITEL'),
          const SizedBox(height: 12),
          CinemaInput(
            controller: contentCtrl,
            label: 'INHALT',
            variant: CinemaInputVariant.multiline,
            maxLines: 5,
          ),
          const SizedBox(height: 16),
          GlowButton(
            label: 'Posten',
            variant: GlowVariant.primary,
            fullWidth: true,
            onPressed: () async {
              final user = ref.read(currentUserProvider);
              if (user == null) return;
              try {
                await supabase.client.from('board_posts').insert({
                  'user_id': user.id,
                  'title': titleCtrl.text.trim(),
                  'content': contentCtrl.text.trim(),
                });
                if (context.mounted) Navigator.of(context).pop();
              } catch (e) {
                if (context.mounted) {
                  CinemaToast.show(
                    context,
                    variant: ToastVariant.error,
                    message: 'Posten fehlgeschlagen: $e',
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _openDetail(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> post,
    bool isAdmin,
  ) {
    CinemaSheet.show<void>(
      context,
      initialSize: 0.75,
      child: _BoardDetail(post: post, isAdmin: isAdmin),
    );
  }

  Future<void> _togglePin(
    WidgetRef ref,
    BuildContext context,
    String postId,
    bool currentlyPinned,
  ) async {
    try {
      if (currentlyPinned) {
        await supabase.client
            .from('board_pins')
            .delete()
            .eq('post_id', postId);
      } else {
        await supabase.client.from('board_pins').insert({'post_id': postId});
      }
      ref.invalidate(_pinnedProvider);
    } catch (e) {
      if (context.mounted) {
        CinemaToast.show(
          context,
          variant: ToastVariant.error,
          message: 'Pin fehlgeschlagen: $e',
        );
      }
    }
  }
}

class _BoardDetail extends ConsumerStatefulWidget {
  final Map<String, dynamic> post;
  final bool isAdmin;
  const _BoardDetail({required this.post, required this.isAdmin});

  @override
  ConsumerState<_BoardDetail> createState() => _BoardDetailState();
}

class _BoardDetailState extends ConsumerState<_BoardDetail> {
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final user = ref.read(currentUserProvider);
    if (user == null || _comment.text.trim().isEmpty) return;
    try {
      await supabase.client.from('board_comments').insert({
        'board_post_id': widget.post['id'],
        'user_id': user.id,
        'content': _comment.text.trim(),
      });
      _comment.clear();
    } catch (e) {
      if (!mounted) return;
      CinemaToast.show(
        context,
        variant: ToastVariant.error,
        message: 'Kommentar fehlgeschlagen: $e',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final comments = ref.watch(_commentsProvider(widget.post['id'] as String));
    final title = (widget.post['title'] as String?) ?? '';
    final content = (widget.post['content'] as String?) ?? '';
    final author = (widget.post['author_name'] as String?) ?? 'Nachbar*in';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title.isNotEmpty) ...[
          Text(title, style: MnTypography.display(size: 22)),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            CinemaAvatar(displayName: author, size: AvatarSize.sm),
            const SizedBox(width: 8),
            Text(
              author,
              style: MnTypography.body(
                color: MnColors.mute,
                size: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(content, style: MnTypography.body(color: MnColors.inkSoft)),
        const SizedBox(height: 24),
        Text(
          'Kommentare',
          style: MnTypography.label(color: MnColors.mute),
        ),
        const SizedBox(height: 12),
        comments.when(
          loading: () =>
              const CinemaLoadingSkeleton(variant: SkeletonVariant.text),
          error: (e, _) => Text(
            'Fehler: $e',
            style: MnTypography.body(color: MnColors.herzrot, size: 13),
          ),
          data: (cs) {
            if (cs.isEmpty) {
              return Text(
                'Noch keine Kommentare.',
                style: MnTypography.body(color: MnColors.mute, size: 13),
              );
            }
            return Column(
              children: cs.map((c) {
                final cAuthor = (c['author_name'] as String?) ?? 'Nachbar*in';
                final cContent = (c['content'] as String?) ?? '';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CinemaAvatar(displayName: cAuthor, size: AvatarSize.sm),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cAuthor,
                              style: MnTypography.body(
                                color: MnColors.ink,
                                size: 13,
                                weight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              cContent,
                              style: MnTypography.body(
                                color: MnColors.inkSoft,
                                size: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: CinemaInput(
                controller: _comment,
                placeholder: 'Kommentar schreiben…',
              ),
            ),
            const SizedBox(width: 8),
            GlowButton(
              label: '',
              icon: LucideIcons.send,
              compact: true,
              onPressed: _send,
            ),
          ],
        ),
      ],
    );
  }
}
