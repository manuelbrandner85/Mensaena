import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../models/marketplace_listing.dart';
import '../../../repositories/marketplace_repository.dart';
import '../../../services/haptics.dart';
import '../../../repositories/content_reports_repository.dart';
import '../../../repositories/conversations_repository.dart';
import '../../../services/supabase_service.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../../widgets/effects/parallax_image_header.dart';
import '../../../widgets/effects/shimmer_skeleton.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';
import '../../../widgets/shared/error_state_widget.dart';
import '../../../widgets/marketplace/barter_matches_carousel.dart';
import '../../../widgets/marketplace_reservation.dart';
import '../../../widgets/shared/image_carousel.dart';
import '../../../widgets/shared/app_snackbar.dart';

// Stabile DB-Werte → Anzeige-i18n-Keys (Spiegel des Create-Screens).
const Map<String, String> _kTypeLabels = {
  'verschenken': 'marketplace.typeVerschenken',
  'tauschen': 'marketplace.typeTauschen',
  'verkaufen': 'marketplace.typeVerkaufen',
  'leihen': 'marketplace.typeLeihen',
};
const Map<String, String> _kCondLabels = {
  'neu': 'marketplace.condNeu',
  'sehr_gut': 'marketplace.condSehrGut',
  'gut': 'marketplace.condGut',
  'gebraucht': 'marketplace.condGebraucht',
  'defekt': 'marketplace.condDefekt',
};

String _typeLabel(String v) =>
    _kTypeLabels[v] != null ? _kTypeLabels[v]!.tr() : v.toUpperCase();
String _condLabel(String v) => _kCondLabels[v] != null ? _kCondLabels[v]!.tr() : v;

class MarketplaceDetailScreen extends ConsumerStatefulWidget {
  const MarketplaceDetailScreen({required this.listingId, super.key});
  final String listingId;

  @override
  ConsumerState<MarketplaceDetailScreen> createState() =>
      _MarketplaceDetailScreenState();
}

