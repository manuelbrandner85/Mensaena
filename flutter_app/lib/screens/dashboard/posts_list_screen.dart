import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../models/post.dart';
import '../../repositories/posts_repository.dart';
import '../../widgets/layouts/dashboard_scaffold.dart';
import '../../widgets/shared/post_card.dart';

/// SKILL: flutter-build-responsive-layout + mensaena-features
/// Posts-Feed mit Filter nach Typ.
class PostsListScreen extends ConsumerStatefulWidget {
  const PostsListScreen({super.key});

  @override
  ConsumerState<PostsListScreen> createState() => _PostsListScreenState();
}

class _PostsListScreenState extends ConsumerState<PostsListScreen> {
  static const List<({String value, String label, String emoji})> _filters = [
    (value: 'all', label: 'Alle', emoji: '📍'),
    (value: 'help_request', label: 'Hilfe gesucht', emoji: '🆘'),
    (value: 'help_offered', label: 'Hilfe', emoji: '💚'),
    (value: 'rescue', label: 'Retten', emoji: '🧡'),
    (value: 'animal', label: 'Tier', emoji: '🐾'),
    (value: 'housing', label: 'Wohnen', emoji: '🏡'),
    (value: 'supply', label: 'Versorgung', emoji: '🌾'),
    (value: 'mobility', label: 'Mobilität', emoji: '🚗'),
    (value: 'sharing', label: 'Teilen', emoji: '🔄'),
    (value: 'community', label: 'Community', emoji: '🗳️'),
    (value: 'crisis', label: 'Notfall', emoji: '🚨'),
  ];

  String _filter = 'all';
  Future<List<Post>>? _future;

  @override
  void initState() {
    super.initState();
    _future = PostsRepository.getNearby(limit: 50);
  }

  Future<void> _refresh() async {
    final fresh = PostsRepository.getNearby(limit: 50);
    setState(() => _future = fresh);
    await fresh;
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'Beiträge',
      currentRoute: '/dashboard/posts',
      fab: FloatingActionButton.extended(
        backgroundColor: AppColors.amber,
        foregroundColor: AppColors.voidColor,
        onPressed: () => context.go('/dashboard/create'),
        icon: const Icon(LucideIcons.plus),
        label: const Text('Posten'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 44,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                itemCount: _filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, i) {
                  final f = _filters[i];
                  final active = f.value == _filter;
                  return GestureDetector(
                    onTap: () => setState(() => _filter = f.value),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.amber.withValues(alpha: 0.18)
                            : AppColors.surface.withValues(alpha: 0.5),
                        border: Border.all(
                          color: active ? AppColors.amber : AppColors.line,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        children: [
                          Text(
                            f.emoji,
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            f.label,
                            style: AppTypography.label(
                              size: 10,
                              color:
                                  active ? AppColors.amber : AppColors.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.amber,
                backgroundColor: AppColors.surface,
                onRefresh: _refresh,
                child: FutureBuilder<List<Post>>(
                  future: _future,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: 6,
                        itemBuilder: (_, __) => Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          height: 110,
                          decoration: BoxDecoration(
                            color: AppColors.surface.withValues(alpha: 0.4),
                            border: Border.all(color: AppColors.line),
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      );
                    }
                    final all = snap.data ?? const <Post>[];
                    final filtered = _filter == 'all'
                        ? all
                        : all.where((p) => p.type == _filter).toList();
                    if (filtered.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 120),
                          Center(
                            child: Column(
                              children: [
                                const Icon(
                                  LucideIcons.inbox,
                                  size: 32,
                                  color: AppColors.mute,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Keine Beiträge in dieser Kategorie.',
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
                    return ListView.builder(
                      padding: const EdgeInsets.all(12),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) => PostCard(post: filtered[i]),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
