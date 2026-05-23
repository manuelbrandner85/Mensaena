import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../models/marketplace_listing.dart';
import '../../../repositories/marketplace_repository.dart';
import '../../../services/supabase_service.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

class MarketplaceDetailScreen extends ConsumerWidget {
  const MarketplaceDetailScreen({required this.listingId, super.key});
  final String listingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(marketplaceDetailProvider(listingId));
    return DashboardScaffold(
      title: 'Inserat',
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
                child: Text('Inserat nicht gefunden.',
                    style: AppTypography.caption()),
              );
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (l.images.isNotEmpty)
                  SizedBox(
                    height: 240,
                    child: PageView.builder(
                      itemCount: l.images.length,
                      itemBuilder: (context, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(l.images[i], fit: BoxFit.cover),
                      ),
                    ),
                  ),
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
                  Text('Zustand: ${l.conditionState}',
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
                const SizedBox(height: 18),
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
                        label: const Text('Kontakt'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _CircleIconButton(
                      icon: LucideIcons.share2,
                      onTap: () => _share(l),
                    ),
                    const SizedBox(width: 8),
                    _SaveButton(listingId: l.id),
                    if (l.userId == SupabaseService.currentUser?.id) ...[
                      const SizedBox(width: 8),
                      _CircleIconButton(
                        icon: l.status == 'reserved'
                            ? LucideIcons.unlock
                            : LucideIcons.lock,
                        color: AppColors.amber,
                        onTap: () =>
                            _toggleReserved(context, ref, l),
                      ),
                      const SizedBox(width: 8),
                      _CircleIconButton(
                        icon: LucideIcons.checkCircle,
                        color: AppColors.leben,
                        onTap: () => _markSold(context, ref, l),
                      ),
                    ],
                  ],
                ),
                if (l.status == 'reserved') ...[
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
                        Text('Reserviert',
                            style: AppTypography.label(
                                size: 10,
                                color: AppColors.amber)),
                      ],
                    ),
                  ),
                ],
                if (l.status == 'sold') ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.leben.withValues(alpha: 0.10),
                      border: Border.all(
                          color: AppColors.leben
                              .withValues(alpha: 0.4)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.checkCircle,
                            size: 14,
                            color: AppColors.lebenSoft),
                        const SizedBox(width: 8),
                        Text('Vergeben',
                            style: AppTypography.label(
                                size: 10,
                                color: AppColors.lebenSoft)),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Text(
                  'Inseriert am ${DateFormat('dd.MM.yyyy').format(l.createdAt)}',
                  style: AppTypography.caption(),
                ),
              ],
            );
          },
        ),
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
              'title':
                  'Marktplatz: ${l.title.length > 40 ? "${l.title.substring(0, 40)}..." : l.title}',
            })
            .select()
            .single();
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
        content: Text('Konnte Kontakt nicht aufnehmen.',
            style: AppTypography.body(
                size: 13, color: AppColors.ink)),
      ));
    }
  }

  Future<void> _share(MarketplaceListing l) async {
    await Share.share(
      '${l.title}\n\nAuf Mensaena: https://www.mensaena.de/dashboard/marketplace/${l.id}',
      subject: 'Mensaena: ${l.title}',
    );
  }

  Future<void> _toggleReserved(
      BuildContext context, WidgetRef ref, MarketplaceListing l) async {
    final next = l.status == 'reserved' ? 'active' : 'reserved';
    try {
      await sb.from('marketplace_listings').update({
        'status': next,
      }).eq('id', l.id);
      ref.invalidate(marketplaceDetailProvider(l.id));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text(
          next == 'reserved'
              ? 'Als reserviert markiert.'
              : 'Reservierung aufgehoben.',
          style: AppTypography.body(size: 13, color: AppColors.ink),
        ),
      ));
    } catch (_) {}
  }

  Future<void> _markSold(
      BuildContext context, WidgetRef ref, MarketplaceListing l) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Als vergeben markieren?',
            style:
                AppTypography.display(size: 18, color: AppColors.ink)),
        content: Text(
          'Das Inserat wird inaktiv und für andere nicht mehr sichtbar.',
          style: AppTypography.body(size: 13, color: AppColors.inkSoft),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.leben,
                foregroundColor: AppColors.voidColor),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Vergeben'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await sb.from('marketplace_listings').update({
        'status': 'sold',
      }).eq('id', l.id);
      ref.invalidate(marketplaceDetailProvider(l.id));
    } catch (_) {}
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.inkSoft;
    return Material(
      color: AppColors.elevated,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 16, color: c),
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
