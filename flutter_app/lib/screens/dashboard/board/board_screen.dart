import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../models/board_post.dart';
import '../../../repositories/board_repository.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

/// SKILL: mensaena-features
/// Schwarzes Brett — Cinema-Sticky-Notes Grid in Cinema-Dark.
class BoardScreen extends ConsumerWidget {
  const BoardScreen({super.key});


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(boardPostsProvider);
    return DashboardScaffold(
      title: 'Schwarzes Brett',
      currentRoute: '/dashboard/board',
      fab: FloatingActionButton.extended(
        backgroundColor: AppColors.amber,
        foregroundColor: AppColors.voidColor,
        onPressed: () => context.go('/dashboard/board/create'),
        icon: const Icon(LucideIcons.stickyNote),
        label: const Text('Anpinnen'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.amber,
          backgroundColor: AppColors.surface,
          onRefresh: () async => ref.invalidate(boardPostsProvider),
          child: async.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.amber),
            ),
            error: (e, _) => Center(child: Text('$e', style: AppTypography.caption())),
            data: (list) {
              if (list.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 120),
                    Center(
                      child: Column(
                        children: [
                          const Icon(
                            LucideIcons.stickyNote,
                            size: 32,
                            color: AppColors.mute,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Pinnwand ist leer.',
                            style: AppTypography.body(
                              size: 14,
                              color: AppColors.mute,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }
              return GridView.builder(
                padding: const EdgeInsets.all(12),
                physics: const AlwaysScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.95,
                ),
                itemCount: list.length,
                itemBuilder: (context, i) => _Note(post: list[i]),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.post});
  final BoardPost post;

  static const Map<String, Color> _bgColors = {
    'yellow': Color(0xFFFEF08A),
    'green': Color(0xFFBBF7D0),
    'blue': Color(0xFFBFDBFE),
    'pink': Color(0xFFFBCFE8),
    'orange': Color(0xFFFED7AA),
    'purple': Color(0xFFE9D5FF),
  };

  @override
  Widget build(BuildContext context) {
    // Cinema-Dark: Pastel-Noten zu gedaempften Versionen umrechnen.
    final base = _bgColors[post.color] ?? const Color(0xFFFEF08A);
    return InkWell(
      onTap: () => context.go('/dashboard/board/${post.id}'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: base.withValues(alpha: 0.12),
          border: Border.all(color: base.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (post.pinned)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(LucideIcons.pin, size: 11, color: AppColors.amber),
                  ),
                Text(
                  post.category.toUpperCase(),
                  style: AppTypography.label(size: 8, color: base),
                ),
                const Spacer(),
                Text(
                  DateFormat('dd.MM.').format(post.createdAt),
                  style: AppTypography.caption(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Text(
                post.content,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body(
                  size: 13,
                  color: AppColors.ink,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (post.commentCount > 0) ...[
                  const Icon(LucideIcons.messageSquare,
                      size: 11, color: AppColors.inkSoft),
                  const SizedBox(width: 3),
                  Text('${post.commentCount}',
                      style: AppTypography.caption()),
                  const SizedBox(width: 10),
                ],
                if (post.pinCount > 0) ...[
                  const Icon(LucideIcons.pin,
                      size: 11, color: AppColors.amber),
                  const SizedBox(width: 3),
                  Text('${post.pinCount}',
                      style: AppTypography.caption()),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
