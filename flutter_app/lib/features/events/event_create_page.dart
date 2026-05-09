import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase.dart';
import '../../theme/app_colors.dart';
import 'models.dart';

/// /dashboard/events/create — Pendant zu src/app/dashboard/events/create.
class EventCreatePage extends ConsumerStatefulWidget {
  const EventCreatePage({super.key});

  @override
  ConsumerState<EventCreatePage> createState() => _EventCreatePageState();
}

class _EventCreatePageState extends ConsumerState<EventCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _locationName = TextEditingController();
  final _locationAddress = TextEditingController();
  final _onlineUrl = TextEditingController();
  final _maxAttendees = TextEditingController();
  final _cost = TextEditingController(text: 'kostenlos');

  String _category = 'meetup';
  bool _isAllDay = false;
  bool _isOnline = false;
  DateTime? _startDate;
  TimeOfDay? _startTime;
  DateTime? _endDate;
  TimeOfDay? _endTime;
  String? _imageUrl;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _locationName.dispose();
    _locationAddress.dispose();
    _onlineUrl.dispose();
    _maxAttendees.dispose();
    _cost.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _startTime = picked);
  }

  Future<void> _pickEndDate() async {
    final base = _startDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? base,
      firstDate: base,
      lastDate: base.add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? (_startTime ?? TimeOfDay.now()),
    );
    if (picked != null) setState(() => _endTime = picked);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 80,
    );
    if (picked == null) return;
    try {
      final db = ref.read(supabaseProvider);
      final user = db.auth.currentUser;
      if (user == null) return;
      final ext = picked.name.split('.').last.toLowerCase();
      final path =
          '${user.id}/event-${DateTime.now().millisecondsSinceEpoch}.$ext';
      final bytes = await picked.readAsBytes();
      await db.storage.from('event-images').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );
      final url = db.storage.from('event-images').getPublicUrl(path);
      if (!mounted) return;
      setState(() => _imageUrl = url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bild-Upload fehlgeschlagen: $e')),
      );
    }
  }

  DateTime _composeDateTime(DateTime date, TimeOfDay? time) {
    if (time == null) {
      return DateTime(date.year, date.month, date.day);
    }
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte Startdatum wählen')),
      );
      return;
    }
    if (!_isAllDay && _startTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte Startzeit wählen')),
      );
      return;
    }
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    try {
      final db = ref.read(supabaseProvider);
      final user = db.auth.currentUser;
      if (user == null) throw Exception('Nicht eingeloggt');

      final start = _composeDateTime(_startDate!, _isAllDay ? null : _startTime);
      DateTime? end;
      if (_endDate != null) {
        end = _composeDateTime(_endDate!, _isAllDay ? null : _endTime);
      }

      final maxAtt = int.tryParse(_maxAttendees.text.trim());

      final row = await db.from('events').insert(<String, dynamic>{
        'author_id': user.id,
        'title': _title.text.trim(),
        if (_description.text.trim().isNotEmpty)
          'description': _description.text.trim(),
        'category': _category,
        'is_all_day': _isAllDay,
        'is_online': _isOnline,
        'start_date': start.toIso8601String(),
        if (end != null) 'end_date': end.toIso8601String(),
        if (!_isOnline && _locationName.text.trim().isNotEmpty)
          'location_name': _locationName.text.trim(),
        if (!_isOnline && _locationAddress.text.trim().isNotEmpty)
          'location_address': _locationAddress.text.trim(),
        if (_isOnline && _onlineUrl.text.trim().isNotEmpty)
          'online_url': _onlineUrl.text.trim(),
        if (_imageUrl != null) 'image_url': _imageUrl,
        if (maxAtt != null) 'max_attendees': maxAtt,
        if (_cost.text.trim().isNotEmpty) 'cost': _cost.text.trim(),
        'status': 'active',
      }).select('id').single();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event veröffentlicht')),
      );
      context.go('/dashboard/events/${row['id']}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Event erstellen')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ImagePickerTile(imageUrl: _imageUrl, onPick: _pickImage),
            const SizedBox(height: 16),
            const _Label('Titel *'),
            TextFormField(
              controller: _title,
              maxLength: 100,
              textCapitalization: TextCapitalization.sentences,
              decoration: _deco('z. B. Park-Cleanup am Sonntag'),
              validator: (v) =>
                  (v ?? '').trim().length < 3 ? 'Min. 3 Zeichen' : null,
            ),
            const SizedBox(height: 12),
            const _Label('Beschreibung'),
            TextFormField(
              controller: _description,
              maxLines: 5,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              decoration: _deco('Was erwartet die Teilnehmer?'),
            ),
            const SizedBox(height: 12),
            const _Label('Kategorie *'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: EventCategory.all
                  .map(
                    (c) => ChoiceChip(
                      label: Text('${c.emoji} ${c.label}'),
                      selected: _category == c.value,
                      onSelected: (_) =>
                          setState(() => _category = c.value),
                      selectedColor: c.color.withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                        color: _category == c.value
                            ? c.color
                            : AppColors.ink700,
                        fontWeight: _category == c.value
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ganztägig'),
              value: _isAllDay,
              onChanged: (v) => setState(() => _isAllDay = v),
            ),
            const _Label('Start *'),
            Row(
              children: [
                Expanded(
                  child: _PickerButton(
                    icon: Icons.calendar_today_outlined,
                    label: _startDate != null
                        ? DateFormat('d. MMM yyyy', 'de').format(_startDate!)
                        : 'Datum',
                    onTap: _pickStartDate,
                  ),
                ),
                if (!_isAllDay) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PickerButton(
                      icon: Icons.access_time,
                      label: _startTime != null
                          ? _startTime!.format(context)
                          : 'Uhrzeit',
                      onTap: _pickStartTime,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            const _Label('Ende (optional)'),
            Row(
              children: [
                Expanded(
                  child: _PickerButton(
                    icon: Icons.calendar_today_outlined,
                    label: _endDate != null
                        ? DateFormat('d. MMM yyyy', 'de').format(_endDate!)
                        : 'Datum',
                    onTap: _pickEndDate,
                  ),
                ),
                if (!_isAllDay) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PickerButton(
                      icon: Icons.access_time,
                      label: _endTime != null
                          ? _endTime!.format(context)
                          : 'Uhrzeit',
                      onTap: _pickEndTime,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Online-Event'),
              subtitle: const Text(
                'Findet per Video-Call statt',
                style: TextStyle(fontSize: 12, color: AppColors.ink400),
              ),
              value: _isOnline,
              onChanged: (v) => setState(() => _isOnline = v),
            ),
            if (_isOnline) ...[
              const SizedBox(height: 8),
              const _Label('Online-Link'),
              TextFormField(
                controller: _onlineUrl,
                keyboardType: TextInputType.url,
                decoration: _deco('https://meet.example/abc'),
              ),
            ] else ...[
              const SizedBox(height: 8),
              const _Label('Ort'),
              TextFormField(
                controller: _locationName,
                textCapitalization: TextCapitalization.sentences,
                decoration: _deco('z. B. Stadtpark Eingang Nord'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _locationAddress,
                textCapitalization: TextCapitalization.sentences,
                decoration: _deco('Adresse'),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('Max. Teilnehmer'),
                      TextFormField(
                        controller: _maxAttendees,
                        keyboardType: TextInputType.number,
                        decoration: _deco('z. B. 20'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('Kosten'),
                      TextFormField(
                        controller: _cost,
                        decoration: _deco('kostenlos'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.event_available),
                label: Text(_saving ? 'Veröffentliche…' : 'Veröffentlichen'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _deco(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: AppColors.primary500,
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: AppColors.ink400,
        ),
      ),
    );
  }
}

class _PickerButton extends StatelessWidget {
  const _PickerButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: AppColors.ink700),
      label: Text(
        label,
        style: const TextStyle(
          color: AppColors.ink700,
          fontWeight: FontWeight.w500,
        ),
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        side: BorderSide(color: Colors.grey.shade300),
        backgroundColor: Colors.white,
        alignment: Alignment.centerLeft,
      ),
    );
  }
}

class _ImagePickerTile extends StatelessWidget {
  const _ImagePickerTile({required this.imageUrl, required this.onPick});
  final String? imageUrl;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPick,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        clipBehavior: Clip.antiAlias,
        child: imageUrl != null
            ? Image.network(
                imageUrl!,
                width: double.infinity,
                fit: BoxFit.cover,
              )
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 32,
                    color: AppColors.primary500,
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Bild hinzufügen',
                    style: TextStyle(
                      color: AppColors.ink400,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
