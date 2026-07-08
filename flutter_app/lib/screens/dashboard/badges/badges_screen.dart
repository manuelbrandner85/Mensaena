import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../widgets/badges/badge_detail_sheet.dart';
import '../../../widgets/effects/animated_entrance.dart';
import '../../../models/badge.dart';
import '../../../models/user_badge.dart';
import '../../../repositories/challenges_repository.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';
import '../../../widgets/shared/skeleton_card.dart';
import '../../../widgets/shared/app_snackbar.dart';
import '../../../widgets/shared/error_state_widget.dart';

/// SKILL: mensaena-features
/// Badges-Gallery — alle Badges der Plattform, eigene markiert.
class BadgesScreen extends ConsumerStatefulWidget {
  const BadgesScreen({super.key});

  @override
  ConsumerState<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends ConsumerState<BadgesScreen> {
  @override
  void initState() {
    super.initState();
    // Beim Öffnen alle erreichten Badges nachverleihen (z.B. retroaktiv für
    // bestehende Aktivität) und die Liste auffrischen, damit neu vergebene
    // Badges sofort erscheinen.
    WidgetsBinding.instance.addPostFrameCallback((_) => _awardCheck());
  }

  Future<void> _awardCheck() async {
    final newCount = await ChallengesRepository.checkAndAwardBadges();
    if (!mounted) return;
    if (newCount > 0) {
      ref.invalidate(myBadgesProvider);
      AppSnackBar.info(context, 'badges.newlyEarned'.tr(namedArgs: {'n': '$newCount'}));
    }
  }

  @override
  Widget build(BuildContext context) {
    final allAsync = ref.watch(allBadgesProvider);
    final mineAsync = ref.watch(myBadgesProvider);

    return DashboardScaffold(
      title: 'misc.badges'.tr(),
      currentRoute: '/dashboard/badges',
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.amber,
          backgroundColor: AppColors.surface,
          onRefresh: () async {
            await ChallengesRepository.checkAndAwardBadges();
            ref.invalidate(allBadgesProvider);
            ref.invalidate(myBadgesProvider);
            await ref.read(allBadgesProvider.future);
          },
          child: allAsync.when(
            loading: () => const SkeletonList(count: 5, itemHeight: 96),
            error: (_, __) => ErrorStateWidget(
              onRetry: () {
                ref.invalidate(allBadgesProvider);
                ref.invalidate(myBadgesProvider);
              },
            ),
            data: (badges) {
              if (badges.isEmpty) {
                return _empty('badges.empty'.tr());
              }
              final earnedIds = <String>{
                for (final ub in mineAsync.value ?? const <UserBadge>[])
                  ub.badgeId,
              };
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                // Max-Extent statt fixer Spaltenzahl: Phone bleibt 2-spaltig,
                // Tablets bekommen automatisch 3-4 Spalten (Phase 6).
                gridDelegate:
                    const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 200,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.95,
                ),
                itemCount: badges.length,
                itemBuilder: (context, i) {
                  final b = badges[i];
                  return AnimatedEntrance(
                    index: i,
                    child: _BadgeTile(
                      badge: b,
                      earned: earnedIds.contains(b.id),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _empty(String msg) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Center(
          child: Column(
            children: [
              const Icon(LucideIcons.award,
                  size: 32, color: AppColors.mute),
              const SizedBox(height: 10),
              Text(
                msg,
                style:
                    AppTypography.body(size: 14, color: AppColors.mute),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge, required this.earned});
  final BadgeModel badge;
  final bool earned;

  Color get _rarityColor {
    switch (badge.rarity.toLowerCase()) {
      case 'legendary':
        return AppColors.herzrot;
      case 'epic':
        return AppColors.amber;
      case 'rare':
        return AppColors.teal;
      default:
        return AppColors.mute;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _rarityColor;
    return GestureDetector(
      // G2: Neuer BadgeDetailSheet mit "Wie bekomme ich das?"-Erklärung.
      onTap: () => BadgeDetailSheet.show(context, badge, earned: earned),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: earned
              ? color.withValues(alpha: 0.10)
              : AppColors.surface.withValues(alpha: 0.5),
          border: Border.all(
            color: earned ? color.withValues(alpha: 0.6) : AppColors.line,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 54,
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: earned
                    ? color.withValues(alpha: 0.18)
                    : AppColors.elevated,
                shape: BoxShape.circle,
              ),
              child: Icon(
                earned ? LucideIcons.award : LucideIcons.lock,
                color: earned ? color : AppColors.mute,
                size: 26,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              badge.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTypography.body(
                size: 12,
                color: earned ? AppColors.ink : AppColors.inkSoft,
                weight: FontWeight.w700,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              badge.rarity.toUpperCase(),
              style: AppTypography.label(size: 8, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

