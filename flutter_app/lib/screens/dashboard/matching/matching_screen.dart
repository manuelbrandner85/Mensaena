import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../widgets/shared/editorial_module_header.dart';
import '../../../models/match_summary.dart';
import '../../../repositories/matching_repository.dart';
import '../../../services/supabase_service.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

const _filters = <(String, String)>[
  ('all', 'Alle'),
  ('pending', 'Offen'),
  ('accepted', 'Akzeptiert'),
  ('completed', 'Abgeschlossen'),
];

/// SKILL: mensaena-features
/// Matching-Screen — automatische Vorschlaege fuer passende Posts.
class MatchingScreen extends ConsumerWidget {
  const MatchingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(matchingFilterProvider);
    final matchesAsync = ref.watch(matchingListProvider);
    final countsAsync = ref.watch(matchingCountsProvider);
    final prefsAsync = ref.watch(matchPreferencesProvider);
    final matchingDisabled = prefsAsync.value?.matchingEnabled == false;

    // Realtime-Sub: bei jedem Insert/Update der matches-Tabelle die Liste neu laden.
    ref.listen(matchingStreamProvider, (prev, next) {
      if (next.hasValue) {
        ref.invalidate(matchingListProvider);
        ref.invalidate(matchingCountsProvider);
      }
    });

