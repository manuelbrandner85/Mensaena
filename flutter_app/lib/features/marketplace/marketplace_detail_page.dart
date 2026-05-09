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

class _MarketplaceDetailPageState
    extends ConsumerState<MarketplaceDetailPage> {
  Map<String, dynamic>? _listing;
  bool _loading = true;
  String? _error;
  bool _busyDm = false;

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
            '*, profiles:author_id(id, name, avatar_url, trust_score, trust_score_count)',
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
    final authorId = l['author_id'] as String?;
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
    final isMine = myId == l['author_id'];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(l['title'] as String? ?? 'Inserat')),
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
                  child: Image.network(
                    allImages[i],
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
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
                            fontWeight: FontWeight.w600, fontSize: 14),
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
                if (l['author_id'] != null)
                  TextButton(
                    onPressed: () => context.go(
                        '${Routes.dashboardProfile}/${l['author_id']}'),
                    child: const Text('Profil'),
                  ),
              ],
            ),
          ),
          if (!isMine) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _busyDm ? null : _contactAuthor,
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Anschreiben'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
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
