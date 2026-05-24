/// SKILL: mensaena-features
/// Translate-Button — übersetzt Text on-tap via LibreTranslate.
/// Inline-Anzeige der Übersetzung unter dem Original mit Undo-Toggle.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../providers/locale_provider.dart';
import '../../services/libre_translate_service.dart';

class TranslateInlineButton extends ConsumerStatefulWidget {
  const TranslateInlineButton({
    required this.text,
    this.iconSize = 12,
    super.key,
  });

  final String text;
  final double iconSize;

  @override
  ConsumerState<TranslateInlineButton> createState() =>
      _TranslateInlineButtonState();
}

class _TranslateInlineButtonState
    extends ConsumerState<TranslateInlineButton> {
  String? _translated;
  bool _loading = false;
  String? _detectedSource;

  Future<void> _toggle() async {
    if (_translated != null) {
      setState(() {
        _translated = null;
        _detectedSource = null;
      });
      return;
    }
    setState(() => _loading = true);
    final target = ref.read(localeProvider).activeLocale.languageCode;
    final r = await LibreTranslateService.translate(
        text: widget.text, target: target);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _translated = r?.text;
      _detectedSource = r?.detectedSource;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_translated != null) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.tealSoft.withValues(alpha: 0.10),
              border: Border.all(
                  color: AppColors.tealSoft.withValues(alpha: 0.30)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.languages,
                        size: 10,
                        color: AppColors.tealSoft.withValues(alpha: 0.8)),
                    const SizedBox(width: 4),
                    Text(
                      _detectedSource != null
                          ? 'aus ${_detectedSource!.toUpperCase()}'
                          : 'Übersetzt',
                      style: AppTypography.label(
                          size: 9, color: AppColors.tealSoft),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(_translated!,
                    style: AppTypography.body(
                        size: 13, color: AppColors.ink, height: 1.4)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 4),
        InkWell(
          onTap: _loading ? null : _toggle,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_loading)
                  const SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.5, color: AppColors.tealSoft),
                  )
                else
                  Icon(
                    _translated != null
                        ? LucideIcons.undo2
                        : LucideIcons.languages,
                    size: widget.iconSize,
                    color: AppColors.tealSoft.withValues(alpha: 0.75),
                  ),
                const SizedBox(width: 4),
                Text(
                  _translated != null ? 'Original zeigen' : 'Übersetzen',
                  style: AppTypography.label(
                      size: 9,
                      color: AppColors.tealSoft.withValues(alpha: 0.85)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
