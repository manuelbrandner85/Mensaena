import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../models/post.dart';
import '../../../services/supabase_service.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';
import '../../../widgets/shared/post_card.dart';

/// SKILL: mensaena-features
/// Generischer Modul-Screen — filtert posts nach Type.
/// Pendant zur Web shared/ModulePage.tsx. Pro Modul werden Title, Emoji,
/// PostType (z.B. 'animal'/'housing'/...) konfiguriert. Create-FAB
/// navigiert zu /dashboard/create?type=<typ>.
class ModulePostsScreen extends ConsumerStatefulWidget {
  const ModulePostsScreen({
    required this.title,
    required this.emoji,
    required this.postType,
    required this.route,
    this.subtitle,
    super.key,
  });

  final String title;
  final String emoji;
  final String postType;
  final String route;
  final String? subtitle;

  @override
  ConsumerState<ModulePostsScreen> createState() => _ModulePostsScreenState();
}

class _ModulePostsScreenState extends ConsumerState<ModulePostsScreen> {
  Future<List<Post>>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Post>> _load() async {
    try {
      final rows = await sb
          .from('posts')
          .select()
          .eq('type', widget.postType)
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(50);
      return (rows as List)
          .whereType<Map<String, dynamic>>()
          .map(Post.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _refresh() async {
    final fresh = _load();
    setState(() => _future = fresh);
    await fresh;
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: widget.title,
      currentRoute: widget.route,
      fab: FloatingActionButton.extended(
        backgroundColor: AppColors.amber,
        foregroundColor: AppColors.voidColor,
        onPressed: () =>
            context.go('/dashboard/create?type=${widget.postType}'),
        icon: const Icon(LucideIcons.plus),
        label: const Text('Beitrag'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.amber,
          backgroundColor: AppColors.surface,
          onRefresh: _refresh,
          child: FutureBuilder<List<Post>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.amber),
                );
              }
              final list = snap.data ?? const <Post>[];
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.amber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(widget.emoji,
                            style: const TextStyle(fontSize: 22)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.title,
                                style: AppTypography.display(
                                  size: 22,
                                  color: AppColors.ink,
                                )),
                            if (widget.subtitle != null)
                              Text(
                                widget.subtitle!,
                                style: AppTypography.caption(),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (list.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.4),
                        border: Border.all(color: AppColors.line),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          const Icon(LucideIcons.inbox,
                              size: 28, color: AppColors.mute),
                          const SizedBox(height: 10),
                          Text(
                            'Noch keine ${widget.title}-Beiträge.',
                            textAlign: TextAlign.center,
                            style: AppTypography.body(
                              size: 13,
                              color: AppColors.inkSoft,
                              height: 1.55,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Sei der/die Erste:r — tippe den Plus-Button.',
                            textAlign: TextAlign.center,
                            style: AppTypography.caption(),
                          ),
                        ],
                      ),
                    )
                  else
                    ...list.map((p) => PostCard(post: p)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
