import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../models/skill_offer.dart';
import '../../../repositories/skills_repository.dart';
import '../../../widgets/effects/animated_entrance.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';
import '../../../widgets/shared/editorial_module_header.dart';
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: EditorialModuleHeader(
                metaIndex: '§ 12',
                metaCategory: 'skills.screenTitle'.tr(),
                title: 'modules.skillsHero.title'.tr(),
                subtitle: 'modules.skillsHero.subtitle'.tr(),
              ),
            ),
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
              final list = snap.data ?? const <SkillOffer>[];
              if (list.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 120),
                    Center(
                      child: Column(
                        children: [
                          const Icon(LucideIcons.wrench,
                              size: 32, color: AppColors.mute),
                          const SizedBox(height: 10),
                          Text(
                            'skills.empty'.tr(),
                            style: AppTypography.body(
                              size: 14,
                              color: AppColors.mute,
                            ),
                          ),
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
                  child: _SkillTile(skill: list[i]),
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

class _SkillTile extends StatelessWidget {
  const _SkillTile({required this.skill});
  final SkillOffer skill;

  @override
  Widget build(BuildContext context) {
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
        ],
      ),
    );
  }
}
