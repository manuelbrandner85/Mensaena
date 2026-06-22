/// SKILL: mensaena-features + mensaena-design
/// ContactRequestsManager (Schritt 10): BottomSheet fuer Post-Ersteller
/// um eingehende Anfragen zu verwalten (Annehmen/Ablehnen/Erledigt).
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../models/post_contact_request.dart';
import '../../providers/post_contact_provider.dart';
import '../../repositories/conversations_repository.dart';
import '../../services/haptics.dart';
import '../effects/celebrate_burst.dart';
import '../effects/glass_card.dart';

class ContactRequestsManager extends ConsumerWidget {
  const ContactRequestsManager({required this.postId, super.key});

  final String postId;

  static Future<void> show(BuildContext context, String postId) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scroll) => ContactRequestsManager(postId: postId),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(postContactRequestsProvider(postId));
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
            child: Row(
              children: [
                const Icon(LucideIcons.inbox,
                    size: 20, color: AppColors.bronze),
                const SizedBox(width: 8),
                Text('contact.requests.title'.tr(),
                    style: AppTypography.display(
                        size: 18, color: AppColors.ink)),
              ],
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.bronze),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (list) {
                if (list.isEmpty) {
                  return Center(
                    child: Text('contact.requests.empty'.tr(),
                        style: AppTypography.caption()),
                  );
                }
                final pending =
                    list.where((r) => r.isPending).length;
                final accepted =
                    list.where((r) => r.isAccepted).length;
                final completed =
                    list.where((r) => r.isCompleted).length;
                return Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding:
                            const EdgeInsets.fromLTRB(20, 8, 20, 20),
                        itemCount: list.length,
                        itemBuilder: (_, i) => _RequestCard(
                          req: list[i],
                          postId: postId,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: const BoxDecoration(
                        color: AppColors.elevated,
                        border: Border(
                          top: BorderSide(
                              color: AppColors.line),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceAround,
                        children: [
                          _StatusCount(
                              count: pending,
                              label: 'contact.requests.pending'.tr(),
                              color: AppColors.amber),
                          _StatusCount(
                              count: accepted,
                              label: 'contact.requests.accepted'.tr(),
                              color: AppColors.leben),
                          _StatusCount(
                              count: completed,
                              label: 'contact.requests.completed'.tr(),
                              color: AppColors.bronze),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends ConsumerWidget {
  const _RequestCard({required this.req, required this.postId});
  final PostContactRequest req;
  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Avatar(name: req.requesterName, url: req.requesterAvatar),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        req.requesterName ?? '—',
                        style: AppTypography.body(
                            size: 14,
                            color: AppColors.ink,
                            weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(_relative(req.createdAt),
                          style: AppTypography.caption()),
                    ],
                  ),
                ),
                _StatusPill(status: req.status),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(LucideIcons.atSign,
                    size: 12, color: AppColors.mute),
                const SizedBox(width: 4),
                Text(
                  '${'contact.requests.via'.tr()} ${_methodLabel(req.contactMethod)}',
                  style: AppTypography.caption(),
                ),
              ],
            ),
            if (req.message != null && req.message!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.elevated,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(req.message!,
                    style: AppTypography.body(
                        size: 13,
                        color: AppColors.inkSoft,
                        height: 1.4)),
              ),
            ],
            const SizedBox(height: 10),
            if (req.isPending) _PendingActions(req: req, postId: postId),
            if (req.isAccepted) _AcceptedActions(req: req, postId: postId),
          ],
        ),
      ),
    );
  }

  String _methodLabel(String m) {
    switch (m) {
      case 'in_app_chat':
        return 'contact.in_app_chat'.tr();
      case 'phone':
        return 'contact.phone'.tr();
      case 'email':
        return 'contact.email'.tr();
      case 'whatsapp':
        return 'contact.whatsapp'.tr();
      case 'location_meetup':
        return 'contact.location_meetup'.tr();
      default:
        return m;
    }
  }

  String _relative(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'common.justNow'.tr();
    if (diff.inMinutes < 60) {
      return 'common.minAgo'.tr(namedArgs: {'n': '${diff.inMinutes}'});
    }
    if (diff.inHours < 24) {
      return 'common.hoursAgo'.tr(namedArgs: {'n': '${diff.inHours}'});
    }
    return 'common.daysAgo'.tr(namedArgs: {'n': '${diff.inDays}'});
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({this.name, this.url});
  final String? name;
  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return CircleAvatar(
        radius: 18,
        backgroundColor: AppColors.elevated,
        backgroundImage: CachedNetworkImageProvider(url!),
      );
    }
    final letter =
        (name == null || name!.isEmpty) ? '?' : name!.substring(0, 1).toUpperCase();
    return CircleAvatar(
      radius: 18,
      backgroundColor: AppColors.elevated,
      child: Text(letter,
          style: AppTypography.display(size: 14, color: AppColors.bronze)),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;

  Color get _c {
    switch (status) {
      case 'pending':
        return AppColors.amber;
      case 'accepted':
        return AppColors.leben;
      case 'declined':
        return AppColors.herzrotWarm;
      case 'completed':
        return AppColors.bronze;
      default:
        return AppColors.mute;
    }
  }

  String get _label {
    switch (status) {
      case 'pending':
        return 'contact.requests.pending'.tr();
      case 'accepted':
        return 'contact.requests.accepted'.tr();
      case 'declined':
        return 'contact.request_declined'.tr();
      case 'completed':
        return 'contact.requests.completed'.tr();
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _c.withValues(alpha: 0.5)),
      ),
      child: Text(_label,
          style: AppTypography.body(
              size: 10, color: _c, weight: FontWeight.w700)),
    );
  }
}

