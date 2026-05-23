import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../repositories/events_repository.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

class EventCreateScreen extends ConsumerStatefulWidget {
  const EventCreateScreen({super.key});

  @override
  ConsumerState<EventCreateScreen> createState() => _EventCreateScreenState();
}

class _EventCreateScreenState extends ConsumerState<EventCreateScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _location = TextEditingController();
  final _maxAttendees = TextEditingController();
  String _category = 'community';
  DateTime _start = DateTime.now().add(const Duration(hours: 24));
  DateTime? _end;
  bool _isOnline = false;
  bool _submitting = false;
  String? _error;

  static const List<({String value, String label})> _categories = [
    (value: 'community', label: 'Community'),
    (value: 'workshop', label: 'Workshop'),
    (value: 'sport', label: 'Sport'),
    (value: 'kultur', label: 'Kultur'),
    (value: 'familie', label: 'Familie'),
    (value: 'sonstiges', label: 'Sonstiges'),
  ];

  Future<void> _pickStart() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_start),
    );
    if (time == null || !mounted) return;
    setState(() {
      _start = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Titel ist Pflicht.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final id = await EventsRepository.create(
      title: _title.text.trim(),
      category: _category,
      startDate: _start,
      endDate: _end,
      description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
      locationName: _location.text.trim().isEmpty
          ? null
          : _location.text.trim(),
      maxAttendees: int.tryParse(_maxAttendees.text.trim()),
      isOnline: _isOnline,
    );
    if (!mounted) return;
    if (id == null) {
      setState(() {
        _submitting = false;
        _error = 'Konnte Event nicht speichern.';
      });
      return;
    }
    context.go('/dashboard/events/$id');
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'Event erstellen',
      currentRoute: '/dashboard/events',
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextField(
              controller: _title,
              maxLength: 120,
              style: AppTypography.body(size: 15, color: AppColors.ink),
              decoration: const InputDecoration(labelText: 'Titel'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _desc,
              maxLines: 4,
              style: AppTypography.body(size: 14, color: AppColors.ink),
              decoration: const InputDecoration(
                labelText: 'Beschreibung',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 14),
            Text('Kategorie', style: AppTypography.label(size: 10)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: _categories.map((c) {
                final active = c.value == _category;
                return GestureDetector(
                  onTap: () => setState(() => _category = c.value),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.amber.withValues(alpha: 0.2)
                          : AppColors.surface.withValues(alpha: 0.5),
                      border: Border.all(
                        color: active ? AppColors.amber : AppColors.line,
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      c.label,
                      style: AppTypography.label(
                        size: 10,
                        color: active ? AppColors.amber : AppColors.inkSoft,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _pickStart,
              icon: const Icon(LucideIcons.calendar, size: 16),
              label: Text(
                DateFormat('EEEE, dd.MM.yyyy HH:mm', 'de').format(_start),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _location,
              style: AppTypography.body(size: 14, color: AppColors.ink),
              decoration: const InputDecoration(labelText: 'Ort'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _maxAttendees,
              keyboardType: TextInputType.number,
              style: AppTypography.body(size: 14, color: AppColors.ink),
              decoration: const InputDecoration(
                labelText: 'Max. Teilnehmer:innen (optional)',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: AppColors.amber,
              value: _isOnline,
              onChanged: (v) => setState(() => _isOnline = v),
              title: Text(
                'Online-Event',
                style: AppTypography.body(size: 14, color: AppColors.ink),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: AppTypography.body(
                  size: 13,
                  color: AppColors.herzrotWarm,
                ),
              ),
            ],
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: const Icon(LucideIcons.calendarPlus, size: 16),
              label: Text(_submitting ? 'Speichere…' : 'Event veröffentlichen'),
            ),
          ],
        ),
      ),
    );
  }
}
