/// SKILL: mensaena-features (Phase 12 F52)
/// "Vorlesen"-Button für Post-Detail. Toggle: Play → Stop → Play.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/tts_service.dart';

class TtsPlayButton extends StatefulWidget {
  const TtsPlayButton({required this.text, super.key});
  final String text;

  @override
  State<TtsPlayButton> createState() => _TtsPlayButtonState();
}

class _TtsPlayButtonState extends State<TtsPlayButton> {
  bool _speaking = false;

  @override
  void initState() {
    super.initState();
    TtsService.instance.isSpeakingStream.listen((v) {
      if (mounted) setState(() => _speaking = v);
    });
  }

  @override
  void dispose() {
    TtsService.instance.stop();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_speaking) {
      await TtsService.instance.stop();
    } else {
      await TtsService.instance.speak(widget.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: widget.text.trim().isEmpty ? null : _toggle,
      icon: Icon(
        _speaking ? LucideIcons.square : LucideIcons.volume2,
        size: 14,
      ),
      label: Text(
        _speaking ? 'tts.stop'.tr() : 'tts.read'.tr(),
        style: AppTypography.body(size: 12, color: AppColors.bronze),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.bronze,
        side: BorderSide(color: AppColors.bronze.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
    );
  }
}
