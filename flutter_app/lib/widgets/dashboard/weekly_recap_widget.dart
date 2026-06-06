/// SKILL: mensaena-features + mensaena-design
/// Weekly-Recap-Widget (F40): eigener 7-Tage-Snapshot mit Delta zur Vorwoche.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../repositories/ai_features_repository.dart';
import '../../services/weekly_recap_service.dart';
import '../effects/bloom.dart';
import '../effects/glass_card.dart';

final _recapProvider = FutureProvider<WeeklyRecap>((ref) async {
  return WeeklyRecapService.compute();
});

// H) KI-generierte Community-Zusammenfassung (community_recaps, via Cron erzeugt).
final _aiRecapProvider =
    FutureProvider<({String? content, String? shareText})?>((ref) async {
  final row = await AiFeaturesRepository().latestRecap();
  if (row == null) return null;
  return (
    content: row['content']?.toString(),
    shareText: row['share_text']?.toString(),
  );
});

class WeeklyRecapWidget extends ConsumerWidget {
  const WeeklyRecapWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_recapProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (r) {
        if (r.totalThisWeek == 0 && r.totalLastWeek == 0) {
          return const SizedBox.shrink();
        }
        final delta = r.totalDeltaPct;
        final deltaColor = delta > 0
            ? AppColors.lebenSoft
            : (delta < 0 ? AppColors.herzrotWarm : AppColors.mute);
        final aiData = ref.watch(_aiRecapProvider).asData?.value;
        final aiRecap = aiData?.content;
        final shareText = aiData?.shareText;
        return GlassCard(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (aiRecap != null && aiRecap.trim().isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.auto_awesome,
                        size: 14, color: AppColors.bronze),
                    const SizedBox(width: 6),
                    Text('assistant.community_recap_title'.tr(),
                        style: AppTypography.label(
                            size: 10, color: AppColors.bronze)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(aiRecap,
                    style: AppTypography.body(
                        size: 13, color: AppColors.ink, height: 1.4)),
                // 2) Teilbarer Wochenrückblick — Veröffentlichen bleibt manuell.
                if (shareText != null && shareText.trim().isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => Share.share(shareText),
                      icon: const Icon(LucideIcons.share2,
                          size: 14, color: AppColors.bronze),
                      label: Text('recap.share_week'.tr(),
                          style: AppTypography.label(
                              size: 11, color: AppColors.bronze)),
                    ),
                  ),
                const SizedBox(height: 12),
                Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  const Bloom(
                    color: AppColors.teal,
                    intensity: 0.5,
                    radius: 12,
                    child: Icon(LucideIcons.trendingUp,
                        size: 20, color: AppColors.teal),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('recap.title'.tr(),
                        style: AppTypography.body(
                            size: 13,
                            color: AppColors.ink,
                            weight: FontWeight.w700)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: deltaColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: deltaColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      delta >= 0 ? '+$delta%' : '$delta%',
                      style: AppTypography.body(
                        size: 11,
                        color: deltaColor,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('recap.subtitle'.tr(),
                  style: AppTypography.caption()),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatBlock(
                      icon: LucideIcons.helpingHand,
                      value: r.helpsThisWeek,
                      prev: r.helpsLastWeek,
                      label: 'recap.helps'.tr(),
                    ),
                  ),
                  Expanded(
                    child: _StatBlock(
                      icon: LucideIcons.fileText,
                      value: r.postsThisWeek,
                      prev: r.postsLastWeek,
                      label: 'recap.posts'.tr(),
                    ),
                  ),
                  Expanded(
                    child: _StatBlock(
                      icon: LucideIcons.messageSquare,
                      value: r.commentsThisWeek,
                      prev: r.commentsLastWeek,
                      label: 'recap.comments'.tr(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({
    required this.icon,
    required this.value,
    required this.prev,
    required this.label,
  });
  final IconData icon;
  final int value;
  final int prev;
  final String label;

  @override
  Widget build(BuildContext context) {
    final diff = value - prev;
    final diffColor = diff > 0
        ? AppColors.lebenSoft
        : (diff < 0 ? AppColors.herzrotWarm : AppColors.mute);
    return Column(
      children: [
        Icon(icon, size: 16, color: AppColors.bronze),
        const SizedBox(height: 4),
        Text('$value',
            style: AppTypography.display(size: 22, color: AppColors.ink)),
        const SizedBox(height: 2),
        Text(label, style: AppTypography.caption()),
        if (diff != 0)
          Text(
            diff > 0 ? '+$diff' : '$diff',
            style: AppTypography.body(
              size: 10,
              color: diffColor,
              weight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}
