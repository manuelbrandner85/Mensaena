/// SKILL: mensaena-features (P10) — Become-Mentor CTA.
/// Zeigt unauffällige Karte wenn User Skills hat aber is_mentor=false.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/supabase_service.dart';
import '../effects/glass_card.dart';

final _myMentorEligibilityProvider =
    FutureProvider.autoDispose<bool>((ref) async {
  final uid = SupabaseService.currentUser?.id;
  if (uid == null) return false;
  try {
    final row = await sb
        .from('profiles')
        .select('is_mentor, skills, offer_tags')
        .eq('id', uid)
        .maybeSingle();
    if (row == null) return false;
    final isMentor = row['is_mentor'] as bool? ?? false;
    if (isMentor) return false;
    final skillCount =
        ((row['skills'] as List?)?.length ?? 0) +
            ((row['offer_tags'] as List?)?.length ?? 0);
    return skillCount >= 3;
  } catch (_) {
    return false;
  }
});

class BecomeMentorCta extends ConsumerWidget {
  const BecomeMentorCta({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(_myMentorEligibilityProvider).maybeWhen(
          data: (eligible) {
            if (!eligible) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: GlassCard(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.amber.withValues(alpha: 0.18),
                      border: Border.all(
                          color: AppColors.amber, width: 1.5),
                    ),
                    child: const Icon(LucideIcons.lightbulb,
                        size: 20, color: AppColors.amber),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('mentorship.become_title'.tr(),
                            style: AppTypography.body(
                                size: 14,
                                color: AppColors.ink,
                                weight: FontWeight.w700)),
                        Text('mentorship.become_body'.tr(),
                            style: AppTypography.body(
                                size: 12,
                                color: AppColors.inkSoft,
                                height: 1.4)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () =>
                        context.push('/dashboard/profile/edit'),
                    icon: const Icon(LucideIcons.arrowRight,
                        size: 18, color: AppColors.bronze),
                  ),
                ]),
              ),
            );
          },
          orElse: () => const SizedBox.shrink(),
        );
  }
}
