import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../routing/routes.dart';
import '../../theme/app_colors.dart';
import '../../widgets/page_chrome.dart';
import 'crisis_dashboard.dart';
import 'crisis_repository.dart';
import 'models.dart';

class CrisisPage extends ConsumerStatefulWidget {
  const CrisisPage({super.key});

  @override
  ConsumerState<CrisisPage> createState() => _CrisisPageState();
}

class _CrisisPageState extends ConsumerState<CrisisPage> {
  List<Crisis> _items = [];
  bool _loading = true;
  String _category = 'all';
  String _urgency = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await ref.read(crisisRepositoryProvider).list(
            category: _category,
            urgency: _urgency,
          );
      if (!mounted) return;
      setState(() {
        _items = list;
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
        title: const Text('Krisen-Berichte'),
        actions: [
          IconButton(
            icon: const Icon(Icons.local_phone_outlined),
            tooltip: 'Notruf-Nummern',
            onPressed: () => context.go(Routes.dashboardCrisisResources),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Krise melden',
            onPressed: () => context.go(Routes.dashboardCrisisCreate),
          ),
        ],
      ),
      body: Column(
        children: [
          const HeroHeader(
            metaLabel: 'Krisen',
            title: 'Hilfe in der Nachbarschaft',
            subtitle:
                'Akute Notlagen melden oder helfen — anonym, schnell, lokal.',
            icon: Icons.crisis_alert,
            iconColor: AppColors.emergency500,
          ),
          if (!_loading) CrisisDashboard(items: _items),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _Chip(
                  label: 'Alle Kategorien',
                  selected: _category == 'all',
                  onTap: () {
                    setState(() => _category = 'all');
                    _load();
                  },
                ),
                ...CrisisCategory.all.map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: _Chip(
                      label: '${c.emoji} ${c.label}',
                      selected: _category == c.value,
                      onTap: () {
                        setState(() => _category = c.value);
                        _load();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _Chip(
                  label: 'Alle Stufen',
                  selected: _urgency == 'all',
                  onTap: () {
                    setState(() => _urgency = 'all');
                    _load();
                  },
                ),
                ...CrisisUrgency.values.map(
                  (u) => Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: _Chip(
                      label: u.label,
                      selected: _urgency == u.value,
                      color: u.color,
                      onTap: () {
                        setState(() => _urgency = u.value);
                        _load();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('🛡️', style: TextStyle(fontSize: 48)),
                              SizedBox(height: 12),
                              Text(
                                'Keine aktiven Krisen',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) => _CrisisTile(crisis: _items[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppColors.primary500;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: accent.withValues(alpha: 0.15),
      checkmarkColor: accent,
      labelStyle: TextStyle(
        color: selected ? accent : AppColors.ink700,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        fontSize: 12,
      ),
    );
  }
}

class _CrisisTile extends StatelessWidget {
  const _CrisisTile({required this.crisis});
  final Crisis crisis;

  @override
  Widget build(BuildContext context) {
    final cat = crisis.categoryConfig;
    final time = DateFormat('d. MMM, HH:mm', 'de').format(crisis.createdAt);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => context.go('${Routes.dashboardCrisis}/${crisis.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border(
              left: BorderSide(color: crisis.urgency.color, width: 4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: crisis.urgency.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${cat.emoji} ${crisis.urgency.label}',
                      style: TextStyle(
                        color: crisis.urgency.color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: crisis.status.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      crisis.status.label,
                      style: TextStyle(
                        color: crisis.status.color,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
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
              const SizedBox(height: 8),
              Text(
                crisis.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              if (crisis.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  crisis.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink700,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  if (crisis.locationText != null) ...[
                    const Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: AppColors.ink400,
                    ),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(
                        crisis.locationText!,
                        style: const TextStyle(
                          color: AppColors.ink400,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  const Spacer(),
                  const Icon(
                    Icons.people_outline,
                    size: 14,
                    color: AppColors.ink400,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${crisis.helperCount}/${crisis.neededHelpers}',
                    style: const TextStyle(
                      color: AppColors.ink400,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
