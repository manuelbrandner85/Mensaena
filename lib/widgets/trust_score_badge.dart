import 'package:flutter/material.dart';
import 'package:mensaena/config/theme.dart';

enum TrustBadgeSize { small, medium, large }

class TrustScoreBadge extends StatelessWidget {
  final double score;
  final TrustBadgeSize size;

  const TrustScoreBadge({
    super.key,
    required this.score,
    this.size = TrustBadgeSize.medium,
  });

  int get _level {
    if (score >= 90) return 5;
    if (score >= 70) return 4;
    if (score >= 50) return 3;
    if (score >= 30) return 2;
    if (score > 0) return 1;
    return 0;
  }

  String get _label {
    switch (_level) {
      case 5: return 'Leuchtturm';
      case 4: return 'Erfahren';
      case 3: return 'Vertraut';
      case 2: return 'Aktiv';
      case 1: return 'Starter';
      default: return 'Neu';
    }
  }

  Color get _color {
    switch (_level) {
      case 5: return const Color(0xFFFFD700);
      case 4: return AppColors.primary500;
      case 3: return AppColors.success;
      case 2: return AppColors.info;
      case 1: return AppColors.textMuted;
      default: return AppColors.border;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSmall = size == TrustBadgeSize.small;
    final isMedium = size == TrustBadgeSize.medium;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 6 : isMedium ? 8 : 12,
        vertical: isSmall ? 2 : isMedium ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(isSmall ? 8 : 12),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.shield_outlined,
            size: isSmall ? 12 : isMedium ? 14 : 18,
            color: _color,
          ),
          const SizedBox(width: 4),
          Text(
            isSmall ? '${score.round()}' : _label,
            style: TextStyle(
              fontSize: isSmall ? 10 : isMedium ? 12 : 14,
              fontWeight: FontWeight.w600,
              color: _color,
            ),
          ),
        ],
      ),
    );
  }
}
