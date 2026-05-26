/// SKILL: mensaena-features (P2) — @-Mentions Autocomplete im Chat.
/// Erkennt "@..." am Caret-Position, zeigt Overlay mit Teilnehmern.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/supabase_service.dart';

final _membersProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, conversationId) async {
  try {
    final rows = await sb
        .from('conversation_members')
        .select('user_id, profiles!inner(id, display_name, avatar_url)')
        .eq('conversation_id', conversationId)
        .limit(100);
    return (rows as List)
        .whereType<Map<String, dynamic>>()
        .map((r) => Map<String, dynamic>.from(r['profiles'] as Map))
        .toList();
  } catch (_) {
    return const [];
  }
});

class MentionsAutocomplete extends ConsumerWidget {
  const MentionsAutocomplete({
    required this.controller,
    required this.conversationId,
    super.key,
  });

  final TextEditingController controller;
  final String conversationId;

  /// Liefert das gerade getippte "@..." Token am Caret oder null.
  String? _activeToken() {
    final text = controller.text;
    final sel = controller.selection;
    if (!sel.isValid || sel.baseOffset != sel.extentOffset) return null;
    final caret = sel.baseOffset;
    if (caret <= 0 || caret > text.length) return null;
    final before = text.substring(0, caret);
    final atIdx = before.lastIndexOf('@');
    if (atIdx < 0) return null;
    if (atIdx > 0) {
      final prev = before[atIdx - 1];
      if (prev != ' ' && prev != '\n') return null;
    }
    final token = before.substring(atIdx + 1);
    if (token.contains(' ') || token.contains('\n')) return null;
    return token;
  }

  void _insert(Map<String, dynamic> profile) {
    final text = controller.text;
    final sel = controller.selection;
    if (!sel.isValid) return;
    final caret = sel.baseOffset;
    final before = text.substring(0, caret);
    final atIdx = before.lastIndexOf('@');
    if (atIdx < 0) return;
    final name = (profile['display_name'] as String?) ?? 'user';
    final replacement = '@$name ';
    final newText = text.substring(0, atIdx) + replacement + text.substring(caret);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
          offset: atIdx + replacement.length),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final token = _activeToken();
        if (token == null) return const SizedBox.shrink();
        return ref.watch(_membersProvider(conversationId)).maybeWhen(
              data: (members) {
                final lower = token.toLowerCase();
                final matches = members.where((m) {
                  final name =
                      ((m['display_name'] as String?) ?? '').toLowerCase();
                  return name.startsWith(lower);
                }).take(5).toList();
                if (matches.isEmpty) return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.line),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: matches
                        .map((m) => InkWell(
                              onTap: () => _insert(m),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                child: Row(
                                  children: [
                                    ClipOval(
                                      child: (m['avatar_url'] as String?) != null
                                          ? CachedNetworkImage(
                                              imageUrl:
                                                  m['avatar_url'] as String,
                                              width: 24,
                                              height: 24,
                                              fit: BoxFit.cover,
                                              errorWidget: (_, __, ___) =>
                                                  _fallback(m),
                                            )
                                          : _fallback(m),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        (m['display_name'] as String?) ??
                                            'mensaena',
                                        style: AppTypography.body(
                                            size: 14,
                                            color: AppColors.ink,
                                            weight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                );
              },
              orElse: () => const SizedBox.shrink(),
            );
      },
    );
  }

  Widget _fallback(Map<String, dynamic> profile) {
    final name = (profile['display_name'] as String?) ?? '?';
    return Container(
      width: 24,
      height: 24,
      color: AppColors.elevated,
      alignment: Alignment.center,
      child: Text(name[0].toUpperCase(),
          style: AppTypography.body(
              size: 12, color: AppColors.ink, weight: FontWeight.w700)),
    );
  }
}
