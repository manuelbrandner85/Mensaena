import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/widgets/empty_state.dart';

Future<void> _toggleMarketplaceFavorite(SupabaseClient client, String listingId, String userId) async {
  final existing = await client.from('marketplace_favorites').select('id').eq('listing_id', listingId).eq('user_id', userId).maybeSingle();
  if (existing != null) {
    await client.from('marketplace_favorites').delete().eq('id', existing['id']);
  } else {
    await client.from('marketplace_favorites').insert({'listing_id': listingId, 'user_id': userId});
  }
}

Future<void> _sendMarketplaceMessage(SupabaseClient client, String listingId, String senderId, String content) async {
  await client.from('marketplace_messages').insert({'listing_id': listingId, 'sender_id': senderId, 'content': content});
}

final _marketplaceProvider = FutureProvider.family<List<Map<String, dynamic>>, Map<String, String?>>((ref, params) async {
  final client = ref.watch(supabaseProvider);
  var query = client.from('marketplace_listings').select('*, profiles:user_id(id, name, nickname, avatar_url)').eq('status', 'active');
  if (params['type'] != null) query = query.eq('listing_type', params['type']!);
  if (params['category'] != null) query = query.eq('category', params['category']!);
  if (params['search'] != null && params['search']!.isNotEmpty) {
    query = query.or('title.ilike.%${params['search']}%,description.ilike.%${params['search']}%');
  }
  final data = await query.order('created_at', ascending: false).limit(50);
  return List<Map<String, dynamic>>.from(data);
});

class MarketplaceScreen extends ConsumerStatefulWidget {
  const MarketplaceScreen({super.key});
  @override
  ConsumerState<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen> {
  final _searchCtrl = TextEditingController();
  String? _selectedType;
  String? _selectedCategory;

  static const _types = [
    (value: null, label: 'Alle'),
    (value: 'offer', label: 'Angebote'),
    (value: 'request', label: 'Gesuche'),
  ];

  static const _categories = [
    'elektronik', 'kleidung', 'moebel', 'buecher', 'sport',
    'garten', 'kinder', 'haushalt', 'sonstiges',
  ];

  static const _categoryLabels = {
    'elektronik': '📱 Elektronik',
    'kleidung': '👕 Kleidung',
    'moebel': '🪑 Möbel',
    'buecher': '📚 Buecher',
    'sport': '⚽ Sport',
    'garten': '🌱 Garten',
    'kinder': '👶 Kinder',
    'haushalt': '🏠 Haushalt',
    'sonstiges': '📦 Sonstiges',
  };

  Map<String, String?> get _params => {
    'type': _selectedType,
    'category': _selectedCategory,
    'search': _searchCtrl.text.isNotEmpty ? _searchCtrl.text : null,
  };

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listingsAsync = ref.watch(_marketplaceProvider(_params));

    return Scaffold(
      appBar: AppBar(title: const Text('Marktplatz')),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Marktplatz durchsuchen...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _searchCtrl.clear(); setState(() {}); })
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppColors.border)),
                filled: true,
                fillColor: AppColors.background,
              ),
              onSubmitted: (_) => setState(() {}),
            ),
          ),

          // Type tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: _types.map((t) {
                final isSelected = _selectedType == t.value;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: ChoiceChip(
                      label: Text(t.label, style: TextStyle(fontSize: 13, color: isSelected ? Colors.white : AppColors.textSecondary)),
                      selected: isSelected,
                      selectedColor: AppColors.primary500,
                      onSelected: (_) => setState(() => _selectedType = t.value),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Category chips
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                if (i == 0) {
                  return FilterChip(
                    label: const Text('Alle', style: TextStyle(fontSize: 11)),
                    selected: _selectedCategory == null,
                    selectedColor: AppColors.primary50,
                    onSelected: (_) => setState(() => _selectedCategory = null),
                  );
                }
                final cat = _categories[i - 1];
                return FilterChip(
                  label: Text(_categoryLabels[cat] ?? cat, style: const TextStyle(fontSize: 11)),
                  selected: _selectedCategory == cat,
                  selectedColor: AppColors.primary50,
                  onSelected: (_) => setState(() => _selectedCategory = cat),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // Listings
          Expanded(
            child: listingsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Fehler: $e')),
              data: (listings) {
                if (listings.isEmpty) {
                  return const EmptyState(
                    icon: Icons.storefront_outlined,
                    title: 'Keine Angebote',
                    message: 'Erstelle das erste Inserat!',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(_marketplaceProvider(_params)),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: listings.length,
                    itemBuilder: (_, i) => _ListingCard(listing: listings[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateListingDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Inserieren'),
      ),
    );
  }

  void _showCreateListingDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    String listingType = 'offer';
    String category = 'sonstiges';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: StatefulBuilder(builder: (ctx, setBS) => SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Neues Inserat', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'offer', label: Text('Biete')),
                  ButtonSegment(value: 'request', label: Text('Suche')),
                ],
                selected: {listingType},
                onSelectionChanged: (v) => setBS(() => listingType = v.first),
              ),
              const SizedBox(height: 12),
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Titel *')),
              const SizedBox(height: 12),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Beschreibung *'), maxLines: 3),
              const SizedBox(height: 12),
              TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'Preis (leer = Kostenlos)', suffixText: '€'), keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              TextField(controller: locationCtrl, decoration: const InputDecoration(labelText: 'Standort', prefixIcon: Icon(Icons.location_on_outlined))),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: category,
                decoration: const InputDecoration(labelText: 'Kategorie'),
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(_categoryLabels[c] ?? c))).toList(),
                onChanged: (v) => setBS(() => category = v ?? 'sonstiges'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty || descCtrl.text.trim().isEmpty) return;
                    final userId = ref.read(currentUserIdProvider);
                    if (userId == null) return;
                    Navigator.pop(ctx);
                    try {
                      final price = double.tryParse(priceCtrl.text);
                      await ref.read(supabaseProvider).from('marketplace_listings').insert({
                        'user_id': userId,
                        'title': titleCtrl.text.trim(),
                        'description': descCtrl.text.trim(),
                        'listing_type': listingType,
                        'category': category,
                        'price': price,
                        'price_type': price != null && price > 0 ? 'fixed' : 'free',
                        'location_text': locationCtrl.text.trim().isNotEmpty ? locationCtrl.text.trim() : null,
                        'status': 'active',
                      });
                      ref.invalidate(_marketplaceProvider(_params));
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inserat erstellt!')));
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
                    }
                  },
                  child: const Text('Inserat erstellen'),
                ),
              ),
            ],
          ),
        )),
      ),
    );
  }
}

