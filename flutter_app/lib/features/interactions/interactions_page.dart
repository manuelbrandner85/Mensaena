import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../routing/routes.dart';
import '../../theme/app_colors.dart';
import '../../widgets/page_chrome.dart';
import 'interactions_repository.dart';
import 'models.dart';

class InteractionsPage extends ConsumerStatefulWidget {
  const InteractionsPage({super.key});

  @override
  ConsumerState<InteractionsPage> createState() => _InteractionsPageState();
}

class _InteractionsPageState extends ConsumerState<InteractionsPage> {
  List<Interaction> _items = [];
  bool _loading = true;
  String _filter = 'all';
  String? _busyId;

  static const _filters = [
    (value: 'all', label: 'Alle'),
    (value: 'requested', label: 'Angefragt'),
    (value: 'accepted', label: 'Angenommen'),
    (value: 'in_progress', label: 'Aktiv'),
    (value: 'completed', label: 'Erledigt'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await ref
          .read(interactionsRepositoryProvider)
          .list(filter: _filter);
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    }
  }

  Future<void> _runAction(
    Interaction it,
    Future<void> Function() op,
  ) async {
    HapticFeedback.mediumImpact();
    setState(() => _busyId = it.id);
    try {
      await op();
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  /// Öffnet ein Bottom-Sheet mit Sterne-Rating + optionalem Kommentar.
  /// Bei Submit: complete(id, notes) + rate(rating, comment) parallel.
  Future<void> _completeWithRating(Interaction it) async {
    final result = await showModalBottomSheet<_CompleteResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      builder: (_) => _CompleteSheet(partner: it.partner),
    );
    if (result == null) return;
    HapticFeedback.mediumImpact();
    setState(() => _busyId = it.id);
    try {
      final repo = ref.read(interactionsRepositoryProvider);
      await repo.complete(it.id, notes: result.note);
      // Nur bewerten, wenn Partner-ID vorhanden ist
      if (it.partner.id.isNotEmpty) {
        await repo.rate(
          interactionId: it.id,
          ratedUserId: it.partner.id,
          rating: result.rating,
          comment: result.note,
          wouldRecommend: result.rating >= 4,
        );
      }
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Abgeschlossen + Bewertung gesendet 🎉')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Interaktionen'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final f = _filters[i];
                final selected = _filter == f.value;
                return ChoiceChip(
                  label: Text(f.label),
                  selected: selected,
                  onSelected: (_) {
                    setState(() => _filter = f.value);
                    _load();
                  },
                  selectedColor: AppColors.primary500.withValues(alpha: 0.15),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const SkeletonList(count: 4)
                : _items.isEmpty
                    ? EmptyState(
                        emoji: '🤝',
                        title: _filter == 'all'
                            ? 'Noch keine Interaktionen'
                            : 'Keine Einträge in diesem Status',
                        subtitle: _filter == 'all'
                            ? 'Wenn du jemandem hilfst oder Hilfe annimmst, '
                                'erscheinen die Interaktionen hier.'
                            : 'Probier einen anderen Filter aus.',
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) => _InteractionCard(
                            it: _items[i],
                            busy: _busyId == _items[i].id,
                            onAccept: () => _runAction(
                              _items[i],
                              () => ref
                                  .read(interactionsRepositoryProvider)
                                  .respond(_items[i].id, accept: true),
                            ),
                            onDecline: () => _runAction(
                              _items[i],
                              () => ref
                                  .read(interactionsRepositoryProvider)
                                  .respond(_items[i].id, accept: false),
                            ),
                            onStart: () => _runAction(
                              _items[i],
                              () => ref
                                  .read(interactionsRepositoryProvider)
                                  .startProgress(_items[i].id),
                            ),
                            onComplete: () => _completeWithRating(_items[i]),
                            onCancel: () => _runAction(
                              _items[i],
                              () => ref
                                  .read(interactionsRepositoryProvider)
                                  .cancel(_items[i].id),
                            ),
                            onOpenChat: _items[i].conversationId != null
                                ? () => context.go(
                                      '${Routes.dashboardChat}?conv=${_items[i].conversationId}',
                                    )
                                : null,
                            onOpenPost: _items[i].post != null
                                ? () => context.go(
                                      '${Routes.dashboardPosts}/${_items[i].post!.id}',
                                    )
                                : null,
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _InteractionCard extends StatelessWidget {
  const _InteractionCard({
    required this.it,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
    required this.onStart,
    required this.onComplete,
    required this.onCancel,
    this.onOpenChat,
    this.onOpenPost,
  });

  final Interaction it;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onStart;
  final VoidCallback onComplete;
  final VoidCallback onCancel;
  final VoidCallback? onOpenChat;
  final VoidCallback? onOpenPost;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('d. MMM yyyy', 'de').format(it.createdAt);
    final partner = it.partner;
    final initial = (partner.name ?? '?').isNotEmpty
        ? partner.name![0].toUpperCase()
        : '?';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: partner.avatarUrl != null
                      ? NetworkImage(partner.avatarUrl!)
                      : null,
                  backgroundColor: AppColors.primary500.withValues(alpha: 0.2),
                  child: partner.avatarUrl == null
                      ? Text(
                          initial,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        partner.displayName(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${it.amIHelper ? 'Du hilfst' : 'Hilft dir'} · $time',
                        style: const TextStyle(
                          color: AppColors.ink400,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: it.status.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    it.status.label,
                    style: TextStyle(
                      color: it.status.color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (it.post?.title != null) ...[
              const SizedBox(height: 10),
              InkWell(
                onTap: onOpenPost,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.article_outlined,
                        size: 14,
                        color: AppColors.ink400,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          it.post!.title!,
                          style: const TextStyle(fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (onOpenPost != null)
                        const Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: AppColors.ink400,
                        ),
                    ],
                  ),
                ),
              ),
            ],
            if ((it.message ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                it.message!,
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
            ],
            const SizedBox(height: 10),
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    final buttons = <Widget>[];

    if (it.status == InteractionStatus.requested && it.amIHelper) {
      buttons.addAll([
        _btn(
          'Annehmen',
          filled: true,
          onTap: onAccept,
        ),
        _btn('Ablehnen', onTap: onDecline),
      ]);
    } else if (it.status == InteractionStatus.accepted) {
      buttons.add(_btn('Starten', filled: true, onTap: onStart));
      buttons.add(_btn('Abbrechen', onTap: onCancel));
    } else if (it.status == InteractionStatus.inProgress) {
      buttons.add(_btn('Abschließen', filled: true, onTap: onComplete));
      buttons.add(_btn('Abbrechen', onTap: onCancel));
    }

    if (onOpenChat != null) {
      buttons.add(
        _btn('Chat', icon: Icons.chat_bubble_outline, onTap: onOpenChat!),
      );
    }

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Wrap(spacing: 8, runSpacing: 8, children: buttons);
  }

  Widget _btn(
    String label, {
    bool filled = false,
    IconData? icon,
    required VoidCallback onTap,
  }) {
    final child = busy
        ? const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : icon != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [Icon(icon, size: 14), const SizedBox(width: 4), Text(label)],
              )
            : Text(label);

    return SizedBox(
      height: 32,
      child: filled
          ? FilledButton(
              onPressed: busy ? null : onTap,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary500,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: child,
            )
          : OutlinedButton(
              onPressed: busy ? null : onTap,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                foregroundColor: AppColors.ink700,
                side: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              child: child,
            ),
    );
  }
}

// ─── Complete-Sheet ──────────────────────────────────────────────────────────

class _CompleteResult {
  const _CompleteResult({required this.rating, this.note});
  final int rating;
  final String? note;
}

class _CompleteSheet extends StatefulWidget {
  const _CompleteSheet({required this.partner});
  final InteractionPartner partner;

  @override
  State<_CompleteSheet> createState() => _CompleteSheetState();
}

class _CompleteSheetState extends State<_CompleteSheet> {
  int _rating = 5;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  String get _ratingLabel {
    switch (_rating) {
      case 5:
        return 'Sehr gut – ich würde wieder helfen';
      case 4:
        return 'Gut – alles geklappt';
      case 3:
        return 'OK – ein paar Kleinigkeiten';
      case 2:
        return 'Mäßig – nicht ideal';
      case 1:
        return 'Schwierig – würde ungern wieder';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final partnerName = widget.partner.displayName();
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + inset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Text(
              '🎉 Geschafft!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Wie war die Hilfe von $partnerName?',
              style: const TextStyle(color: AppColors.ink400, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _rating = i);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      i <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 44,
                      color: i <= _rating
                          ? const Color(0xFFF59E0B)
                          : AppColors.ink400,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              _ratingLabel,
              style: const TextStyle(fontSize: 13, color: AppColors.ink700),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Notiz (optional)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: AppColors.ink400,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _note,
            maxLines: 3,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Was hat besonders gut funktioniert?',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Abbrechen'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(
                      _CompleteResult(
                        rating: _rating,
                        note: _note.text.trim().isEmpty
                            ? null
                            : _note.text.trim(),
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary500,
                    ),
                    child: const Text('Bewerten + Abschließen'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
