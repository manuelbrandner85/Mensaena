/// SKILL: mensaena-features (F59 Stories)
/// Horizontale Stories-Liste oben im Feed mit Ring-Avataren + (+)-Button
/// fuer eigene Story.
library;

import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../models/mega_models.dart';
import '../../providers/mega_providers.dart';
import '../../repositories/mega_repositories.dart';
import '../../services/haptics.dart';
import '../../services/supabase_service.dart';
import 'story_viewer.dart';

class StoriesRing extends ConsumerWidget {
  const StoriesRing({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(activeStoriesProvider);
    return SizedBox(
      height: 92,
      child: async.when(
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
        data: (stories) {
          // Gruppiere nach userId — pro User nur ein Eintrag mit allen Stories.
          final byUser = <String, List<Story>>{};
          for (final s in stories) {
            byUser.putIfAbsent(s.userId, () => []).add(s);
          }
          final entries = byUser.entries.toList();
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: entries.length + 1, // +1 fuer Add-Button
            itemBuilder: (_, i) {
              if (i == 0) return _AddStoryBtn(onUploaded: () => ref.invalidate(activeStoriesProvider));
              final entry = entries[i - 1];
              final firstStory = entry.value.first;
              return _StoryAvatar(
                story: firstStory,
                allUserStories: entry.value,
                onTap: () async {
                  Haptics.tap();
                  await StoryViewer.show(
                    context,
                    stories: entry.value,
                  );
                  ref.invalidate(activeStoriesProvider);
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _AddStoryBtn extends StatelessWidget {
  const _AddStoryBtn({required this.onUploaded});
  final VoidCallback onUploaded;

  Future<void> _pickAndUpload(BuildContext context) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return;
    final picker = ImagePicker();
    final pick = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (pick == null) return;
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('stories.uploading'.tr()),
      duration: const Duration(seconds: 2),
    ));
    try {
      final file = File(pick.path);
      final ext = pick.path.split('.').last;
      final path =
          'story/$uid/${DateTime.now().millisecondsSinceEpoch}.$ext';
      await sb.storage.from('post-images').upload(path, file);
      final url = sb.storage.from('post-images').getPublicUrl(path);
      final ok = await StoriesRepository.create(mediaUrl: url);
      if (ok) onUploaded();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('stories.upload_failed'.tr())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkResponse(
        onTap: () => _pickAndUpload(context),
        radius: 36,
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.elevated,
                border: Border.all(
                    color: AppColors.bronze.withValues(alpha: 0.5),
                    width: 2),
              ),
              child: const Icon(LucideIcons.plus,
                  size: 28, color: AppColors.bronze),
            ),
            const SizedBox(height: 4),
            Text('stories.add'.tr(),
                style: AppTypography.caption()),
          ],
        ),
      ),
    );
  }
}

class _StoryAvatar extends StatelessWidget {
  const _StoryAvatar({
    required this.story,
    required this.allUserStories,
    required this.onTap,
  });
  final Story story;
  final List<Story> allUserStories;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.bronze,
                    AppColors.amber,
                    AppColors.herzrotWarm,
                  ],
                ),
              ),
              padding: const EdgeInsets.all(3),
              child: CircleAvatar(
                backgroundColor: AppColors.voidColor,
                backgroundImage: story.authorAvatar != null
                    ? CachedNetworkImageProvider(story.authorAvatar!)
                    : null,
                child: story.authorAvatar == null
                    ? Text(
                        (story.authorName ?? '?')
                            .substring(0, 1)
                            .toUpperCase(),
                        style: AppTypography.display(
                            size: 18, color: AppColors.bronze))
                    : null,
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 64,
              child: Text(
                story.authorName ?? '?',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTypography.body(
                    size: 10, color: AppColors.inkSoft),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