    return DashboardScaffold(
      title: 'Matching',
      currentRoute: '/dashboard/matching',
      fab: FloatingActionButton(
        backgroundColor: AppColors.amber,
        foregroundColor: AppColors.voidColor,
        onPressed: () => _openPreferences(context, ref),
        child: const Icon(LucideIcons.settings),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.amber,
          backgroundColor: AppColors.surface,
          onRefresh: () async {
            ref.invalidate(matchingListProvider);
            ref.invalidate(matchingCountsProvider);
            ref.invalidate(matchPreferencesProvider);
            await ref.read(matchingListProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const EditorialModuleHeader(
                metaIndex: '§ 10',
                metaCategory: 'Matching',
                title: 'Smart-Match',
                subtitle: 'KI-Vorschlaege fuer passende Beitraege',
              ),
              _header(
                countsAsync.value ?? const MatchCounts.empty(),
                onRefresh: () {
                  ref.invalidate(matchingListProvider);
                  ref.invalidate(matchingCountsProvider);
                },
                onOpenPrefs: () => _openPreferences(context, ref),
              ),
              const SizedBox(height: 14),
              if (matchingDisabled) ...[
                _disabledBanner(context, ref),
                const SizedBox(height: 12),
              ],
              _FilterBar(active: filter),
              const SizedBox(height: 14),
              matchesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                    child:
                        CircularProgressIndicator(color: AppColors.amber),
                  ),
                ),
                error: (_, __) => _empty('Fehler beim Laden.'),
                data: (matches) {
                  if (matches.isEmpty) {
                    return _empty(filter == 'all'
                        ? 'Noch keine Matches.'
                        : 'Keine Matches in dieser Kategorie.');
                  }
                  return Column(
                    children: matches
                        .map((m) => _MatchCard(
                              match: m,
                              onTap: () =>
                                  _openDetail(context, ref, m),
                              onAccept: () => _respond(context, ref, m, true),
                              onDecline: () =>
                                  _respond(context, ref, m, false),
                              onOpenChat: m.conversationId != null
                                  ? () => context.go(
                                      '/dashboard/chat?conv=${m.conversationId}')
                                  : null,
                            ))
                        .toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _disabledBanner(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.10),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.bellOff,
              color: AppColors.amber, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Matching ist deaktiviert',
                    style: AppTypography.body(
                      size: 13,
                      color: AppColors.amber,
                      weight: FontWeight.w700,
                    )),
                Text(
                  'Aktiviere Matching in den Einstellungen, um Vorschläge zu erhalten.',
                  style: AppTypography.caption(),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _openPreferences(context, ref),
            child: Text('Öffnen',
                style: AppTypography.label(
                    size: 10, color: AppColors.amber)),
          ),
        ],
      ),
    );
  }

  void _openDetail(
      BuildContext context, WidgetRef ref, MatchSummary m) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _MatchDetailSheet(
        match: m,
        onAccept: () async {
          Navigator.pop(context);
          await _respond(context, ref, m, true);
        },
        onDecline: () async {
          Navigator.pop(context);
          await _respond(context, ref, m, false);
        },
        onOpenChat: m.conversationId != null
            ? () {
                Navigator.pop(context);
                context
                    .go('/dashboard/chat?conv=${m.conversationId}');
              }
            : null,
      ),
    );
  }

  void _openPreferences(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PreferencesSheet(
        onSaved: () {
          ref.invalidate(matchPreferencesProvider);
          ref.invalidate(matchingListProvider);
        },
      ),
    );
  }

  Widget _header(
    MatchCounts c, {
    required VoidCallback onRefresh,
    required VoidCallback onOpenPrefs,
  }) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.teal.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(LucideIcons.sparkles,
              color: AppColors.tealSoft, size: 22),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Matching',
                  style: AppTypography.display(
                    size: 22,
                    color: AppColors.ink,
                  )),
              Text(
                'Vorschläge für passende Angebote & Gesuche.',
                style: AppTypography.caption(),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(LucideIcons.refreshCw,
              size: 16, color: AppColors.mute),
          onPressed: onRefresh,
        ),
        _stat('Offen', c.pending, AppColors.amber),
        const SizedBox(width: 6),
        _stat('Aktiv', c.accepted, AppColors.lebenSoft),
      ],
    );
  }

  Widget _stat(String label, int n, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            '$n',
            style: AppTypography.mono(size: 14, color: color),
          ),
          Text(
            label,
            style: AppTypography.label(size: 8, color: color),
          ),
        ],
      ),
    );
  }

  Widget _empty(String msg) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.4),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Icon(LucideIcons.sparkles,
              size: 28, color: AppColors.mute),
          const SizedBox(height: 10),
          Text(
            msg,
            textAlign: TextAlign.center,
            style: AppTypography.body(
              size: 13,
              color: AppColors.inkSoft,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _respond(
    BuildContext context,
    WidgetRef ref,
    MatchSummary m,
    bool accept,
  ) async {
    final result = await MatchingRepository.respond(
      matchId: m.id,
      accept: accept,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.surface,
      content: Text(
        result.success
            ? (accept
                ? (result.conversationId != null
                    ? 'Match akzeptiert — Chat eröffnet.'
                    : 'Du hast zugestimmt. Warte auf Gegenseite.')
                : 'Match abgelehnt.')
            : 'Fehler: ${result.error ?? 'unbekannt'}',
        style: AppTypography.body(size: 13, color: AppColors.ink),
      ),
    ));
    if (result.success) {
      ref.invalidate(matchingListProvider);
      ref.invalidate(matchingCountsProvider);
      if (accept && result.conversationId != null && context.mounted) {
        context.go('/dashboard/chat?conv=${result.conversationId}');
      }
    }
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.active});
  final String active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (val, label) in _filters) ...[
            GestureDetector(
              onTap: () =>
                  ref.read(matchingFilterProvider.notifier).state = val,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: active == val
                      ? AppColors.amber.withValues(alpha: 0.18)
                      : AppColors.elevated,
                  border: Border.all(
                    color: active == val
                        ? AppColors.amber.withValues(alpha: 0.6)
                        : AppColors.line,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  label,
                  style: AppTypography.label(
                    size: 10,
                    color: active == val
                        ? AppColors.amber
                        : AppColors.inkSoft,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({
    required this.match,
    required this.onAccept,
    required this.onDecline,
    this.onTap,
    this.onOpenChat,
  });

  final MatchSummary match;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback? onTap;
  final VoidCallback? onOpenChat;

  @override
  Widget build(BuildContext context) {
    final uid = SupabaseService.currentUser?.id;
    final iAmOffer = uid == match.offerUserId;
    final myPost = iAmOffer ? match.offerPost : match.requestPost;
    final theirPost = iAmOffer ? match.requestPost : match.offerPost;
    final theirUser = iAmOffer ? match.requestUser : match.offerUser;
    final myResponded = iAmOffer
        ? (match.offerAccepted != null)
        : (match.requestAccepted != null);
    final scorePct = (match.matchScore * 100).clamp(0, 100).toInt();

    final card = Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('$scorePct% Match',
                    style: AppTypography.label(
                      size: 9,
                      color: AppColors.tealSoft,
                    )),
              ),
              const SizedBox(width: 6),
              if (match.distanceKm != null)
                Text('${match.distanceKm!.toStringAsFixed(1)} km',
                    style: AppTypography.label(size: 9)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _statusBg(match.status),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  match.status,
                  style: AppTypography.label(
                    size: 8,
                    color: _statusFg(match.status),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _PostRow(
            label: 'Du',
            title: myPost.title,
            type: myPost.type,
            color: AppColors.amber,
          ),
          const SizedBox(height: 6),
          const Center(
            child: Icon(LucideIcons.arrowDown,
                size: 14, color: AppColors.mute),
          ),
          const SizedBox(height: 6),
          _PostRow(
            label: theirUser.name ?? 'Anonym',
            title: theirPost.title,
            type: theirPost.type,
            color: AppColors.tealSoft,
          ),
          const SizedBox(height: 12),
          if (match.status == 'accepted' && match.conversationId != null)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.amber,
                  foregroundColor: AppColors.voidColor,
                ),
                onPressed: onOpenChat,
                icon: const Icon(LucideIcons.messageCircle, size: 16),
                label: const Text('Chat öffnen'),
              ),
            )
          else if (!myResponded)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.herzrotWarm,
                      side: BorderSide(
                          color:
                              AppColors.herzrot.withValues(alpha: 0.5)),
                    ),
                    onPressed: onDecline,
                    icon:
                        const Icon(LucideIcons.x, size: 14),
                    label: const Text('Ablehnen'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.leben,
                      foregroundColor: AppColors.voidColor,
                    ),
                    onPressed: onAccept,
                    icon: const Icon(LucideIcons.check, size: 14),
                    label: const Text('Annehmen'),
                  ),
                ),
              ],
            )
          else
            Text(
              'Du hast geantwortet. Warten auf Gegenseite.',
              style: AppTypography.caption(),
            ),
        ],
      ),
    );

    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: card,
    );
  }

  Color _statusBg(String s) {
    switch (s) {
      case 'accepted':
        return AppColors.leben.withValues(alpha: 0.18);
      case 'completed':
        return AppColors.amber.withValues(alpha: 0.18);
      case 'declined':
        return AppColors.herzrot.withValues(alpha: 0.18);
      default:
        return AppColors.elevated;
    }
  }

  Color _statusFg(String s) {
    switch (s) {
      case 'accepted':
        return AppColors.lebenSoft;
      case 'completed':
        return AppColors.amber;
      case 'declined':
        return AppColors.herzrotWarm;
      default:
        return AppColors.inkSoft;
    }
  }
}

