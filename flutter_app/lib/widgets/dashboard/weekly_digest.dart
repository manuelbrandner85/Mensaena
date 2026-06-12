/// SKILL: mensaena-features
/// WeeklyDigest — Aktivitaet der letzten 7 Tage.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../models/profile.dart';
import '../../repositories/dashboard_widgets_repository.dart';

class WeeklyDigest extends StatefulWidget {
  const WeeklyDigest({super.key, required this.profile});
  final Profile profile;

  @override
  State<WeeklyDigest> createState() => _WeeklyDigestState();
}

class _WeeklyDigestState extends State<WeeklyDigest> {
  late Future<_DigestData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DigestData> _load() async {
    try {
      final c =
          await DashboardWidgetsRepository.weeklyDigestCounts(widget.profile.id);
      return _DigestData(
        posts: c.posts,
        interactions: c.interactions,
        messages: c.messages,
      );
    } catch (_) {
      return const _DigestData(posts: 0, interactions: 0, messages: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DigestData>(
      future: _future,
      builder: (context, snap) {
        final d = snap.data ??
            const _DigestData(posts: 0, interactions: 0, messages: 0);
        if (d.posts + d.interactions + d.messages == 0) {
          return const SizedBox.shrink();
        }
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.bronze.withValues(alpha: 0.10),
            border: Border.all(
                color: AppColors.bronze.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.calendar,
                      color: AppColors.bronze, size: 14),
                  const SizedBox(width: 6),
                  Text('home.thisWeek'.tr(),
                      style: AppTypography.label(
                          size: 10, color: AppColors.bronzeSoft)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                      child: _digestStat('${d.posts}',
                          'Beiträge', LucideIcons.fileText)),
                  const SizedBox(width: 6),
                  Expanded(
                      child: _digestStat('${d.interactions}',
                          'Hilfen', LucideIcons.helpingHand)),
                  const SizedBox(width: 6),
                  Expanded(
                      child: _digestStat('${d.messages}',
                          'Nachrichten', LucideIcons.messageCircle)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _digestStat(String value, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 12, color: AppColors.bronzeSoft),
          const SizedBox(height: 4),
          Text(value,
              style: AppTypography.mono(size: 18, color: AppColors.ink)),
          Text(label,
              style: AppTypography.label(
                  size: 8, color: AppColors.bronzeSoft)),
        ],
      ),
    );
  }
}

class _DigestData {
  const _DigestData({
    required this.posts,
    required this.interactions,
    required this.messages,
  });
  final int posts;
  final int interactions;
  final int messages;
}
