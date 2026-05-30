import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../models/post.dart';
import '../../repositories/posts_repository.dart';
import '../../widgets/layouts/dashboard_scaffold.dart';
import '../../widgets/posts/save_collection_picker.dart';
import '../../widgets/effects/animated_entrance.dart';
import '../../widgets/shared/post_card.dart';

/// SKILL: mensaena-features
/// Gespeicherte Posts — Bookmark-Liste aus saved_posts.
/// Mit Collection-Filter-Chips (P7).
class ProfileSavedScreen extends ConsumerStatefulWidget {
  const ProfileSavedScreen({super.key});

  @override
  ConsumerState<ProfileSavedScreen> createState() =>
      _ProfileSavedScreenState();
}

class _ProfileSavedScreenState extends ConsumerState<ProfileSavedScreen> {
  Future<List<Post>>? _future;
  String? _collectionId; // null = alle

  @override
  void initState() {
    super.initState();
    _future = PostsRepository.listSaved();
  }

  Future<void> _refresh() async {
    final f = PostsRepository.listSaved(collectionId: _collectionId);
    setState(() => _future = f);
    await f;
  }

  void _setCollection(String? id) {
    setState(() {
      _collectionId = id;
      _future = PostsRepository.listSaved(collectionId: id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final collections = ref.watch(saveCollectionsProvider);
    return DashboardScaffold(
      title: 'profile.savedTitle'.tr(),
      currentRoute: '/dashboard/profile/saved',
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 44,
              child: collections.maybeWhen(
                data: (list) => ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 6),
                      child: ChoiceChip(
                        selected: _collectionId == null,
                        label: Text('collections.default'.tr()),
                        onSelected: (_) => _setCollection(null),
                      ),
                    ),
                    for (final c in list)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 6),
                        child: ChoiceChip(
                          selected: _collectionId == c['id'],
                          label: Text(
                              '${c['emoji'] ?? '📁'} ${c['name']}'),
                          onSelected: (_) =>
                              _setCollection(c['id'] as String),
                        ),
                      ),
                  ],
                ),
                orElse: () => const SizedBox.shrink(),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.bronze,
                backgroundColor: AppColors.surface,
                onRefresh: _refresh,
                child: FutureBuilder<List<Post>>(
                  future: _future,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.bronze),
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
                                Text('profile.nothingSaved'.tr(),
                                    style: AppTypography.body(
                                        size: 14,
                                        color: AppColors.ink,
                                        weight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text('profile.savedHint'.tr(),
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
                      itemBuilder: (context, i) => AnimatedEntrance(
                        index: i,
                        child: PostCard(post: list[i]),
                      ),
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
