import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/supabase.dart';
import '../../routing/routes.dart';
import '../../theme/app_colors.dart';
import '../messages/messages_repository.dart';

/// /dashboard/marketplace/:id — Inserat-Detail.
class MarketplaceDetailPage extends ConsumerStatefulWidget {
  const MarketplaceDetailPage({super.key, required this.id});
  final String id;

  @override
  ConsumerState<MarketplaceDetailPage> createState() =>
      _MarketplaceDetailPageState();
}

enum _OwnerAction { markSold, delete }

class _MarketplaceDetailPageState
    extends ConsumerState<MarketplaceDetailPage> {
  Map<String, dynamic>? _listing;
  bool _loading = true;
  String? _error;
  bool _busyDm = false;
  bool _busyReserve = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final row = await ref
          .read(supabaseProvider)
          .from('marketplace_listings')
          .select(
            '*, profiles:user_id(id, name, avatar_url, trust_score, trust_score_count)',
          )
          .eq('id', widget.id)
          .maybeSingle();
      if (!mounted) return;
      if (row == null) {
        setState(() {
          _error = 'Inserat nicht gefunden';
          _loading = false;
        });
        return;
      }
      setState(() {
        _listing = row;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _contactAuthor() async {
    final l = _listing;
    if (l == null || _busyDm) return;
    final myId = ref.read(supabaseProvider).auth.currentUser?.id;
    final authorId = (l['user_id'] ?? l['seller_id'] ?? l['author_id']) as String?;
    if (myId == null || authorId == null || myId == authorId) return;
    setState(() => _busyDm = true);
    try {
      final convId = await ref
          .read(messagesRepositoryProvider)
          .findOrCreateDirectConversation(userA: myId, userB: authorId);
      if (!mounted) return;
      context.go('${Routes.dashboardChat}?conv=$convId');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Konnte Chat nicht öffnen: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyDm = false);
    }
  }

  Future<void> _onOwnerAction(_OwnerAction action) async {
    final l = _listing;
    if (l == null) return;
    final id = l['id'] as String?;
    if (id == null) return;
    switch (action) {
      case _OwnerAction.markSold:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Inserat als verkauft markieren?'),
            content: const Text(
              'Andere User sehen das Inserat nicht mehr in der Liste.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Zurück'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Verkauft'),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
        try {
          await ref.read(supabaseProvider).from('marketplace_listings').update(
            <String, dynamic>{'status': 'sold'},
          ).eq('id', id);
          await _load();
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fehler: $e')),
          );
        }
        break;
      case _OwnerAction.delete:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Inserat löschen?'),
            content: const Text(
              'Das Inserat wird unwiderruflich gelöscht.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Abbrechen'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.emergency500,
                ),
                child: const Text('Löschen'),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
        try {
          await ref
              .read(supabaseProvider)
              .from('marketplace_listings')
              .delete()
              .eq('id', id);
          if (!mounted) return;
          Navigator.of(context).pop();
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Löschen fehlgeschlagen: $e')),
          );
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(_error!)),
      );
    }
    final l = _listing!;
    final media = (l['media_urls'] is List)
        ? List<String>.from(l['media_urls'] as List<dynamic>)
        : <String>[];
    final image = l['image_url'] as String?;
    final allImages = [...media, if (image != null) image];

    final priceType = (l['listing_type'] ?? l['price_type']) as String?;
    final price = l['price'];
    final priceLabel = priceType == 'free'
        ? 'Gratis 🎁'
        : priceType == 'swap'
            ? 'Tausch 🔄'
            : (price is num)
                ? '${price.toStringAsFixed(price.truncateToDouble() == price ? 0 : 2)} ${l['currency'] ?? 'EUR'}'
                : 'Preis auf Anfrage';

    final created = l['created_at'] as String?;
    final time = created != null
        ? DateFormat('d. MMMM yyyy', 'de').format(DateTime.parse(created))
        : '';

    final profile = l['profiles'] as Map<String, dynamic>?;
    final authorName = profile?['name'] as String? ?? 'Unbekannt';
    final authorAvatar = profile?['avatar_url'] as String?;
    final myId = ref.read(supabaseProvider).auth.currentUser?.id;
    // Schema: marketplace_listings hat user_id (Owner). Aliases: seller_id.
    final ownerId = (l['user_id'] ?? l['seller_id'] ?? l['author_id']) as String?;
    final isMine = myId != null && myId == ownerId;
    final reservedFor = l['reserved_for'] as String?;
    final reservedByMe = myId != null && reservedFor == myId;
    final reservedByOther = reservedFor != null && reservedFor != myId;

    final status = l['status'] as String? ?? 'active';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l['title'] as String? ?? 'Inserat'),
        actions: [
          if (isMine && status == 'active')
            PopupMenuButton<_OwnerAction>(
              tooltip: 'Aktionen',
              icon: const Icon(Icons.more_vert),
              onSelected: _onOwnerAction,
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: _OwnerAction.markSold,
                  child: ListTile(
                    leading: Icon(
                      Icons.check_circle_outline,
                      color: AppColors.primary500,
                    ),
                    title: Text('Als verkauft markieren'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: _OwnerAction.delete,
                  child: ListTile(
                    leading: Icon(Icons.delete_outline,
                        color: AppColors.emergency500,),
                    title: Text(
                      'Inserat löschen',
                      style: TextStyle(color: AppColors.emergency500),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          if (isMine && status != 'active')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary500.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status == 'sold'
                      ? 'Verkauft'
                      : status == 'reserved'
                          ? 'Reserviert'
                          : 'Inaktiv',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary500,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (allImages.isNotEmpty)
            SizedBox(
              height: 240,
              child: PageView.builder(
                itemCount: allImages.length,
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: allImages[i],
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        const ColoredBox(color: Color(0xFFF5F5F4)),
                    errorWidget: (_, __, ___) => Container(
                      color: Colors.grey.shade200,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image, size: 32),
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            l['title'] as String? ?? '',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            priceLabel,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.primary500,
            ),
          ),
          const SizedBox(height: 12),
          if ((l['description'] as String? ?? '').isNotEmpty)
            Text(
              l['description'] as String,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(
              children: [
                if (l['category'] != null)
                  _meta('Kategorie', l['category'] as String),
                if (l['condition'] != null)
                  _meta('Zustand', l['condition'] as String),
                if (l['location_text'] != null)
                  _meta('Ort', l['location_text'] as String),
                _meta('Veröffentlicht', time),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundImage:
                      authorAvatar != null ? NetworkImage(authorAvatar) : null,
                  backgroundColor:
                      AppColors.primary500.withValues(alpha: 0.18),
                  child: authorAvatar == null
                      ? Text(
                          authorName.isNotEmpty
                              ? authorName[0].toUpperCase()
                              : '?',
                          style:
                              const TextStyle(fontWeight: FontWeight.w700),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authorName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      if (profile?['trust_score'] != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          '⭐ ${(profile!['trust_score'] as num).toDouble().toStringAsFixed(1)} '
                          '· ${profile['trust_score_count'] ?? 0} Bewertungen',
                          style: const TextStyle(
                            color: AppColors.ink400,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (ownerId != null)
                  TextButton(
                    onPressed: () => context.go(
                      '${Routes.dashboardProfile}/$ownerId',
                    ),
                    child: const Text('Profil'),
                  ),
              ],
            ),
          ),
          if (!isMine) ...[
            const SizedBox(height: 16),
            if (reservedByMe)
              _ReservationCard(
                kind: ReservationKind.byMe,
                onCancel: _cancelReservation,
                busy: _busyReserve,
              )
            else if (reservedByOther)
              const _ReservationCard(kind: ReservationKind.byOther)
            else
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _busyReserve ? null : _reserve,
                  icon: const Icon(Icons.bookmark_added_outlined),
                  label: Text(_busyReserve ? 'Reserviere…' : 'Reservieren'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary500,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _busyDm ? null : _contactAuthor,
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Anschreiben'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary500,
                  side: const BorderSide(color: AppColors.primary500),
                ),
              ),
            ),
          ] else if (reservedFor != null) ...[
            const SizedBox(height: 16),
            const _ReservationCard(kind: ReservationKind.ownerView),
          ],
        ],
      ),
    );
  }

  Future<void> _reserve() async {
    final l = _listing;
    if (l == null || _busyReserve) return;
    final myId = ref.read(supabaseProvider).auth.currentUser?.id;
    if (myId == null) return;
    setState(() => _busyReserve = true);
    try {
      await ref.read(supabaseProvider).from('marketplace_listings').update(
        <String, dynamic>{'reserved_for': myId},
      ).eq('id', widget.id);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reserviert. Schreib der/dem Verkäufer:in.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Konnte nicht reservieren: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyReserve = false);
    }
  }

  Future<void> _cancelReservation() async {
    if (_busyReserve) return;
    setState(() => _busyReserve = true);
    try {
      await ref.read(supabaseProvider).from('marketplace_listings').update(
        <String, dynamic>{'reserved_for': null},
      ).eq('id', widget.id);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reservierung aufgehoben.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyReserve = false);
    }
  }

  Widget _meta(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.ink400, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: AppColors.ink700),
            ),
          ),
        ],
      ),
    );
  }
}

