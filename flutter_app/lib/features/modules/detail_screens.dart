import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/atmosphere/cinema_scaffold.dart';
import '../../core/supabase.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/dimensions.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/cinema_appbar.dart';
import '../../core/widgets/cinema_input.dart';
import '../../core/widgets/cinema_loading_skeleton.dart';
import '../../core/widgets/cinema_progress.dart';
import '../../core/widgets/cinema_sheet.dart';
import '../../core/widgets/cinema_toast.dart';
import '../../core/widgets/glow_button.dart';
import '../../services/supabase/database_service.dart';
import '../../services/supabase/supabase_service.dart';

/// Generischer Provider fuer Detail-Screens — laedt eine Row anhand der ID.
final _byIdProvider =
    FutureProvider.family<Map<String, dynamic>?, ({String table, String id})>(
        (ref, q) async {
  final res = await supabase.client.from(q.table).select().eq('id', q.id).maybeSingle();
  return res;
});

/// Teilnahme-Status fuer Events.
final eventAttendanceProvider =
    FutureProvider.family<bool, String>((ref, eventId) async {
  final uid = supabase.userId;
  if (uid == null) return false;
  final row = await supabase.client
      .from('event_attendees')
      .select('event_id')
      .eq('event_id', eventId)
      .eq('user_id', uid)
      .maybeSingle();
  return row != null;
});

/// Anzahl Teilnehmer.
final eventAttendeesCountProvider =
    FutureProvider.family<int, String>((ref, eventId) async {
  final res = await supabase.client
      .from('event_attendees')
      .select('event_id')
      .eq('event_id', eventId);
  return (res as List).length;
});

/// Mitgliedschaft-Status fuer Gruppen.
final groupMembershipProvider =
    FutureProvider.family<bool, String>((ref, groupId) async {
  final uid = supabase.userId;
  if (uid == null) return false;
  final row = await supabase.client
      .from('group_members')
      .select('group_id')
      .eq('group_id', groupId)
      .eq('user_id', uid)
      .maybeSingle();
  return row != null;
});

/// Fortschritt fuer eine Challenge.
final challengeProgressProvider =
    FutureProvider.family<num, String>((ref, challengeId) async {
  final uid = supabase.userId;
  if (uid == null) return 0;
  final row = await supabase.client
      .from('challenge_progress')
      .select('amount')
      .eq('challenge_id', challengeId)
      .eq('user_id', uid)
      .maybeSingle();
  if (row == null) return 0;
  return (row['amount'] as num?) ?? 0;
});