class _MarketplaceDetailScreenState
    extends ConsumerState<MarketplaceDetailScreen> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listingId = widget.listingId;
    final async = ref.watch(marketplaceDetailProvider(listingId));
    return DashboardScaffold(
      title: 'marketplace.listing'.tr(),
      currentRoute: '/dashboard/marketplace',
      body: SafeArea(
        child: async.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.amber),
          ),
          error: (e, _) => Center(
            child: ErrorStateWidget(
              onRetry: () =>
                  ref.invalidate(marketplaceDetailProvider(listingId)),
            ),
          ),
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
              controller: _scroll,
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
                      child: Text(_typeLabel(l.listingType).toUpperCase(),
                          style: AppTypography.label(size: 9)),
                    ),
                    const SizedBox(width: 6),
                    Text(l.category, style: AppTypography.label(size: 9)),
                    const Spacer(),
                    if (l.price != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '${l.price!.toStringAsFixed(0)} €',
                            style: AppTypography.mono(
                              size: 18,
                              color: AppColors.amber,
                              weight: FontWeight.w700,
                            ),
                          ),
                          if (l.priceType == 'negotiable') ...[
                            const SizedBox(width: 4),
                            Text('marketplace.priceNegotiable'.tr(),
                                style: AppTypography.label(
                                    size: 9, color: AppColors.mute)),
                          ],
                        ],
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
                          namedArgs: {'state': _condLabel(l.conditionState!)}),
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
                // M4: Inline-Karten-Vorschau wenn Koordinaten vorhanden.
                if (l.displayLat != null && l.displayLng != null) ...[
                  const SizedBox(height: 10),
                  _MapPreview(lat: l.displayLat!, lng: l.displayLng!),
                ],
                if (l.tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: l.tags
                        .map((t) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.surface.withValues(alpha: 0.6),
                                border: Border.all(color: AppColors.line),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text('#$t',
                                  style: AppTypography.label(
                                      size: 10, color: AppColors.inkSoft)),
                            ))
                        .toList(),
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
                        tooltip: 'marketplace.reserve_request'.tr(),
                        onTap: () => _reserveAsBuyer(context, ref, l),
                      ),
                    ],
                    const SizedBox(width: 8),
                    _CircleIconButton(
                      icon: LucideIcons.share2,
                      tooltip: 'common.share'.tr(),
                      onTap: () => _share(l),
                    ),
                    const SizedBox(width: 8),
                    _SaveButton(listingId: l.id),
                  ],
                ),
                // Melden (nur fremde Inserate). Betrugs-/Spam-Schutz.
                if (!isOwner) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _reportListing(context, l),
                      icon: const Icon(LucideIcons.flag,
                          size: 13, color: AppColors.mute),
                      label: Text('marketplace.report'.tr(),
                          style: AppTypography.label(
                              size: 10, color: AppColors.mute)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        minimumSize: const Size(0, 30),
                      ),
                    ),
                  ),
                ],
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
                if (isOwner) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _editListing(context, l),
                          icon: const Icon(LucideIcons.pencil, size: 14),
                          label: Text('marketplace.editListing'.tr()),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary500,
                            side: BorderSide(
                              color: AppColors.primary500.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () => _deleteListing(context, ref, l),
                          icon: const Icon(LucideIcons.trash2, size: 14),
                          label: Text('marketplace.deleteListing'.tr()),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.herzrot,
                          ),
                        ),
                      ),
                    ],
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
                const SizedBox(height: 20),
                // M1: Kommentare / Anfragen.
                _CommentsSection(listingId: l.id, ownerId: ownerId),
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
      // Cinema: Einzelbild → Parallax-Hero (Carousel-Fall bleibt ohne
      // Parallax, da Paging-Gesten sonst mit dem Translate kollidieren).
      base = ParallaxImageHeader(
        scrollController: _scroll,
        height: 240,
        child: Hero(
          tag: 'marketplace-image-${l.id}',
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

  // In-Flight-Guard gegen Doppel-Tap (Screen ist stateless → static Set).
  static final Set<String> _contactInFlight = {};

  Future<void> _contactSeller(
      BuildContext context, WidgetRef ref, MarketplaceListing l) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null || uid == l.userId) return;
    if (!_contactInFlight.add(l.id)) return; // schon in Arbeit
    try {
      // BUGFIX: vorher wurde die DM manuell über die Schnittmenge aller
      // gemeinsamen conversation_members ermittelt — das konnte eine GRUPPE/
      // Community (nicht-DM) treffen, sodass 'Verkäufer kontaktieren' den
      // falschen Chat öffnete. Jetzt der atomare, race-sichere RPC, der
      // garantiert eine echte 2er-DM liefert (Advisory-Lock auf Paar).
      final convId = await ConversationsRepository.getOrCreateDm(l.userId);
      if (!context.mounted) return;
      if (convId == null) {
        AppSnackBar.error(context, 'marketplace.contactFailed'.tr());
        return;
      }
      context.go('/dashboard/chat?conv=$convId');
    } catch (_) {
      if (!context.mounted) return;
      AppSnackBar.error(context, 'marketplace.contactFailed'.tr());
    } finally {
      _contactInFlight.remove(l.id);
    }
  }

  /// Meldet ein Inserat zur Moderation. Grund-Auswahl per Bottom-Sheet,
  /// dann INSERT in reports (content_type='marketplace').
  Future<void> _reportListing(
      BuildContext context, MarketplaceListing l) async {
    const reasons = <String, String>{
      'fraud': 'report.reasonFraud',
      'spam': 'report.reasonSpam',
      'false_info': 'report.reasonFalseInfo',
      'danger': 'report.reasonDanger',
      'other': 'report.reasonOther',
    };
    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text('marketplace.reportTitle'.tr(),
                  style: AppTypography.display(size: 17, color: AppColors.ink)),
            ),
            for (final e in reasons.entries)
              ListTile(
                leading: const Icon(LucideIcons.flag,
                    size: 16, color: AppColors.mute),
                title: Text(e.value.tr(),
                    style: AppTypography.body(size: 14, color: AppColors.ink)),
                onTap: () => Navigator.pop(ctx, e.key),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (reason == null) return;
    final ok = await ContentReportsRepository.report(
      contentType: 'marketplace',
      contentId: l.id,
      reason: reason,
    );
    if (!context.mounted) return;
    if (ok) {
      AppSnackBar.success(context, 'report.thanks'.tr());
    } else {
      AppSnackBar.error(context, 'marketplace.contactFailed'.tr());
    }
  }

  Future<void> _share(MarketplaceListing l) async {
    await Share.share(
      'marketplace.shareBody'.tr(namedArgs: {
        'title': l.title,
        'url': 'https://www.mensaena.de/get/marketplace/${l.id}',
      }),
      subject: 'marketplace.shareSubject'
          .tr(namedArgs: {'title': l.title}),
    );
  }

  /// Käufer-Aktion: Reservierungs-Anfrage mit optionaler Nachricht.
  Future<void> _reserveAsBuyer(
      BuildContext context, WidgetRef ref, MarketplaceListing l) async {
    final msgCtrl = TextEditingController();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.sheetBackground,
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
    final ok = await MarketplaceRepository.requestReservation(
      listingId: l.id,
      message: msgCtrl.text,
    );
    if (!context.mounted) return;
    if (ok) {
      AppSnackBar.success(context, 'marketplace.reserve_sent'.tr());
    } else {
      AppSnackBar.error(context, 'marketplace.reserve_failed'.tr());
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
      AppSnackBar.success(context, 'marketplace.markedReserved'.tr());
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
      AppSnackBar.success(context, 'marketplace.sold'.tr());
    }
  }

  /// Owner-Aktion: Inserat bearbeiten.
  void _editListing(BuildContext context, MarketplaceListing l) {
    context.push('/dashboard/marketplace/create', extra: l);
  }

  /// Owner-Aktion: Inserat löschen (Soft-Delete via deleted_at).
  Future<void> _deleteListing(
      BuildContext context, WidgetRef ref, MarketplaceListing l) async {
    final ok = await ConfirmDialog.show(
      context,
      title: 'marketplace.deleteListing'.tr(),
      message: 'marketplace.deleteListingDescription'.tr(),
      confirmLabel: 'common.delete'.tr(),
      danger: true,
    );
    if (!ok) return;
    Haptics.tap();
    final success = await MarketplaceRepository.deleteListing(l.id);
    if (!context.mounted) return;
    if (success) {
      ref.invalidate(marketplaceStatsProvider);
      context.go('/dashboard/marketplace');
    } else {
      AppSnackBar.error(context, 'errors.generic'.tr());
    }
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  // a11y: Screenreader-Label + Long-Press-Tooltip für das sonst nackte Icon.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final btn = Material(
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
    if (tooltip == null) return btn;
    return Tooltip(
      message: tooltip!,
      child: Semantics(button: true, label: tooltip, child: btn),
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

/// M4: kleine nicht-interaktive Karten-Vorschau mit Pin + "Route"-Button.
/// Tiles direkt von OSM (kein FMTC-Cache nötig für ein einzelnes statisches
/// Preview). interactionOptions = none → kein versehentliches Verschieben
/// im Scroll-Body.
class _MapPreview extends StatelessWidget {
  const _MapPreview({required this.lat, required this.lng});
  final double lat;
  final double lng;

  Future<void> _route(BuildContext context) async {
    final geo = Uri.parse('geo:0,0?q=$lat,$lng');
    final web = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    try {
      if (await canLaunchUrl(geo)) {
        await launchUrl(geo, mode: LaunchMode.externalApplication);
        return;
      }
      await launchUrl(web, mode: LaunchMode.externalApplication);
    } catch (_) {/* still */}
  }

  @override
  Widget build(BuildContext context) {
    final center = LatLng(lat, lng);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 140,
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom: 14,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'de.mensaena.app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: center,
                      width: 34,
                      height: 34,
                      child: const Icon(LucideIcons.mapPin,
                          size: 30, color: AppColors.herzrot),
                    ),
                  ],
                ),
              ],
            ),
            // Route-Button unten rechts.
            Positioned(
              right: 8,
              bottom: 8,
              child: Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => _route(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.navigation,
                            size: 13, color: AppColors.bronze),
                        const SizedBox(width: 5),
                        Text('map.routeTo'.tr(),
                            style: AppTypography.label(
                                size: 10, color: AppColors.bronze)),
                      ],
                    ),
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

