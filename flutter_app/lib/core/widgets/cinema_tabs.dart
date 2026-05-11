import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/typography.dart';

/// Cinema-Tabs: amber-indicator, mute Inactive, kein TabBar-Background.
class CinemaTabs extends StatelessWidget {
  final TabController controller;
  final List<String> labels;

  const CinemaTabs({super.key, required this.controller, required this.labels});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: MnColors.line)),
      ),
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: MnColors.amber,
        unselectedLabelColor: MnColors.mute,
        labelStyle: MnTypography.body(size: 14, weight: FontWeight.w600, color: MnColors.amber),
        unselectedLabelStyle: MnTypography.body(size: 14, weight: FontWeight.w500),
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(color: MnColors.amber, width: 2),
        ),
        dividerColor: Colors.transparent,
        tabs: labels.map((l) => Tab(text: l)).toList(),
      ),
    );
  }
}
