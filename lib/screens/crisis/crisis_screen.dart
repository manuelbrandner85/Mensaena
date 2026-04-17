import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/crisis_provider.dart';
import 'package:mensaena/models/crisis.dart';
import 'package:mensaena/widgets/editorial_header.dart';

class CrisisScreen extends ConsumerStatefulWidget {
  const CrisisScreen({super.key});
  @override
  ConsumerState<CrisisScreen> createState() => _CrisisScreenState();
}

class _CrisisScreenState extends ConsumerState<CrisisScreen> {
  String? _selectedCategory;
  String _statusFilter = 'active';
  String _view = 'list';
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _channel = Supabase.instance.client.channel('crises-realtime')
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'crises',
          callback: (_) { if (mounted) ref.invalidate(activeCrisesProvider); })
        .subscribe();
  }

  @override
  void dispose() { _channel?.unsubscribe(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final crises = ref.watch(activeCrisesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('§ 16 · Krisenhilfe'),
        backgroundColor: AppColors.emergencyLight,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'list', icon: Icon(Icons.list), label: Text('Liste')),
                ButtonSegment(value: 'map', icon: Icon(Icons.map), label: Text('Karte')),
              ],
              selected: {_view},
              onSelectionChanged: (v) => setState(() => _view = v.first),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: EditorialHeader(
              section: 'KRISEN',
              number: '08',
              title: 'Krisen & Notfälle',
              subtitle: 'Schnelle Hilfe in Notsituationen',
              icon: Icons.warning_outlined,
            ),
          ),
          // SOS Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: GestureDetector(
              onTap: () => context.push('/dashboard/crisis/create'),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.emergency,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.emergency.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.warning, color: Colors.white, size: 28),
                    SizedBox(width: 12),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('SOS – Krise melden',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                        Text('Sofort Hilfe anfordern',
                            style: TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Active crisis alert banner
          crises.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (list) {
              final criticalCount = list
                  .where((c) => c.urgency == CrisisUrgency.critical && c.status == 'active')
                  .length;
              if (criticalCount == 0) return const SizedBox.shrink();
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                decoration: BoxDecoration(
                  color: AppColors.emergency.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.emergency),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: AppColors.emergency),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$criticalCount aktive kritische Krise${criticalCount == 1 ? '' : 'n'}!',
                        style: const TextStyle(color: AppColors.emergency, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Status filter
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Row(
              children: [
                _StatusChip(label: 'Aktiv', value: 'active', selected: _statusFilter, onTap: (v) => setState(() => _statusFilter = v)),
                const SizedBox(width: 6),
                _StatusChip(label: 'In Bearbeitung', value: 'in_progress', selected: _statusFilter, onTap: (v) => setState(() => _statusFilter = v)),
                const SizedBox(width: 6),
                _StatusChip(label: 'Gelöst', value: 'resolved', selected: _statusFilter, onTap: (v) => setState(() => _statusFilter = v)),
              ],
            ),
          ),
          // Category filter
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _CatChip(label: 'Alle', emoji: '📋', selected: _selectedCategory == null, onTap: () => setState(() => _selectedCategory = null)),
                ...CrisisCategory.values.map((cat) => Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: _CatChip(label: cat.label, emoji: cat.emoji, selected: _selectedCategory == cat.value, onTap: () => setState(() => _selectedCategory = cat.value)),
                )),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Crisis list or map
          Expanded(
            child: crises.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Fehler: $e')),
              data: (list) {
                var filtered = list.where((c) {
                  if (_statusFilter == 'active') return c.status == 'active' || c.status == 'in_progress';
                  return c.status == _statusFilter;
                }).toList();
                if (_selectedCategory != null) {
                  filtered = filtered.where((c) => c.type == _selectedCategory).toList();
                }
                if (_view == 'map') {
                  return _CrisisMapView(crises: filtered);
                }
                if (filtered.isEmpty) {
                  return ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_statusFilter == 'active' ? Icons.check_circle_outline : Icons.history,
                                size: 56, color: _statusFilter == 'active' ? AppColors.success : AppColors.textMuted),
                            const SizedBox(height: 12),
                            Text(_statusFilter == 'active' ? 'Keine aktiven Krisen' : 'Keine Eintraege',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                            if (_statusFilter == 'active')
                              const Text('Alles in Ordnung!', style: TextStyle(color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: _EmergencyNumbersCard(),
                      ),
                    ],
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(activeCrisesProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length + 1,
                    itemBuilder: (_, i) {
                      if (i == filtered.length) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: _EmergencyNumbersCard(),
                        );
                      }
                      return _CrisisCard(
                        crisis: filtered[i],
                        onTap: () => context.push('/dashboard/crisis/${filtered[i].id}'),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final void Function(String) onTap;
  const _StatusChip({required this.label, required this.value, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final sel = selected == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? AppColors.emergency : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? AppColors.emergency : AppColors.border),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sel ? Colors.white : AppColors.textSecondary)),
      ),
    );
  }
}

