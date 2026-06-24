/// SKILL: mensaena-features (P3) — Voicemail an Profil senden.
/// Hold-to-record (max 60s), Upload zu voicemails bucket, INSERT in
/// call_voicemails.
library;

import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../repositories/calls_repository.dart';
import '../../services/supabase_service.dart';
import '../../services/voice_recorder_service.dart';

class SendVoicemailSheet extends ConsumerStatefulWidget {
  const SendVoicemailSheet({
    required this.calleeId,
    required this.calleeName,
    super.key,
  });
  final String calleeId;
  final String calleeName;

  static Future<void> show(
    BuildContext context, {
    required String calleeId,
    required String calleeName,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.sheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SendVoicemailSheet(
        calleeId: calleeId,
        calleeName: calleeName,
      ),
    );
  }

  @override
  ConsumerState<SendVoicemailSheet> createState() => _SendVoicemailSheetState();
}

class _SendVoicemailSheetState extends ConsumerState<SendVoicemailSheet> {
  bool _recording = false;
  bool _sending = false;
  String? _errorMsg;

  Future<void> _startStop() async {
    if (_recording) {
      final res = await VoiceRecorderService.stop();
      if (!mounted) return;
      setState(() {
        _recording = false;
        _sending = true;
      });
      if (res == null) {
        setState(() {
          _sending = false;
          _errorMsg = 'voicemail.error_record'.tr();
        });
        return;
      }
      await _uploadAndSend(res.path, res.durationSeconds);
    } else {
      final ok = await VoiceRecorderService.start();
      if (!mounted) return;
      if (!ok) {
        setState(() => _errorMsg = 'voicemail.error_permission'.tr());
        return;
      }
      setState(() {
        _recording = true;
        _errorMsg = null;
      });
    }
  }

  Future<void> _uploadAndSend(String path, int seconds) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return;
    try {
      final remote =
          '$uid/${DateTime.now().millisecondsSinceEpoch}.m4a';
      await sb.storage.from('voicemails').upload(
            remote,
            File(path),
            fileOptions:
                const FileOptions(contentType: 'audio/mp4', upsert: false),
          );
      final url = sb.storage.from('voicemails').getPublicUrl(remote);
      await CallsRepository.sendVoicemail(
        calleeId: widget.calleeId,
        audioUrl: url,
        seconds: seconds,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text('voicemail.sent'.tr(),
            style: AppTypography.body(size: 13, color: AppColors.ink)),
      ));
    } catch (_) {
      if (mounted) {
        setState(() {
          _sending = false;
          _errorMsg = 'voicemail.error_upload'.tr();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              const Icon(LucideIcons.voicemail,
                  size: 18, color: AppColors.bronze),
              const SizedBox(width: 8),
              Text('voicemail.send_to'.tr(),
                  style: AppTypography.display(
                      size: 18, color: AppColors.ink)),
            ]),
            const SizedBox(height: 4),
            Text(widget.calleeName, style: AppTypography.caption()),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _sending ? null : _startStop,
              child: Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _recording
                      ? AppColors.herzrotWarm
                      : AppColors.bronze.withValues(alpha: 0.85),
                ),
                child: Icon(
                  _recording ? LucideIcons.square : LucideIcons.mic,
                  size: 38,
                  color: AppColors.voidColor,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _sending
                  ? 'voicemail.sending'.tr()
                  : _recording
                      ? 'voicemail.recording'.tr()
                      : 'voicemail.tap_to_record'.tr(),
              style: AppTypography.caption(),
            ),
            if (_errorMsg != null) ...[
              const SizedBox(height: 8),
              Text(_errorMsg!,
                  style: AppTypography.body(
                      size: 12, color: AppColors.herzrotWarm)),
            ],
          ],
        ),
      ),
    );
  }
}