class _PostRow extends StatelessWidget {
  const _PostRow({
    required this.label,
    required this.title,
    required this.type,
    required this.color,
  });

  final String label;
  final String title;
  final String type;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.elevated.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Text(
              label.isNotEmpty ? label[0].toUpperCase() : '?',
              style: AppTypography.mono(size: 12, color: color),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.label(size: 9, color: color),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(
                    size: 13,
                    color: AppColors.ink,
                    weight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (type.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.elevated,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(type, style: AppTypography.label(size: 8)),
            ),
        ],
      ),
    );
  }
}

class _MatchDetailSheet extends StatelessWidget {
  const _MatchDetailSheet({
    required this.match,
    required this.onAccept,
    required this.onDecline,
    this.onOpenChat,
  });

  final MatchSummary match;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback? onOpenChat;

  @override
  Widget build(BuildContext context) {
    final uid = SupabaseService.currentUser?.id;
    final iAmOffer = uid == match.offerUserId;
    final myPost = iAmOffer ? match.offerPost : match.requestPost;
    final theirPost = iAmOffer ? match.requestPost : match.offerPost;
    final theirUser = iAmOffer ? match.requestUser : match.offerUser;
    final myResponded = iAmOffer
        ? (match.offerAccepted != null)
        : (match.requestAccepted != null);
    final scorePct = (match.matchScore * 100).clamp(0, 100).toInt();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (ctx, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.all(20),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('$scorePct% Match',
                    style: AppTypography.label(
                        size: 10, color: AppColors.tealSoft)),
              ),
              const SizedBox(width: 8),
              if (match.distanceKm != null)
                Text('${match.distanceKm!.toStringAsFixed(1)} km',
                    style: AppTypography.label(size: 10)),
            ],
          ),
          const SizedBox(height: 16),
          _detailSection('Dein Beitrag', myPost.title, myPost.type,
              myPost.description, myPost.location, AppColors.amber),
          const SizedBox(height: 12),
          _detailSection(
            theirUser.name ?? 'Anonym',
            theirPost.title,
            theirPost.type,
            theirPost.description,
            theirPost.location,
            AppColors.tealSoft,
          ),
          const SizedBox(height: 12),
          if (match.scoreBreakdown.isNotEmpty) _scoreBreakdown(match),
          const SizedBox(height: 20),
          if (match.status == 'accepted' && match.conversationId != null)
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.amber,
                foregroundColor: AppColors.voidColor,
              ),
              onPressed: onOpenChat,
              icon: const Icon(LucideIcons.messageCircle, size: 16),
              label: const Text('Chat öffnen'),
            )
          else if (!myResponded)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.herzrotWarm,
                      side: BorderSide(
                          color:
                              AppColors.herzrot.withValues(alpha: 0.5)),
                    ),
                    onPressed: onDecline,
                    icon: const Icon(LucideIcons.x, size: 14),
                    label: const Text('Ablehnen'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.leben,
                      foregroundColor: AppColors.voidColor,
                    ),
                    onPressed: onAccept,
                    icon: const Icon(LucideIcons.check, size: 14),
                    label: const Text('Annehmen'),
                  ),
                ),
              ],
            )
          else
            Text(
              'Du hast geantwortet. Warte auf die andere Seite.',
              style: AppTypography.caption(),
            ),
        ],
      ),
    );
  }

  Widget _detailSection(
    String label,
    String title,
    String type,
    String? description,
    String? location,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.elevated.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.label(size: 9, color: color)),
          const SizedBox(height: 6),
          Text(title,
              style: AppTypography.body(
                size: 15,
                color: AppColors.ink,
                weight: FontWeight.w700,
                height: 1.3,
              )),
          if (type.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(type, style: AppTypography.label(size: 9)),
          ],
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(description,
                style: AppTypography.body(
                  size: 13,
                  color: AppColors.inkSoft,
                  height: 1.5,
                )),
          ],
          if (location != null && location.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(LucideIcons.mapPin,
                    size: 11, color: AppColors.mute),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(location, style: AppTypography.caption()),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _scoreBreakdown(MatchSummary m) {
    final b = m.scoreBreakdown;
    final rows = <(String, double)>[
      ('Kategorie', (b['category_match'] as num?)?.toDouble() ?? 0.0),
      ('Distanz', (b['distance_score'] as num?)?.toDouble() ?? 0.0),
      ('Vertrauen', (b['trust_score'] as num?)?.toDouble() ?? 0.0),
      ('Verfügbarkeit',
          (b['availability_score'] as num?)?.toDouble() ?? 0.0),
      ('Aktivität', (b['activity_score'] as num?)?.toDouble() ?? 0.0),
    ];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Match-Aufschlüsselung',
              style: AppTypography.label(size: 10)),
          const SizedBox(height: 8),
          for (final r in rows) ...[
            Row(
              children: [
                SizedBox(
                  width: 100,
                  child: Text(r.$1, style: AppTypography.caption()),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: r.$2.clamp(0.0, 1.0),
                      minHeight: 4,
                      backgroundColor: AppColors.elevated,
                      valueColor: const AlwaysStoppedAnimation(
                          AppColors.tealSoft),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 30,
                  child: Text('${(r.$2 * 100).toInt()}',
                      textAlign: TextAlign.right,
                      style: AppTypography.mono(
                          size: 10, color: AppColors.inkSoft)),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

class _PreferencesSheet extends ConsumerStatefulWidget {
  const _PreferencesSheet({required this.onSaved});
  final VoidCallback onSaved;

  @override
  ConsumerState<_PreferencesSheet> createState() =>
      _PreferencesSheetState();
}

class _PreferencesSheetState extends ConsumerState<_PreferencesSheet> {
  MatchPreferences? _prefs;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    MatchingRepository.fetchPreferences().then((p) {
      if (mounted) setState(() => _prefs = p);
    });
  }

  Future<void> _save() async {
    if (_prefs == null) return;
    setState(() => _saving = true);
    final ok = await MatchingRepository.savePreferences(_prefs!);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.surface,
      content: Text(
        ok ? 'Gespeichert.' : 'Speichern fehlgeschlagen.',
        style: AppTypography.body(size: 13, color: AppColors.ink),
      ),
    ));
    if (ok) {
      widget.onSaved();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _prefs;
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (ctx, scroll) => p == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.amber),
            )
          : ListView(
              controller: scroll,
              padding: const EdgeInsets.all(20),
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
                Text('Matching-Einstellungen',
                    style: AppTypography.display(
                        size: 20, color: AppColors.ink)),
                const SizedBox(height: 14),
                SwitchListTile(
                  value: p.matchingEnabled,
                  onChanged: (v) => setState(() {
                    _prefs = p.copyWith(matchingEnabled: v);
                  }),
                  activeColor: AppColors.amber,
                  contentPadding: EdgeInsets.zero,
                  title: Text('Matching aktivieren',
                      style: AppTypography.body(
                        size: 14,
                        color: AppColors.ink,
                        weight: FontWeight.w600,
                      )),
                  subtitle: Text(
                    'Wir suchen automatisch nach passenden Beiträgen.',
                    style: AppTypography.caption(),
                  ),
                ),
                SwitchListTile(
                  value: p.notifyOnMatch,
                  onChanged: (v) => setState(() {
                    _prefs = p.copyWith(notifyOnMatch: v);
                  }),
                  activeColor: AppColors.amber,
                  contentPadding: EdgeInsets.zero,
                  title: Text('Benachrichtigungen',
                      style: AppTypography.body(
                        size: 14,
                        color: AppColors.ink,
                        weight: FontWeight.w600,
                      )),
                  subtitle: Text(
                    'Push wenn ein neuer Match gefunden wird.',
                    style: AppTypography.caption(),
                  ),
                ),
                const SizedBox(height: 14),
                Text('Maximaler Umkreis: ${p.maxDistanceKm} km',
                    style: AppTypography.label(size: 10)),
                Slider(
                  value: p.maxDistanceKm.toDouble(),
                  min: 5,
                  max: 200,
                  divisions: 39,
                  activeColor: AppColors.amber,
                  inactiveColor: AppColors.elevated,
                  label: '${p.maxDistanceKm} km',
                  onChanged: (v) => setState(() {
                    _prefs = p.copyWith(maxDistanceKm: v.round());
                  }),
                ),
                const SizedBox(height: 6),
                Text('Max. Matches pro Tag: ${p.maxMatchesPerDay}',
                    style: AppTypography.label(size: 10)),
                Slider(
                  value: p.maxMatchesPerDay.toDouble(),
                  min: 1,
                  max: 20,
                  divisions: 19,
                  activeColor: AppColors.amber,
                  inactiveColor: AppColors.elevated,
                  label: '${p.maxMatchesPerDay}',
                  onChanged: (v) => setState(() {
                    _prefs = p.copyWith(maxMatchesPerDay: v.round());
                  }),
                ),
                const SizedBox(height: 6),
                Text('Mindest-Vertrauenswert: ${p.minTrustScore}',
                    style: AppTypography.label(size: 10)),
                Slider(
                  value: p.minTrustScore.toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 20,
                  activeColor: AppColors.amber,
                  inactiveColor: AppColors.elevated,
                  label: '${p.minTrustScore}',
                  onChanged: (v) => setState(() {
                    _prefs = p.copyWith(minTrustScore: v.round());
                  }),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.amber,
                    foregroundColor: AppColors.voidColor,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.voidColor,
                          ),
                        )
                      : const Text('Speichern'),
                ),
              ],
            ),
    );
  }
}
