/// SKILL: mensaena-design (Web-Parität Dashboard „Profil vervollständigen")
/// Zeigt einen Fortschritts-Ring (%) plus die noch fehlenden Profil-Schritte
/// als antippbare Chips (→ Einstellungen). Blendet sich bei 100 % komplett aus,
/// damit fertige Profile keinen Nag sehen.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../repositories/profiles_repository.dart';

class ProfileCompletionCard extends ConsumerWidget {
  const ProfileCompletionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myProfileProvider);
    return async.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      data: (p) {
        if (p == null) return const SizedBox.shrink();
        // Aus dem Profil ableitbare Schritte (kein Extra-Query nötig).
        final items = <({String key, bool done})>[
          (key: 'avatar', done: (p.avatarUrl ?? '').trim().isNotEmpty),
          (
            key: 'name',
            done: ((p.displayName ?? p.nickname ?? '').trim().isNotEmpty)
          ),
          (key: 'bio', done: (p.bio ?? '').trim().isNotEmpty),
          (
            key: 'location',
            done: ((p.homeCity ?? p.location ?? '').trim().isNotEmpty) ||
                p.latitude != null
          ),
          (key: 'phone', done: (p.phone ?? '').trim().isNotEmpty),
        ];
        final total = items.length;
        final doneCount = items.where((i) => i.done).length;
        final pct = doneCount / total;
        // Alles erledigt → keine Karte (kein Nag).
        if (pct >= 1.0) return const SizedBox.shrink();
        final missing = items.where((i) => !i.done).toList();

        return Container(
          margin: const EdgeInsets.only(top: 4, bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.bronze.withValues(alpha: 0.16),
                AppColors.amber.withValues(alpha: 0.06),
              ],
            ),
            border: Border.all(color: AppColors.bronze.withValues(alpha: 0.30)),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 52,
                          height: 52,
                          child: CircularProgressIndicator(
                            value: pct,
                            strokeWidth: 5,
                            backgroundColor: AppColors.line,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.bronze),
                          ),
                        ),
                        Text('${(pct * 100).round()}%',
                            style: AppTypography.label(
                                size: 11, color: AppColors.ink)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('dashboard.profileCompletionTitle'.tr(),
                            style: AppTypography.display(
                                size: 15, color: AppColors.ink)),
                        const SizedBox(height: 2),
                        Text('dashboard.profileCompletionHint'.tr(),
                            style: AppTypography.caption()),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in missing)
                    InkWell(
                      onTap: () => context.go('/dashboard/settings'),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.surface.withValues(alpha: 0.6),
                          border: Border.all(color: AppColors.line),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(LucideIcons.plus,
                                size: 13, color: AppColors.bronze),
                            const SizedBox(width: 5),
                            Text('dashboard.profileItem.${m.key}'.tr(),
                                style: AppTypography.label(
                                    size: 11, color: AppColors.inkSoft)),
                          ],
                        ),
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
