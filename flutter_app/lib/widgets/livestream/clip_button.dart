/// SKILL: mensaena-features (P4) — Stream-Clip-Button.
/// Speichert eine 30s-Markierung im Livestream (start_seconds = aktuell).
/// Caller übergibt streamId (UUID) + currentSeconds.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../providers/wave_final_providers.dart';

class ClipButton extends ConsumerStatefulWidget {
  const ClipButton({
    required this.streamId,
    required this.currentSeconds,
    super.key,
  });
  final String streamId;
  final int currentSeconds;

  @override
  ConsumerState<ClipButton> createState() => _ClipButtonState();
}

class _ClipButtonState extends ConsumerState<ClipButton> {
  bool _saving = false;

  Future<void> _create() async {
    setState(() => _saving = true);
    try {
      await ref.read(streamClipsRepoProvider).create(
            streamId: widget.streamId,
            startSeconds: widget.currentSeconds,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppColors.surface,
          content: Text('live.clip_saved'.tr())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'live.clip_save'.tr(),
      onPressed: _saving ? null : _create,
      icon: _saving
          ? const SizedBox(
              width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(LucideIcons.scissors, size: 18, color: AppColors.bronze),
    );
  }
}
