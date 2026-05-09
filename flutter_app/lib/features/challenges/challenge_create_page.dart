import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/supabase.dart';
import '../../theme/app_colors.dart';

/// /dashboard/challenges/create — Pendant zu src/app/dashboard/challenges/create.
class ChallengeCreatePage extends ConsumerStatefulWidget {
  const ChallengeCreatePage({super.key});

  @override
  ConsumerState<ChallengeCreatePage> createState() =>
      _ChallengeCreatePageState();
}

class _ChallengeCreatePageState extends ConsumerState<ChallengeCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _maxParticipants = TextEditingController();

  String _category = 'community';
  String _difficulty = 'easy';
  int _points = 50;
  DateTime? _start;
  DateTime? _end;
  bool _saving = false;

  static const _categories = [
    (value: 'community', emoji: '🤝', label: 'Gemeinschaft'),
    (value: 'fitness', emoji: '🏃', label: 'Fitness'),
    (value: 'environment', emoji: '🌱', label: 'Umwelt'),
    (value: 'learning', emoji: '🎓', label: 'Lernen'),
    (value: 'creativity', emoji: '🎨', label: 'Kreativität'),
    (value: 'kindness', emoji: '💝', label: 'Mitgefühl'),
  ];

  static const _difficulties = [
    (value: 'easy', label: 'Einfach', icon: '🟢'),
    (value: 'medium', label: 'Mittel', icon: '🟡'),
    (value: 'hard', label: 'Schwer', icon: '🔴'),
  ];

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _maxParticipants.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final initial = isStart ? (_start ?? now) : (_end ?? _start ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _start = picked;
        } else {
          _end = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    if (_start == null || _end == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte Start und Ende wählen')),
      );
      return;
    }
    if (_end!.isBefore(_start!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ende muss nach dem Start liegen')),
      );
      return;
    }
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    try {
      final db = ref.read(supabaseProvider);
      final user = db.auth.currentUser;
      if (user == null) throw Exception('Nicht eingeloggt');
      final maxP = int.tryParse(_maxParticipants.text.trim());
      final row = await db.from('challenges').insert(<String, dynamic>{
        'creator_id': user.id,
        'title': _title.text.trim(),
        if (_description.text.trim().isNotEmpty)
          'description': _description.text.trim(),
        'category': _category,
        'difficulty': _difficulty,
        'points': _points,
        if (maxP != null) 'max_participants': maxP,
        'start_date': _start!.toIso8601String(),
        'end_date': _end!.toIso8601String(),
        'status': 'active',
      }).select('id').single();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Challenge erstellt')),
      );
      context.go('/dashboard/challenges/${row['id']}');
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
    final fmt = DateFormat('d. MMM yyyy', 'de');
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Challenge erstellen')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _Label('Titel *'),
            TextFormField(
              controller: _title,
              maxLength: 100,
              textCapitalization: TextCapitalization.sentences,
              decoration: _deco('z. B. 7-Tage-Müllsammel-Challenge'),
              validator: (v) =>
                  (v ?? '').trim().length < 5 ? 'Min. 5 Zeichen' : null,
            ),
            const SizedBox(height: 12),
            const _Label('Beschreibung'),
            TextFormField(
              controller: _description,
              maxLines: 4,
              maxLength: 500,
              decoration: _deco('Was sollen die Teilnehmer tun?'),
            ),
            const SizedBox(height: 12),
            const _Label('Kategorie *'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _categories
                  .map(
                    (c) => ChoiceChip(
                      label: Text('${c.emoji} ${c.label}'),
                      selected: _category == c.value,
                      onSelected: (_) =>
                          setState(() => _category = c.value),
                      selectedColor:
                          AppColors.primary500.withValues(alpha: 0.15),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            const _Label('Schwierigkeit *'),
            Row(
              children: _difficulties.map((d) {
                final selected = _difficulty == d.value;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _difficulty = d.value),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary500.withValues(alpha: 0.15)
                            : Colors.white,
                        border: Border.all(
                          color: selected
                              ? AppColors.primary500
                              : Colors.grey.shade300,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Text(d.icon, style: const TextStyle(fontSize: 18)),
                          const SizedBox(height: 2),
                          Text(
                            d.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: selected
                                  ? AppColors.primary500
                                  : AppColors.ink700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            _Label('Punkte: $_points'),
            Slider(
              value: _points.toDouble(),
              min: 10,
              max: 500,
              divisions: 49,
              activeColor: AppColors.primary500,
              onChanged: (v) => setState(() => _points = v.toInt()),
            ),
            const SizedBox(height: 4),
            const _Label('Max. Teilnehmer (optional)'),
            TextFormField(
              controller: _maxParticipants,
              keyboardType: TextInputType.number,
              decoration: _deco('z. B. 50'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('Start *'),
                      OutlinedButton.icon(
                        onPressed: () => _pickDate(isStart: true),
                        icon: const Icon(
                          Icons.calendar_today_outlined,
                          size: 14,
                        ),
                        label: Text(_start != null ? fmt.format(_start!) : 'Wählen'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor: Colors.white,
                          alignment: Alignment.centerLeft,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('Ende *'),
                      OutlinedButton.icon(
                        onPressed: () => _pickDate(isStart: false),
                        icon: const Icon(
                          Icons.calendar_today_outlined,
                          size: 14,
                        ),
                        label: Text(_end != null ? fmt.format(_end!) : 'Wählen'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor: Colors.white,
                          alignment: Alignment.centerLeft,
                        ),
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
                    : const Icon(Icons.flag_outlined),
                label: Text(_saving ? 'Erstelle…' : 'Challenge starten'),
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
