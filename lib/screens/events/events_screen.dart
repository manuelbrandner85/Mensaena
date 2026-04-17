import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/event_provider.dart';
import 'package:mensaena/models/event.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mensaena/widgets/empty_state.dart';

class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});
  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  String? _selectedCategory;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _channel = Supabase.instance.client.channel('events-realtime')
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'events',
          callback: (_) { if (mounted) ref.invalidate(eventsProvider); })
        .subscribe();
  }

  @override
  void dispose() { _channel?.unsubscribe(); super.dispose(); }

  static const _categories = [
    (value: null, label: 'Alle', emoji: '📋'),
    (value: 'meetup', label: 'Treffen', emoji: '👥'),
    (value: 'workshop', label: 'Workshop', emoji: '🎓'),
    (value: 'sport', label: 'Sport', emoji: '🏃'),
    (value: 'food', label: 'Essen', emoji: '🍽️'),
    (value: 'market', label: 'Markt', emoji: '🛍️'),
    (value: 'culture', label: 'Kultur', emoji: '🎵'),
    (value: 'kids', label: 'Kinder', emoji: '👶'),
    (value: 'seniors', label: 'Senioren', emoji: '❤️'),
    (value: 'cleanup', label: 'Aufraeumaktion', emoji: '♻️'),
  ];

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(eventsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('§ 05 · Termine')),
      body: Column(
        children: [
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final c = _categories[i];
                final sel = _selectedCategory == c.value;
                return FilterChip(
                  label: Text('${c.emoji} ${c.label}', style: TextStyle(fontSize: 11, color: sel ? Colors.white : AppColors.textSecondary)),
                  selected: sel, selectedColor: AppColors.primary500,
                  onSelected: (_) => setState(() => _selectedCategory = c.value),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: events.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Fehler: $e')),
              data: (list) {
                final filtered = _selectedCategory != null
                    ? list.where((e) => e.category == _selectedCategory).toList()
                    : list;
                if (filtered.isEmpty) {
                  return const EmptyState(icon: Icons.event_outlined, title: 'Keine Events', message: 'Erstelle das erste Event!');
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(eventsProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _EventCard(
                      event: filtered[i],
                      onTap: () => context.push('/dashboard/events/${filtered[i].id}'),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/dashboard/events/create'),
        icon: const Icon(Icons.add),
        label: const Text('Event erstellen'),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Event event;
  final VoidCallback onTap;
  const _EventCard({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final catConfig = EventCategoryConfig.fromString(event.category);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(color: AppColors.primary50, borderRadius: BorderRadius.circular(14)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(DateFormat('dd').format(event.startDate), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary700)),
                    Text(DateFormat('MMM', 'de').format(event.startDate), style: const TextStyle(fontSize: 11, color: AppColors.primary500)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(catConfig.emoji, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Expanded(child: Text(event.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    if (event.locationDisplay.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(children: [
                        const Icon(Icons.location_on_outlined, size: 13, color: AppColors.textMuted),
                        const SizedBox(width: 3),
                        Expanded(child: Text(event.locationDisplay, style: const TextStyle(fontSize: 11, color: AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ]),
                    ],
                    if (!event.isAllDay) ...[
                      const SizedBox(height: 2),
                      Row(children: [
                        const Icon(Icons.access_time, size: 13, color: AppColors.textMuted),
                        const SizedBox(width: 3),
                        Text(DateFormat('HH:mm', 'de').format(event.startDate), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        if (event.cost != null && event.cost != 'kostenlos') ...[
                          const SizedBox(width: 10),
                          Text(event.cost!, style: const TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w500)),
                        ],
                      ]),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
