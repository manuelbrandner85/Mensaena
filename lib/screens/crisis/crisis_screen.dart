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
  String? _urgencyFilter;
  String _view = 'list';
  String _search = '';
  RealtimeChannel? _channel;
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _channel = Supabase.instance.client.channel('crises-realtime')
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'crises',
          callback: (_) {
            if (mounted) {
              ref.invalidate(activeCrisesProvider);
              ref.invalidate(crisisStatsProvider);
            }
          })
        .subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _scrollCtrl.dispose();
    super.dispose();
  }

  List<Crisis> _applyFilters(List<Crisis> list) {
    var filtered = list.where((c) {
      if (_statusFilter == 'active') return c.status == 'active' || c.status == 'in_progress';
      return c.status == _statusFilter;
    }).toList();
    if (_selectedCategory != null) {
      filtered = filtered.where((c) => c.type == _selectedCategory).toList();
    }
    if (_urgencyFilter != null) {
      filtered = filtered.where((c) => c.urgency.value == _urgencyFilter).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      filtered = filtered.where((c) =>
          c.title.toLowerCase().contains(q) ||
          (c.description?.toLowerCase().contains(q) ?? false)).toList();
    }
    return filtered;
  }

  void _showSOSModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning, size: 48, color: AppColors.emergency),
              const SizedBox(height: 12),
              const Text('SOS – Soforthilfe', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.emergency)),
              const SizedBox(height: 20),
              _SOSButton(label: '112 Anrufen', subtitle: 'Feuerwehr / Rettungsdienst', icon: Icons.local_fire_department,
                  onTap: () { Navigator.pop(ctx); launchUrl(Uri.parse('tel:112')); }),
              const SizedBox(height: 10),
              _SOSButton(label: 'Polizei 110', subtitle: 'Polizeinotruf', icon: Icons.local_police,
                  onTap: () { Navigator.pop(ctx); launchUrl(Uri.parse('tel:110')); }),
              const SizedBox(height: 10),
              _SOSButton(label: 'Telefonseelsorge', subtitle: '0800 111 0 111 (kostenlos)', icon: Icons.phone_in_talk, emergency: false,
                  onTap: () { Navigator.pop(ctx); launchUrl(Uri.parse('tel:08001110111')); }),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () { Navigator.pop(ctx); context.push('/dashboard/crisis/create'); },
                  icon: const Icon(Icons.edit),
                  label: const Text('Krise bei Mensaena melden'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    foregroundColor: AppColors.emergency,
                    side: const BorderSide(color: AppColors.emergency),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final crises = ref.watch(activeCrisesProvider);
    final statsAsync = ref.watch(crisisStatsProvider);

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
              number: '16',
              title: 'Krisen & Notfälle',
              subtitle: 'Schnelle Hilfe in Notsituationen',
              icon: Icons.warning_outlined,
            ),
          ),
          // SOS Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: GestureDetector(
              onTap: _showSOSModal,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.emergency,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: AppColors.emergency.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4))],
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
                        Text('SOS – Krise melden', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                        Text('Sofort Hilfe anfordern', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Stats Dashboard
          statsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (stats) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  _StatMini(label: 'Aktiv', value: stats['active'] ?? 0, color: AppColors.emergency),
                  const SizedBox(width: 8),
                  _StatMini(label: 'In Bearbeitung', value: stats['in_progress'] ?? 0, color: AppColors.warning),
                  const SizedBox(width: 8),
                  _StatMini(label: 'Gelöst', value: stats['resolved'] ?? 0, color: AppColors.success),
                ],
              ),
            ),
          ),

          // Alert Banner (ALL active + in_progress, not just critical)
          crises.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (list) {
              final activeCount = list.where((c) => c.status == 'active' || c.status == 'in_progress').length;
              if (activeCount == 0) return const SizedBox.shrink();
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
                        '$activeCount aktive Krise${activeCount == 1 ? '' : 'n'} in deiner Umgebung',
                        style: const TextStyle(color: AppColors.emergency, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Search field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Krisen suchen...',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setState(() => _search = ''))
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true, fillColor: AppColors.background,
              ),
              onChanged: (v) => setState(() => _search = v.trim()),
            ),
          ),

          // Status + Urgency filters
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

          // Urgency filter
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: SizedBox(
              height: 32,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _UrgencyChip(label: 'Alle', value: null, selected: _urgencyFilter, onTap: (v) => setState(() => _urgencyFilter = v)),
                  const SizedBox(width: 6),
                  _UrgencyChip(label: 'Kritisch', value: 'critical', selected: _urgencyFilter, color: AppColors.emergency, onTap: (v) => setState(() => _urgencyFilter = v)),
                  const SizedBox(width: 6),
                  _UrgencyChip(label: 'Hoch', value: 'high', selected: _urgencyFilter, color: const Color(0xFFF97316), onTap: (v) => setState(() => _urgencyFilter = v)),
                  const SizedBox(width: 6),
                  _UrgencyChip(label: 'Mittel', value: 'medium', selected: _urgencyFilter, color: AppColors.warning, onTap: (v) => setState(() => _urgencyFilter = v)),
                  const SizedBox(width: 6),
                  _UrgencyChip(label: 'Niedrig', value: 'low', selected: _urgencyFilter, color: AppColors.success, onTap: (v) => setState(() => _urgencyFilter = v)),
                ],
              ),
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
                final filtered = _applyFilters(list);
                if (_view == 'map') return _CrisisMapView(crises: filtered);
                if (filtered.isEmpty) {
                  return ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Column(
                          children: [
                            Icon(_statusFilter == 'active' ? Icons.check_circle_outline : Icons.history,
                                size: 56, color: _statusFilter == 'active' ? AppColors.success : AppColors.textMuted),
                            const SizedBox(height: 12),
                            Text(_statusFilter == 'active' ? 'Keine aktiven Krisen' : 'Keine Einträge',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                            if (_statusFilter == 'active')
                              const Text('Alles in Ordnung!', style: TextStyle(color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                      const Padding(padding: EdgeInsets.all(12), child: _EmergencyNumbersCard()),
                    ],
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(activeCrisesProvider);
                    ref.invalidate(crisisStatsProvider);
                  },
                  child: ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length + 2,
                    itemBuilder: (_, i) {
                      if (i == filtered.length) {
                        return const Padding(padding: EdgeInsets.only(top: 8), child: _EmergencyNumbersCard());
                      }
                      if (i == filtered.length + 1) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: OutlinedButton.icon(
                            onPressed: () => context.push('/dashboard/crisis/resources'),
                            icon: const Icon(Icons.menu_book, size: 18),
                            label: const Text('Ressourcen & Hilfsangebote'),
                          ),
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

class _SOSButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool emergency;
  const _SOSButton({required this.label, required this.subtitle, required this.icon, required this.onTap, this.emergency = true});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: emergency ? AppColors.emergency : AppColors.primary500,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 24),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.white70)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatMini extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _StatMini({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text('$value', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _UrgencyChip extends StatelessWidget {
  final String label;
  final String? value;
  final String? selected;
  final Color color;
  final void Function(String?) onTap;
  const _UrgencyChip({required this.label, required this.value, required this.selected, this.color = AppColors.primary500, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final sel = selected == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: sel ? color.withValues(alpha: 0.15) : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: sel ? color : AppColors.border),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: sel ? color : AppColors.textSecondary)),
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

class _EmergencyNumbersCard extends ConsumerWidget {
  const _EmergencyNumbersCard();

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'emergency': return Icons.emergency;
      case 'crisis': return Icons.phone_in_talk;
      case 'children': return Icons.child_care;
      case 'women': return Icons.shield;
      case 'poison': return Icons.science;
      default: return Icons.local_hospital;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final numbersAsync = ref.watch(emergencyNumbersProvider(null));
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Notrufnummern', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            numbersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Text('Fehler beim Laden'),
              data: (numbers) {
                if (numbers.isEmpty) {
                  return const Text('Keine Notrufnummern verfügbar');
                }
                return Column(
                  children: numbers.map((n) => _EmergencyTile(
                    label: n['label'] as String? ?? '',
                    number: n['number'] as String? ?? '',
                    icon: _categoryIcon(n['category'] as String? ?? ''),
                    description: n['description'] as String?,
                    is24h: n['is_24h'] as bool? ?? false,
                    isFree: n['is_free'] as bool? ?? false,
                  )).toList(),
                );
              },
            ),
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
  final String? description;
  final bool is24h;
  final bool isFree;
  const _EmergencyTile({required this.label, required this.number, required this.icon, this.description, this.is24h = false, this.isFree = false});

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
      subtitle: Row(
        children: [
          Text(number, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          if (is24h) ...[const SizedBox(width: 6), const Text('24h', style: TextStyle(fontSize: 10, color: AppColors.success, fontWeight: FontWeight.w600))],
          if (isFree) ...[const SizedBox(width: 4), const Text('kostenlos', style: TextStyle(fontSize: 10, color: AppColors.success, fontWeight: FontWeight.w600))],
        ],
      ),
      trailing: const Icon(Icons.call, size: 20, color: AppColors.emergency),
      onTap: () async {
        await launchUrl(Uri.parse('tel:${number.replaceAll(' ', '')}'));
      },
    );
  }
}

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
      options: MapOptions(initialCenter: center, initialZoom: withCoords.isEmpty ? 6 : 10),
      children: [
        TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'de.mensaena.app'),
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
