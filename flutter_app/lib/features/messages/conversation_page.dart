import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:intl/intl.dart';

import '../../core/supabase.dart';
import '../../theme/app_colors.dart';
import '../calls/models.dart' as calls;
import '../calls/outgoing_call_page.dart';
import 'messages_repository.dart';
import 'models.dart';
import 'voice_recorder_button.dart';

final _voiceRegex = RegExp(r'^\[Sprachnachricht\s+(\d+)s\]\((.+)\)$');

/// Thread-View einer Conversation – Pendant zur "Detail-Spalte" in
/// ChatView.tsx (wenn ?conv=… gesetzt ist).
/// Lädt Messages initial, hängt Realtime-INSERTs an, sendet via Repo.
class ConversationPage extends ConsumerStatefulWidget {
  const ConversationPage({super.key, required this.conversationId});
  final String conversationId;

  @override
  ConsumerState<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends ConsumerState<ConversationPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<Message> _messages = [];
  bool _initialLoaded = false;
  bool _sending = false;
  Profile? _other;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final repo = ref.read(messagesRepositoryProvider);
    final user = ref.read(currentUserProvider);
    final initial = await repo.listMessages(widget.conversationId);
    if (!mounted) return;
    setState(() {
      _messages
        ..clear()
        ..addAll(initial);
      _initialLoaded = true;
    });
    _scrollToBottom();
    if (user != null) {
      await repo.markAsRead(conversationId: widget.conversationId, userId: user.id);
      // Anderes Mitglied (für Call-Buttons) lazy nachladen.
      _loadOtherProfile(user.id);
    }
  }

  Future<void> _loadOtherProfile(String myId) async {
    final rows = await sb
        .from('conversation_members')
        .select('user_id, profiles!inner(id, name, avatar_url)')
        .eq('conversation_id', widget.conversationId)
        .neq('user_id', myId)
        .limit(1);
    if (!mounted || rows.isEmpty) return;
    final p = rows.first['profiles'];
    if (p is Map<String, dynamic>) {
      setState(() => _other = Profile.fromJson(p));
    }
  }

  void _startCall(calls.DmCallType type) {
    final other = _other;
    if (other == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => OutgoingCallPage(
          conversationId: widget.conversationId,
          callee: other,
          callType: type,
        ),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() => _sending = true);
    try {
      final msg = await ref.read(messagesRepositoryProvider).sendMessage(
            conversationId: widget.conversationId,
            senderId: user.id,
            content: text,
          );
      _input.clear();
      // Optimistic – auch Realtime liefert es zurück; doppelt fügen wir nicht ein.
      if (!_messages.any((m) => m.id == msg.id)) {
        setState(() => _messages.add(msg));
      }
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Senden fehlgeschlagen: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Realtime-Subscription auf neue Messages
    ref.listen<AsyncValue<Message>>(
      conversationStreamProvider(widget.conversationId),
      (_, next) {
        next.whenData((m) {
          if (_messages.any((existing) => existing.id == m.id)) return;
          setState(() => _messages.add(m));
          _scrollToBottom();
        });
      },
    );

    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_other?.displayName() ?? 'Gespräch'),
        actions: _other == null
            ? null
            : [
                IconButton(
                  icon: const Icon(Icons.call),
                  tooltip: 'Sprachanruf',
                  onPressed: () => _startCall(calls.DmCallType.audio),
                ),
                IconButton(
                  icon: const Icon(Icons.videocam),
                  tooltip: 'Videoanruf',
                  onPressed: () => _startCall(calls.DmCallType.video),
                ),
              ],
      ),
      body: Column(
        children: [
          Expanded(
            child: !_initialLoaded
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      final m = _messages[i];
                      final isOwn = user != null && m.senderId == user.id;
                      final showTime = _shouldShowTimeBefore(i);
                      return Column(
                        crossAxisAlignment: isOwn
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          if (showTime)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                child: Text(
                                  _dayLabel(m.createdAt),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.stone500,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          _Bubble(message: m, isOwn: isOwn),
                        ],
                      );
                    },
                  ),
          ),
          _Composer(
            controller: _input,
            sending: _sending,
            onSend: _send,
            conversationId: widget.conversationId,
            userId: user?.id,
          ),
        ],
      ),
    );
  }

  bool _shouldShowTimeBefore(int i) {
    if (i == 0) return true;
    final prev = _messages[i - 1].createdAt;
    final cur = _messages[i].createdAt;
    return prev.year != cur.year || prev.month != cur.month || prev.day != cur.day;
  }

  String _dayLabel(DateTime t) {
    final now = DateTime.now();
    final isToday = t.year == now.year && t.month == now.month && t.day == now.day;
    if (isToday) return 'Heute';
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday =
        t.year == yesterday.year && t.month == yesterday.month && t.day == yesterday.day;
    if (isYesterday) return 'Gestern';
    return DateFormat('EEEE, d. MMMM', 'de').format(t);
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.isOwn});
  final Message message;
  final bool isOwn;

  @override
  Widget build(BuildContext context) {
    final bg = isOwn ? AppColors.primary500 : AppColors.paper;
    final fg = isOwn ? Colors.white : AppColors.ink800;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Align(
        alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isOwn ? 16 : 4),
                bottomRight: Radius.circular(isOwn ? 4 : 16),
              ),
              border: isOwn ? null : Border.all(color: AppColors.stone200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _bubbleContent(fg),
                const SizedBox(height: 4),
                Text(
                  DateFormat('HH:mm').format(message.createdAt),
                  style: TextStyle(
                    fontSize: 10,
                    color: isOwn
                        ? Colors.white.withValues(alpha: 0.75)
                        : AppColors.stone400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bubbleContent(Color fg) {
    if (message.isDeleted) {
      return Text(
        'Nachricht gelöscht',
        style: TextStyle(
          color: fg,
          fontSize: 14,
          fontStyle: FontStyle.italic,
        ),
      );
    }
    final match = _voiceRegex.firstMatch(message.content.trim());
    if (match != null) {
      return _VoiceMessagePlayer(
        url: match.group(2)!,
        durationSeconds: int.tryParse(match.group(1) ?? '') ?? 0,
        isOwn: isOwn,
      );
    }
    return Text(
      message.content,
      style: TextStyle(color: fg, fontSize: 14),
    );
  }
}

/// Inline-Audio-Player für Sprachnachrichten in Chat-Bubbles.
/// Lazy-Load: lädt erst beim ersten Play, spart Bandbreite in langen Listen.
class _VoiceMessagePlayer extends StatefulWidget {
  const _VoiceMessagePlayer({
    required this.url,
    required this.durationSeconds,
    required this.isOwn,
  });
  final String url;
  final int durationSeconds;
  final bool isOwn;

  @override
  State<_VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<_VoiceMessagePlayer> {
  final _player = FlutterSoundPlayer();
  bool _opened = false;
  bool _isPlaying = false;
  bool _failed = false;
  Duration _position = Duration.zero;
  Duration _total = Duration.zero;
  StreamSubscription<PlaybackDisposition>? _sub;

  @override
  void initState() {
    super.initState();
    _total = Duration(seconds: widget.durationSeconds);
  }

  Future<bool> _ensureOpen() async {
    if (_opened) return true;
    try {
      await _player.openPlayer();
      await _player.setSubscriptionDuration(const Duration(milliseconds: 100));
      _sub = _player.onProgress?.listen((d) {
        if (!mounted) return;
        setState(() {
          _position = d.position;
          if (d.duration.inMilliseconds > 0) _total = d.duration;
        });
      });
      _opened = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    if (_opened) {
      _player.closePlayer();
    }
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_failed) return;
    try {
      if (!await _ensureOpen()) {
        if (!mounted) return;
        setState(() => _failed = true);
        return;
      }
      if (_isPlaying) {
        await _player.pausePlayer();
        if (!mounted) return;
        setState(() => _isPlaying = false);
        return;
      }
      if (_player.isPaused) {
        await _player.resumePlayer();
      } else {
        await _player.startPlayer(
          fromURI: widget.url,
          codec: Codec.aacMP4,
          whenFinished: () {
            if (!mounted) return;
            setState(() {
              _position = Duration.zero;
              _isPlaying = false;
            });
          },
        );
      }
      if (!mounted) return;
      setState(() => _isPlaying = true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.isOwn ? Colors.white : AppColors.ink800;
    final accent = widget.isOwn ? Colors.white : AppColors.primary500;
    final progress = _total.inMilliseconds == 0
        ? 0.0
        : (_position.inMilliseconds / _total.inMilliseconds).clamp(0.0, 1.0);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: _toggle,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Icon(
              _failed
                  ? Icons.error_outline
                  : _isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
              color: accent,
              size: 32,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 120,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 3,
                  backgroundColor: widget.isOwn
                      ? Colors.white.withValues(alpha: 0.3)
                      : AppColors.stone200,
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _format(_isPlaying || progress > 0 ? _position : _total),
                style: TextStyle(
                  color: fg,
                  fontSize: 11,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.onSend,
    required this.sending,
    required this.conversationId,
    required this.userId,
  });

  final TextEditingController controller;
  final String conversationId;
  final String? userId;
  final VoidCallback onSend;
  final bool sending;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: const BoxDecoration(
          color: AppColors.paper,
          border: Border(top: BorderSide(color: AppColors.stone200)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 5,
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(
                  hintText: 'Nachricht schreiben…',
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ),
            if (userId != null)
              VoiceRecorderButton(
                conversationId: conversationId,
                userId: userId!,
              ),
            const SizedBox(width: 4),
            Material(
              color: AppColors.primary500,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: sending ? null : onSend,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    sending ? Icons.hourglass_empty : Icons.send,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