class _ListingCard extends StatelessWidget {
  final Map<String, dynamic> listing;
  const _ListingCard({required this.listing});

  @override
  Widget build(BuildContext context) {
    final title = listing['title'] as String? ?? '';
    final description = listing['description'] as String? ?? '';
    final price = listing['price'] as num?;
    final priceType = listing['price_type'] as String? ?? 'kostenlos';
    final category = listing['category'] as String? ?? '';
    final listingType = listing['listing_type'] as String?;
    final location = listing['location_text'] as String?;
    final imageUrls = (listing['image_urls'] as List?)?.cast<String>() ?? [];
    final images = (listing['images'] as List?)?.cast<String>() ?? [];
    final thumbnailUrl = listing['thumbnail_url'] as String?;
    final displayImage = thumbnailUrl ?? (imageUrls.isNotEmpty ? imageUrls[0] : (images.isNotEmpty ? images[0] : null));
    final favoriteCount = listing['favorite_count'] as int? ?? 0;
    final createdAt = DateTime.tryParse(listing['created_at'] as String? ?? '');
    final profileData = listing['profiles'] as Map<String, dynamic>?;
    final sellerName = profileData?['nickname'] as String? ?? profileData?['name'] as String? ?? 'Anonym';
    final conditionState = listing['condition_state'] as String? ?? listing['condition'] as String?;

    final priceDisplay = (price != null && price > 0)
        ? '${price.toStringAsFixed(price.truncateToDouble() == price ? 0 : 2)} €'
        : 'Kostenlos';
    final isPaid = price != null && price > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 80,
                  height: 80,
                  color: AppColors.background,
                  child: displayImage != null
                      ? Image.network(displayImage, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image_outlined, color: AppColors.textMuted))
                      : const Icon(Icons.storefront_outlined, color: AppColors.textMuted, size: 32),
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isPaid ? AppColors.warning.withValues(alpha: 0.1) : AppColors.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(priceDisplay, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isPaid ? AppColors.warning : AppColors.success)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.3)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (listingType != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: listingType == 'offer' ? AppColors.primary50 : const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              listingType == 'offer' ? 'Biete' : 'Suche',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: listingType == 'offer' ? AppColors.primary700 : const Color(0xFFB45309)),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (conditionState != null) ...[
                          Text(conditionState, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                          const SizedBox(width: 6),
                        ],
                        if (location != null) ...[
                          const Icon(Icons.location_on_outlined, size: 12, color: AppColors.textMuted),
                          const SizedBox(width: 2),
                          Flexible(child: Text(location, style: const TextStyle(fontSize: 10, color: AppColors.textMuted), overflow: TextOverflow.ellipsis)),
                        ],
                        const Spacer(),
                        if (favoriteCount > 0) ...[
                          Icon(Icons.favorite_border, size: 12, color: AppColors.textMuted.withValues(alpha: 0.6)),
                          const SizedBox(width: 2),
                          Text('$favoriteCount', style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                        ],
                        if (createdAt != null) ...[
                          const SizedBox(width: 6),
                          Text(timeago.format(createdAt, locale: 'de'), style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
