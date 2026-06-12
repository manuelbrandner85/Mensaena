/// SKILL: mensaena-features (Phase 7 F76)
/// Schnellübersicht für eine Konversation — KEINE ML-Summarization,
/// stattdessen einfache Statistik + Top-5 Stichworte aus den letzten
/// 100 Messages. Trigger: Long-Press auf Conversation in messages_screen.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/supabase_service.dart';

class ChatRecapSheet {
  static Future<void> show(
    BuildContext context, {
    required String conversationId,
    required String conversationTitle,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.sheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _RecapBody(
        conversationId: conversationId,
        conversationTitle: conversationTitle,
      ),
    );
  }
}

class _RecapBody extends StatelessWidget {
  const _RecapBody({
    required this.conversationId,
    required this.conversationTitle,
  });
  final String conversationId;
  final String conversationTitle;

  Future<_Recap> _compute() async {
    try {
      final rows = await sb
          .from('messages')
          .select('content, sender_id, created_at')
          .eq('conversation_id', conversationId)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false)
          .limit(100);
      final list =
          (rows as List).whereType<Map<String, dynamic>>().toList();
      if (list.isEmpty) return _Recap.empty();
      final total = list.length;
      final senders = <String, int>{};
      final words = <String, int>{};
      DateTime? newest;
      DateTime? oldest;
      String? lastMsg;
      for (final m in list) {
        final s = m['sender_id'] as String?;
        if (s != null) senders[s] = (senders[s] ?? 0) + 1;
        final c = (m['content'] as String?)?.trim() ?? '';
        lastMsg ??= c.isEmpty ? null : c;
        for (final w in c.split(RegExp(r'\W+'))) {
          if (w.length < 5) continue;
          final wl = w.toLowerCase();
          if (_stopWords.contains(wl)) continue;
          words[wl] = (words[wl] ?? 0) + 1;
        }
        final t = DateTime.tryParse(m['created_at'] as String? ?? '')?.toUtc();
        if (t != null) {
          newest ??= t;
          oldest = t;
        }
      }
      final top = words.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return _Recap(
        total: total,
        senderCount: senders.length,
        topKeywords: top.take(5).map((e) => e.key).toList(),
        newest: newest,
        oldest: oldest,
        lastSnippet: lastMsg,
      );
    } catch (_) {
      return _Recap.empty();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Recap>(
      future: _compute(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox(
            height: 200,
            child: Center(
              child: CircularProgressIndicator(color: AppColors.bronze),
            ),
          );
        }
        final r = snap.data!;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(children: [
                const Icon(LucideIcons.fileText,
                    color: AppColors.bronze, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'chat.recapTitle'.tr(
                        namedArgs: {'name': conversationTitle}),
                    style: AppTypography.body(
                        size: 15,
                        color: AppColors.ink,
                        weight: FontWeight.w700),
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              if (r.total == 0) ...[
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('chat.recapEmpty'.tr(),
                      style: AppTypography.body(
                          size: 13, color: AppColors.mute),
                      textAlign: TextAlign.center),
                ),
              ] else ...[
                _StatLine(
                  label: 'chat.recapMessageCount'.tr(),
                  value: '${r.total}',
                ),
                _StatLine(
                  label: 'chat.recapParticipants'.tr(),
                  value: '${r.senderCount}',
                ),
                if (r.oldest != null && r.newest != null)
                  _StatLine(
                    label: 'chat.recapTimespan'.tr(),
                    value: _timespan(r.oldest!, r.newest!),
                  ),
                const SizedBox(height: 10),
                if (r.topKeywords.isNotEmpty) ...[
                  Text('chat.recapKeywords'.tr().toUpperCase(),
                      style: AppTypography.label(
                          size: 9, color: AppColors.mute)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: r.topKeywords
                        .map((k) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.bronze
                                    .withValues(alpha: 0.15),
                                border: Border.all(
                                    color: AppColors.bronze
                                        .withValues(alpha: 0.4)),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text('#$k',
                                  style: AppTypography.body(
                                      size: 11,
                                      color: AppColors.bronze,
                                      weight: FontWeight.w600)),
                            ))
                        .toList(),
                  ),
                ],
                if (r.lastSnippet != null) ...[
                  const SizedBox(height: 14),
                  Text('chat.recapLastMessage'.tr().toUpperCase(),
                      style: AppTypography.label(
                          size: 9, color: AppColors.mute)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.elevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Text(
                      r.lastSnippet!,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body(
                          size: 13,
                          color: AppColors.inkSoft,
                          height: 1.4),
                    ),
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  String _timespan(DateTime a, DateTime b) {
    final d = b.difference(a);
    if (d.inDays >= 1) return '${d.inDays} d';
    if (d.inHours >= 1) return '${d.inHours} h';
    return '${d.inMinutes} min';
  }
}

class _StatLine extends StatelessWidget {
  const _StatLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(
          child: Text(label,
              style: AppTypography.body(size: 13, color: AppColors.inkSoft)),
        ),
        Text(value,
            style: AppTypography.body(
                size: 13,
                color: AppColors.bronze,
                weight: FontWeight.w700)),
      ]),
    );
  }
}

class _Recap {
  const _Recap({
    required this.total,
    required this.senderCount,
    required this.topKeywords,
    required this.newest,
    required this.oldest,
    required this.lastSnippet,
  });
  factory _Recap.empty() => const _Recap(
        total: 0,
        senderCount: 0,
        topKeywords: [],
        newest: null,
        oldest: null,
        lastSnippet: null,
      );
  final int total;
  final int senderCount;
  final List<String> topKeywords;
  final DateTime? newest;
  final DateTime? oldest;
  final String? lastSnippet;
}

const _stopWords = {
  'aber','alle','also','andere','auch','beim','dann','dass','denn',
  'doch','eine','einen','einer','etwas','geht','haben','heute','hier',
  'hierhin','ihre','ihren','immer','jeder','jetzt','kann','kein','keine',
  'kommt','machen','meine','mein','nicht','ohne','sein','sehr','sich',
  'sind','soll','solche','unsere','unser','vielleicht','wegen','weil',
  'werden','wieder','wirst','wirklich','würden','about','again','because',
  'before','being','could','doing','having','their','these','those',
  'where','which','would','your','yours',
};
