import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../theme/colors.dart';

class TrustStars extends StatelessWidget {
  final double rating; // 0..5
  final double size;
  final int totalRatings;

  const TrustStars({
    super.key,
    required this.rating,
    this.size = 16,
    this.totalRatings = 0,
  });

  @override
  Widget build(BuildContext context) {
    final r = rating.clamp(0.0, 5.0);
    return Semantics(
      label: 'Bewertung: ${r.toStringAsFixed(1)} von 5 Sternen${totalRatings > 0 ? ", $totalRatings Bewertungen" : ""}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (i) {
          final filled = i + 1 <= r;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Icon(
              filled ? LucideIcons.star : LucideIcons.star,
              size: size,
              color: filled ? MnColors.trust : MnColors.ghost,
              shadows: filled
                  ? [
                      Shadow(
                        color: MnColors.trust.withValues(alpha: 0.5),
                        blurRadius: 6,
                      ),
                    ]
                  : null,
            ),
          );
        }),
      ),
    );
  }
}