/// M1: Kommentar-/Anfrage-Bereich unter einem Inserat. Liste + Composer.
class _CommentsSection extends ConsumerStatefulWidget {
  const _CommentsSection({required this.listingId, required this.ownerId});
  final String listingId;
  final String ownerId;

  @override
  ConsumerState<_CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends ConsumerState<_CommentsSection> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    final ok = await MarketplaceRepository.addComment(widget.listingId, text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) {
      _ctrl.clear();
      ref.invalidate(marketplaceCommentsProvider(widget.listingId));
    }
  }

  Future<void> _delete(String id) async {
    final ok = await MarketplaceRepository.deleteComment(id);
    if (!mounted) return;
    if (ok) ref.invalidate(marketplaceCommentsProvider(widget.listingId));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(marketplaceCommentsProvider(widget.listingId));
    final me = SupabaseService.currentUser?.id;
    final isOwner = me != null && me == widget.ownerId;
    final comments = async.asData?.value ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'marketplace.commentsCount'
              .tr(namedArgs: {'n': '${comments.length}'}),
          style: AppTypography.label(size: 10),
        ),
        const SizedBox(height: 8),
        if (async.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.amber),
              ),
            ),
          )
        else if (comments.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('marketplace.noComments'.tr(),
                style: AppTypography.caption()),
          )
        else
          for (final c in comments)
            _CommentTile(
              comment: c,
              canDelete: isOwner || c['user_id'] == me,
              onDelete: () => _delete(c['id'] as String),
            ),
        const SizedBox(height: 8),
        // Composer
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                style: AppTypography.body(size: 14, color: AppColors.ink),
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'marketplace.commentHint'.tr(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: 'common.send'.tr(),
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.bronze),
                    )
                  : const Icon(LucideIcons.send,
                      size: 18, color: AppColors.bronze),
            ),
          ],
        ),
      ],
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.canDelete,
    required this.onDelete,
  });
  final Map<String, dynamic> comment;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final profile = comment['profiles'] as Map<String, dynamic>?;
    final name = (profile?['display_name'] ??
            profile?['name'] ??
            'common.neighbour'.tr())
        .toString();
    final content = (comment['content'] ?? '').toString();
    final createdRaw = comment['created_at']?.toString();
    final created = createdRaw != null ? DateTime.tryParse(createdRaw)?.toUtc() : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(name,
                  style: AppTypography.body(
                      size: 12,
                      color: AppColors.ink,
                      weight: FontWeight.w700)),
              const Spacer(),
              if (created != null)
                Text(DateFormat('dd.MM. HH:mm').format(created),
                    style: AppTypography.caption()),
              if (canDelete)
                GestureDetector(
                  onTap: onDelete,
                  child: const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(LucideIcons.trash2,
                        size: 13, color: AppColors.mute),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(content,
              style: AppTypography.body(
                  size: 13, color: AppColors.ink, height: 1.4)),
        ],
      ),
    );
  }
}