class _StatusCount extends StatelessWidget {
  const _StatusCount({
    required this.count,
    required this.label,
    required this.color,
  });
  final int count;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$count',
            style: AppTypography.display(size: 18, color: color)),
        Text(label, style: AppTypography.caption()),
      ],
    );
  }
}

class _PendingActions extends ConsumerWidget {
  const _PendingActions({required this.req, required this.postId});
  final PostContactRequest req;
  final String postId;

  Future<void> _accept(BuildContext context, WidgetRef ref) async {
    Haptics.confirm();
    final ok = await ref
        .read(postContactRepositoryProvider)
        .respondToRequest(req.id, 'accepted');
    if (!ok) return;
    // Bei in_app_chat → DM erstellen (BUG1: mit postId für Post-Bezug,
    // F26: erste Nachricht ist die Auto-Kontaktkarte mit Post-Vorschau).
    if (req.contactMethod == 'in_app_chat') {
      final convId = await ConversationsRepository.getOrCreateDm(
        req.requesterId,
        postId: postId,
      );
      if (convId != null) {
        await _maybeInsertPostCard(convId);
      }
    }
    ref.invalidate(postContactRequestsProvider(postId));
    ref.invalidate(myIncomingContactRequestsProvider);
    ref.invalidate(helperCountProvider(postId));
  }

  /// F26: Erste Nachricht ist eine [POSTCARD]-Markierung. Wird vom Chat-
  /// Bubble erkannt und als Karte mit Post-Preview gerendert. Nur einfügen
  /// wenn die Konversation noch keine Messages hat (erste Begegnung).
  Future<void> _maybeInsertPostCard(String convId) async {
    try {
      if (await ConversationsRepository.hasMessages(convId)) return;
      await MessagesRepository.insertSystemNote(
        conversationId: convId,
        content: '[POSTCARD:$postId]',
      );
    } catch (_) {/* silent — fallback ist normaler leerer Chat */}
  }

  Future<void> _decline(BuildContext context, WidgetRef ref) async {
    Haptics.tap();
    await ref
        .read(postContactRepositoryProvider)
        .respondToRequest(req.id, 'declined');
    ref.invalidate(postContactRequestsProvider(postId));
    ref.invalidate(myIncomingContactRequestsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _decline(context, ref),
            icon: const Icon(LucideIcons.x, size: 14),
            label: Text('contact.requests.decline'.tr()),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.herzrotWarm,
              side: BorderSide(
                  color: AppColors.herzrotWarm.withValues(alpha: 0.5)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: FilledButton.icon(
            onPressed: () => _accept(context, ref),
            icon: const Icon(LucideIcons.check, size: 14),
            label: Text('contact.requests.accept'.tr()),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.leben,
              foregroundColor: AppColors.voidColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _AcceptedActions extends ConsumerWidget {
  const _AcceptedActions({required this.req, required this.postId});
  final PostContactRequest req;
  final String postId;

  Future<void> _complete(BuildContext context, WidgetRef ref) async {
    final ok = await ref
        .read(postContactRepositoryProvider)
        .markCompleted(req.id);
    if (!ok || !context.mounted) return;
    CelebrateBurst.fire(context, ref: ref);
    ref.invalidate(postContactRequestsProvider(postId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _complete(context, ref),
        icon: const Icon(LucideIcons.checkCheck, size: 14),
        label: Text('contact.requests.complete'.tr()),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.bronze,
          side: BorderSide(
              color: AppColors.bronze.withValues(alpha: 0.5)),
        ),
      ),
    );
  }
}
