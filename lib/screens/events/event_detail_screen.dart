import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/event_provider.dart';

class EventDetailScreen extends ConsumerWidget {
  final String eventId;
  const EventDetailScreen({super.key, required this.eventId});
  @override Widget build(BuildContext context, WidgetRef ref) {
    final event = ref.watch(eventDetailProvider(eventId));
    return Scaffold(
      appBar: AppBar(title: const Text('Event')),
      body: event.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (e) {
          if (e == null) return const Center(child: Text('Event nicht gefunden'));
          return ListView(padding: const EdgeInsets.all(16), children: [
            Text(e.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            _InfoRow(icon: Icons.calendar_today, text: DateFormat('dd.MM.yyyy', 'de').format(e.eventDate)),
            if (e.eventTime != null) _InfoRow(icon: Icons.access_time, text: e.eventTime!),
            if (e.locationText != null) _InfoRow(icon: Icons.location_on_outlined, text: e.locationText!),
            if (e.description != null) ...[const SizedBox(height: 16), Text(e.description!, style: const TextStyle(fontSize: 15, height: 1.5))],
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.check), label: const Text('Teilnehmen'))),
          ]);
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon; final String text;
  const _InfoRow({required this.icon, required this.text});
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [Icon(icon, size: 18, color: AppColors.primary500), const SizedBox(width: 8), Text(text, style: const TextStyle(fontSize: 14))]));
}