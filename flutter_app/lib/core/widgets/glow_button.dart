import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/dimensions.dart';
import '../theme/shadows.dart';
import '../theme/typography.dart';

enum GlowVariant { primary, secondary, crisis, teal, ghost }

class GlowButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final GlowVariant variant;
  final VoidCallback? onPressed;
  final bool fullWidth;
  final bool compact;

  const GlowButton({
    super.key,
    required this.label,
    this.icon,
    this.variant = GlowVariant.primary,
    this.onPressed,
    this.fullWidth = false,
    this.compact = false,
  });

  @override
  State<GlowButton> createState() => _GlowButtonState();
}

class _GlowButtonState extends State<GlowButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null;

  ({
    Color bg,
    Color text,
    Border? border,
    List<BoxShadow>? shadow,
    LinearGradient? gradient,
  }) _resolve() {
    switch (widget.variant) {
      case GlowVariant.primary:
        return (
          bg: Colors.transparent,
          text: MnColors.voidColor,
          border: null,
          shadow: MnShadows.amberGlow,
          gradient: const LinearGradient(
            colors: [MnColors.amber, MnColors.amberWarm],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        );
      case GlowVariant.secondary:
        return (
          bg: Colors.transparent,
          text: MnColors.amber,
          border: Border.all(color: MnColors.amber.withValues(alpha: 0.4), width: 1.5),
          shadow: null,
          gradient: null,
        );
      case GlowVariant.crisis:
        return (
          bg: Colors.transparent,
          text: MnColors.ink,
          border: null,
          shadow: MnShadows.herzrotGlow,
          gradient: const LinearGradient(
            colors: [MnColors.herzrot, MnColors.herzrotWarm],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        );
      case GlowVariant.teal:
        return (
          bg: Colors.transparent,
          text: MnColors.ink,
          border: null,
          shadow: MnShadows.tealGlow,
          gradient: const LinearGradient(
            colors: [MnColors.teal, MnColors.tealSoft],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        );
      case GlowVariant.ghost:
        return (
          bg: const Color(0x0DFFFFFF),
          text: MnColors.inkSoft,
          border: null,
          shadow: null,
          gradient: null,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _resolve();
    final pad = widget.compact
        ? const EdgeInsets.symmetric(horizontal: 14, vertical: 8)
        : const EdgeInsets.symmetric(horizontal: 20, vertical: 14);

    final child = Row(
      mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: 18, color: r.text),
          const SizedBox(width: 8),
        ],
        Text(
          widget.label,
          style: MnTypography.body(
            color: r.text,
            weight: FontWeight.w600,
            size: widget.compact ? 13 : 15,
            height: 1.0,
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: MnDimensions.durFast,
            padding: pad,
            decoration: BoxDecoration(
              color: r.gradient == null ? r.bg : null,
              gradient: r.gradient,
              border: r.border,
              borderRadius: BorderRadius.circular(MnDimensions.radiusButton),
              boxShadow: _enabled ? r.shadow : null,
            ),
            child: Opacity(opacity: _enabled ? 1.0 : 0.5, child: child),
          ),
        ),
      ),
    );
  }
}
