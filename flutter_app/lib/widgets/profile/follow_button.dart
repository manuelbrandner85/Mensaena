/// SKILL: mensaena-features (F36 Follower-System)
/// Follow/Unfollow Button. Optimistic-Update bei Tap.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../providers/mega_providers.dart';
import '../../repositories/mega_repositories.dart';
import '../../services/haptics.dart';
import '../../services/supabase_service.dart';

class FollowButton extends ConsumerStatefulWidget {
  const FollowButton({required this.userId, super.key});
  final String userId;

  @override
  ConsumerState<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends ConsumerState<FollowButton> {
  bool _busy = false;

  bool get _isOwn => widget.userId == SupabaseService.currentUser?.id;

  @override
  Widget build(BuildContext context) {
    if (_isOwn) return const SizedBox.shrink();
    final async = ref.watch(isFollowingProvider(widget.userId));
    return async.when(
      loading: () => const SizedBox(
        height: 32,
        width: 110,
        child: Center(
          child: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.bronze),
          ),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (isFollowing) {
        return SizedBox(
          height: 32,
          child: FilledButton.icon(
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    Haptics.tap();
                    if (isFollowing) {
                      await FollowsRepository.unfollow(widget.userId);
                    } else {
                      await FollowsRepository.follow(widget.userId);
                    }
                    ref.invalidate(isFollowingProvider(widget.userId));
                    ref.invalidate(followCountsProvider(widget.userId));
                    if (mounted) setState(() => _busy = false);
                  },
            icon: Icon(
              isFollowing ? LucideIcons.userMinus : LucideIcons.userPlus,
              size: 14,
            ),
            label: Text(
              isFollowing ? 'profile.unfollow'.tr() : 'profile.follow'.tr(),
              style: AppTypography.body(
                size: 12,
                color: AppColors.voidColor,
                weight: FontWeight.w700,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor:
                  isFollowing ? AppColors.elevated : AppColors.bronze,
              foregroundColor:
                  isFollowing ? AppColors.ink : AppColors.voidColor,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        );
      },
    );
  }
}
