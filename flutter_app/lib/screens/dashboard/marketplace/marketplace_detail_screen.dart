import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../models/marketplace_listing.dart';
import '../../../repositories/marketplace_repository.dart';
import '../../../services/haptics.dart';
import '../../../services/supabase_service.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../../widgets/effects/shimmer_skeleton.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';
import '../../../widgets/marketplace/barter_matches_carousel.dart';
import '../../../widgets/marketplace_reservation.dart';
import '../../../widgets/shared/image_carousel.dart';

class MarketplaceDetailScreen extends ConsumerWidget {
  const MarketplaceDetailScreen({required this.listingId, super.key});
  final String listingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(marketplaceDetailProvider(listingId));
    return DashboardScaffold(
      title: 'marketplace.listing'.tr(),
      currentRoute: '/dashboard/marketplace',
      body: SafeArea(
        child: async.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.amber),
          ),
          error: (e, _) => Center(child: Text('$e', style: AppTypography.caption())),
          data: (l) {
            if (l == null) {
              return Center(
                child: Text('marketplace.listingNotFound'.tr(),
                    style: AppTypography.caption()),
              );
            }
            final me = SupabaseService.currentUser?.id;
            final ownerId = l.userId.isNotEmpty
                ? l.userId
                : (l.sellerId ?? '');
            final isOwner = me != null && me == ownerId;
            final isClaimed = l.status == 'claimed' || l.status == 'sold';

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildHero(l, isClaimed),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.amber.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(l.listingType.toUpperCase(),
                          style: AppTypography.label(size: 9)),
                    ),
                    const SizedBox(width: 6),
                    Text(l.category, style: AppTypography.label(size: 9)),
                    const Spacer(),
                    if (l.price != null)
                      Text(
                        '${l.price!.toStringAsFixed(0)} €',
                        style: AppTypography.mono(
                          size: 18,
                          color: AppColors.amber,
                          weight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  l.title,
                  style: AppTypography.display(
                    size: 24,
                    color: AppColors.ink,
                    height: 1.2,
                  ),
                ),
                if (l.conditionState != null) ...[
                  const SizedBox(height: 6),
                  Text(
                      'marketplace.condition'.tr(
                          namedArgs: {'state': l.conditionState!}),
                      style: AppTypography.caption()),
                ],
                const SizedBox(height: 12),
                Text(
                  l.description,
                  style: AppTypography.body(
                    size: 14,
                    color: AppColors.inkSoft,
                    height: 1.55,
                  ),
                ),
                if (l.locationText != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(LucideIcons.mapPin,
                          size: 14, color: AppColors.amber),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(l.locationText!,
                            style: AppTypography.body(
                              size: 13,
                              color: AppColors.inkSoft,
                            )),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                // Reservation-Widget (4 Konstellationen).
                MarketplaceReservation(
                  listingId: l.id,
                  ownerId: ownerId,
                  reservedFor: l.reservedFor,
                ),
                // F67: Tausch-Matches in derselben Kategorie (nur bei
                // listing_type='tauschen').
                BarterMatchesCarousel(
                  listingId: l.id,
                  category: l.category,
                  listingType: l.listingType,
                ),
                const SizedBox(height: 14),
                // Action-Bar
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.bronze,
                          foregroundColor: AppColors.voidColor,
                        ),
                        onPressed: () =>
                            _contactSeller(context, ref, l),
                        icon: const Icon(
                            LucideIcons.messageCircle,
                            size: 16),
                        label: Text('marketplace.contact'.tr()),
                      ),
                    ),
                    if (!isOwner && l.status == 'active') ...[
                      const SizedBox(width: 8),
                      _CircleIconButton(
                        icon: LucideIcons.bookmark,
                        onTap: () => _reserveAsBuyer(context, ref, l),
                      ),
                    ],
                    const SizedBox(width: 8),
                    _CircleIconButton(
                      icon: LucideIcons.share2,
                      onTap: () => _share(l),
                    ),
                    const SizedBox(width: 8),
                    _SaveButton(listingId: l.id),
                  ],
                ),
                // Owner-Aktionen (nur sichtbar, wenn aktiv & nicht reserved).
                if (isOwner &&
                    l.status == 'active' &&
                    l.reservedFor == null) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => _reserveDirect(context, ref, l),
                    icon: const Icon(LucideIcons.bookmark, size: 14),
                    label: Text('marketplace.reservation.reserveBtn'.tr()),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.amber,
                      side: BorderSide(
                        color: AppColors.amber.withValues(alpha: 0.5),
                      ),
                      minimumSize: const Size.fromHeight(44),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => _markClaimed(context, ref, l),
                    icon: const Icon(LucideIcons.checkCircle, size: 14),
                    label: Text('marketplace.claimedBadge'.tr()),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.herzrot,
                      foregroundColor: AppColors.ink,
                      minimumSize: const Size.fromHeight(44),
                    ),
                  ),
                ],
                if (l.status == 'reserved' && !isOwner) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.amber.withValues(alpha: 0.10),
                      border: Border.all(
                          color: AppColors.amber
                              .withValues(alpha: 0.4)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.lock,
                            size: 14,
                            color: AppColors.amber),
                        const SizedBox(width: 8),
                        Text('marketplace.reserved'.tr(),
                            style: AppTypography.label(
                                size: 10,
                                color: AppColors.amber)),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Text(
                  'marketplace.postedOn'.tr(namedArgs: {
                    'date': DateFormat('dd.MM.yyyy').format(l.createdAt),
                  }),
                  style: AppTypography.caption(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Hero-Bereich: Carousel falls >1 Bild, sonst Single-Image-Hero.
  /// Bei status=claimed/sold zusätzlich BackdropFilter + Badge.
  Widget _buildHero(MarketplaceListing l, bool isClaimed) {
    Widget? base;
    if (l.images.length > 1) {
      base = Hero(
        tag: 'marketplace-image-${l.id}',
        child: ImageCarousel(
          urls: l.images,
          height: 280,
          borderRadius: 0,
        ),
      );
    } else if (l.images.isNotEmpty) {
      base = SizedBox(
        height: 240,
        child: Hero(
          tag: 'marketplace-image-${l.id}',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: CachedNetworkImage(
              imageUrl: l.images.first,
              fadeInDuration: const Duration(milliseconds: 200),
              fit: BoxFit.cover,
              width: double.infinity,
              placeholder: (_, __) => const ShimmerBox(
                width: double.infinity,
                height: 240,
                borderRadius: 14,
              ),
              errorWidget: (_, __, ___) => Container(
                color: AppColors.elevated,
                alignment: Alignment.center,
                child: const Icon(LucideIcons.imageOff,
                    size: 20, color: AppColors.mute),
              ),
            ),
          ),
        ),
      );
    }
    if (base == null) {
      return const SizedBox.shrink();
    }
    if (!isClaimed) return base;
    // Claimed-Overlay: blur + zentrale herzrote Badge.
    return ClipRRect(
      borderRadius: BorderRadius.circular(l.images.length > 1 ? 0 : 14),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          base,
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                color: Colors.black.withValues(alpha: 0.15),
                alignment: Alignment.center,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.herzrot.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'marketplace.claimedBadge'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _contactSeller(
      BuildContext context, WidgetRef ref, MarketplaceListing l) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null || uid == l.userId) return;
    try {
      // Suche/create Conversation
      final convs = await sb
          .from('conversation_members')
          .select('conversation_id')
          .eq('user_id', uid);
      final existing = (convs as List)
          .whereType<Map<String, dynamic>>()
          .map((r) => r['conversation_id'] as String)
          .toSet();
      final peerConvs = await sb
          .from('conversation_members')
          .select('conversation_id')
          .eq('user_id', l.userId);
      final peer = (peerConvs as List)
          .whereType<Map<String, dynamic>>()
          .map((r) => r['conversation_id'] as String)
          .toSet();
      final shared = existing.intersection(peer);
      String convId;
      if (shared.isNotEmpty) {
        convId = shared.first;
      } else {
        final inserted = await sb
            .from('conversations')
            .insert({
              'title': 'marketplace.chatTitle'.tr(namedArgs: {
                'title': l.title.length > 40
                    ? '${l.title.substring(0, 40)}...'
                    : l.title,
              }),
            })
            .select()
            .maybeSingle();
        if (inserted == null) throw StateError('insert_blocked');
        convId = inserted['id'] as String;
        await sb.from('conversation_members').insert([
          {'conversation_id': convId, 'user_id': uid},
          {'conversation_id': convId, 'user_id': l.userId},
        ]);
      }
      if (!context.mounted) return;
      context.go('/dashboard/chat?conv=$convId');
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text('marketplace.contactFailed'.tr(),
            style: AppTypography.body(
                size: 13, color: AppColors.ink)),
      ));
    }
  }

  Future<void> _share(MarketplaceListing l) async {
    await Share.share(
      'marketplace.shareBody'.tr(namedArgs: {
        'title': l.title,
        'url': 'https://www.mensaena.de/dashboard/marketplace/${l.id}',
      }),
      subject: 'marketplace.shareSubject'
          .tr(namedArgs: {'title': l.title}),
    );
  }

  /// Käufer-Aktion: Reservierungs-Anfrage mit optionaler Nachricht.
  Future<void> _reserveAsBuyer(
      BuildContext context, WidgetRef ref, MarketplaceListing l) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return;
    final msgCtrl = TextEditingController();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xF0121A28),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: 20 + MediaQuery.of(sheetCtx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(LucideIcons.bookmark,
                    size: 18, color: AppColors.bronze),
                const SizedBox(width: 8),
                Text('marketplace.reserve_request'.tr(),
                    style: AppTypography.display(
                        size: 18, color: AppColors.ink)),
              ]),
              const SizedBox(height: 6),
              Text('marketplace.reserve_hint'.tr(),
                  style: AppTypography.body(
                      size: 12, color: AppColors.inkSoft, height: 1.4)),
              const SizedBox(height: 12),
              TextField(
                controller: msgCtrl,
                maxLines: 4,
                maxLength: 500,
                decoration: InputDecoration(
                    labelText: 'marketplace.reserve_message'.tr(),
                    border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => Navigator.pop(sheetCtx, true),
                icon: const Icon(LucideIcons.send, size: 14),
                label: Text('marketplace.reserve_send'.tr()),
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.bronze,
                    foregroundColor: AppColors.voidColor,
                    minimumSize: const Size.fromHeight(44)),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await sb.from('marketplace_reservations').insert({
        'listing_id': l.id,
        'user_id': uid,
        'message': msgCtrl.text.trim().isEmpty ? null : msgCtrl.text.trim(),
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text('marketplace.reserve_sent'.tr(),
            style: AppTypography.body(size: 13, color: AppColors.ink)),
      ));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text('marketplace.reserve_failed'.tr(),
            style: AppTypography.body(size: 13, color: AppColors.ink)),
      ));
    }
  }

  /// Owner-Aktion: Direkt-Reservierung (vereinfachter Flow).
  /// Setzt status='claimed' (= vergeben) ohne User-Selektion.
  Future<void> _reserveDirect(
      BuildContext context, WidgetRef ref, MarketplaceListing l) async {
    final ok = await ConfirmDialog.show(
      context,
      title: 'marketplace.markAsSoldQuestion'.tr(),
      message: 'marketplace.markAsSoldDescription'.tr(),
      confirmLabel: 'marketplace.markSold'.tr(),
    );
    if (!ok) return;
    final success = await MarketplaceRepository.markAsClaimed(l.id);
    if (!context.mounted) return;
    if (success) {
      ref.invalidate(marketplaceDetailProvider(l.id));
      ref.invalidate(marketplaceStatsProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text('marketplace.markedReserved'.tr(),
            style:
                AppTypography.body(size: 13, color: AppColors.ink)),
      ));
    }
  }

  /// Owner-Aktion: Als vergeben markieren via ConfirmDialog → markAsClaimed.
  Future<void> _markClaimed(
      BuildContext context, WidgetRef ref, MarketplaceListing l) async {
    final ok = await ConfirmDialog.show(
      context,
      title: 'marketplace.markAsSoldQuestion'.tr(),
      message: 'marketplace.markAsSoldDescription'.tr(),
      confirmLabel: 'marketplace.markSold'.tr(),
      danger: true,
    );
    if (!ok) return;
    Haptics.tap();
    final success = await MarketplaceRepository.markAsClaimed(l.id);
    if (!context.mounted) return;
    if (success) {
      ref.invalidate(marketplaceDetailProvider(l.id));
      ref.invalidate(marketplaceStatsProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text('marketplace.sold'.tr(),
            style:
                AppTypography.body(size: 13, color: AppColors.ink)),
      ));
    }
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.elevated,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 16, color: AppColors.inkSoft),
        ),
      ),
    );
  }
}

class _SaveButton extends ConsumerWidget {
  const _SaveButton({required this.listingId});
  final String listingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedListingIdsProvider).value ??
        const <String>{};
    final isSaved = saved.contains(listingId);
    return Material(
      color: AppColors.elevated,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () async {
          Haptics.tap();
          await MarketplaceFavorites.toggle(listingId);
          ref.invalidate(savedListingIdsProvider);
        },
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            isSaved ? LucideIcons.heart : LucideIcons.bookmark,
            size: 16,
            color: isSaved ? AppColors.bronze : AppColors.inkSoft,
          ),
        ),
      ),
    );
  }
}
