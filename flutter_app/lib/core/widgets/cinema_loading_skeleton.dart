import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/colors.dart';
import '../theme/dimensions.dart';

enum SkeletonVariant { card, text, avatar, list }

class CinemaLoadingSkeleton extends StatelessWidget {
  final SkeletonVariant variant;
  final int lines;

  const CinemaLoadingSkeleton({
    super.key,
    this.variant = SkeletonVariant.card,
    this.lines = 3,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: MnColors.surface,
      highlightColor: MnColors.elevated.withValues(alpha: 0.8),
      period: const Duration(milliseconds: 1400),
      child: _build(),
    );
  }

  Widget _build() {
    switch (variant) {
      case SkeletonVariant.avatar:
        return Container(
          width: MnDimensions.avatarMd,
          height: MnDimensions.avatarMd,
          decoration: const BoxDecoration(
            color: MnColors.surface,
            shape: BoxShape.circle,
          ),
        );
      case SkeletonVariant.text:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: List.generate(lines, (i) {
            final w = i == lines - 1 ? 0.6 : 1.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FractionallySizedBox(
                widthFactor: w,
                alignment: Alignment.centerLeft,
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: MnColors.surface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            );
          }),
        );
      case SkeletonVariant.list:
        return Column(
          children: List.generate(
            3,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _cardSkeleton(),
            ),
          ),
        );
      case SkeletonVariant.card:
        return _cardSkeleton();
    }
  }

  Widget _cardSkeleton() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MnColors.surface,
          borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
          border: Border.all(color: MnColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(radius: 20, backgroundColor: MnColors.elevated),
                const SizedBox(width: 12),
                Container(width: 120, height: 12, color: MnColors.elevated),
              ],
            ),
            const SizedBox(height: 16),
            Container(height: 12, color: MnColors.elevated),
            const SizedBox(height: 8),
            Container(width: 200, height: 12, color: MnColors.elevated),
          ],
        ),
      );
}
