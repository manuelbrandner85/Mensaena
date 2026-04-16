import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/providers/event_provider.dart';

class EventCreateScreen extends ConsumerStatefulWidget {
  const EventCreateScreen({super.key});
  @override ConsumerState<EventCreateScreen> createState() => _EventCreateScreenState();
}

class _EventCreateScreenState extends ConsumerState<EventCreateScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();
  DateTime _date = DateTime.now().add(const Duration(days: 7));
  bool _loading = false;

  @override void dispose() { _titleCtrl.dispose(); _descCtrl.dispose(); _locationCtrl.dispose(); _timeCtrl.dispose(); super.dispose(); }

  Future<void> _create() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    setState(() => _loading = true);
    try {
      await ref.read(eventServiceProvider).createEvent({
        'user_id': userId, 'title': _titleCtrl.text.trim(), 'description': _descCtrl.text.trim(),
        'event_date': _date.toIso8601String().split('T')[0], 'event_time': _timeCtrl.text.trim().isNotEmpty ? _timeCtrl.text.trim() : null,
        'location_text': _locationCtrl.text.trim().isNotEmpty ? _locationCtrl.text.trim() : null, 'status': 'upcoming',
      });
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event erstellt!'))); context.pop(); }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e'))); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Event erstellen')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextFormField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Titel *')),
        const SizedBox(height: 16),
        TextFormField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Beschreibung'), maxLines: 4),
        const SizedBox(height: 16),
        ListTile(leading: const Icon(Icons.calendar_today), title: Text('${_date.day}.${_date.month}.${_date.year}'), subtitle: const Text('Datum'),
          onTap: () async { final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365))); if (d != null) setState(() => _date = d); }),
        TextFormField(controller: _timeCtrl, decoration: const InputDecoration(labelText: 'Uhrzeit', hintText: '14:00')),
        const SizedBox(height: 16),
        TextFormField(controller: _locationCtrl, decoration: const InputDecoration(labelText: 'Ort', prefixIcon: Icon(Icons.location_on_outlined))),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _loading ? null : _create, child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Event erstellen'))),
      ]),
    );
  }
}