class _CatChip extends StatelessWidget {
  final String label;
  final String emoji;
  final bool selected;
  final VoidCallback onTap;
  const _CatChip({required this.label, required this.emoji, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.emergencyLight : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? AppColors.emergency : AppColors.border),
        ),
        child: Text('$emoji $label', style: TextStyle(fontSize: 11, color: selected ? AppColors.emergency : AppColors.textSecondary)),
      ),
    );
  }
}

class _CrisisCard extends StatelessWidget {
  final Crisis crisis;
  final VoidCallback onTap;
  const _CrisisCard({required this.crisis, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final urgencyColor = _getUrgencyColor(crisis.urgency);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: crisis.urgency == CrisisUrgency.critical ? AppColors.emergency.withValues(alpha: 0.5) : AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(crisis.crisisCategory.emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(crisis.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: urgencyColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(crisis.urgency.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: urgencyColor)),
                  ),
                ],
              ),
              if (crisis.description != null && crisis.description!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(crisis.description!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3)),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  if (crisis.address != null) ...[
                    const Icon(Icons.location_on_outlined, size: 13, color: AppColors.textMuted),
                    const SizedBox(width: 3),
                    Expanded(child: Text(crisis.address!, style: const TextStyle(fontSize: 11, color: AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                  if (crisis.helperCount != null && crisis.helperCount! > 0) ...[
                    const Icon(Icons.people_outline, size: 13, color: AppColors.textMuted),
                    const SizedBox(width: 3),
                    Text('${crisis.helperCount} Helfer', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    const SizedBox(width: 8),
                  ],
                  Text(timeago.format(crisis.createdAt, locale: 'de'), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  if (crisis.verified) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.verified, size: 14, color: AppColors.info),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getUrgencyColor(CrisisUrgency urgency) {
    switch (urgency) {
      case CrisisUrgency.critical: return AppColors.emergency;
      case CrisisUrgency.high: return const Color(0xFFF97316);
      case CrisisUrgency.medium: return AppColors.warning;
      case CrisisUrgency.low: return AppColors.success;
    }
  }
}

// ---------------------------------------------------------------------------
// Emergency numbers card (quick dial)
// ---------------------------------------------------------------------------
class _EmergencyNumbersCard extends StatelessWidget {
  const _EmergencyNumbersCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Notrufnummern', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            SizedBox(height: 12),
            _EmergencyTile(label: 'Polizei', number: '110', icon: Icons.local_police),
            _EmergencyTile(label: 'Feuerwehr / Rettung', number: '112', icon: Icons.local_fire_department),
            _EmergencyTile(label: 'Telefonseelsorge', number: '0800 111 0 111', icon: Icons.phone_in_talk),
            _EmergencyTile(label: 'Giftnotruf', number: '030 19240', icon: Icons.science),
            _EmergencyTile(label: 'Frauennotruf', number: '08000 116 016', icon: Icons.shield),
          ],
        ),
      ),
    );
  }
}

class _EmergencyTile extends StatelessWidget {
  final String label;
  final String number;
  final IconData icon;
  const _EmergencyTile({required this.label, required this.number, required this.icon});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: AppColors.emergency.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: AppColors.emergency, size: 18),
      ),
      title: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      subtitle: Text(number, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
      trailing: const Icon(Icons.call, size: 20, color: AppColors.emergency),
      onTap: () async {
        final uri = Uri.parse('tel:${number.replaceAll(' ', '')}');
        await launchUrl(uri);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Crisis Map view
// ---------------------------------------------------------------------------
class _CrisisMapView extends StatelessWidget {
  final List<Crisis> crises;
  const _CrisisMapView({required this.crises});

  @override
  Widget build(BuildContext context) {
    final withCoords = crises.where((c) => c.latitude != null && c.longitude != null).toList();
    final center = withCoords.isNotEmpty
        ? LatLng(withCoords.first.latitude!, withCoords.first.longitude!)
        : const LatLng(48.2082, 16.3738);
    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: withCoords.isEmpty ? 6 : 10,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'de.mensaena.app',
        ),
        MarkerLayer(
          markers: withCoords.map((c) => Marker(
            point: LatLng(c.latitude!, c.longitude!),
            width: 40, height: 40,
            child: GestureDetector(
              onTap: () => context.push('/dashboard/crisis/${c.id}'),
              child: Container(
                decoration: BoxDecoration(
                  color: c.urgency == CrisisUrgency.critical ? AppColors.emergency : AppColors.warning,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 2))],
                ),
                child: const Icon(Icons.warning, color: Colors.white, size: 20),
              ),
            ),
          )).toList(),
        ),
      ],
    );
  }
}
