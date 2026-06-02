import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import 'supabase_service.dart';

/// SKILL: mensaena-features
/// Voice-Message-Workflow — 1:1 zu Web VoiceRecorder.tsx.
///
/// Flow:
/// 1. start() requests mic-permission + begins recording to temp .m4a
/// 2. stop() finalizes file + returns local path + duration in seconds
/// 3. upload() uploads file to chat-voice-messages Storage bucket
///    + returns public URL
///
/// Chat-Message-Format (text-content of messages):
///   `[VOICE:<url>:<seconds>]`
/// The bubble parses this and renders a VoiceMessageBubble.
class VoiceRecorderService {
  VoiceRecorderService._();

  static final _recorder = AudioRecorder();
  static String? _currentPath;
  static DateTime? _startedAt;

  /// Returns true if currently recording.
  static Future<bool> isRecording() => _recorder.isRecording();

  /// Asks for mic-permission and starts recording.
  /// Returns false if permission denied or recording already in progress.
  static Future<bool> start() async {
    final mic = await Permission.microphone.request();
    if (mic.isDenied || mic.isPermanentlyDenied) return false;
    if (await _recorder.isRecording()) return false;
    try {
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/voice-${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 22050,
          numChannels: 1,
        ),
        path: path,
      );
      _currentPath = path;
      _startedAt = DateTime.now();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Stops recording. Returns (path, durationSeconds) or null on error.
  static Future<({String path, int durationSeconds})?> stop() async {
    if (!await _recorder.isRecording()) return null;
    try {
      final returned = await _recorder.stop();
      final path = returned ?? _currentPath;
      final started = _startedAt;
      _currentPath = null;
      _startedAt = null;
      if (path == null) return null;
      final duration = started != null
          ? DateTime.now().difference(started).inSeconds
          : 0;
      return (path: path, durationSeconds: duration);
    } catch (_) {
      _currentPath = null;
      _startedAt = null;
      return null;
    }
  }

  /// Cancels current recording without saving.
  static Future<void> cancel() async {
    try {
      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }
      final path = _currentPath;
      if (path != null) {
        try {
          await File(path).delete();
        } catch (_) {}
      }
    } catch (_) {}
    _currentPath = null;
    _startedAt = null;
  }

  /// Uploads recorded file to chat-voice-messages Storage bucket.
  /// Returns public URL or null on failure.
  static Future<String?> upload(String localPath) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return null;
    try {
      final file = File(localPath);
      if (!await file.exists()) return null;
      final remotePath =
          '$uid/voice-${DateTime.now().millisecondsSinceEpoch}.m4a';
      await sb.storage.from('chat-voice-messages').upload(
            remotePath,
            file,
            fileOptions:
                const FileOptions(contentType: 'audio/mp4', upsert: false),
          );
      return sb.storage
          .from('chat-voice-messages')
          .getPublicUrl(remotePath);
    } catch (e) {
      debugPrint('VoiceRecorderService.upload failed: $e');
      return null;
    }
  }

  /// Pattern to embed in messages.content.
  /// `[VOICE:<url>:<seconds>]`
  static String encodeMessage({required String url, required int durationSeconds}) {
    return '[VOICE:$url:$durationSeconds]';
  }

  /// Parses a voice-message content string. Returns null if not a voice message.
  static ({String url, int durationSeconds})? decodeMessage(String content) {
    final match = RegExp(r'^\[VOICE:(https?://[^\s\]]+):(\d+)\]$')
        .firstMatch(content.trim());
    if (match == null) return null;
    final url = match.group(1)!;
    final dur = int.tryParse(match.group(2)!) ?? 0;
    return (url: url, durationSeconds: dur);
  }
}
