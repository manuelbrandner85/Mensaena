import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../models/skill_offer.dart';
import '../../../repositories/profiles_repository.dart';
import '../../../repositories/skills_repository.dart';
import '../../../widgets/effects/animated_entrance.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';
import '../../../widgets/shared/editorial_module_header.dart';
import '../../../widgets/shared/empty_state_widget.dart';
import '../../../widgets/shared/error_state_card.dart';
import '../../../widgets/shared/sized_avatar_image.dart';
import '../../../widgets/shared/skeleton_card.dart';

/// SKILL: mensaena-features
/// Skills-Liste aus skill_offers (eigenes Schema, kein post.type).
class SkillsScreen extends ConsumerStatefulWidget {
  const SkillsScreen({super.key});

  @override
  ConsumerState<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends ConsumerState<SkillsScreen> {
  Future<List<SkillOffer>>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<SkillOffer>> _load() => SkillsRepository.listActive();

  Future<void> _refresh() async {
    final fresh = _load();
    setState(() => _future = fresh);
    await fresh;
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'skills.screenTitle'.tr(),
      currentRoute: '/dashboard/skills',
      fab: FloatingActionButton.extended(
        backgroundColor: AppColors.amber,
        foregroundColor: AppColors.voidColor,
        onPressed: () => context.go('/dashboard/skills/create'),
        icon: const Icon(LucideIcons.plus),
        label: Text('skills.offerSkill'.tr()),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Editorial-Header in den Scroll verschoben → mehr Platz.
            Expanded(
              child: RefreshIndicator(
          color: AppColors.amber,
          backgroundColor: AppColors.surface,
          onRefresh: _refresh,
          child: FutureBuilder<List<SkillOffer>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const SkeletonList(count: 6, itemHeight: 84);
              }
              if (snap.hasError) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 40),
                    ErrorStateCard(onRetry: _refresh),
                  ],
                );
              }
              final list = snap.data ?? const <SkillOffer>[];
              if (list.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: EditorialModuleHeader(
                        metaIndex: '§ 12',
                        metaCategory: 'skills.screenTitle'.tr(),
                        title: 'modules.skillsHero.title'.tr(),
                        subtitle: 'modules.skillsHero.subtitle'.tr(),
                      ),
                    ),
                    const SizedBox(height: 40),
                    EmptyStateWidget(
                      icon: LucideIcons.wrench,
                      title: 'skills.empty'.tr(),
                      subtitle: 'skills.emptyHint'.tr(),
                    ),
                  ],
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                // i0 = Editorial-Header (aus dem fixen Kopf → mehr Platz).
                itemCount: list.length + 1,
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                      child: EditorialModuleHeader(
                        metaIndex: '§ 12',
                        metaCategory: 'skills.screenTitle'.tr(),
                        title: 'modules.skillsHero.title'.tr(),
                        subtitle: 'modules.skillsHero.subtitle'.tr(),
                      ),
                    );
                  }
                  return AnimatedEntrance(
                    index: i,
                    child: _SkillTile(skill: list[i - 1]),
                  );
                },
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

class _SkillTile extends ConsumerWidget {
  const _SkillTile({required this.skill});
  final SkillOffer skill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providerProfile = ref.watch(profileByIdProvider(skill.userId));
    final p = providerProfile.asData?.value;
    final providerName =
        p?.displayName ?? p?.name ?? p?.username ?? 'skills.providerFallback'.tr();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (skill.skillCategory != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.amber.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    skill.skillCategory!,
                    style: AppTypography.label(size: 9),
                  ),
                ),
              if (skill.level != null) ...[
                const SizedBox(width: 6),
                Text(skill.level!, style: AppTypography.label(size: 9)),
              ],
              const Spacer(),
              if (skill.isFree == true)
                Text('skills.free'.tr(),
                    style: AppTypography.label(
                      size: 9,
                      color: AppColors.lebenSoft,
                    ))
              else if (skill.hourlyRate != null)
                Text(
                  '${skill.hourlyRate!.toStringAsFixed(0)} €/h',
                  style: AppTypography.mono(
                    size: 13,
                    color: AppColors.amber,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            skill.title,
            style: AppTypography.body(
              size: 14,
              color: AppColors.ink,
              weight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            skill.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.body(
              size: 13,
              color: AppColors.inkSoft,
              height: 1.45,
            ),
          ),
          if (skill.locationAddress != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(LucideIcons.mapPin,
                    size: 11, color: AppColors.mute),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(skill.locationAddress!,
                      style: AppTypography.caption()),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.line),
          const SizedBox(height: 10),
          Row(
            children: [
              GestureDetector(
                onTap: () => context.push('/dashboard/profile/${skill.userId}'),
                child: SizedAvatarImage(
                  url: p?.avatarUrl,
                  size: 28,
                  fallbackInitial:
                      providerName.isNotEmpty ? providerName[0] : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () =>
                      context.push('/dashboard/profile/${skill.userId}'),
                  child: Text(
                    providerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body(
                      size: 12,
                      color: AppColors.ink,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () =>
                    context.push('/dashboard/profile/${skill.userId}'),
                icon: const Icon(LucideIcons.messageCircle, size: 14),
                label: Text('skills.contactProvider'.tr()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.amber,
                  side: const BorderSide(color: AppColors.amber),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: AppTypography.label(size: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
