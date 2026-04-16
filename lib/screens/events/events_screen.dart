import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/event_provider.dart';
import 'package:mensaena/models/event.dart';
import 'package:mensaena/widgets/empty_state.dart';

class EventsScreen extends ConsumerWidget {
  const EventsScreen({super.key});
  @override Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(eventsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('📅 Events')),
      body: events.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (list) => list.isEmpty
          ? EmptyState(icon: Icons.event_outlined, title: 'Keine Events', message: 'Erstelle das erste Event!')
          : RefreshIndicator(onRefresh: () async { ref.invalidate(eventsProvider); },
              child: ListView.builder(padding: const EdgeInsets.all(12), itemCount: list.length,
                itemBuilder: (_, i) => _EventCard(event: list[i], onTap: () => context.push('/dashboard/events/${list[i].id}')))),
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => context.push('/dashboard/events/create'), icon: const Icon(Icons.add), label: const Text('Event erstellen')),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Event event; final VoidCallback onTap;
  const _EventCard({required this.event, required this.onTap});
  @override Widget build(BuildContext context) {
    return Card(margin: const EdgeInsets.only(bottom: 12), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16),
      child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.primary50, borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            Text(DateFormat('dd').format(event.eventDate), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.primary700)),
            Text(DateFormat('MMM', 'de').format(event.eventDate), style: const TextStyle(fontSize: 12, color: AppColors.primary500)),
          ])),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(event.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          if (event.locationText != null) ...[const SizedBox(height: 4), Row(children: [
            const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textMuted), const SizedBox(width: 4),
            Expanded(child: Text(event.locationText!, style: const TextStyle(fontSize: 12, color: AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis))])],
          if (event.eventTime != null) ...[const SizedBox(height: 2), Row(children: [
            const Icon(Icons.access_time, size: 14, color: AppColors.textMuted), const SizedBox(width: 4),
            Text(event.eventTime!, style: const TextStyle(fontSize: 12, color: AppColors.textMuted))])],
        ])),
        const Icon(Icons.chevron_right, color: AppColors.textMuted),
      ]))));
  }
}