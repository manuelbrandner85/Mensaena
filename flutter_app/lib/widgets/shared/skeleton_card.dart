import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../config/theme/app_colors.dart';

/// SKILL: mensaena-design
/// Skeleton-Loader Bones — 1:1 zu Web `animate-pulse bg-mn-elevated`.
/// Ersetzt CircularProgressIndicator bei List-Loading für besseres
/// "etwas-kommt-gleich"-Feeling.
///
/// Nutzung:
/// ```dart
/// if (loading) return SkeletonList(count: 5);
/// ```
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({
    this.height = 120,
    this.margin = const EdgeInsets.only(bottom: 10),
    super.key,
  });

  final double height;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.elevated,
      highlightColor: AppColors.raised,
      period: const Duration(milliseconds: 1400),
      child: Container(
        margin: margin,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.elevated,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}

/// Mehrere SkeletonCards untereinander — passt zur typischen Listen-Höhe.
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    this.count = 4,
    this.itemHeight = 120,
    this.padding = const EdgeInsets.all(12),
    super.key,
  });

  final int count;
  final double itemHeight;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: padding,
      physics: const AlwaysScrollableScrollPhysics(),
      children: List.generate(
        count,
        (_) => SkeletonCard(height: itemHeight),
      ),
    );
  }
}

/// Skeleton fuer Chat-Bubbles — alternierend links/rechts.
class SkeletonChat extends StatelessWidget {
  const SkeletonChat({this.count = 6, super.key});
  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: count,
      itemBuilder: (context, i) {
        final mine = i % 2 == 1;
        final width = 120.0 + (i * 23) % 140;
        return Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: Shimmer.fromColors(
            baseColor: AppColors.elevated,
            highlightColor: AppColors.raised,
            period: const Duration(milliseconds: 1400),
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              width: width,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.elevated,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(mine ? 14 : 4),
                  bottomRight: Radius.circular(mine ? 4 : 14),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
