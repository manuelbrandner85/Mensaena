import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase.dart';
import '../../theme/app_colors.dart';

/// Reaction-Pillen für PostCards / Post-Detail.
/// Pendant zu src/components/shared/PostCard.tsx (handleReaction).
/// 4 Typen: heart / thanks / support / compassion.
/// Tabelle: post_reactions (post_id, user_id, reaction_type) mit
/// unique(post_id, user_id) — d. h. ein User hat genau eine Reaction.
class PostReactionsWidget extends ConsumerStatefulWidget {
  const PostReactionsWidget({
    super.key,
    required this.postId,
    this.compact = false,
  });

  final String postId;
  final bool compact;

  @override
  ConsumerState<PostReactionsWidget> createState() =>
      _PostReactionsWidgetState();
}

class _PostReactionsWidgetState extends ConsumerState<PostReactionsWidget> {
  static const _types = [
    (value: 'heart', emoji: '❤️', label: 'Herz'),
    (value: 'thanks', emoji: '🙏', label: 'Danke'),
    (value: 'support', emoji: '💪', label: 'Stark'),
    (value: 'compassion', emoji: '🤗', label: 'Mitgefühl'),
  ];

  Map<String, int> _counts = const {};
  String? _myReaction;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final db = ref.read(supabaseProvider);
      final user = db.auth.currentUser;
      // Alle Reactions für diesen Post zählen
      final rows = await db
          .from('post_reactions')
          .select('reaction_type, user_id')
          .eq('post_id', widget.postId);
      final counts = <String, int>{};
      String? mine;
      for (final r in List<Map<String, dynamic>>.from(rows)) {
        final t = r['reaction_type'] as String?;
        if (t != null) counts[t] = (counts[t] ?? 0) + 1;
        if (user != null && r['user_id'] == user.id) mine = t;
      }
      if (!mounted) return;
      setState(() {
        _counts = counts;
        _myReaction = mine;
      });
    } catch (_) {}
  }

  Future<void> _toggle(String type) async {
    if (_busy) return;
    final db = ref.read(supabaseProvider);
    final user = db.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte einloggen, um zu reagieren')),
      );
      return;
    }
    HapticFeedback.lightImpact();
    setState(() => _busy = true);
    final wasMine = _myReaction == type;
    // Optimistic Update
    setState(() {
      if (wasMine) {
        _myReaction = null;
        _counts = {..._counts, type: ((_counts[type] ?? 1) - 1).clamp(0, 999)};
      } else {
        // Falls vorher andere Reaction war, Count dort -1
        if (_myReaction != null) {
          _counts = {
            ..._counts,
            _myReaction!: ((_counts[_myReaction!] ?? 1) - 1).clamp(0, 999),
          };
        }
        _myReaction = type;
        _counts = {..._counts, type: (_counts[type] ?? 0) + 1};
      }
    });
    try {
      if (wasMine) {
        await db
            .from('post_reactions')
            .delete()
            .eq('post_id', widget.postId)
            .eq('user_id', user.id);
      } else {
        // Upsert: ein User darf nur eine Reaction haben
        await db.from('post_reactions').upsert(
          <String, dynamic>{
            'post_id': widget.postId,
            'user_id': user.id,
            'reaction_type': type,
          },
          onConflict: 'post_id,user_id',
        );
      }
    } catch (_) {
      // Rollback bei Fehler
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: widget.compact ? 4 : 6,
      runSpacing: 4,
      children: _types.map((t) {
        final count = _counts[t.value] ?? 0;
        final mine = _myReaction == t.value;
        return _ReactionChip(
          emoji: t.emoji,
          label: t.label,
          count: count,
          selected: mine,
          compact: widget.compact,
          onTap: () => _toggle(t.value),
        );
      }).toList(),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({
    required this.emoji,
    required this.label,
    required this.count,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final int count;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primary500.withValues(alpha: 0.12)
          : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 10,
            vertical: compact ? 4 : 6,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.primary500 : AppColors.stone200,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                emoji,
                style: TextStyle(fontSize: compact ? 13 : 14),
              ),
              if (count > 0) ...[
                const SizedBox(width: 4),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: compact ? 11 : 12,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? AppColors.primary500
                        : AppColors.ink700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
