import 'dart:async';
import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../services/haptics.dart';
import '../../../services/voice_recorder_service.dart';
import '../../../widgets/shared/voice_dictation_button.dart';

/// SKILL: mensaena-features
/// Chat-Input-Bar — Textfeld + Voice-Diktat + Voice-Recorder + Send-Button.
class ChatInputBar extends StatelessWidget {
  const ChatInputBar({
    required this.controller,
    required this.conversationId,
    required this.onSend,
    required this.onVoiceUploaded,
    required this.onTextChanged,
    super.key,
  });

  final TextEditingController controller;
  final String conversationId;
  final VoidCallback onSend;
  final Future<void> Function(String url, int durationSeconds) onVoiceUploaded;
  final VoidCallback onTextChanged;

  @override
  Widget build(BuildContext context) {
    // #19 Glass-Effect Input-Bar: leichter BackdropFilter ueber dem
    // unteren Rand, halbtransparenter Background, Bronze-Top-Border.
    // RepaintBoundary isoliert den Blur damit Scrolling nicht
    // permanent neu blurred.
    return RepaintBoundary(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.deep.withValues(alpha: 0.72),
              border: Border(
                top: BorderSide(
                  color: AppColors.bronze.withValues(alpha: 0.18),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: controller,
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => onSend(),
                        onChanged: (_) => onTextChanged(),
                        style: AppTypography.body(
                            size: 14, color: AppColors.ink),
                        decoration: InputDecoration(
                          hintText: 'chat.messageHint'.tr(),
                          isDense: true,
                        ),
                      ),
                      // F87: Char-Counter sichtbar ab 800 Zeichen
                      AnimatedBuilder(
                        animation: controller,
                        builder: (_, __) {
                          final len = controller.text.length;
                          if (len < 800) return const SizedBox.shrink();
                          final overLimit = len >= 2000;
                          return Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              '$len',
                              style: AppTypography.body(
                                size: 10,
                                color: overLimit
                                    ? AppColors.herzrotWarm
                                    : AppColors.mute,
                                weight: FontWeight.w700,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                // Voice-Diktat → Text-Composer.
                VoiceDictationButton(controller: controller, localeId: 'de_DE'),
                const SizedBox(width: 2),
                // Voice-Recorder — long-press = recording, release = send.
                ChatVoiceRecorderButton(
                  conversationId: conversationId,
                  onUploaded: onVoiceUploaded,
                ),
                const SizedBox(width: 6),
                // Send-Button: aktiv = Bronze-Glow, inaktiv = opacity 0.3
                // Perf: AnimatedBuilder lauscht direkt auf controller →
                // kein setState im Parent (ChatScreen) bei jedem Keystroke.
                AnimatedBuilder(
                  animation: controller,
                  builder: (_, __) => ChatSendButton(
                    enabled: controller.text.trim().isNotEmpty,
                    onPressed: onSend,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// SendButton — Bronze-Glow bei aktiv, dimmed bei leer
class ChatSendButton extends StatelessWidget {
  const ChatSendButton({
    required this.enabled,
    required this.onPressed,
    super.key,
  });

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'chat.send'.tr(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: enabled
              ? LinearGradient(
                  colors: [
                    AppColors.bronze,
                    AppColors.bronze.withValues(alpha: 0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: enabled ? null : AppColors.elevated,
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.bronze.withValues(alpha: 0.5),
                    blurRadius: 14,
                    spreadRadius: -2,
                  ),
                ]
              : null,
        ),
        child: IconButton(
          padding: EdgeInsets.zero,
          onPressed: enabled ? onPressed : null,
          icon: Icon(
            LucideIcons.send,
            size: 20,
            color: enabled
                ? AppColors.voidColor
                : AppColors.bronze.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }
}

/// Voice-Recorder-Button (Phase 5.2) — long-press to record,
/// release to send. Tap shows hint. 1:1 zu Web VoiceRecorder.tsx.
class ChatVoiceRecorderButton extends StatefulWidget {
  const ChatVoiceRecorderButton({
    required this.conversationId,
    required this.onUploaded,
    super.key,
  });

  final String conversationId;
  final Future<void> Function(String url, int durationSeconds) onUploaded;

  @override
  State<ChatVoiceRecorderButton> createState() =>
      _ChatVoiceRecorderButtonState();
}

class _ChatVoiceRecorderButtonState extends State<ChatVoiceRecorderButton> {
  bool _recording = false;
  bool _uploading = false;
  DateTime? _startedAt;
  Timer? _ticker;
  int _elapsed = 0;

  Future<void> _startRecord() async {
    if (_recording || _uploading) return;
    final ok = await VoiceRecorderService.start();
    if (!ok) {
      if (!mounted) return;
      unawaited(Haptics.error());
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text(
          'Mikrofon-Berechtigung erforderlich.',
          style: AppTypography.body(size: 13, color: AppColors.herzrotWarm),
        ),
      ));
      return;
    }
    Haptics.tap();
    setState(() {
      _recording = true;
      _startedAt = DateTime.now();
      _elapsed = 0;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed =
          DateTime.now().difference(_startedAt!).inSeconds);
    });
  }

  Future<void> _stopAndSend() async {
    _ticker?.cancel();
    final result = await VoiceRecorderService.stop();
    if (!mounted) return;
    setState(() => _recording = false);
    if (result == null || result.durationSeconds < 1) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text(
          'chat.recordingTooShort'.tr(),
          style: AppTypography.body(size: 13, color: AppColors.mute),
        ),
      ));
      return;
    }
    setState(() => _uploading = true);
    final url = await VoiceRecorderService.upload(result.path);
    if (!mounted) return;
    setState(() => _uploading = false);
    if (url == null) {
      unawaited(Haptics.error());
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text(
          'Upload fehlgeschlagen.',
          style: AppTypography.body(
              size: 13, color: AppColors.herzrotWarm),
        ),
      ));
      return;
    }
    unawaited(Haptics.success());
    await widget.onUploaded(url, result.durationSeconds);
  }

  Future<void> _cancel() async {
    _ticker?.cancel();
    await VoiceRecorderService.cancel();
    if (!mounted) return;
    setState(() => _recording = false);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_recording) {
      // Recording state: timer + cancel + send
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.herzrot.withValues(alpha: 0.18),
          border:
              Border.all(color: AppColors.herzrot.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.circle,
                size: 10, color: AppColors.herzrot),
            const SizedBox(width: 4),
            Text('${_elapsed}s',
                style: AppTypography.mono(
                    size: 11, color: AppColors.herzrotWarm)),
            IconButton(
              tooltip: 'chat.tooltipCancel'.tr(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: _cancel,
              icon: const Icon(LucideIcons.x,
                  size: 14, color: AppColors.mute),
            ),
            IconButton(
              tooltip: 'chat.tooltipSend'.tr(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: _stopAndSend,
              icon: const Icon(LucideIcons.send,
                  size: 14, color: AppColors.amber),
            ),
          ],
        ),
      );
    }
    if (_uploading) {
      return const Padding(
        padding: EdgeInsets.all(10),
        child: SizedBox(
          width: 18,
          height: 18,
          child:
              CircularProgressIndicator(strokeWidth: 2, color: AppColors.amber),
        ),
      );
    }
    // Idle: mic icon — tap to start recording
    return IconButton(
      tooltip: 'chat.tooltipRecordVoice'.tr(),
      onPressed: _startRecord,
      icon: const Icon(LucideIcons.mic, color: AppColors.bronze),
    );
  }
}
