import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/dimensions.dart';
import '../theme/typography.dart';

/// Statistik-Karte mit CountUp-Animation.
class CinemaStat extends StatefulWidget {
  final int value;
  final String label;
  final IconData? icon;
  final Color valueColor;

  const CinemaStat({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.valueColor = MnColors.amber,
  });

  @override
  State<CinemaStat> createState() => _CinemaStatState();
}

class _CinemaStatState extends State<CinemaStat>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  int _from = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..forward();
  }

  @override
  void didUpdateWidget(covariant CinemaStat old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _from = old.value;
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MnColors.surface,
        borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
        border: Border.all(color: MnColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.icon != null) ...[
            Icon(widget.icon, size: 18, color: MnColors.teal),
            const SizedBox(height: 8),
          ],
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              final t = Curves.easeOutCubic.transform(_ctrl.value);
              final current = (_from + (widget.value - _from) * t).round();
              return Text(
                current.toString(),
                style: MnTypography.mono(
                  size: 28,
                  color: widget.valueColor,
                  weight: FontWeight.w700,
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          Text(widget.label, style: MnTypography.body(size: 13, color: MnColors.mute)),
        ],
      ),
    );
  }
}
