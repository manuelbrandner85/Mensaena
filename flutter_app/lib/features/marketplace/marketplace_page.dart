import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase.dart';
import '../../routing/routes.dart';
import '../../theme/app_colors.dart';
import '../../widgets/page_chrome.dart';
import '../../widgets/realtime_feed.dart';

class MarketplacePage extends ConsumerStatefulWidget {
  const MarketplacePage({super.key});

  @override
  ConsumerState<MarketplacePage> createState() => _MarketplacePageState();
}

class _MarketplacePageState extends ConsumerState<MarketplacePage>
    with RealtimeFeedMixin {
  List<Map<String, dynamic>> _listings = const [];
  bool _loading = true;
  String _filter = 'all';
  String _conditionFilter = 'all';
  int? _radiusKm; // null = bundesweit
  Position? _userLocation;
  bool _resolvingLocation = false;

  static const _radiusOptions = [5, 10, 25, 50, 100];

  static const _filters = [
    (value: 'all', label: 'Alle'),
    (value: 'sell', label: 'Verkauf'),
    (value: 'rent', label: 'Miete'),
    (value: 'free', label: 'Verschenken'),
    (value: 'wanted', label: 'Suche'),
  ];

  static const _conditionFilters = [
    (value: 'all', label: 'Alle Zustände'),
    (value: 'neu', label: '✨ Neu'),
    (value: 'wie_neu', label: '🆕 Wie neu'),
    (value: 'gut', label: '👍 Gut'),
    (value: 'akzeptabel', label: '👌 Akzeptabel'),
  ];

  @override
  String get realtimeChannelName => 'marketplace-feed-realtime';

  @override
  List<FeedRealtimeRule> get realtimeRules => const [
        FeedRealtimeRule(
          event: PostgresChangeEvent.insert,
          table: 'marketplace_listings',
          action: FeedRealtimeAction.bumpNewCount,
        ),
        FeedRealtimeRule(
          event: PostgresChangeEvent.update,
          table: 'marketplace_listings',
          action: FeedRealtimeAction.reloadImmediately,
        ),
      ];

  @override
  bool shouldBumpForInsert(Map<String, dynamic> row) {
    if (row['status'] != 'active') return false;
    if (_filter != 'all' && row['listing_type'] != _filter) return false;
    if (_conditionFilter != 'all' &&
        row['condition_state'] != _conditionFilter) {
      return false;
    }
    final myId = ref.read(supabaseProvider).auth.currentUser?.id;
    if (myId != null && row['user_id'] == myId) return false;
    return true;
  }

  @override
  Future<void> reloadFeed() => _load();

  @override
  void initState() {
    super.initState();
    _load();
    subscribeRealtime();
  }

  void _showNewItems() {
    resetNewItemCount();
    _load();
  }

  /// Holt die User-Location falls noch nicht vorhanden. Permission wird
  /// einmalig angefragt; bei Denial bleibt _userLocation = null und der
  /// Radius-Filter ist deaktiviert.
  Future<bool> _ensureLocation() async {
    if (_userLocation != null) return true;
    setState(() => _resolvingLocation = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Standort-Zugriff verweigert — Radius nicht möglich.'),
            ),
          );
        }
        return false;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 8),
      ).timeout(const Duration(seconds: 10));
      if (!mounted) return false;
      setState(() => _userLocation = pos);
      return true;
    } catch (_) {
      return false;
    } finally {
      if (mounted) setState(() => _resolvingLocation = false);
    }
  }

  Future<void> _setRadius(int? km) async {
    if (km == null) {
      setState(() => _radiusKm = null);
      _load();
      return;
    }
    final ok = await _ensureLocation();
    if (!ok) return;
    setState(() => _radiusKm = km);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final db = ref.read(supabaseProvider);
      var q = db
          .from('marketplace_listings')
          .select(
            '*, profiles:user_id(name, display_name, avatar_url)',
          )
          .eq('status', 'active');
      if (_filter != 'all') q = q.eq('listing_type', _filter);
      if (_conditionFilter != 'all') {
        q = q.eq('condition_state', _conditionFilter);
      }
      final loc = _userLocation;
      final radius = _radiusKm;
      if (loc != null && radius != null) {
        // Approximate bbox: 1° lat ≈ 111 km, lng ≈ 111 * cos(lat)
        final dLat = radius / 111.0;
        final dLng = radius / (111.0 * 0.7);
        q = q
            .not('latitude', 'is', null)
            .not('longitude', 'is', null)
            .gte('latitude', loc.latitude - dLat)
            .lte('latitude', loc.latitude + dLat)
            .gte('longitude', loc.longitude - dLng)
            .lte('longitude', loc.longitude + dLng);
      }
      final rows = await q.order('created_at', ascending: false).limit(50);
      if (!mounted) return;
      setState(() {
        _listings = List<Map<String, dynamic>>.from(rows);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Marktplatz'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.go(Routes.dashboardMarketplaceCreate),
          ),
        ],
      ),
      body: Column(
        children: [
          const HeroHeader(
            metaLabel: 'Marktplatz',
            title: 'Tauschen, Verschenken, Verkaufen',
            subtitle:
                'Was du nicht mehr brauchst, kann jemand in der Nähe gut gebrauchen.',
            icon: Icons.shopping_bag_outlined,
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: _filters
                  .map(
                    (f) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(f.label),
                        selected: _filter == f.value,
                        onSelected: (_) {
                          setState(() => _filter = f.value);
                          _load();
                        },
                        selectedColor:
                            AppColors.primary500.withValues(alpha: 0.15),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: _conditionFilters
                  .map(
                    (f) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(
                          f.label,
                          style: const TextStyle(fontSize: 12),
                        ),
                        selected: _conditionFilter == f.value,
                        onSelected: (_) {
                          setState(() => _conditionFilter = f.value);
                          _load();
                        },
                        selectedColor:
                            AppColors.primary500.withValues(alpha: 0.15),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    avatar: _resolvingLocation
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            Icons.public,
                            size: 14,
                            color: _radiusKm == null
                                ? AppColors.primary500
                                : AppColors.ink400,
                          ),
                    label: const Text(
                      'Bundesweit',
                      style: TextStyle(fontSize: 12),
                    ),
                    selected: _radiusKm == null,
                    onSelected: (_) => _setRadius(null),
                    selectedColor:
                        AppColors.primary500.withValues(alpha: 0.15),
                  ),
                ),
                ..._radiusOptions.map(
                  (km) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      avatar: Icon(
                        Icons.near_me,
                        size: 14,
                        color: _radiusKm == km
                            ? AppColors.primary500
                            : AppColors.ink400,
                      ),
                      label: Text(
                        '$km km',
                        style: const TextStyle(fontSize: 12),
                      ),
                      selected: _radiusKm == km,
                      onSelected: (_) => _setRadius(km),
                      selectedColor:
                          AppColors.primary500.withValues(alpha: 0.15),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          NewItemsBanner(
            count: newItemCount,
            singularLabel: 'Inserat',
            pluralLabel: 'Inserate',
            onTap: _showNewItems,
            icon: Icons.shopping_bag_outlined,
          ),
          Expanded(
            child: _loading
                ? const SkeletonList(count: 5)
                : _listings.isEmpty
                    ? EmptyState(
                        emoji: '🛍️',
                        title: 'Noch keine Inserate',
                        subtitle:
                            'Probier einen anderen Filter oder erstelle das erste Inserat.',
                        actionLabel: 'Inserat erstellen',
                        onAction: () => context
                            .go(Routes.dashboardMarketplaceCreate),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _listings.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) =>
                              _ListingCard(data: _listings[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _ListingCard extends StatelessWidget {
  const _ListingCard({required this.data});
  final Map<String, dynamic> data;

  String? get _imageUrl {
    final media = data['media_urls'];
    if (media is List && media.isNotEmpty) return media.first as String?;
    return data['image_url'] as String?;
  }

  String get _typeLabel {
    switch (data['listing_type'] as String?) {
      case 'sell':
        return 'Verkauf';
      case 'rent':
        return 'Miete';
      case 'free':
        return 'Verschenken';
      case 'wanted':
        return 'Suche';
      default:
        return 'Inserat';
    }
  }

  String? get _priceLabel {
    final price = data['price'];
    final currency = data['currency'] as String? ?? 'EUR';
    if (price is num) {
      final s = price.toStringAsFixed(price.truncateToDouble() == price ? 0 : 2);
      return '$s $currency';
    }
    return data['listing_type'] == 'free' ? 'Gratis' : null;
  }

  @override
  Widget build(BuildContext context) {
    final created = data['created_at'] as String?;
    final time = created != null
        ? DateFormat('d. MMM', 'de').format(DateTime.parse(created))
        : '';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => context.go('/dashboard/marketplace/${data['id']}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _imageUrl != null
                  ? Image.network(
                      _imageUrl!,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.image_outlined),
                      ),
                    )
                  : Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey.shade100,
                      alignment: Alignment.center,
                      child: const Text('🛒', style: TextStyle(fontSize: 28)),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color:
                              AppColors.primary500.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _typeLabel,
                          style: const TextStyle(
                            color: AppColors.primary500,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        time,
                        style: const TextStyle(
                          color: AppColors.ink400,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data['title'] as String? ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  if ((data['description'] as String? ?? '').isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      data['description'] as String,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.ink700,
                        height: 1.3,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  if (_priceLabel != null)
                    Text(
                      _priceLabel!,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary500,
                      ),
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
