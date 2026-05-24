/// SKILL: mensaena-design
/// Shimmer — animierte Loading-Glanz-Welle wie LinkedIn/Instagram.
/// Ersetzt statische Skeleton-Boxen.
library;

import 'package:flutter/material.dart';

import '../../config/theme/app_colors.dart';

class Shimmer extends StatefulWidget {
  const Shimmer({
    required this.child,
    this.baseColor,
    this.highlightColor,
    this.duration = const Duration(milliseconds: 1500),
    super.key,
  });

  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;
  final Duration duration;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.baseColor ?? AppColors.elevated;
    final highlight =
        widget.highlightColor ?? AppColors.surface.withValues(alpha: 0.85);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (rect) {
          final t = _ctrl.value;
          return LinearGradient(
            begin: Alignment(-2.0 + t * 4.0, -0.3),
            end: Alignment(-1.0 + t * 4.0, 0.3),
            colors: [base, highlight, base],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(rect);
        },
        child: widget.child,
      ),
    );
  }
}

/// Standard-Skeleton-Box mit Shimmer (Card-Layout).
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    this.height = 80,
    this.width = double.infinity,
    this.borderRadius = 12,
    super.key,
  });

  final double height;
  final double width;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: AppColors.elevated,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// Shimmer-List für Skeleton-Listen.
class ShimmerList extends StatelessWidget {
  const ShimmerList({
    this.count = 5,
    this.itemHeight = 80,
    this.padding = const EdgeInsets.all(12),
    this.spacing = 8,
    super.key,
  });

  final int count;
  final double itemHeight;
  final EdgeInsets padding;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: padding,
      itemCount: count,
      itemBuilder: (_, __) => Padding(
        padding: EdgeInsets.only(bottom: spacing),
        child: ShimmerBox(height: itemHeight),
      ),
    );
  }
}
