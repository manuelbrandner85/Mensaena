/// SKILL: mensaena-features + mensaena-design
/// Release-Notes-Sheet (F48): zeigt die letzten 8 App-Releases mit
/// Changelog-Entries. Aufrufbar von Settings → Account-Tab.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../models/app_release.dart';
import '../../repositories/app_releases_repository.dart';
import '../effects/glass_card.dart';

final _recentReleasesProvider =
    FutureProvider.autoDispose<List<AppRelease>>((ref) async {
  return AppReleasesRepository.recent();
});

class ReleaseNotesSheet extends ConsumerWidget {
  const ReleaseNotesSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ReleaseNotesSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_recentReleasesProvider);
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Row(
                  children: [
                    const Icon(LucideIcons.sparkles,
                        size: 20, color: AppColors.amber),
                    const SizedBox(width: 8),
                    Text('releaseNotes.title'.tr(),
                        style: AppTypography.display(
                            size: 20, color: AppColors.ink)),
                  ],
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Text('releaseNotes.subtitle'.tr(),
                    style: AppTypography.caption()),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: async.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.bronze),
                  ),
                  error: (_, __) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text('releaseNotes.error'.tr(),
                          style: AppTypography.caption(),
                          textAlign: TextAlign.center),
                    ),
                  ),
                  data: (releases) {
                    if (releases.isEmpty) {
                      return Center(
                        child: Text('releaseNotes.empty'.tr(),
                            style: AppTypography.caption()),
                      );
                    }
                    return ListView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      itemCount: releases.length,
                      itemBuilder: (_, i) => _ReleaseCard(release: releases[i]),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ReleaseCard extends StatelessWidget {
  const _ReleaseCard({required this.release});
  final AppRelease release;

  @override
  Widget build(BuildContext context) {
    final entries = (release.changelog['entries'] as List?) ?? const [];
    final isPatch = release.changelog['is_patch'] == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.bronze.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.bronze.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    'v${release.version}',
                    style: AppTypography.body(
                      size: 11,
                      color: AppColors.bronze,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                if (release.mandatory)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.herzrotWarm.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('releaseNotes.mandatory'.tr(),
                        style: AppTypography.body(
                            size: 9,
                            color: AppColors.herzrotWarm,
                            weight: FontWeight.w700)),
                  ),
                if (isPatch) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.tealSoft.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('releaseNotes.patch'.tr(),
                        style: AppTypography.body(
                            size: 9,
                            color: AppColors.tealSoft,
                            weight: FontWeight.w700)),
                  ),
                ],
                const Spacer(),
                Text('#${release.buildNumber}',
                    style: AppTypography.caption()),
              ],
            ),
            const SizedBox(height: 8),
            if (entries.isEmpty)
              Text('releaseNotes.noEntries'.tr(),
                  style: AppTypography.body(
                      size: 12,
                      color: AppColors.mute,
                      height: 1.4))
            else
              ...entries.whereType<Map<String, dynamic>>().map((e) {
                final type = e['type'] as String? ?? 'feature';
                final title = e['title'] as String? ?? '';
                final desc = e['description'] as String? ?? '';
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_typeEmoji(type),
                          style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: AppTypography.body(
                                    size: 13,
                                    color: AppColors.ink,
                                    weight: FontWeight.w600)),
                            if (desc.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(desc,
                                    style: AppTypography.body(
                                      size: 12,
                                      color: AppColors.inkSoft,
                                      height: 1.4,
                                    )),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  String _typeEmoji(String type) {
    switch (type) {
      case 'fix':
        return '🛠';
      case 'feature':
        return '✨';
      case 'breaking':
        return '⚠️';
      case 'security':
        return '🔒';
      default:
        return '•';
    }
  }
}
