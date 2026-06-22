/// SKILL: mensaena-features (Phase 7 F38)
/// Post-Reactions-Button mit Emoji-System.
/// - Tap (kurz): Toggle Default-Reaction (❤️)
/// - Long-Press: Picker mit 6 Reactions (❤️ 👍 😂 😮 😢 🔥)
/// - Anzeige: Top-2 Emojis + Total-Count
///
/// Verwendet post_reactions-Tabelle via PostReactionsRepository.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../repositories/extra_repositories.dart';
import '../../services/haptics.dart';
import '../../services/supabase_service.dart';

const _reactionEmojis = ['❤️', '👍', '😂', '😮', '😢', '🔥'];

class _ReactionsState {
  const _ReactionsState({
    required this.total,
    required this.byType,
    required this.mine,
  });
  final int total;
  final Map<String, int> byType;
  final String? mine;
}

final _reactionsStateProvider = FutureProvider.autoDispose
    .family<_ReactionsState, String>((ref, postId) async {
  final rows = await PostReactionsRepository.forPost(postId);
  final me = SupabaseService.currentUser?.id;
  final byType = <String, int>{};
  String? mine;
  for (final r in rows) {
    final t = r['reaction_type'] as String? ?? '';
    if (t.isEmpty) continue;
    byType[t] = (byType[t] ?? 0) + 1;
    if (me != null && r['user_id'] == me) mine = t;
  }
  return _ReactionsState(
    total: rows.length,
    byType: byType,
    mine: mine,
  );
});

/// Berechnet den neuen Zustand nach einem Toggle LOKAL (optimistisch), damit
/// die Anzeige sofort reagiert statt erst nach dem Netzwerk-Roundtrip — das
/// war die Ursache für „Likes werden nicht richtig gezählt" (Lag → wirkte, als
/// würde nichts passieren).
_ReactionsState _applyToggle(_ReactionsState s, String emoji) {
  final byType = Map<String, int>.from(s.byType);
  void dec(String t) {
    final v = (byType[t] ?? 0) - 1;
    if (v <= 0) {
      byType.remove(t);
    } else {
      byType[t] = v;
    }
  }

  if (s.mine == emoji) {
    // Gleiche Reaction → entfernen.
    dec(emoji);
    return _ReactionsState(total: s.total - 1, byType: byType, mine: null);
  }
  if (s.mine == null) {
    // Neue Reaction → hinzufügen.
    byType[emoji] = (byType[emoji] ?? 0) + 1;
    return _ReactionsState(total: s.total + 1, byType: byType, mine: emoji);
  }
  // Andere Reaction → ersetzen (Total bleibt gleich, 1 pro User).
  dec(s.mine!);
  byType[emoji] = (byType[emoji] ?? 0) + 1;
  return _ReactionsState(total: s.total, byType: byType, mine: emoji);
}

class PostReactionsButton extends ConsumerStatefulWidget {
  const PostReactionsButton({required this.postId, super.key});
  final String postId;

  @override
  ConsumerState<PostReactionsButton> createState() =>
      _PostReactionsButtonState();
}

class _PostReactionsButtonState extends ConsumerState<PostReactionsButton> {
  // Optimistischer Override — überlagert den Provider-Wert bis der Server-
  // Refetch abgeschlossen ist.
  _ReactionsState? _optimistic;

  String get postId => widget.postId;

  Future<void> _toggle(String emoji) async {
    Haptics.tap();
    // Aktuellen Stand (Override oder Provider) als Basis nehmen.
    // Expliziter Typ-Parameter + Annotation: im `??`-Kontext würde maybeWhen
    // sonst als nullable inferiert (argument_type_not_assignable).
    final _ReactionsState base = _optimistic ??
        ref.read(_reactionsStateProvider(postId)).maybeWhen<_ReactionsState>(
              data: (s) => s,
              orElse: () =>
                  const _ReactionsState(total: 0, byType: {}, mine: null),
            );
    setState(() => _optimistic = _applyToggle(base, emoji));
    await PostReactionsRepository.toggle(postId, emoji);
    // Frisch vom Server holen, dann Override auflösen.
    await ref.refresh(_reactionsStateProvider(postId).future).catchError(
          (_) => _optimistic ??
              const _ReactionsState(total: 0, byType: {}, mine: null),
        );
    if (mounted) setState(() => _optimistic = null);
  }

  void _openPicker(BuildContext context) {
    Haptics.longPress();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.sheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final e in _reactionEmojis)
                InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _toggle(e);
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.elevated,
                      shape: BoxShape.circle,
                    ),
                    child: Text(e, style: const TextStyle(fontSize: 26)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final providerState = ref.watch(_reactionsStateProvider(postId)).maybeWhen(
          data: (s) => s,
          orElse: () => const _ReactionsState(
              total: 0, byType: {}, mine: null),
        );
    final state = _optimistic ?? providerState;
    final hasMine = state.mine != null;
    // Top-2 Emojis nach Count.
    final topEmojis = state.byType.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final display = topEmojis.take(2).map((e) => e.key).toList();
    return InkWell(
      onTap: () => _toggle(state.mine ?? '❤️'),
      onLongPress: () => _openPicker(context),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (display.isEmpty)
              Text('❤️',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.mute.withValues(alpha: 0.6),
                  ))
            else
              ...display.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: Text(e, style: const TextStyle(fontSize: 14)),
                ),
              ),
            const SizedBox(width: 4),
            Text(
              '${state.total}',
              style: AppTypography.body(
                size: 12,
                color: hasMine ? AppColors.herzrotWarm : AppColors.mute,
                weight: hasMine ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
