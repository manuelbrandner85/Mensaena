import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';

/// Button-Komponenten – matchen 1:1 die CSS-Klassen aus globals.css:
/// .btn-primary, .btn-secondary, .btn-outline, .btn-ghost, .btn-danger

enum BtnSize { small, medium, large }

class _BtnBase extends StatelessWidget {
  const _BtnBase({
    required this.onPressed,
    required this.child,
    required this.background,
    required this.foreground,
    this.border,
    this.shadow,
    this.size = BtnSize.medium,
    this.fullWidth = false,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final Color background;
  final Color foreground;
  final BoxBorder? border;
  final List<BoxShadow>? shadow;
  final BtnSize size;
  final bool fullWidth;

  EdgeInsets get _padding {
    switch (size) {
      case BtnSize.small:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
      case BtnSize.medium:
        return const EdgeInsets.symmetric(horizontal: 24, vertical: 12);
      case BtnSize.large:
        return const EdgeInsets.symmetric(horizontal: 32, vertical: 16);
    }
  }

  double get _fontSize {
    switch (size) {
      case BtnSize.small:
        return 13;
      case BtnSize.medium:
        return 14;
      case BtnSize.large:
        return 16;
    }
  }

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            padding: _padding,
            width: fullWidth ? double.infinity : null,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(12),
              border: border,
              boxShadow: shadow,
            ),
            child: DefaultTextStyle.merge(
              style: TextStyle(
                color: foreground,
                fontSize: _fontSize,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
              child: IconTheme.merge(
                data: IconThemeData(color: foreground, size: 18),
                child: Center(
                  child: Row(
                    mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [child],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BtnPrimary extends StatelessWidget {
  const BtnPrimary({super.key, required this.onPressed, required this.label, this.icon, this.size = BtnSize.medium, this.fullWidth = false});

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final BtnSize size;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    return _BtnBase(
      onPressed: onPressed,
      background: AppColors.primary500,
      foreground: Colors.white,
      shadow: AppShadows.glowTeal,
      size: size,
      fullWidth: fullWidth,
      child: _LabelWithIcon(label: label, icon: icon),
    );
  }
}

class BtnSecondary extends StatelessWidget {
  const BtnSecondary({super.key, required this.onPressed, required this.label, this.icon, this.size = BtnSize.medium, this.fullWidth = false});

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final BtnSize size;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    return _BtnBase(
      onPressed: onPressed,
      background: AppColors.trust400,
      foreground: Colors.white,
      shadow: AppShadows.soft,
      size: size,
      fullWidth: fullWidth,
      child: _LabelWithIcon(label: label, icon: icon),
    );
  }
}

class BtnOutline extends StatelessWidget {
  const BtnOutline({super.key, required this.onPressed, required this.label, this.icon, this.size = BtnSize.medium, this.fullWidth = false});

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final BtnSize size;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    return _BtnBase(
      onPressed: onPressed,
      background: Colors.transparent,
      foreground: AppColors.primary600,
      border: Border.all(color: AppColors.primary500, width: 1.5),
      size: size,
      fullWidth: fullWidth,
      child: _LabelWithIcon(label: label, icon: icon),
    );
  }
}

class BtnGhost extends StatelessWidget {
  const BtnGhost({super.key, required this.onPressed, required this.label, this.icon, this.size = BtnSize.small});

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final BtnSize size;

  @override
  Widget build(BuildContext context) {
    return _BtnBase(
      onPressed: onPressed,
      background: Colors.transparent,
      foreground: AppColors.primary700,
      size: size,
      child: _LabelWithIcon(label: label, icon: icon),
    );
  }
}

class BtnDanger extends StatelessWidget {
  const BtnDanger({super.key, required this.onPressed, required this.label, this.icon, this.size = BtnSize.medium, this.fullWidth = false});

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final BtnSize size;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    return _BtnBase(
      onPressed: onPressed,
      background: AppColors.emergency500,
      foreground: Colors.white,
      shadow: AppShadows.soft,
      size: size,
      fullWidth: fullWidth,
      child: _LabelWithIcon(label: label, icon: icon),
    );
  }
}

class _LabelWithIcon extends StatelessWidget {
  const _LabelWithIcon({required this.label, this.icon});
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    if (icon == null) return Text(label);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}
