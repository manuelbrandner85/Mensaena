/// SKILL: mensaena-features (Phase 10 E6)
/// WeeklySummaryWidget — kombiniert WeeklyRecap (Meine Aktivität) +
/// WeeklyDigest (Community) in einem TabBar-Container. Spart 1 Slot.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../models/profile.dart';
import 'weekly_digest.dart';
import 'weekly_recap_widget.dart';

class WeeklySummaryWidget extends StatefulWidget {
  const WeeklySummaryWidget({required this.profile, super.key});
  final Profile profile;

  @override
  State<WeeklySummaryWidget> createState() => _WeeklySummaryWidgetState();
}

class _WeeklySummaryWidgetState extends State<WeeklySummaryWidget>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.4),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.elevated,
              borderRadius: BorderRadius.circular(999),
            ),
            child: TabBar(
              controller: _tab,
              indicator: BoxDecoration(
                color: AppColors.bronze.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                    color: AppColors.bronze.withValues(alpha: 0.5)),
              ),
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: AppColors.bronze,
              unselectedLabelColor: AppColors.inkSoft,
              labelStyle: AppTypography.body(
                  size: 11, weight: FontWeight.w700),
              unselectedLabelStyle: AppTypography.body(size: 11),
              tabs: [
                Tab(height: 30, text: 'dashboard.summary.mine'.tr()),
                Tab(height: 30, text: 'dashboard.summary.community'.tr()),
              ],
            ),
          ),
          SizedBox(
            height: 280,
            child: TabBarView(
              controller: _tab,
              children: [
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: WeeklyRecapWidget(),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: WeeklyDigest(profile: widget.profile),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
