import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../models/post.dart';
import '../../repositories/posts_repository.dart';
import '../../widgets/layouts/dashboard_scaffold.dart';
import '../../widgets/shared/post_card.dart';

/// SKILL: mensaena-features
/// Gespeicherte Posts — Bookmark-Liste aus saved_posts.
class ProfileSavedScreen extends ConsumerStatefulWidget {
  const ProfileSavedScreen({super.key});

  @override
  ConsumerState<ProfileSavedScreen> createState() =>
      _ProfileSavedScreenState();
}

class _ProfileSavedScreenState extends ConsumerState<ProfileSavedScreen> {
  Future<List<Post>>? _future;

  @override
  void initState() {
    super.initState();
    _future = PostsRepository.listSaved();
  }

  Future<void> _refresh() async {
    final f = PostsRepository.listSaved();
    setState(() => _future = f);
    await f;
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'Gespeichert',
      currentRoute: '/dashboard/profile/saved',
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.bronze,
          backgroundColor: AppColors.surface,
          onRefresh: _refresh,
          child: FutureBuilder<List<Post>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.bronze),
                );
              }
              final list = snap.data ?? const <Post>[];
              if (list.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 120),
                    Center(
                      child: Column(
                        children: [
                          const Icon(LucideIcons.bookmark,
                              size: 36, color: AppColors.mute),
                          const SizedBox(height: 10),
                          Text('Noch nichts gespeichert.',
                              style: AppTypography.body(
                                  size: 14,
                                  color: AppColors.ink,
                                  weight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(
                              'Tippe das Lesezeichen auf einem Beitrag, um ihn hier zu sammeln.',
                              textAlign: TextAlign.center,
                              style: AppTypography.body(
                                  size: 12, color: AppColors.mute)),
                        ],
                      ),
                    ),
                  ],
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: list.length,
                itemBuilder: (context, i) => PostCard(post: list[i]),
              );
            },
          ),
        ),
      ),
    );
  }
}