enum ReservationKind { byMe, byOther, ownerView }

class _ReservationCard extends StatelessWidget {
  const _ReservationCard({required this.kind, this.onCancel, this.busy = false});
  final ReservationKind kind;
  final VoidCallback? onCancel;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    late final IconData icon;
    late final String title;
    late final String subtitle;
    late final Color accent;
    switch (kind) {
      case ReservationKind.byMe:
        icon = Icons.bookmark_added;
        title = 'Du hast reserviert';
        subtitle = 'Schreibe der/dem Verkäufer:in zur Übergabe.';
        accent = AppColors.primary500;
        break;
      case ReservationKind.byOther:
        icon = Icons.lock_clock;
        title = 'Bereits reserviert';
        subtitle = 'Jemand anderes hat zuerst reserviert.';
        accent = const Color(0xFFD97706);
        break;
      case ReservationKind.ownerView:
        icon = Icons.bookmark;
        title = 'Reserviert';
        subtitle = 'Eine interessierte Person wartet auf dich.';
        accent = AppColors.primary500;
        break;
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: accent,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.ink700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (kind == ReservationKind.byMe)
            TextButton(
              onPressed: busy ? null : onCancel,
              child: Text(busy ? '…' : 'Aufheben'),
            ),
        ],
      ),
    );
  }
}
