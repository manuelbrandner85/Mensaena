import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/models/event.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/providers/event_provider.dart';

class EventCreateScreen extends ConsumerStatefulWidget {
  const EventCreateScreen({super.key});

  @override
  ConsumerState<EventCreateScreen> createState() => _EventCreateScreenState();
}

class _EventCreateScreenState extends ConsumerState<EventCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locationNameCtrl = TextEditingController();
  final _locationAddressCtrl = TextEditingController();
  final _maxAttendeesCtrl = TextEditingController();
  final _costCtrl = TextEditingController(text: 'kostenlos');
  final _whatToBringCtrl = TextEditingController();
  final _contactInfoCtrl = TextEditingController();

  String _selectedCategory = 'meetup';
  DateTime _startDate = DateTime.now().add(const Duration(days: 7));
  TimeOfDay _startTime = const TimeOfDay(hour: 14, minute: 0);
  DateTime? _endDate;
  TimeOfDay? _endTime;
  bool _isAllDay = false;
  bool _isRecurring = false;
  bool _loading = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationNameCtrl.dispose();
    _locationAddressCtrl.dispose();
    _maxAttendeesCtrl.dispose();
    _costCtrl.dispose();
    _whatToBringCtrl.dispose();
    _contactInfoCtrl.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _pickStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      locale: const Locale('de', 'DE'),
      helpText: 'Startdatum waehlen',
      cancelText: 'Abbrechen',
      confirmText: 'Waehlen',
    );
    if (date != null) {
      setState(() {
        _startDate = date;
        // If end date is before start date, reset it
        if (_endDate != null && _endDate!.isBefore(_startDate)) {
          _endDate = null;
          _endTime = null;
        }
      });
    }
  }

  Future<void> _pickStartTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _startTime,
      helpText: 'Startzeit waehlen',
      cancelText: 'Abbrechen',
      confirmText: 'Waehlen',
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (time != null) {
      setState(() => _startTime = time);
    }
  }

  Future<void> _pickEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 730)),
      locale: const Locale('de', 'DE'),
      helpText: 'Enddatum waehlen',
      cancelText: 'Abbrechen',
      confirmText: 'Waehlen',
    );
    if (date != null) {
      setState(() => _endDate = date);
    }
  }

  Future<void> _pickEndTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _endTime ?? _startTime,
      helpText: 'Endzeit waehlen',
      cancelText: 'Abbrechen',
      confirmText: 'Waehlen',
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (time != null) {
      setState(() => _endTime = time);
    }
  }

  DateTime _combineDateAndTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Du musst angemeldet sein.')),
        );
      }
      return;
    }

    setState(() => _loading = true);

    try {
      final startDateTime = _isAllDay
          ? DateTime(_startDate.year, _startDate.month, _startDate.day)
          : _combineDateAndTime(_startDate, _startTime);

      DateTime? endDateTime;
      if (_endDate != null) {
        endDateTime = _isAllDay
            ? DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59)
            : _endTime != null
                ? _combineDateAndTime(_endDate!, _endTime!)
                : DateTime(
                    _endDate!.year, _endDate!.month, _endDate!.day, 23, 59);
      }

      final maxAttendees = _maxAttendeesCtrl.text.trim().isNotEmpty
          ? int.tryParse(_maxAttendeesCtrl.text.trim())
          : null;

      final cost = _costCtrl.text.trim();
      final whatToBring = _whatToBringCtrl.text.trim();
      final contactInfo = _contactInfoCtrl.text.trim();
      final locationName = _locationNameCtrl.text.trim();
      final locationAddress = _locationAddressCtrl.text.trim();

      final eventData = <String, dynamic>{
        'author_id': userId,
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim().isNotEmpty
            ? _descCtrl.text.trim()
            : null,
        'category': _selectedCategory,
        'start_date': startDateTime.toIso8601String(),
        'end_date': endDateTime?.toIso8601String(),
        'is_all_day': _isAllDay,
        'location_name': locationName.isNotEmpty ? locationName : null,
        'location_address':
            locationAddress.isNotEmpty ? locationAddress : null,
        'max_attendees': maxAttendees,
        'cost': cost.isNotEmpty ? cost : null,
        'what_to_bring': whatToBring.isNotEmpty ? whatToBring : null,
        'contact_info': contactInfo.isNotEmpty ? contactInfo : null,
        'is_recurring': _isRecurring,
        'status': 'upcoming',
      };

      await ref.read(eventServiceProvider).createEvent(eventData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Event erfolgreich erstellt!'),
            backgroundColor: AppColors.success,
          ),
        );
        // Invalidate events cache
        ref.invalidate(eventsProvider);
        ref.invalidate(upcomingEventsProvider);
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Erstellen: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event erstellen'),
        actions: [
          TextButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Erstellen'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // -- Section: Grundlegendes --
            _buildSectionHeader('Grundlegendes'),
            const SizedBox(height: 12),

            // Title
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Titel *',
                hintText: 'z.B. Nachbarschafts-Brunch',
                prefixIcon: Icon(Icons.title),
              ),
              maxLength: 100,
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Bitte gib einen Titel ein';
                }
                if (value.trim().length < 3) {
                  return 'Der Titel muss mindestens 3 Zeichen lang sein';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Beschreibung',
                hintText: 'Was erwartet die Teilnehmenden?',
                prefixIcon: Icon(Icons.description_outlined),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              maxLength: 2000,
              textInputAction: TextInputAction.newline,
            ),
            const SizedBox(height: 16),

            // Category
            _buildSectionHeader('Kategorie'),
            const SizedBox(height: 12),
            _buildCategorySelector(),

            const SizedBox(height: 24),

            // -- Section: Datum & Zeit --
            _buildSectionHeader('Datum & Zeit'),
            const SizedBox(height: 12),

            // Is all day toggle
            _buildToggleRow(
              icon: Icons.wb_sunny_outlined,
              label: 'Ganztaegig',
              value: _isAllDay,
              onChanged: (value) => setState(() => _isAllDay = value),
            ),
            const SizedBox(height: 12),

            // Start date row
            Row(
              children: [
                Expanded(
                  child: _buildDatePickerTile(
                    icon: Icons.calendar_today,
                    label: 'Startdatum *',
                    value: _formatDate(_startDate),
                    onTap: _pickStartDate,
                  ),
                ),
                if (!_isAllDay) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDatePickerTile(
                      icon: Icons.access_time,
                      label: 'Startzeit',
                      value: _formatTime(_startTime),
                      onTap: _pickStartTime,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // End date row
            Row(
              children: [
                Expanded(
                  child: _buildDatePickerTile(
                    icon: Icons.calendar_today_outlined,
                    label: 'Enddatum',
                    value: _endDate != null ? _formatDate(_endDate!) : 'Optional',
                    onTap: _pickEndDate,
                    isMuted: _endDate == null,
                    onClear: _endDate != null
                        ? () => setState(() {
                              _endDate = null;
                              _endTime = null;
                            })
                        : null,
                  ),
                ),
                if (!_isAllDay && _endDate != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDatePickerTile(
                      icon: Icons.access_time_outlined,
                      label: 'Endzeit',
                      value: _endTime != null
                          ? _formatTime(_endTime!)
                          : 'Optional',
                      onTap: _pickEndTime,
                      isMuted: _endTime == null,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // Is recurring toggle
            _buildToggleRow(
              icon: Icons.repeat,
              label: 'Wiederkehrend',
              value: _isRecurring,
              onChanged: (value) => setState(() => _isRecurring = value),
            ),

            const SizedBox(height: 24),

            // -- Section: Ort --
            _buildSectionHeader('Ort'),
            const SizedBox(height: 12),

            TextFormField(
              controller: _locationNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Ortsname',
                hintText: 'z.B. Stadtpark Wien',
                prefixIcon: Icon(Icons.place_outlined),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _locationAddressCtrl,
              decoration: const InputDecoration(
                labelText: 'Adresse',
                hintText: 'z.B. Prater 1, 1020 Wien',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              textInputAction: TextInputAction.next,
            ),

            const SizedBox(height: 24),

            // -- Section: Details --
            _buildSectionHeader('Details'),
            const SizedBox(height: 12),

            TextFormField(
              controller: _maxAttendeesCtrl,
              decoration: const InputDecoration(
                labelText: 'Max. Teilnehmer',
                hintText: 'Leer = unbegrenzt',
                prefixIcon: Icon(Icons.group_outlined),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _costCtrl,
              decoration: const InputDecoration(
                labelText: 'Kosten',
                hintText: 'z.B. kostenlos, 5 EUR',
                prefixIcon: Icon(Icons.euro_outlined),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _whatToBringCtrl,
              decoration: const InputDecoration(
                labelText: 'Mitbringen',
                hintText: 'Was sollen Teilnehmende mitbringen?',
                prefixIcon: Icon(Icons.backpack_outlined),
              ),
              maxLines: 2,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _contactInfoCtrl,
              decoration: const InputDecoration(
                labelText: 'Kontaktinformation',
                hintText: 'z.B. Telefon, E-Mail',
                prefixIcon: Icon(Icons.contact_phone_outlined),
              ),
              textInputAction: TextInputAction.done,
            ),

            const SizedBox(height: 32),

            // Submit button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _submit,
                icon: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(_loading ? 'Wird erstellt...' : 'Event erstellen'),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // -- Reusable builders --

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildCategorySelector() {
    final categories = EventCategoryConfig.categories;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: categories.entries.map((entry) {
        final config = entry.value;
        final isSelected = _selectedCategory == config.value;
        return ChoiceChip(
          label: Text('${config.emoji} ${config.label}'),
          selected: isSelected,
          onSelected: (_) => setState(() => _selectedCategory = config.value),
          selectedColor: AppColors.primary500,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isSelected ? AppColors.primary500 : AppColors.border,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDatePickerTile({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
    bool isMuted = false,
    VoidCallback? onClear,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primary500),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color:
                          isMuted ? AppColors.textMuted : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(
                  Icons.close,
                  size: 18,
                  color: AppColors.textMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleRow({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary500),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary500,
          ),
        ],
      ),
    );
  }
}
