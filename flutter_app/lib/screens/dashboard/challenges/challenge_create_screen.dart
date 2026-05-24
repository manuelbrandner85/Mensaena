/// SKILL: mensaena-features
/// Challenge-Create-Screen — 1:1 zu Web /dashboard/challenges/create.
/// Felder: Titel, Beschreibung, Kategorie, Schwierigkeit, Punkte, Dauer.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../repositories/challenges_repository.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

class ChallengeCreateScreen extends ConsumerStatefulWidget {
  const ChallengeCreateScreen({super.key});

  @override
  ConsumerState<ChallengeCreateScreen> createState() =>
      _ChallengeCreateScreenState();
}

class _ChallengeCreateScreenState
    extends ConsumerState<ChallengeCreateScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  String _category = 'umwelt';
  String _difficulty = 'mittel';
  int _points = 50;
  int _days = 7;
  bool _busy = false;

  static const _categories = <String, String>{
    'umwelt': '🌱 Umwelt',
    'sozial': '🤝 Sozial',
    'fitness': '💪 Fitness',
    'bildung': '📚 Bildung',
    'kreativ': '🎨 Kreativ',
    'ernaehrung': '🥗 Ernährung',
    'gemeinschaft': '🏘️ Gemeinschaft',
  };

  static const _difficulties = <String, String>{
    'leicht': 'Leicht',
    'mittel': 'Mittel',
    'schwer': 'Schwer',
  };

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final id = await ChallengesRepository.create(
      title: _title.text,
      description: _desc.text,
      category: _category,
      difficulty: _difficulty,
      points: _points,
      durationDays: _days,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text('Challenge konnte nicht erstellt werden.',
            style: AppTypography.body(size: 13, color: AppColors.ink)),
      ));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.surface,
      content: Text('Challenge erstellt!',
          style: AppTypography.body(size: 13, color: AppColors.leben)),
    ));
    context.go('/dashboard/challenges');
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'Challenge erstellen',
      currentRoute: '/dashboard/challenges/create',
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Text('Neue Challenge',
                  style: AppTypography.display(
                      size: 22, color: AppColors.ink)),
              const SizedBox(height: 4),
              Text('Motiviere deine Nachbarschaft zu einer guten Sache.',
                  style: AppTypography.body(
                      size: 13, color: AppColors.mute)),
              const SizedBox(height: 20),
              TextFormField(
                controller: _title,
                style: AppTypography.body(size: 14, color: AppColors.ink),
                maxLength: 80,
                decoration: _input('Titel', 'z. B. 7 Tage plastikfrei'),
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.length < 5) return 'Mindestens 5 Zeichen.';
                  if (t.length > 80) return 'Maximal 80 Zeichen.';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _desc,
                style: AppTypography.body(size: 14, color: AppColors.ink),
                maxLength: 500,
                maxLines: 4,
                decoration: _input('Beschreibung (optional)',
                    'Worum geht es bei dieser Challenge?'),
              ),
              const SizedBox(height: 18),
              Text('Kategorie',
                  style: AppTypography.label(
                      size: 10, color: AppColors.mute)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.entries
                    .map((e) => _ChoiceChip(
                          label: e.value,
                          selected: _category == e.key,
                          onTap: () => setState(() => _category = e.key),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 18),
              Text('Schwierigkeit',
                  style: AppTypography.label(
                      size: 10, color: AppColors.mute)),
              const SizedBox(height: 8),
              Row(
                children: _difficulties.entries
                    .map((e) => Expanded(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4),
                            child: _ChoiceChip(
                              label: e.value,
                              selected: _difficulty == e.key,
                              onTap: () =>
                                  setState(() => _difficulty = e.key),
                              expanded: true,
                            ),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 18),
              _slider(
                label: 'Punkte für Teilnehmer:innen',
                value: _points.toDouble(),
                min: 10,
                max: 500,
                divisions: 49,
                suffix: ' P',
                onChanged: (v) => setState(() => _points = v.round()),
              ),
              const SizedBox(height: 12),
              _slider(
                label: 'Dauer',
                value: _days.toDouble(),
                min: 1,
                max: 90,
                divisions: 89,
                suffix: ' Tage',
                onChanged: (v) => setState(() => _days = v.round()),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _busy ? null : _submit,
                icon: _busy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.voidColor),
                      )
                    : const Icon(LucideIcons.trophy, size: 16),
                label: const Text('Challenge starten'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.amber,
                  foregroundColor: AppColors.voidColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _input(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: AppTypography.body(size: 13, color: AppColors.mute),
      hintStyle: AppTypography.body(size: 12, color: AppColors.mute),
      filled: true,
      fillColor: AppColors.elevated,
      counterStyle: AppTypography.label(size: 9, color: AppColors.mute),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.bronze),
      ),
    );
  }

  Widget _slider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String suffix,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label,
                  style: AppTypography.label(
                      size: 10, color: AppColors.mute)),
            ),
            Text('${value.round()}$suffix',
                style:
                    AppTypography.mono(size: 13, color: AppColors.bronze)),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          activeColor: AppColors.bronze,
          inactiveColor: AppColors.line,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.expanded = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.bronze : AppColors.line;
    final bg = selected
        ? AppColors.bronze.withValues(alpha: 0.18)
        : AppColors.elevated;
    final fg = selected ? AppColors.bronze : AppColors.inkSoft;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        alignment: expanded ? Alignment.center : null,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color),
        ),
        child: Text(label,
            style: AppTypography.body(
                size: 12,
                color: fg,
                weight: selected ? FontWeight.w700 : FontWeight.w500)),
      ),
    );
  }
}
