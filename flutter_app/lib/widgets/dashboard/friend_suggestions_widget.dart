/// SKILL: mensaena-features (Phase 6 ZUSATZ-4D)
/// "Personen die du kennen könntest" — horizontale Scroll-Karten.
/// Region-basierte Vorschläge ohne bestehende Friendship/Block-Beziehung.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../repositories/friendships_repository.dart';
import '../profile/friend_request_button.dart';
import '../shared/sized_avatar_image.dart';

final _friendSuggestionsProvider = FutureProvider.autoDispose<
    List<Map<String, dynamic>>>((ref) async {
  return FriendshipsRepository.suggestions();
});

class FriendSuggestionsWidget extends ConsumerWidget {
  const FriendSuggestionsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_friendSuggestionsProvider);
    return async.maybeWhen(
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(children: [
                  const Icon(LucideIcons.userPlus,
                      size: 13, color: AppColors.bronze),
                  const SizedBox(width: 6),
                  Text(
                    'friends.suggestionsTitle'.tr(),
                    style: AppTypography.label(size: 10),
                  ),
                ]),
              ),
              SizedBox(
                height: 175,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => _SuggestionTile(p: list[i]),
                ),
              ),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({required this.p});
  final Map<String, dynamic> p;

  @override
  Widget build(BuildContext context) {
    final id = p['id'] as String;
    final name = (p['display_name'] as String?) ??
        (p['name'] as String?) ??
        'common.neighbour'.tr();
    final avatar = p['avatar_url'] as String?;
    return InkWell(
      onTap: () => context.push('/dashboard/profile/$id'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 132,
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.5),
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedAvatarImage(
              url: avatar,
              size: 56,
              fallbackInitial: name,
            ),
            const SizedBox(height: 8),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTypography.body(
                  size: 12,
                  color: AppColors.ink,
                  weight: FontWeight.w700,
                  height: 1.2),
            ),
            const SizedBox(height: 4),
            Text(
              'friends.fromYourArea'.tr(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption(),
            ),
            const Spacer(),
            FriendRequestButton(userId: id),
          ],
        ),
      ),
    );
  }
}
