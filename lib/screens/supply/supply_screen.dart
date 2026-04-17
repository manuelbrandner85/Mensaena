import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/services/farm_service.dart';
import 'package:mensaena/models/farm_listing.dart';
import 'package:mensaena/widgets/empty_state.dart';
import 'package:mensaena/widgets/editorial_header.dart';
import 'package:url_launcher/url_launcher.dart';

final _farmServiceProvider = Provider<FarmService>((ref) => FarmService(ref.watch(supabaseProvider)));

final _farmListingsProvider = FutureProvider.family<List<FarmListing>, Map<String, String?>>((ref, params) async {
  return ref.read(_farmServiceProvider).getFarmListings(
    category: params['category'],
    country: params['country'],
    search: params['search'],
  );
});

class SupplyScreen extends ConsumerStatefulWidget {
  const SupplyScreen({super.key});
  @override
  ConsumerState<SupplyScreen> createState() => _SupplyScreenState();
}

class _SupplyScreenState extends ConsumerState<SupplyScreen> {
  final _searchCtrl = TextEditingController();
  String? _selectedCountry;
  String? _selectedCategory;

  static const _countries = [
    (value: null, label: 'Alle', flag: '🌍'),
    (value: 'DE', label: 'Deutschland', flag: '🇩🇪'),
    (value: 'AT', label: 'Oesterreich', flag: '🇦🇹'),
    (value: 'CH', label: 'Schweiz', flag: '🇨🇭'),
  ];

  Map<String, String?> get _params => {
    'category': _selectedCategory,
    'country': _selectedCountry,
    'search': _searchCtrl.text.isNotEmpty ? _searchCtrl.text : null,
  };

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final farmsAsync = ref.watch(_farmListingsProvider(_params));
    return Scaffold(
      appBar: AppBar(title: const Text('Versorgung')),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: EditorialHeader(
              section: 'VERSORGUNG',
              number: '13',
              title: 'Versorgung',
              subtitle: 'Lebensmittel und Hofläden',
              icon: Icons.agriculture_outlined,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Hoflaeden, Produkte suchen...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _searchCtrl.clear(); setState(() {}); }) : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppColors.border)),
                filled: true, fillColor: AppColors.background,
              ),
              onSubmitted: (_) => setState(() {}),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _countries.length, separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final c = _countries[i];
                final sel = _selectedCountry == c.value;
                return FilterChip(
                  label: Text('${c.flag} ${c.label}', style: TextStyle(fontSize: 12, color: sel ? Colors.white : AppColors.textSecondary)),
                  selected: sel, selectedColor: AppColors.primary500,
                  onSelected: (_) => setState(() => _selectedCountry = c.value),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: farmsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Fehler: $e')),
              data: (farms) {
                if (farms.isEmpty) return const EmptyState(icon: Icons.storefront_outlined, title: 'Keine Ergebnisse', message: 'Versuche andere Filter');
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(_farmListingsProvider(_params)),
                  child: ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 12), itemCount: farms.length,
                    itemBuilder: (_, i) => _FarmCard(farm: farms[i])),
                );
              },
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
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showDetail(context),
        child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(farm.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
            if (farm.isBio) _badge('Bio', AppColors.success),
            if (farm.isVerified) ...[const SizedBox(width: 4), _badge('✓', AppColors.info)],
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Text(farm.countryFlag, style: const TextStyle(fontSize: 14)), const SizedBox(width: 4),
            Text('${farm.city ?? ''}'.trim(), style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ]),
          if (farm.products.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 4, runSpacing: 4, children: farm.products.take(5).map((p) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppColors.primary50, borderRadius: BorderRadius.circular(10)),
              child: Text(p, style: const TextStyle(fontSize: 10, color: AppColors.primary700)),
            )).toList()),
          ],
        ])),
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
    child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
  );

  void _showDetail(BuildContext context) {
    showModalBottomSheet(context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(initialChildSize: 0.7, maxChildSize: 0.95, minChildSize: 0.4, expand: false,
        builder: (_, sc) => ListView(controller: sc, padding: const EdgeInsets.all(20), children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Text(farm.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          if (farm.description != null) ...[const SizedBox(height: 8), Text(farm.description!, style: const TextStyle(fontSize: 14, height: 1.5))],
          const SizedBox(height: 16),
          if (farm.address != null) _row(Icons.location_on_outlined, '${farm.address}, ${farm.postalCode ?? ''} ${farm.city ?? ''}'),
          if (farm.phone != null) _row(Icons.phone_outlined, farm.phone!, onTap: () => launchUrl(Uri.parse('tel:${farm.phone}'))),
          if (farm.email != null) _row(Icons.email_outlined, farm.email!, onTap: () => launchUrl(Uri.parse('mailto:${farm.email}'))),
          if (farm.website != null) _row(Icons.language_outlined, farm.website!, onTap: () => launchUrl(Uri.parse(farm.website!))),
          if (farm.products.isNotEmpty) ...[const SizedBox(height: 16), const Text('Produkte', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6), Wrap(spacing: 6, runSpacing: 6, children: farm.products.map((p) => Chip(label: Text(p, style: const TextStyle(fontSize: 12)), backgroundColor: AppColors.primary50, side: BorderSide.none)).toList())],
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  Widget _row(IconData icon, String text, {VoidCallback? onTap}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: InkWell(onTap: onTap, child: Row(children: [
      Icon(icon, size: 18, color: AppColors.primary500), const SizedBox(width: 10),
      Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: onTap != null ? AppColors.primary500 : AppColors.textSecondary))),
    ])),
  );
}