// ─────────────────────────────────────────────────────────────────────
// WIKI ARTICLE
// ─────────────────────────────────────────────────────────────────────
class WikiArticleScreen extends ConsumerWidget {
  final String articleId;
  const WikiArticleScreen({super.key, required this.articleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final article = ref.watch(_byIdProvider((table: 'knowledge_articles', id: articleId)));
    final user = ref.watch(currentUserProvider);

    return CinemaScaffold(
      appBar: CinemaAppBar(
        title: 'WIKI',
        actions: [
          article.maybeWhen(
            data: (a) {
              final authorId = a?['author_id'] as String?;
              if (a == null || user == null || authorId != user.id) {
                return const SizedBox.shrink();
              }
              return IconButton(
                tooltip: 'Bearbeiten',
                icon: const Icon(LucideIcons.pencil, color: MnColors.amber, size: 20),
                onPressed: () => context.push('/modules/wissen/$articleId/edit'),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: SafeArea(
        child: article.when(
          loading: () => const CinemaLoadingSkeleton(),
          error: (e, _) => Center(child: Text('$e', style: MnTypography.body())),
          data: (a) {
            if (a == null) return Center(child: Text('Nicht gefunden', style: MnTypography.body()));
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text((a['title'] as String?) ?? '', style: MnTypography.display(size: 28)),
                const SizedBox(height: 16),
                MarkdownBody(
                  data: (a['content'] as String?) ?? '',
                  styleSheet: _mdStyle(context),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  MarkdownStyleSheet _mdStyle(BuildContext ctx) {
    return MarkdownStyleSheet(
      h1: MnTypography.display(size: 24),
      h2: MnTypography.display(size: 20),
      p: MnTypography.body(size: 16, color: MnColors.inkSoft, height: 1.7),
      code: MnTypography.mono(color: MnColors.amber),
      codeblockDecoration: BoxDecoration(
        color: MnColors.surface,
        borderRadius: BorderRadius.circular(MnDimensions.radiusInput),
      ),
      blockquoteDecoration: const BoxDecoration(
        border: Border(left: BorderSide(color: MnColors.amber, width: 3)),
      ),
      a: MnTypography.body(color: MnColors.teal),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// WIKI EDIT
// ─────────────────────────────────────────────────────────────────────
class WikiArticleEditScreen extends ConsumerStatefulWidget {
  final String articleId;
  const WikiArticleEditScreen({super.key, required this.articleId});

  @override
  ConsumerState<WikiArticleEditScreen> createState() => _WikiArticleEditScreenState();
}

class _WikiArticleEditScreenState extends ConsumerState<WikiArticleEditScreen> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final row = await supabase.client
          .from('knowledge_articles')
          .select()
          .eq('id', widget.articleId)
          .maybeSingle();
      if (row != null) {
        _titleCtrl.text = (row['title'] as String?) ?? '';
        _contentCtrl.text = (row['content'] as String?) ?? '';
      }
    } catch (e) {
      if (mounted) {
        CinemaToast.show(context, message: 'Laden fehlgeschlagen: $e', variant: ToastVariant.error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await supabase.client
          .from('knowledge_articles')
          .update({
            'title': _titleCtrl.text.trim(),
            'content': _contentCtrl.text,
          })
          .eq('id', widget.articleId);
      ref.invalidate(_byIdProvider((table: 'knowledge_articles', id: widget.articleId)));
      if (mounted) {
        CinemaToast.show(context, message: 'Gespeichert', variant: ToastVariant.success);
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        CinemaToast.show(context, message: 'Speichern fehlgeschlagen: $e', variant: ToastVariant.error);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CinemaScaffold(
      appBar: const CinemaAppBar(title: 'BEARBEITEN'),
      body: SafeArea(
        child: _loading
            ? const CinemaLoadingSkeleton()
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  CinemaInput(
                    controller: _titleCtrl,
                    label: 'Titel',
                    placeholder: 'Artikel-Titel',
                  ),
                  const SizedBox(height: 16),
                  CinemaInput(
                    controller: _contentCtrl,
                    label: 'Inhalt (Markdown)',
                    variant: CinemaInputVariant.multiline,
                    maxLines: 16,
                  ),
                  const SizedBox(height: 24),
                  GlowButton(
                    label: _saving ? 'Speichere…' : 'Speichern',
                    variant: GlowVariant.primary,
                    fullWidth: true,
                    onPressed: _saving ? null : _save,
                  ),
                ],
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// EVENT DETAIL
// ─────────────────────────────────────────────────────────────────────
class EventDetailScreen extends ConsumerWidget {
  final String eventId;
  const EventDetailScreen({super.key, required this.eventId});

  Future<void> _toggleAttendance(BuildContext context, WidgetRef ref) async {
    final uid = supabase.userId;
    if (uid == null) {
      CinemaToast.show(context, message: 'Bitte einloggen', variant: ToastVariant.warning);
      return;
    }
    final isAttending = ref.read(eventAttendanceProvider(eventId)).valueOrNull ?? false;
    try {
      if (isAttending) {
        await supabase.client
            .from('event_attendees')
            .delete()
            .eq('event_id', eventId)
            .eq('user_id', uid);
        if (context.mounted) {
          CinemaToast.show(context, message: 'Abgesagt', variant: ToastVariant.info);
        }
      } else {
        await supabase.client.from('event_attendees').insert({
          'event_id': eventId,
          'user_id': uid,
        });
        if (context.mounted) {
          CinemaToast.show(context, message: 'Du nimmst teil', variant: ToastVariant.success);
        }
      }
      ref.invalidate(eventAttendanceProvider(eventId));
      ref.invalidate(eventAttendeesCountProvider(eventId));
    } catch (e) {
      if (context.mounted) {
        CinemaToast.show(context, message: 'Fehler: $e', variant: ToastVariant.error);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final event = ref.watch(_byIdProvider((table: 'events', id: eventId)));
    final isAttending = ref.watch(eventAttendanceProvider(eventId)).valueOrNull ?? false;
    final attendeesCount = ref.watch(eventAttendeesCountProvider(eventId)).valueOrNull ?? 0;

    return CinemaScaffold(
      appBar: const CinemaAppBar(title: 'EVENT'),
      body: SafeArea(
        child: event.when(
          loading: () => const CinemaLoadingSkeleton(),
          error: (e, _) => Center(child: Text('$e', style: MnTypography.body())),
          data: (e) {
            if (e == null) return Center(child: Text('Nicht gefunden', style: MnTypography.body()));
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text((e['title'] as String?) ?? '', style: MnTypography.display(size: 24)),
                const SizedBox(height: 8),
                _row(LucideIcons.calendar, _formatDate(e['starts_at'] as String?)),
                if ((e['location'] as String?)?.isNotEmpty == true)
                  _row(LucideIcons.mapPin, e['location'] as String),
                const SizedBox(height: 16),
                Text(
                  (e['description'] as String?) ?? '',
                  style: MnTypography.body(color: MnColors.inkSoft),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Icon(LucideIcons.users, size: 16, color: MnColors.amber),
                    const SizedBox(width: 8),
                    Text(
                      '$attendeesCount nehmen teil',
                      style: MnTypography.mono(color: MnColors.amber),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                GlowButton(
                  label: isAttending ? 'Absagen' : 'Teilnehmen',
                  variant: isAttending ? GlowVariant.secondary : GlowVariant.primary,
                  fullWidth: true,
                  onPressed: () => _toggleAttendance(context, ref),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _row(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            Icon(icon, size: 16, color: MnColors.amber),
            const SizedBox(width: 8),
            Text(text, style: MnTypography.body(color: MnColors.inkSoft)),
          ],
        ),
      );

  String _formatDate(String? iso) {
    if (iso == null) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day}.${d.month}.${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

// ─────────────────────────────────────────────────────────────────────
// GROUP DETAIL
// ─────────────────────────────────────────────────────────────────────
class GroupDetailScreen extends ConsumerWidget {
  final String groupId;
  const GroupDetailScreen({super.key, required this.groupId});

  Future<void> _toggleMembership(BuildContext context, WidgetRef ref) async {
    final uid = supabase.userId;
    if (uid == null) {
      CinemaToast.show(context, message: 'Bitte einloggen', variant: ToastVariant.warning);
      return;
    }
    final isMember = ref.read(groupMembershipProvider(groupId)).valueOrNull ?? false;
    try {
      if (isMember) {
        await supabase.client
            .from('group_members')
            .delete()
            .eq('group_id', groupId)
            .eq('user_id', uid);
        if (context.mounted) {
          CinemaToast.show(context, message: 'Gruppe verlassen', variant: ToastVariant.info);
        }
      } else {
        await supabase.client.from('group_members').insert({
          'group_id': groupId,
          'user_id': uid,
        });
        if (context.mounted) {
          CinemaToast.show(context, message: 'Beigetreten', variant: ToastVariant.success);
        }
      }
      ref.invalidate(groupMembershipProvider(groupId));
    } catch (e) {
      if (context.mounted) {
        CinemaToast.show(context, message: 'Fehler: $e', variant: ToastVariant.error);
      }
    }
  }

  Future<void> _openPostSheet(BuildContext context, WidgetRef ref) async {
    final uid = supabase.userId;
    if (uid == null) return;
    final ctrl = TextEditingController();
    bool submitting = false;
    await CinemaSheet.show<void>(
      context,
      initialSize: 0.6,
      child: StatefulBuilder(
        builder: (ctx, setSheetState) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Beitrag verfassen', style: MnTypography.display(size: 20)),
            const SizedBox(height: 16),
            CinemaInput(
              controller: ctrl,
              label: 'Dein Beitrag',
              variant: CinemaInputVariant.multiline,
              maxLines: 6,
              placeholder: 'Was moechtest du der Gruppe mitteilen?',
              autofocus: true,
            ),
            const SizedBox(height: 20),
            GlowButton(
              label: submitting ? 'Sende…' : 'Posten',
              variant: GlowVariant.primary,
              fullWidth: true,
              onPressed: submitting
                  ? null
                  : () async {
                      final text = ctrl.text.trim();
                      if (text.isEmpty) return;
                      setSheetState(() => submitting = true);
                      try {
                        await supabase.client.from('group_posts').insert({
                          'group_id': groupId,
                          'user_id': uid,
                          'content': text,
                        });
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        if (context.mounted) {
                          CinemaToast.show(
                            context,
                            message: 'Beitrag veroeffentlicht',
                            variant: ToastVariant.success,
                          );
                        }
                      } catch (e) {
                        setSheetState(() => submitting = false);
                        if (context.mounted) {
                          CinemaToast.show(
                            context,
                            message: 'Fehler: $e',
                            variant: ToastVariant.error,
                          );
                        }
                      }
                    },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(_byIdProvider((table: 'groups', id: groupId)));
    final isMember = ref.watch(groupMembershipProvider(groupId)).valueOrNull ?? false;

    return CinemaScaffold(
      appBar: const CinemaAppBar(title: 'GRUPPE'),
      body: SafeArea(
        child: group.when(
          loading: () => const CinemaLoadingSkeleton(),
          error: (e, _) => Center(child: Text('$e', style: MnTypography.body())),
          data: (g) {
            if (g == null) return Center(child: Text('Nicht gefunden', style: MnTypography.body()));
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text((g['name'] as String?) ?? '', style: MnTypography.display(size: 24)),
                const SizedBox(height: 8),
                Text(
                  (g['description'] as String?) ?? '',
                  style: MnTypography.body(color: MnColors.inkSoft),
                ),
                const SizedBox(height: 24),
                GlowButton(
                  label: isMember ? 'Verlassen' : 'Beitreten',
                  variant: isMember ? GlowVariant.secondary : GlowVariant.primary,
                  fullWidth: true,
                  onPressed: () => _toggleMembership(context, ref),
                ),
                if (isMember) ...[
                  const SizedBox(height: 12),
                  GlowButton(
                    label: 'Beitrag verfassen',
                    icon: LucideIcons.edit3,
                    variant: GlowVariant.teal,
                    fullWidth: true,
                    onPressed: () => _openPostSheet(context, ref),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// MARKETPLACE
// ─────────────────────────────────────────────────────────────────────
class MarketplaceListingScreen extends ConsumerWidget {
  final String listingId;
  const MarketplaceListingScreen({super.key, required this.listingId});

  Future<void> _contactSeller(
    BuildContext context,
    WidgetRef ref,
    String? sellerId,
  ) async {
    final uid = supabase.userId;
    if (uid == null) {
      CinemaToast.show(context, message: 'Bitte einloggen', variant: ToastVariant.warning);
      return;
    }
    if (sellerId == null || sellerId.isEmpty) {
      CinemaToast.show(context, message: 'Verkaeufer unbekannt', variant: ToastVariant.error);
      return;
    }
    if (sellerId == uid) {
      CinemaToast.show(
        context,
        message: 'Das ist dein eigenes Inserat',
        variant: ToastVariant.info,
      );
      return;
    }
    try {
      final convId = await db.findOrCreateDirectConversation(uid, sellerId);
      if (context.mounted) context.push('/chat/$convId');
    } catch (e) {
      if (context.mounted) {
        CinemaToast.show(context, message: 'Fehler: $e', variant: ToastVariant.error);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listing = ref.watch(_byIdProvider((table: 'marketplace_listings', id: listingId)));
    return CinemaScaffold(
      appBar: const CinemaAppBar(title: 'MARKTPLATZ'),
      body: SafeArea(
        child: listing.when(
          loading: () => const CinemaLoadingSkeleton(),
          error: (e, _) => Center(child: Text('$e', style: MnTypography.body())),
          data: (l) {
            if (l == null) return Center(child: Text('Nicht gefunden', style: MnTypography.body()));
            final price = l['price'];
            final sellerId = (l['user_id'] ?? l['seller_id']) as String?;
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text((l['title'] as String?) ?? '', style: MnTypography.display(size: 24)),
                const SizedBox(height: 8),
                Text(
                  price == null || price == 0
                      ? 'Gratis'
                      : '${price.toString()} EUR',
                  style: MnTypography.mono(size: 28, color: MnColors.amber),
                ),
                const SizedBox(height: 16),
                Text(
                  (l['description'] as String?) ?? '',
                  style: MnTypography.body(color: MnColors.inkSoft),
                ),
                const SizedBox(height: 24),
                GlowButton(
                  label: 'Nachricht senden',
                  icon: LucideIcons.messageCircle,
                  variant: GlowVariant.primary,
                  fullWidth: true,
                  onPressed: () => _contactSeller(context, ref, sellerId),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// CHALLENGE
// ─────────────────────────────────────────────────────────────────────
class ChallengeDetailScreen extends ConsumerWidget {
  final String challengeId;
  const ChallengeDetailScreen({super.key, required this.challengeId});

  Future<void> _openProgressSheet(
    BuildContext context,
    WidgetRef ref,
    num currentProgress,
    num target,
  ) async {
    final uid = supabase.userId;
    if (uid == null) {
      CinemaToast.show(context, message: 'Bitte einloggen', variant: ToastVariant.warning);
      return;
    }
    final ctrl = TextEditingController(text: currentProgress.toString());
    bool saving = false;
    await CinemaSheet.show<void>(
      context,
      initialSize: 0.45,
      child: StatefulBuilder(
        builder: (ctx, setSheetState) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Fortschritt melden', style: MnTypography.display(size: 20)),
            const SizedBox(height: 8),
            Text(
              'Ziel: ${target.toString()}',
              style: MnTypography.body(color: MnColors.inkSoft),
            ),
            const SizedBox(height: 16),
            CinemaInput(
              controller: ctrl,
              label: 'Wieviel Fortschritt?',
              variant: CinemaInputVariant.number,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            CinemaProgress(
              value: target == 0
                  ? 0
                  : ((num.tryParse(ctrl.text) ?? 0) / target).toDouble().clamp(0.0, 1.0),
              label: '${(((num.tryParse(ctrl.text) ?? 0) / (target == 0 ? 1 : target)) * 100).round()}%',
            ),
            const SizedBox(height: 20),
            GlowButton(
              label: saving ? 'Sende…' : 'Speichern',
              variant: GlowVariant.primary,
              fullWidth: true,
              onPressed: saving
                  ? null
                  : () async {
                      final amount = num.tryParse(ctrl.text.trim());
                      if (amount == null) {
                        CinemaToast.show(
                          context,
                          message: 'Bitte Zahl eingeben',
                          variant: ToastVariant.warning,
                        );
                        return;
                      }
                      setSheetState(() => saving = true);
                      try {
                        await supabase.client.from('challenge_progress').upsert(
                          {
                            'challenge_id': challengeId,
                            'user_id': uid,
                            'amount': amount,
                          },
                          onConflict: 'challenge_id,user_id',
                        );
                        ref.invalidate(challengeProgressProvider(challengeId));
                        ref.invalidate(_byIdProvider((table: 'challenges', id: challengeId)));
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        if (context.mounted) {
                          CinemaToast.show(
                            context,
                            message: 'Fortschritt aktualisiert',
                            variant: ToastVariant.success,
                          );
                        }
                      } catch (e) {
                        setSheetState(() => saving = false);
                        if (context.mounted) {
                          CinemaToast.show(
                            context,
                            message: 'Fehler: $e',
                            variant: ToastVariant.error,
                          );
                        }
                      }
                    },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(_byIdProvider((table: 'challenges', id: challengeId)));
    final userProgress = ref.watch(challengeProgressProvider(challengeId)).valueOrNull ?? 0;

    return CinemaScaffold(
      appBar: const CinemaAppBar(title: 'CHALLENGE'),
      body: SafeArea(
        child: c.when(
          loading: () => const CinemaLoadingSkeleton(),
          error: (e, _) => Center(child: Text('$e', style: MnTypography.body())),
          data: (ch) {
            if (ch == null) return Center(child: Text('Nicht gefunden', style: MnTypography.body()));
            final target = ((ch['target'] as num?) ?? 1);
            final effective = userProgress != 0 ? userProgress : ((ch['current'] as num?) ?? 0);
            final progress = target == 0 ? 0.0 : (effective / target).toDouble();
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text((ch['title'] as String?) ?? '', style: MnTypography.display(size: 24)),
                const SizedBox(height: 8),
                Text(
                  (ch['description'] as String?) ?? '',
                  style: MnTypography.body(color: MnColors.inkSoft),
                ),
                const SizedBox(height: 20),
                Text(
                  '${(progress * 100).clamp(0, 100).round()}% erreicht',
                  style: MnTypography.mono(color: MnColors.amber),
                ),
                const SizedBox(height: 8),
                CinemaProgress(value: progress.clamp(0.0, 1.0)),
                const SizedBox(height: 24),
                GlowButton(
                  label: 'Fortschritt melden',
                  icon: LucideIcons.target,
                  variant: GlowVariant.primary,
                  fullWidth: true,
                  onPressed: () => _openProgressSheet(context, ref, effective, target),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
