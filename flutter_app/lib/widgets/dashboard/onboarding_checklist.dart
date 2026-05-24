/// SKILL: mensaena-features
/// OnboardingChecklist — progressive Disclosure von Setup-Steps.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../models/post.dart';
import '../../models/profile.dart';

class OnboardingChecklist extends StatelessWidget {
  const OnboardingChecklist({
    super.key,
    required this.profile,
    required this.posts,
  });
  final Profile? profile;
  final List<Post> posts;

  @override
  Widget build(BuildContext context) {
    final hasAvatar = (profile?.avatarUrl ?? '').isNotEmpty;
    final hasBio = (profile?.bio ?? '').isNotEmpty;
    final hasLocation = (profile?.location ?? '').isNotEmpty;
    final hasPost = posts.any((p) => p.userId == profile?.id);
    final steps = [
      ('Avatar hochgeladen', hasAvatar, '/dashboard/profile'),
      ('Bio ausgefüllt', hasBio, '/dashboard/settings'),
      ('Standort gesetzt', hasLocation, '/dashboard/settings'),
      ('Erster Beitrag', hasPost, '/dashboard/create'),
    ];
    final done = steps.where((s) => s.$2).length;
    if (done == steps.length) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.amber.withValues(alpha: 0.12),
            AppColors.tealSoft.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.checkCircle,
                  color: AppColors.amber, size: 14),
              const SizedBox(width: 6),
              Text(
                  'home.onboardingStart'.tr(namedArgs: {
                    'done': '$done',
                    'total': '${steps.length}',
                  }),
                  style: AppTypography.label(
                      size: 10, color: AppColors.amber)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: done / steps.length,
              minHeight: 4,
              backgroundColor: AppColors.elevated,
              valueColor: const AlwaysStoppedAnimation(AppColors.amber),
            ),
          ),
          const SizedBox(height: 10),
          for (final s in steps)
            InkWell(
              onTap: s.$2 ? null : () => context.go(s.$3),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                child: Row(
                  children: [
                    Icon(
                      s.$2
                          ? LucideIcons.checkCircle2
                          : LucideIcons.circle,
                      size: 14,
                      color: s.$2 ? AppColors.lebenSoft : AppColors.mute,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.$1,
                        style: AppTypography.body(
                          size: 13,
                          color: s.$2 ? AppColors.mute : AppColors.ink,
                          weight: s.$2
                              ? FontWeight.w400
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                    if (!s.$2)
                      const Icon(LucideIcons.chevronRight,
                          size: 14, color: AppColors.amber),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
