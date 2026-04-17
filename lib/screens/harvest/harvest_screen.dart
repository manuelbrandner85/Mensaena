import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/services/farm_service.dart';
import 'package:mensaena/models/farm_listing.dart';
import 'package:mensaena/widgets/empty_state.dart';
import 'package:mensaena/widgets/editorial_header.dart';
import 'package:mensaena/widgets/loading_skeleton.dart';

final _farmServiceProvider = Provider<FarmService>(
  (ref) => FarmService(ref.watch(supabaseProvider)),
);

final _harvestFarmsProvider =
    FutureProvider.family<List<FarmListing>, Map<String, String?>>((ref, params) async {
  return ref.read(_farmServiceProvider).getFarmListings(
        category: params['category'],
        search: params['search'],
      );
});

class HarvestScreen extends ConsumerStatefulWidget {
  const HarvestScreen({super.key});

  @override
  ConsumerState<HarvestScreen> createState() => _HarvestScreenState();
}

class _HarvestScreenState extends ConsumerState<HarvestScreen> {
  final _searchCtrl = TextEditingController();
  String? _selectedCategory;

  static const _categories = [
    (value: null, label: 'Alle', emoji: '🌱'),
    (value: 'hofladen', label: 'Hofladen', emoji: '🏠'),
    (value: 'selbstpfluecke', label: 'Selbstpflücke', emoji: '🍓'),
    (value: 'markt', label: 'Markt', emoji: '🛒'),
    (value: 'solawi', label: 'Solawi', emoji: '🥕'),
    (value: 'foodsharing', label: 'Foodsharing', emoji: '♻️'),
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final farms = ref.watch(_harvestFarmsProvider({
      'category': _selectedCategory,
      'search': _searchCtrl.text.isEmpty ? null : _searchCtrl.text,
    }));

    return Scaffold(
      appBar: AppBar(title: const Text('🌾 Ernte & Höfe')),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: EditorialHeader(
              section: 'ERNTE',
              number: '28',
              title: 'Ernte & Garten',
              subtitle: 'Gemeinsam ernten und gärtnern',
              icon: Icons.eco_outlined,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Hof, Stadt oder Produkt...',
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                filled: true,
                fillColor: AppColors.background,
              ),
              onSubmitted: (_) => setState(() {}),
            ),
          ),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final c = _categories[i];
                final selected = _selectedCategory == c.value;
                return FilterChip(
                  label: Text('${c.emoji} ${c.label}'),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedCategory = c.value),
                  selectedColor: AppColors.primary500.withValues(alpha: 0.2),
                  checkmarkColor: AppColors.primary500,
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(_harvestFarmsProvider);
              },
              color: AppColors.primary500,
              child: farms.when(
                loading: () => const LoadingSkeleton(type: SkeletonType.postList),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                      const SizedBox(height: 12),
                      Text('Fehler: $e', textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(_harvestFarmsProvider),
                        child: const Text('Erneut versuchen'),
                      ),
                    ],
                  ),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return const EmptyState(
                      icon: Icons.agriculture_outlined,
                      title: 'Keine Höfe gefunden',
                      message: 'Passe deine Filter an oder versuche eine andere Suche.',
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: list.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _FarmCard(farm: list[i]),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FarmCard extends StatelessWidget {
  final FarmListing farm;
  const _FarmCard({required this.farm});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        if (farm.website != null && farm.website!.isNotEmpty) {
          final uri = Uri.tryParse(farm.website!.startsWith('http')
              ? farm.website!
              : 'https://${farm.website!}');
          if (uri != null) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.soft,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.agriculture, color: AppColors.success),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              farm.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (farm.isVerified) const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.verified, size: 14, color: AppColors.primary500),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${farm.countryFlag} ${farm.city ?? '-'}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _Tag(label: farm.category, color: AppColors.primary500),
                if (farm.isBio) const _Tag(label: 'BIO', color: AppColors.success),
                if (farm.isSeasonal) const _Tag(label: 'Saisonal', color: AppColors.warning),
                ...farm.products.take(3).map((p) => _Tag(label: p, color: AppColors.info)),
              ],
            ),
            if (farm.description != null && farm.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                farm.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
