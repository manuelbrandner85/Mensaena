import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase.dart';
import '../../theme/app_colors.dart';
import 'messages_repository.dart';

enum _VoiceState { idle, recording, preview, uploading }

/// Inline-Voice-Recorder im Composer – Pendant zu VoiceRecorder.tsx.
/// Tap auf Mikro startet Aufnahme, Tap auf Stop endet sie und zeigt
/// Verwerfen/Senden. Auto-Stop nach 3 Minuten.
class VoiceRecorderButton extends ConsumerStatefulWidget {
  const VoiceRecorderButton({
    super.key,
    required this.conversationId,
    required this.userId,
    this.onSent,
  });

  final String conversationId;
  final String userId;
  final VoidCallback? onSent;

  @override
  ConsumerState<VoiceRecorderButton> createState() =>
      _VoiceRecorderButtonState();
}

class _VoiceRecorderButtonState extends ConsumerState<VoiceRecorderButton> {
  final _recorder = AudioRecorder();
  _VoiceState _state = _VoiceState.idle;
  Duration _duration = Duration.zero;
  Timer? _timer;
  String? _path;

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_state != _VoiceState.idle) return;
    try {
      if (!await _recorder.hasPermission()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mikrofon-Berechtigung verweigert')),
        );
        return;
      }
      final dir = await getTemporaryDirectory();
      final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}'
          '_${Random().nextInt(99999)}.m4a';
      final path = '${dir.path}/$fileName';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 22050,
        ),
        path: path,
      );
      if (!mounted) return;
      setState(() {
        _state = _VoiceState.recording;
        _duration = Duration.zero;
        _path = path;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _duration += const Duration(seconds: 1));
        if (_duration.inSeconds >= 180) _stop();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mikrofon nicht verfügbar: $e')),
      );
    }
  }

  Future<void> _stop() async {
    if (_state != _VoiceState.recording) return;
    _timer?.cancel();
    final path = await _recorder.stop();
    if (!mounted) return;
    setState(() {
      _state = _VoiceState.preview;
      _path = path ?? _path;
    });
  }

  Future<void> _cancel() async {
    _timer?.cancel();
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
    if (_path != null) {
      try {
        final f = File(_path!);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _state = _VoiceState.idle;
      _duration = Duration.zero;
      _path = null;
    });
  }

  Future<void> _send() async {
    if (_state != _VoiceState.preview || _path == null) return;
    setState(() => _state = _VoiceState.uploading);
    final file = File(_path!);
    final secs = _duration.inSeconds;
    try {
      final bytes = await file.readAsBytes();
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}.m4a';
      final storagePath = 'voice/${widget.userId}/$fileName';

      const buckets = ['chat-images', 'avatars'];
      String? publicUrl;
      Object? lastError;
      for (final bucket in buckets) {
        try {
          await sb.storage.from(bucket).uploadBinary(
                storagePath,
                bytes,
                fileOptions: const FileOptions(
                  upsert: false,
                  contentType: 'audio/mp4',
                ),
              );
          publicUrl = sb.storage.from(bucket).getPublicUrl(storagePath);
          break;
        } catch (e) {
          lastError = e;
        }
      }
      if (publicUrl == null) {
        throw Exception(lastError ?? 'Upload fehlgeschlagen');
      }

      await ref.read(messagesRepositoryProvider).sendMessage(
            conversationId: widget.conversationId,
            senderId: widget.userId,
            content: '[Sprachnachricht ${secs}s]($publicUrl)',
          );

      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _state = _VoiceState.idle;
        _duration = Duration.zero;
        _path = null;
      });
      widget.onSent?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Senden fehlgeschlagen: $e')),
      );
      setState(() => _state = _VoiceState.preview);
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case _VoiceState.idle:
        return IconButton(
          tooltip: 'Sprachnachricht aufnehmen',
          icon: const Icon(Icons.mic, color: AppColors.stone400),
          onPressed: _start,
        );
      case _VoiceState.recording:
        return GestureDetector(
          onTap: _stop,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.emergency500,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stop, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(
                  _formatDuration(_duration),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        );
      case _VoiceState.preview:
      case _VoiceState.uploading:
        final uploading = _state == _VoiceState.uploading;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Verwerfen',
              icon: const Icon(Icons.close, color: AppColors.stone500),
              onPressed: uploading ? null : _cancel,
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.audiotrack,
                    size: 14,
                    color: AppColors.primary500,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDuration(_duration),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Senden',
              icon: uploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary500,
                      ),
                    )
                  : const Icon(Icons.send, color: AppColors.primary500),
              onPressed: uploading ? null : _send,
            ),
          ],
        );
    }
  }

  static String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
