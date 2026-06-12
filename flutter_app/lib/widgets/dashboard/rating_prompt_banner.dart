/// SKILL: mensaena-features
/// RatingPromptBanner — Erinnert User an offene Bewertungen abgeschlossener Hilfen.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../repositories/dashboard_widgets_repository.dart';

class RatingPromptBanner extends StatefulWidget {
  const RatingPromptBanner({super.key, required this.userId});
  final String userId;

  @override
  State<RatingPromptBanner> createState() => _RatingPromptBannerState();
}

class _RatingPromptBannerState extends State<RatingPromptBanner> {
  late Future<List<Map<String, dynamic>>> _future;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    try {
      return await DashboardWidgetsRepository.pendingRatings(widget.userId);
    } catch (_) {
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final list = snap.data ?? const <Map<String, dynamic>>[];
        if (list.isEmpty) return const SizedBox.shrink();
        final count = list.length;
        final first = list.first;
        final partnerName =
            (first['partner_name'] as String?) ?? 'deinen Nachbarn';
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.amber.withValues(alpha: 0.12),
            border:
                Border.all(color: AppColors.amber.withValues(alpha: 0.35)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.star,
                    color: AppColors.amber, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      count == 1
                          ? 'Du hast eine offene Bewertung'
                          : 'Du hast $count offene Bewertungen',
                      style: AppTypography.body(
                        size: 13,
                        color: AppColors.ink,
                        weight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Bewerte $partnerName für die Zusammenarbeit.',
                      style: AppTypography.body(
                          size: 12, color: AppColors.inkSoft),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 32,
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            context.go('/dashboard/interactions'),
                        icon: const Icon(LucideIcons.star, size: 14),
                        label: Text('home.rateNow'.tr()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.amber,
                          foregroundColor: AppColors.voidColor,
                          textStyle: AppTypography.body(
                              size: 12, weight: FontWeight.w600),
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'home.tooltipRemindLater'.tr(),
                icon: const Icon(LucideIcons.x,
                    size: 14, color: AppColors.mute),
                onPressed: () => setState(() => _dismissed = true),
              ),
            ],
          ),
        );
      },
    );
  }
}
