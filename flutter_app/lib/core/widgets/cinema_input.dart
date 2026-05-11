import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../theme/colors.dart';
import '../theme/dimensions.dart';
import '../theme/shadows.dart';
import '../theme/typography.dart';

enum CinemaInputVariant { text, multiline, password, search, email, number }

class CinemaInput extends StatefulWidget {
  final TextEditingController? controller;
  final String? label;
  final String? placeholder;
  final String? errorText;
  final CinemaInputVariant variant;
  final IconData? leadingIcon;
  final Widget? trailing;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final bool autofocus;
  final int? maxLines;
  final bool enabled;

  const CinemaInput({
    super.key,
    this.controller,
    this.label,
    this.placeholder,
    this.errorText,
    this.variant = CinemaInputVariant.text,
    this.leadingIcon,
    this.trailing,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.maxLines,
    this.enabled = true,
  });

  @override
  State<CinemaInput> createState() => _CinemaInputState();
}

class _CinemaInputState extends State<CinemaInput> {
  bool _focused = false;
  bool _obscure = true;
  final FocusNode _node = FocusNode();

  @override
  void initState() {
    super.initState();
    _node.addListener(() => setState(() => _focused = _node.hasFocus));
  }

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  TextInputType get _keyboard {
    switch (widget.variant) {
      case CinemaInputVariant.email: return TextInputType.emailAddress;
      case CinemaInputVariant.number: return TextInputType.number;
      case CinemaInputVariant.multiline: return TextInputType.multiline;
      default: return TextInputType.text;
    }
  }

  IconData? get _leading {
    if (widget.leadingIcon != null) return widget.leadingIcon;
    if (widget.variant == CinemaInputVariant.search) return LucideIcons.search;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final hasError = (widget.errorText ?? '').isNotEmpty;
    final isPassword = widget.variant == CinemaInputVariant.password;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: MnTypography.label(
              color: _focused ? MnColors.amber : MnColors.mute,
            ),
          ),
          const SizedBox(height: 6),
        ],
        AnimatedContainer(
          duration: MnDimensions.durFast,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          decoration: BoxDecoration(
            color: MnColors.surface,
            borderRadius: BorderRadius.circular(MnDimensions.radiusInput),
            border: Border.all(
              color: hasError
                  ? MnColors.herzrot.withValues(alpha: 0.4)
                  : _focused
                      ? MnColors.amber.withValues(alpha: 0.3)
                      : MnColors.line,
              width: _focused || hasError ? 1.5 : 1,
            ),
            boxShadow: _focused && !hasError ? MnShadows.inputFocus : null,
          ),
          child: Row(
            children: [
              if (_leading != null) ...[
                Icon(_leading, size: 18, color: _focused ? MnColors.amber : MnColors.mute),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _node,
                  enabled: widget.enabled,
                  obscureText: isPassword && _obscure,
                  keyboardType: _keyboard,
                  maxLines: widget.variant == CinemaInputVariant.multiline ? (widget.maxLines ?? 6) : 1,
                  cursorColor: MnColors.amber,
                  style: MnTypography.body(color: MnColors.ink),
                  autofocus: widget.autofocus,
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  decoration: InputDecoration(
                    isCollapsed: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: InputBorder.none,
                    hintText: widget.placeholder,
                    hintStyle: MnTypography.body(color: MnColors.ghost),
                  ),
                ),
              ),
              if (isPassword)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure ? LucideIcons.eye : LucideIcons.eyeOff,
                    size: 18,
                    color: MnColors.mute,
                  ),
                )
              else if (widget.trailing != null)
                widget.trailing!,
            ],
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Text(
            widget.errorText!,
            style: MnTypography.caption(color: MnColors.herzrot),
          ),
        ],
      ],
    );
  }
}
